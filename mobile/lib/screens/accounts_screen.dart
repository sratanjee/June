import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/entry.dart';
import '../storage/local_store.dart';
import '../theme.dart';
import 'link_account_screen.dart';

/// Read-and-remove management screen for the locally persisted accounts,
/// paychecks, and goals. Matches the visual language of EntryScreen but
/// surfaces a delete affordance on every row.
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  List<AccountEntry> _accounts = [];
  List<GoalEntry> _goals = [];
  List<PaycheckEntry> _paychecks = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    final stored = await LocalStore.load();
    if (!mounted) return;
    setState(() {
      _accounts = List.of(stored.accounts);
      _goals = List.of(stored.goals);
      _paychecks = List.of(stored.paychecks);
      _loaded = true;
    });
  }

  Future<void> _persist() => LocalStore.save(
        accounts: _accounts,
        goals: _goals,
        paychecks: _paychecks,
      );

  void _removeAccount(int i) {
    setState(() => _accounts.removeAt(i));
    _persist();
  }

  void _removePaycheck(int i) {
    setState(() => _paychecks.removeAt(i));
    _persist();
  }

  void _removeGoal(int i) {
    setState(() => _goals.removeAt(i));
    _persist();
  }

  Future<void> _openLinkBank() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LinkAccountScreen()),
    );
    // Re-hydrate when we come back, in case Plaid sync changed the local set.
    if (mounted) _hydrate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(onBack: () => Navigator.of(context).maybePop()),
            Expanded(
              child: !_loaded
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: JuneColors.inkNavy,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        Text(
                          'Your numbers',
                          style: Theme.of(context).textTheme.displayLarge,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Everything June is tracking right now. Remove anything that no longer fits.',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: JuneColors.neutralMuted,
                                    height: 1.55,
                                  ),
                        ),
                        const SizedBox(height: 28),
                        _SectionHeader(
                          eyebrow: 'accounts',
                          count: _accounts.length,
                        ),
                        const SizedBox(height: 14),
                        if (_accounts.isEmpty)
                          const _EmptyCard(
                            icon: Icons.account_balance_wallet_outlined,
                            text:
                                'No accounts yet. Link a bank below to bring some in.',
                          )
                        else
                          ..._accounts.asMap().entries.map((e) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _DismissibleTile(
                                  keyValue: 'account-${e.key}-${e.value.name}',
                                  onDelete: () => _removeAccount(e.key),
                                  child: _AccountTile(entry: e.value),
                                ),
                              )),
                        const SizedBox(height: 36),
                        _SectionHeader(
                          eyebrow: 'paychecks',
                          count: _paychecks.length,
                        ),
                        const SizedBox(height: 14),
                        if (_paychecks.isEmpty)
                          const _EmptyCard(
                            icon: Icons.calendar_today_outlined,
                            text:
                                "No paychecks logged. You can add one from the home screen.",
                          )
                        else
                          ..._paychecks.asMap().entries.map((e) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _DismissibleTile(
                                  keyValue:
                                      'paycheck-${e.key}-${e.value.date.toIso8601String()}',
                                  onDelete: () => _removePaycheck(e.key),
                                  child: _PaycheckTile(entry: e.value),
                                ),
                              )),
                        const SizedBox(height: 36),
                        _SectionHeader(
                          eyebrow: 'goals',
                          count: _goals.length,
                        ),
                        const SizedBox(height: 14),
                        if (_goals.isEmpty)
                          const _EmptyCard(
                            icon: Icons.flag_outlined,
                            text:
                                'No goals yet. Add one from the home screen when something feels worth chasing.',
                          )
                        else
                          ..._goals.asMap().entries.map((e) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _DismissibleTile(
                                  keyValue: 'goal-${e.key}-${e.value.label}',
                                  onDelete: () => _removeGoal(e.key),
                                  child: _GoalTile(entry: e.value),
                                ),
                              )),
                      ],
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomCta(
        enabled: _loaded,
        onTap: _openLinkBank,
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 20, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onBack,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.arrow_back_rounded,
                  size: 22, color: JuneColors.inkNavy),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'your numbers',
            style: GoogleFonts.lora(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: JuneColors.inkNavy,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String eyebrow;
  final int count;
  const _SectionHeader({required this.eyebrow, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: JuneColors.paperShade,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: JuneColors.neutralMuted,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: JuneColors.paperShade.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: JuneColors.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: JuneColors.paper,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: JuneColors.inkNavy, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: JuneColors.neutralMuted,
                      height: 1.45,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DismissibleTile extends StatelessWidget {
  final String keyValue;
  final VoidCallback onDelete;
  final Widget child;
  const _DismissibleTile({
    required this.keyValue,
    required this.onDelete,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(keyValue),
      direction: DismissDirection.endToStart,
      background: Container(
        padding: const EdgeInsets.only(right: 18),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: JuneColors.amberSurface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: JuneColors.amber, size: 22),
      ),
      onDismissed: (_) => onDelete(),
      child: Stack(
        children: [
          child,
          Positioned(
            top: 0,
            bottom: 0,
            right: 4,
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 18, color: JuneColors.neutralMuted),
                tooltip: 'Remove',
                onPressed: onDelete,
                splashRadius: 18,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

({Color tint, IconData icon}) _accountVisuals(AccountType t) {
  switch (t) {
    case AccountType.checking:
      return (tint: JuneColors.paperShade, icon: Icons.account_balance_outlined);
    case AccountType.savings:
      return (tint: JuneColors.sageSurface, icon: Icons.savings_outlined);
    case AccountType.creditCard:
      return (tint: JuneColors.amberSurface, icon: Icons.credit_card_outlined);
  }
}

({Color tint, IconData icon}) _goalVisuals(GoalKind k) {
  switch (k) {
    case GoalKind.savings:
      return (tint: JuneColors.sageSurface, icon: Icons.savings_outlined);
    case GoalKind.expense:
      return (tint: JuneColors.paperShade, icon: Icons.receipt_long_outlined);
    case GoalKind.debt:
      return (tint: JuneColors.amberSurface, icon: Icons.trending_down_rounded);
  }
}

class _AccountTile extends StatelessWidget {
  final AccountEntry entry;
  const _AccountTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final dollars = (entry.balanceCents / 100).round();
    final v = _accountVisuals(entry.type);
    final formatted = NumberFormat.decimalPattern().format(dollars.abs());
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 44, 14),
      decoration: BoxDecoration(
        color: JuneColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: JuneColors.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: v.tint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(v.icon, color: JuneColors.inkNavy, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name,
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 2),
                Text(entry.type.label,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          Text(
            '${dollars < 0 ? '-' : ''}\$$formatted',
            style: GoogleFonts.lora(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: JuneColors.inkNavy,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  final GoalEntry entry;
  const _GoalTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final dollars = (entry.targetAmountCents / 100).round();
    final v = _goalVisuals(entry.kind);
    final formatted = NumberFormat.decimalPattern().format(dollars);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 44, 14),
      decoration: BoxDecoration(
        color: JuneColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: JuneColors.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: v.tint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(v.icon, color: JuneColors.inkNavy, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.label,
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 2),
                Text(entry.kind.label,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          Text(
            '\$$formatted',
            style: GoogleFonts.lora(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: JuneColors.inkNavy,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaycheckTile extends StatelessWidget {
  final PaycheckEntry entry;
  const _PaycheckTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final dollars = (entry.amountCents / 100).round();
    final formatted = NumberFormat.decimalPattern().format(dollars.abs());
    final dateLabel =
        DateFormat('EEE, MMM d').format(entry.date).toLowerCase();
    final cadence = entry.recurrence?.label ?? 'One-time';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 44, 14),
      decoration: BoxDecoration(
        color: JuneColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: JuneColors.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: JuneColors.sageSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.calendar_today_outlined,
                color: JuneColors.inkNavy, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateLabel,
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 2),
                Text(cadence,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          Text(
            '\$$formatted',
            style: GoogleFonts.lora(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: JuneColors.inkNavy,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomCta extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _BottomCta({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: JuneColors.paper,
        border: Border(top: BorderSide(color: JuneColors.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: FilledButton.icon(
            onPressed: enabled ? onTap : null,
            icon: const Icon(Icons.add_link_rounded, size: 18),
            label: const Text('Link another bank'),
          ),
        ),
      ),
    );
  }
}
