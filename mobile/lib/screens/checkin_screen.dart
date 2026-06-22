import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../api/june_client.dart';
import '../models/checkin.dart';
import '../models/entry.dart';
import '../storage/local_store.dart';
import '../theme.dart';

class CheckInScreen extends StatefulWidget {
  final List<AccountEntry> accounts;
  final List<GoalEntry> goals;
  final List<PaycheckEntry> paychecks;
  final String? userName;
  final String? userInitials;
  const CheckInScreen({
    super.key,
    required this.accounts,
    required this.goals,
    required this.paychecks,
    this.userName,
    this.userInitials,
  });

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  late Future<CheckIn> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<CheckIn> _fetch() async {
    final client = JuneClient();
    // Once a Plaid link exists, the backend has the canonical snapshot. Send
    // a null context so it loads from DB instead of using a stale local one.
    final hasLinkedBank = await LocalStore.loadHasLinkedBank();
    return client.generateCheckIn(
      today: DateTime.now(),
      context: hasLinkedBank ? null : _buildContext(),
    );
  }

  Future<void> _refresh() async {
    final next = _fetch();
    setState(() => _future = next);
    try {
      await next;
    } catch (_) {
      // Errors surface in the FutureBuilder; swallow here so RefreshIndicator
      // ends gracefully.
    }
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<CheckIn>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _Thinking();
            }
            if (snapshot.hasError) {
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.65,
                      child: _Error(message: _errorCopy(snapshot.error)),
                    ),
                  ],
                ),
              );
            }
            final name = (widget.userName == null ||
                    widget.userName!.trim().isEmpty)
                ? 'there'
                : widget.userName!.trim().split(' ').first;
            final initials = (widget.userInitials == null ||
                    widget.userInitials!.trim().isEmpty)
                ? initialsFromName(name)
                : widget.userInitials!.trim().toUpperCase();
            return RefreshIndicator(
              onRefresh: _refresh,
              child: _CheckInView(
                checkin: snapshot.data!,
                userName: name,
                userInitials: initials,
                onBack: () => Navigator.of(context).pop(),
                onRefresh: () => setState(() => _future = _fetch()),
              ),
            );
          },
        ),
      ),
    );
  }
}

String _errorCopy(Object? err) {
  if (err is JuneApiException && err.status == 400) {
    return "I couldn't read what you sent. Try entering an account again.";
  }
  return "I'm having trouble thinking this through. Try again in a moment.";
}

class _Thinking extends StatefulWidget {
  const _Thinking();

  @override
  State<_Thinking> createState() => _ThinkingState();
}

class _ThinkingState extends State<_Thinking> {
  static const _phrases = <String>[
    'reading your numbers',
    'thinking about your week',
    'looking at your card statement',
    'one moment',
  ];

  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % _phrases.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: JuneColors.paperShade,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: JuneColors.inkNavy,
              ),
            ),
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: Text(
              _phrases[_index],
              key: ValueKey(_index),
              style: GoogleFonts.lora(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: JuneColors.inkNavy,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('june is working',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _Error extends StatelessWidget {
  final String message;
  const _Error({required this.message});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Text(message,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center),
      ),
    );
  }
}

String _greetingForNow() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 18) return 'Good afternoon';
  return 'Good evening';
}

