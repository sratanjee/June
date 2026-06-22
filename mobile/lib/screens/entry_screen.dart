import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/entry.dart';
import '../storage/local_store.dart';
import '../theme.dart';
import 'accounts_screen.dart';
import 'chat_screen.dart';
import 'checkin_screen.dart';
import 'link_account_screen.dart';

class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  List<AccountEntry> _accounts = [];
  List<GoalEntry> _goals = [];
  List<PaycheckEntry> _paychecks = [];
  String? _userName;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    final stored = await LocalStore.load();
    final name = await LocalStore.loadUserName();
    if (!mounted) return;
    setState(() {
      _accounts = List.of(stored.accounts);
      _goals = List.of(stored.goals);
      _paychecks = List.of(stored.paychecks);
      _userName = name;
      _loaded = true;
    });
  }

  Future<void> _persist() {
    return LocalStore.save(
      accounts: _accounts,
      goals: _goals,
      paychecks: _paychecks,
    );
  }

  void _loadSample() {
    setState(() {
      _accounts = [
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
      _goals = [
        GoalEntry(
          label: 'Emergency fund',
          targetAmountCents: 750000,
          kind: GoalKind.savings,
        ),
      ];
      _paychecks = [
        PaycheckEntry(
          date: DateTime(2026, 6, 25),
          amountCents: 280000,
          recurrence: PaycheckRecurrence.biweekly,
        ),
      ];
    });
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('EEEE d MMMM').format(DateTime.now()).toLowerCase();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(
              date: today,
              onChat: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      accounts: _accounts,
                      goals: _goals,
                      paychecks: _paychecks,
                    ),
                  ),
                );
              },
              onAccounts: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AccountsScreen(),
                  ),
                );
                if (mounted) _hydrate();
              },
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
                physics: const BouncingScrollPhysics(),
                children: [
                  Text(
                    'Tell me what you have.',
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'A few accounts and a goal or two is enough to start. Add what feels right — nothing is permanent.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: JuneColors.neutralMuted,
                          height: 1.55,
                        ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: _loaded ? _loadSample : null,
                        icon:
                            const Icon(Icons.auto_fix_high_outlined, size: 16),
                        label: const Text('Try with sample data'),
                        style: TextButton.styleFrom(
                          foregroundColor: JuneColors.inkNavy,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          textStyle: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: JuneColors.hairline),
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LinkAccountScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.link_rounded, size: 16),
                        label: const Text('Link a bank instead'),
                        style: TextButton.styleFrom(
                          foregroundColor: JuneColors.inkNavy,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          textStyle: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: JuneColors.hairline),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _SectionHeader(
                    eyebrow: 'accounts',
                    count: _accounts.length,
                    onAdd: () async {
                      final entry = await _editAccount(context);
                      if (entry != null) {
                        setState(() => _accounts.add(entry));
                        _persist();
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  if (_accounts.isEmpty)
                    const _EmptyCard(
                      icon: Icons.account_balance_wallet_outlined,
                      text:
                          'Add a checking, savings, or credit card. Balances stay on this device for now.',
                    )
                  else
                    ..._accounts.map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _AccountTile(entry: a),
                        )),
                  const SizedBox(height: 36),
                  _SectionHeader(
                    eyebrow: 'paychecks',
                    count: _paychecks.length,
                    onAdd: () async {
                      final entry = await _editPaycheck(context);
                      if (entry != null) {
                        setState(() => _paychecks.add(entry));
                        _persist();
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  if (_paychecks.isEmpty)
                    const _EmptyCard(
                      icon: Icons.calendar_today_outlined,
                      text:
                          'Optional but recommended. Telling me when payday is helps June reason about timing balances.',
                    )
                  else
                    ..._paychecks.map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _PaycheckTile(entry: p),
                        )),
                  const SizedBox(height: 36),
                  _SectionHeader(
                    eyebrow: 'goals',
                    count: _goals.length,
                    onAdd: () async {
                      final entry = await _editGoal(context);
                      if (entry != null) {
                        setState(() => _goals.add(entry));
                        _persist();
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  if (_goals.isEmpty)
                    const _EmptyCard(
                      icon: Icons.flag_outlined,
                      text:
                          'Optional. One savings or debt goal helps me say something useful.',
                    )
                  else
                    ..._goals.map((g) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _GoalTile(entry: g),
                        )),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomCta(
        enabled: _accounts.isNotEmpty,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CheckInScreen(
                accounts: _accounts,
                goals: _goals,
                paychecks: _paychecks,
                userName: _userName,
                userInitials:
                    _userName == null ? null : initialsFromName(_userName!),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<AccountEntry?> _editAccount(BuildContext context) =>
      showModalBottomSheet<AccountEntry>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const _AccountForm(),
      );

  Future<GoalEntry?> _editGoal(BuildContext context) =>
      showModalBottomSheet<GoalEntry>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const _GoalForm(),
      );

  Future<PaycheckEntry?> _editPaycheck(BuildContext context) =>
      showModalBottomSheet<PaycheckEntry>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const _PaycheckForm(),
      );
}

class _TopBar extends StatelessWidget {
  final String date;
  final VoidCallback onChat;
  final VoidCallback onAccounts;
  const _TopBar({
    required this.date,
    required this.onChat,
    required this.onAccounts,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
          const Spacer(),
          _IconBtn(
            icon: Icons.chat_bubble_outline_rounded,
            tooltip: 'Chat with june',
            onTap: onChat,
          ),
          const SizedBox(width: 6),
          _IconBtn(
            icon: Icons.tune_rounded,
            tooltip: 'Manage accounts',
            onTap: onAccounts,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: JuneColors.paperShade,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              date,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: JuneColors.neutralMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 20, color: JuneColors.inkNavy),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String eyebrow;
  final int count;
  final VoidCallback onAdd;
  const _SectionHeader({
    required this.eyebrow,
    required this.count,
    required this.onAdd,
  });

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
        const Spacer(),
        InkWell(
          onTap: onAdd,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: JuneColors.inkNavy,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded,
                    color: JuneColors.paper, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Add',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: JuneColors.paper,
                  ),
                ),
              ],
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
      padding: const EdgeInsets.fromLTRB(16, 14, 18, 14),
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
      padding: const EdgeInsets.fromLTRB(16, 14, 18, 14),
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
      padding: const EdgeInsets.fromLTRB(16, 14, 18, 14),
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
            icon: const Icon(Icons.auto_awesome_outlined, size: 18),
            label: const Text("Generate today's check-in"),
          ),
        ),
      ),
    );
  }
}

