import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../api/june_client.dart';
import '../models/chat.dart';
import '../models/entry.dart';
import '../theme.dart';

// Full-screen chat surface for talking to june. Mirrors the context-building
// pattern in CheckInScreen so the backend gets the same snapshot it's already
// reasoning over.
class ChatScreen extends StatefulWidget {
  final List<AccountEntry> accounts;
  final List<GoalEntry> goals;
  final List<PaycheckEntry> paychecks;
  const ChatScreen({
    super.key,
    required this.accounts,
    required this.goals,
    required this.paychecks,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messages = <ChatMessage>[];
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocus = FocusNode();
  final _client = JuneClient();

  StreamSubscription<ChatStreamEvent>? _sub;
  bool _streaming = false;
  // True once june has replied at least once — used to keep quick-reply chips
  // available after the empty state goes away.
  bool _hasJuneReply = false;

  static const _quickReplies = <String>[
    'How am I doing?',
    'Can I afford a \$200 dinner?',
    'When\'s my next paycheck land?',
    'Help me catch up on savings',
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      // Rebuild so the send button enables/disables as the field fills.
      setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // Replicates CheckInScreen._buildContext so the backend can use the same
  // prompt-context shape it already understands. Keep in sync if that one
  // grows new fields.
  Map<String, dynamic> _buildContext() {
    return {
      'accounts': widget.accounts
          .map((a) => {
                'name': a.name,
                'type': a.type.wire,
                'balance_cents': a.balanceCents,
              })
          .toList(),
      'cards': widget.accounts
          .where((a) =>
              a.type == AccountType.creditCard &&
              (a.statementBalanceCents != null ||
                  a.statementCloseDate != null ||
                  a.dueDate != null))
          .map((a) => {
                'account_name': a.name,
                'statement_close_date': a.statementCloseDate == null
                    ? null
                    : _isoDate(a.statementCloseDate!),
                'due_date':
                    a.dueDate == null ? null : _isoDate(a.dueDate!),
                'statement_balance_cents': a.statementBalanceCents ?? 0,
                'current_balance_cents': a.balanceCents,
              })
          .toList(),
      'transactions': <Map<String, dynamic>>[],
      'goals': widget.goals
          .map((g) => {
                'label': g.label,
                'target_amount_cents': g.targetAmountCents,
                'target_date':
                    g.targetDate == null ? null : _isoDate(g.targetDate!),
                'kind': g.kind.wire,
                'priority': 0,
              })
          .toList(),
      'paychecks': widget.paychecks
          .map((p) => {
                'date': _isoDate(p.date),
                'amount_cents': p.amountCents,
                'recurrence': p.recurrence?.wire,
              })
          .toList(),
      'budget_targets': <Map<String, dynamic>>[],
    };
  }

  void _scrollToBottom() {
    // Defer one frame so the new bubble is laid out before we measure extent.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _streaming) return;

    // Build the history snapshot the backend wants BEFORE we append the new
    // turn — `message` is sent separately on the wire.
    final history = List<ChatMessage>.from(_messages);

    setState(() {
      _messages.add(ChatMessage(role: ChatRole.user, text: text));
      _messages.add(
        ChatMessage(role: ChatRole.june, text: '', streaming: true),
      );
      _streaming = true;
      _controller.clear();
    });
    _scrollToBottom();

    final juneIndex = _messages.length - 1;

    _sub = _client
        .streamChat(
      userId: demoUserId,
      today: DateTime.now(),
      context: _buildContext(),
      history: history,
      message: text,
    )
        .listen(
      (event) {
        if (!mounted) return;
        if (event is ChatDelta) {
          setState(() {
            final current = _messages[juneIndex];
            _messages[juneIndex] =
                current.copyWith(text: current.text + event.text);
          });
          _scrollToBottom();
        } else if (event is ChatDone) {
          setState(() {
            _messages[juneIndex] =
                _messages[juneIndex].copyWith(streaming: false);
            _streaming = false;
            _hasJuneReply = true;
          });
        } else if (event is ChatErrorEvent) {
          setState(() {
            _messages[juneIndex] = _messages[juneIndex].copyWith(
              streaming: false,
              errorText:
                  "I'm having trouble thinking this through. Try again in a moment.",
            );
            _streaming = false;
          });
        }
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _messages[juneIndex] = _messages[juneIndex].copyWith(
            streaming: false,
            errorText:
                "I'm having trouble thinking this through. Try again in a moment.",
          );
          _streaming = false;
        });
      },
      onDone: () {
        // Safety net — if the stream closes without ChatDone (e.g. abrupt
        // disconnect after some text), flip the streaming flag off.
        if (!mounted) return;
        if (_streaming) {
          setState(() {
            _messages[juneIndex] =
                _messages[juneIndex].copyWith(streaming: false);
            _streaming = false;
            _hasJuneReply = true;
          });
        }
      },
    );
  }

  void _onChipTap(String text) {
    if (_streaming) return;
    _controller.text = text;
    _send(text);
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        DateFormat('EEEE, MMMM d').format(DateTime.now()).toLowerCase();
    final showChips = _messages.isEmpty || _hasJuneReply;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              date: dateLabel,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: _messages.isEmpty
                  ? const _EmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding:
                          const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final m = _messages[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: _Bubble(message: m),
                        );
                      },
                    ),
            ),
            if (showChips)
              _QuickReplies(
                replies: _quickReplies,
                disabled: _streaming,
                onTap: _onChipTap,
              ),
            _InputBar(
              controller: _controller,
              focusNode: _inputFocus,
              enabled: !_streaming,
              onSend: () => _send(_controller.text),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String date;
  final VoidCallback onBack;
  const _Header({required this.date, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onBack,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Icon(Icons.arrow_back_rounded,
                  size: 22, color: JuneColors.inkNavy),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'chat with june',
                  style: GoogleFonts.lora(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: JuneColors.inkNavy,
                    letterSpacing: -0.3,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: JuneColors.neutralMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "What's on your mind?",
              textAlign: TextAlign.center,
              style: GoogleFonts.lora(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: JuneColors.inkNavy,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "she's read your numbers.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: JuneColors.neutralMuted,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isJune = message.role == ChatRole.june;
    final maxWidth = MediaQuery.of(context).size.width * 0.8;

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: isJune ? JuneColors.inkNavy : JuneColors.paperShade,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(14),
          topRight: const Radius.circular(14),
          // Anchor the bubble on the side it came from.
          bottomLeft:
              Radius.circular(isJune ? 4 : 14),
          bottomRight:
              Radius.circular(isJune ? 14 : 4),
        ),
      ),
      child: isJune
          ? _JuneBubbleBody(message: message)
          : Text(
              message.text,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: JuneColors.inkNavy,
                height: 1.4,
              ),
            ),
    );

    return Column(
      crossAxisAlignment:
          isJune ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        bubble,
        if (message.errorText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              message.errorText!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: JuneColors.neutralMuted,
                height: 1.35,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _JuneBubbleBody extends StatelessWidget {
  final ChatMessage message;
  const _JuneBubbleBody({required this.message});

  @override
  Widget build(BuildContext context) {
    // Lora serif on inkNavy, paper-color text. Matches _StandingCard.
    final textStyle = GoogleFonts.lora(
      fontSize: 16,
      color: JuneColors.paper,
      height: 1.45,
      fontWeight: FontWeight.w400,
    );

    // Empty + streaming = show just the pulsing dot so the bubble doesn't
    // appear blank while we wait for the first delta.
    if (message.text.isEmpty && message.streaming) {
      return const _PulsingDot();
    }

    if (!message.streaming) {
      return Text(message.text, style: textStyle);
    }

    // Streaming with content: text plus inline dot at the end.
    return RichText(
      text: TextSpan(
        style: textStyle,
        children: [
          TextSpan(text: message.text),
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.only(left: 6),
              child: _PulsingDot(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1.0).animate(_ac),
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: JuneColors.paper,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _QuickReplies extends StatelessWidget {
  final List<String> replies;
  final bool disabled;
  final void Function(String) onTap;
  const _QuickReplies({
    required this.replies,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final r in replies) ...[
              _Chip(label: r, disabled: disabled, onTap: () => onTap(r)),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool disabled;
  final VoidCallback onTap;
  const _Chip({
    required this.label,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(100),
        splashColor: JuneColors.paperShade,
        highlightColor: JuneColors.paperShade,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: JuneColors.hairline),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: disabled
                  ? JuneColors.neutralMuted
                  : JuneColors.inkNavy,
            ),
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final VoidCallback onSend;
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.trim().isNotEmpty;
    final canSend = enabled && hasText;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) {
                if (canSend) onSend();
              },
              style: GoogleFonts.inter(
                fontSize: 15,
                color: JuneColors.inkNavy,
                height: 1.4,
              ),
              decoration: InputDecoration(
                hintText: 'Ask june...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 15,
                  color: JuneColors.neutralMuted,
                ),
                filled: true,
                fillColor: JuneColors.card,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: JuneColors.hairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: JuneColors.hairline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: JuneColors.inkNavy, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _SendButton(enabled: canSend, onTap: onSend),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _SendButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'send',
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: enabled ? JuneColors.inkNavy : JuneColors.paperShade,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.arrow_upward_rounded,
            size: 20,
            color: enabled ? JuneColors.paper : JuneColors.neutralMuted,
          ),
        ),
      ),
    );
  }
}
