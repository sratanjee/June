import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/entry.dart';
import '../storage/local_store.dart';
import '../theme.dart';
import 'entry_screen.dart';
import 'link_account_screen.dart';

/// First-launch onboarding. Captures the user's first name, then offers either
/// "try with sample data" or "link a real bank" before handing off to the
/// EntryScreen. The name is persisted to LocalStore before navigating.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Step { name, firstMove }

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();
  final _nameFocus = FocusNode();
  _Step _step = _Step.name;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  String get _firstName {
    final t = _name.text.trim();
    if (t.isEmpty) return '';
    final parts = t.split(RegExp(r'\s+'));
    return parts.first;
  }

  void _toFirstMove() {
    if (_name.text.trim().isEmpty) return;
    _nameFocus.unfocus();
    setState(() => _step = _Step.firstMove);
  }

  Future<void> _completeWithSample() async {
    if (_busy) return;
    setState(() => _busy = true);
    final name = _name.text.trim();
    await LocalStore.saveUserName(name);
    await LocalStore.save(
      accounts: _sampleAccounts(),
      goals: _sampleGoals(),
      paychecks: _samplePaychecks(),
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const EntryScreen()),
    );
  }

  Future<void> _completeWithBank() async {
    if (_busy) return;
    setState(() => _busy = true);
    final name = _name.text.trim();
    await LocalStore.saveUserName(name);
    if (!mounted) return;
    // Replace this screen with the EntryScreen, then push the link flow on top
    // so the user lands back at EntryScreen after Plaid finishes (or skips).
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const EntryScreen()),
    );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LinkAccountScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(
                showBack: _step == _Step.firstMove,
                onBack: () => setState(() => _step = _Step.name),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _step == _Step.name ? _buildNameStep() : _buildMoveStep(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameStep() {
    final canContinue = _name.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'What should I call you?',
          style: Theme.of(context).textTheme.displayLarge,
        ),
        const SizedBox(height: 12),
        Text(
          'Just a first name. You can change it later.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: JuneColors.neutralMuted,
                height: 1.55,
              ),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _name,
          focusNode: _nameFocus,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => canContinue ? _toFirstMove() : null,
          decoration: const InputDecoration(
            labelText: 'Your name',
            hintText: 'Alex',
          ),
        ),
        const Spacer(),
        FilledButton(
          onPressed: canContinue ? _toFirstMove : null,
          child: const Text('Continue'),
        ),
      ],
    );
  }

  Widget _buildMoveStep() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        Text(
          'Nice to meet you, $_firstName.',
          style: Theme.of(context).textTheme.displayLarge,
        ),
        const SizedBox(height: 12),
        Text(
          "Let's see what June can do. Pick one — you can do the other later.",
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: JuneColors.neutralMuted,
                height: 1.55,
              ),
        ),
        const SizedBox(height: 28),
        _MoveCard(
          icon: Icons.auto_fix_high_outlined,
          title: 'Try with sample data',
          detail:
              'Loads a realistic check-in scenario so you can see how June sounds before you connect anything.',
          onTap: _busy ? null : _completeWithSample,
        ),
        const SizedBox(height: 12),
        _MoveCard(
          icon: Icons.account_balance_outlined,
          title: 'Link a real bank',
          detail:
              'Plaid Sandbox for now. user_good / pass_good works on any institution.',
          onTap: _busy ? null : _completeWithBank,
        ),
        if (_busy) ...[
          const SizedBox(height: 24),
          const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: JuneColors.inkNavy,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  final bool showBack;
  final VoidCallback onBack;
  const _TopBar({required this.showBack, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showBack)
          GestureDetector(
            onTap: onBack,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Icon(Icons.arrow_back_rounded,
                  size: 22, color: JuneColors.inkNavy),
            ),
          )
        else
          const SizedBox(width: 26, height: 28),
        const Spacer(),
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: JuneColors.inkNavy,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                'j',
                style: GoogleFonts.lora(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: JuneColors.paper,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'june',
              style: GoogleFonts.lora(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: JuneColors.inkNavy,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const Spacer(),
        const SizedBox(width: 26, height: 28),
      ],
    );
  }
}

class _MoveCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback? onTap;
  const _MoveCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          decoration: BoxDecoration(
            color: JuneColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: JuneColors.hairline),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: JuneColors.paperShade,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: JuneColors.inkNavy, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontSize: 16,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: JuneColors.neutralMuted,
                            height: 1.5,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Icon(Icons.chevron_right_rounded,
                    color: JuneColors.neutralMuted, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----- inline sample data (mirrors entry_screen.dart _loadSample) -----
// Kept here to avoid touching entry_screen.dart, which is owned by the main
// thread this phase. Keep in sync if the canonical set changes.

List<AccountEntry> _sampleAccounts() => [
      AccountEntry(
        name: 'Chase Checking',
        type: AccountType.checking,
        balanceCents: 48000,
      ),
      AccountEntry(
        name: 'Ally Savings',
        type: AccountType.savings,
        balanceCents: 410000,
      ),
      AccountEntry(
        name: 'Amex Gold',
        type: AccountType.creditCard,
        balanceCents: -128000,
        statementBalanceCents: 124000,
        statementCloseDate: DateTime(2026, 6, 18),
        dueDate: DateTime(2026, 7, 9),
      ),
    ];

List<GoalEntry> _sampleGoals() => [
      GoalEntry(
        label: 'Emergency fund',
        targetAmountCents: 750000,
        kind: GoalKind.savings,
      ),
    ];

List<PaycheckEntry> _samplePaychecks() => [
      PaycheckEntry(
        date: DateTime(2026, 6, 25),
        amountCents: 280000,
        recurrence: PaycheckRecurrence.biweekly,
      ),
    ];