class _CheckInView extends StatelessWidget {
  final CheckIn checkin;
  final String userName;
  final String userInitials;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  const _CheckInView({
    required this.checkin,
    required this.userName,
    required this.userInitials,
    required this.onBack,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        DateFormat('EEEE, MMMM d').format(DateTime.now());

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [
        _Header(
          date: dateLabel,
          greeting: '${_greetingForNow()}, $userName',
          initials: userInitials,
          onBack: onBack,
          onRefresh: onRefresh,
        ),
        const SizedBox(height: 20),
        _StandingCard(text: checkin.standing),
        const SizedBox(height: 22),
        if (checkin.balances.isNotEmpty) ...[
          _BalanceGrid(lines: checkin.balances),
          const SizedBox(height: 24),
        ],
        Text(
          'What to do',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: JuneColors.inkNavy,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 12),
        if (checkin.actions.isEmpty)
          _ActionCard(
            action: ActionItem(
              title: "Nothing needs doing today.",
              detail: 'June will check back in tomorrow.',
              severity: 'ok',
            ),
          )
        else
          ...checkin.actions.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ActionCard(action: a),
              )),
        if (checkin.paycheckPlan != null) ...[
          const SizedBox(height: 28),
          Text(
            'Paycheck plan',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: JuneColors.inkNavy,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 12),
          _PaycheckPlanCard(plan: checkin.paycheckPlan!),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final String date;
  final String greeting;
  final String initials;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  const _Header({
    required this.date,
    required this.greeting,
    required this.initials,
    required this.onBack,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
            const Spacer(),
            GestureDetector(
              onTap: onRefresh,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.refresh_rounded,
                    size: 20, color: JuneColors.neutralMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: JuneColors.neutralMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    greeting,
                    style: GoogleFonts.lora(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: JuneColors.inkNavy,
                      letterSpacing: -0.4,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: JuneColors.inkNavy,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: JuneColors.paper,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

({String headline, String? body}) _splitStanding(String standing) {
  final trimmed = standing.trim();
  final match = RegExp(r'^(.+?[\.\!\?])\s+(.+)$', dotAll: true).firstMatch(trimmed);
  if (match == null) return (headline: trimmed, body: null);
  final headline = match.group(1)!.trim();
  final body = match.group(2)!.trim();
  if (headline.length < 16 || body.isEmpty) {
    return (headline: trimmed, body: null);
  }
  return (headline: headline, body: body);
}

class _StandingCard extends StatelessWidget {
  final String text;
  const _StandingCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final split = _splitStanding(text);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: JuneColors.inkNavy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  color: JuneColors.paper, size: 14),
              const SizedBox(width: 8),
              Text(
                "TODAY'S STANDING",
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: JuneColors.paper.withValues(alpha: 0.75),
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            split.headline,
            style: GoogleFonts.lora(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: JuneColors.paper,
              height: 1.25,
              letterSpacing: -0.3,
            ),
          ),
          if (split.body != null) ...[
            const SizedBox(height: 12),
            Text(
              split.body!,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: JuneColors.paper.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BalanceGrid extends StatelessWidget {
  final List<BalanceLine> lines;
  const _BalanceGrid({required this.lines});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final pillWidth = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: lines
              .map((b) => SizedBox(
                    width: pillWidth,
                    child: _BalancePill(line: b),
                  ))
              .toList(),
        );
      },
    );
  }
}

Color _amountColorForLabel(String label, num amount) {
  if (amount < 0) return JuneColors.inkNavy;
  final l = label.toLowerCase();
  if (l.contains('saving')) return JuneColors.sage;
  return JuneColors.inkNavy;
}

class _BalancePill extends StatelessWidget {
  final BalanceLine line;
  const _BalancePill({required this.line});

  @override
  Widget build(BuildContext context) {
    final amount = line.amount.round();
    final formatted = NumberFormat.decimalPattern().format(amount.abs());
    final color = _amountColorForLabel(line.label, line.amount);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: JuneColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: JuneColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            line.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: JuneColors.neutralMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${amount < 0 ? '-' : ''}\$$formatted',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: -0.4,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (line.subtext != null && line.subtext!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              line.subtext!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: JuneColors.neutralMuted,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final ActionItem action;
  const _ActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    final fg = severityColor(action.severity);
    final icon = switch (action.severity) {
      'ok' => Icons.shield_outlined,
      'attention' => Icons.error_outline_rounded,
      _ => Icons.schedule_rounded,
    };
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: JuneColors.hairline),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: fg),
              Expanded(
                child: Container(
                  color: JuneColors.card,
                  padding: const EdgeInsets.fromLTRB(14, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(icon, color: fg, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              action.title,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: JuneColors.inkNavy,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(left: 28),
                        child: Text(
                          action.detail,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: JuneColors.neutralMuted,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaycheckPlanCard extends StatelessWidget {
  final PaycheckPlan plan;
  const _PaycheckPlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final amount = plan.amount.round();
    final formattedAmount = NumberFormat.decimalPattern().format(amount);
    DateTime? parsed;
    try {
      parsed = DateTime.parse(plan.nextPaycheckDate);
    } catch (_) {}
    final dateLabel = parsed == null
        ? plan.nextPaycheckDate
        : DateFormat('EEEE, MMM d').format(parsed).toLowerCase();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: JuneColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: JuneColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateLabel,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text('\$$formattedAmount',
              style: GoogleFonts.lora(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: JuneColors.inkNavy,
                letterSpacing: -0.4,
              )),
          const SizedBox(height: 16),
          ...plan.allocations.map((a) {
            final v = a.amount.round();
            final f = NumberFormat.decimalPattern().format(v.abs());
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(a.label,
                        style: Theme.of(context).textTheme.bodyLarge),
                  ),
                  Text('\$$f',
                      style: Theme.of(context).textTheme.labelLarge),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