// ----------------- bottom sheet forms -----------------

class _AccountForm extends StatefulWidget {
  const _AccountForm();
  @override
  State<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<_AccountForm> {
  final _name = TextEditingController();
  final _balance = TextEditingController();
  final _statementBalance = TextEditingController();
  AccountType _type = AccountType.checking;
  DateTime? _statementCloseDate;
  DateTime? _dueDate;

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    _statementBalance.dispose();
    super.dispose();
  }

  Future<void> _pickStatementClose() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _statementCloseDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _statementCloseDate = picked);
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final isCard = _type == AccountType.creditCard;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New account',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'A short name and the current balance is plenty.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          _SegmentedTypeSelector<AccountType>(
            options: AccountType.values
                .map((t) => (label: t.label, value: t))
                .toList(),
            selected: _type,
            onChanged: (t) => setState(() => _type = t),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Chase Checking',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _balance,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.-]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Balance',
              prefixText: '\$ ',
            ),
          ),
          if (isCard) ...[
            const SizedBox(height: 20),
            Text(
              'CARD DETAILS',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _statementBalance,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Statement balance',
                prefixText: '\$ ',
              ),
            ),
            const SizedBox(height: 12),
            _DateField(
              label: 'Statement close date',
              value: _statementCloseDate,
              onTap: _pickStatementClose,
            ),
            const SizedBox(height: 12),
            _DateField(
              label: 'Due date',
              value: _dueDate,
              onTap: _pickDueDate,
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              final balance = double.tryParse(_balance.text) ?? 0;
              final stmtBalance =
                  double.tryParse(_statementBalance.text);
              Navigator.of(context).pop(AccountEntry(
                name: _name.text.trim().isEmpty
                    ? _type.label
                    : _name.text.trim(),
                type: _type,
                balanceCents: (balance * 100).round(),
                statementBalanceCents: isCard && stmtBalance != null
                    ? (stmtBalance * 100).round()
                    : null,
                statementCloseDate: isCard ? _statementCloseDate : null,
                dueDate: isCard ? _dueDate : null,
              ));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _GoalForm extends StatefulWidget {
  const _GoalForm();
  @override
  State<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends State<_GoalForm> {
  final _label = TextEditingController();
  final _target = TextEditingController();
  GoalKind _kind = GoalKind.savings;

  @override
  void dispose() {
    _label.dispose();
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New goal',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'A label and a number you want to hit.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          _SegmentedTypeSelector<GoalKind>(
            options: GoalKind.values
                .map((k) => (label: k.label, value: k))
                .toList(),
            selected: _kind,
            onChanged: (k) => setState(() => _kind = k),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _label,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Goal',
              hintText: 'Emergency fund',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _target,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Target',
              prefixText: '\$ ',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(_target.text) ?? 0;
              Navigator.of(context).pop(GoalEntry(
                label: _label.text.trim().isEmpty
                    ? _kind.label
                    : _label.text.trim(),
                targetAmountCents: (amount * 100).round(),
                kind: _kind,
              ));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _PaycheckForm extends StatefulWidget {
  const _PaycheckForm();
  @override
  State<_PaycheckForm> createState() => _PaycheckFormState();
}

class _PaycheckFormState extends State<_PaycheckForm> {
  final _amount = TextEditingController();
  DateTime? _date;
  // null = one-time. We use a nullable selector below.
  PaycheckRecurrence? _recurrence;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    // "One-time" first, then the four cadences. value=null means one-time.
    final recurrenceOptions =
        <({String label, PaycheckRecurrence? value})>[
      (label: 'One-time', value: null),
      ...PaycheckRecurrence.values
          .map((r) => (label: r.label, value: r)),
    ];
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New paycheck',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'When is it landing and how much? Cadence is optional.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          _SegmentedTypeSelector<PaycheckRecurrence?>(
            options: recurrenceOptions,
            selected: _recurrence,
            onChanged: (r) => setState(() => _recurrence = r),
          ),
          const SizedBox(height: 16),
          _DateField(
            label: 'Date',
            value: _date,
            onTap: _pickDate,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: '\$ ',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(_amount.text) ?? 0;
              Navigator.of(context).pop(PaycheckEntry(
                date: _date ?? DateTime.now(),
                amountCents: (amount * 100).round(),
                recurrence: _recurrence,
              ));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text =
        value == null ? 'Pick a date' : DateFormat('EEE, MMM d, y').format(value!);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: value == null
                      ? JuneColors.neutralMuted
                      : JuneColors.inkNavy,
                ),
              ),
            ),
            const Icon(Icons.calendar_today_outlined,
                size: 16, color: JuneColors.neutralMuted),
          ],
        ),
      ),
    );
  }
}

class _SegmentedTypeSelector<T> extends StatelessWidget {
  final List<({String label, T value})> options;
  final T selected;
  final ValueChanged<T> onChanged;
  const _SegmentedTypeSelector({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: JuneColors.paperShade,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: options.map((opt) {
          final isSel = opt.value == selected;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(opt.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSel ? JuneColors.card : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isSel
                      ? Border.all(color: JuneColors.hairline)
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  opt.label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
                    color: isSel
                        ? JuneColors.inkNavy
                        : JuneColors.neutralMuted,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
