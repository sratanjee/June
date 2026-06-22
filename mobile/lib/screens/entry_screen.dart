import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/entry.dart';
import '../theme.dart';
import 'checkin_screen.dart';

class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  final List<AccountEntry> _accounts = [];
  final List<GoalEntry> _goals = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('june', style: Theme.of(context).textTheme.headlineMedium),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            Text(
              'Tell me what you have.',
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'A few accounts and a goal or two is enough to start. Add what feels right.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            _SectionHeader(
              title: 'Accounts',
              onAdd: () async {
                final entry = await _editAccount(context);
                if (entry != null) setState(() => _accounts.add(entry));
              },
            ),
            const SizedBox(height: 8),
            ..._accounts.map((a) => _AccountTile(entry: a)),
            if (_accounts.isEmpty)
              const _EmptyHint(
                text:
                    'Nothing yet. Tap add to enter a checking, savings, or credit card.',
              ),
            const SizedBox(height: 32),
            _SectionHeader(
              title: 'Goals',
              onAdd: () async {
                final entry = await _editGoal(context);
                if (entry != null) setState(() => _goals.add(entry));
              },
            ),
            const SizedBox(height: 8),
            ..._goals.map((g) => _GoalTile(entry: g)),
            if (_goals.isEmpty)
              const _EmptyHint(
                text:
                    'Optional. One savings or debt goal helps me say something useful.',
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: ElevatedButton(
            onPressed: _accounts.isEmpty
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CheckInScreen(
                          accounts: _accounts,
                          goals: _goals,
                        ),
                      ),
                    );
                  },
            child: const Text('Generate today\'s check-in'),
          ),
        ),
      ),
    );
  }

  Future<AccountEntry?> _editAccount(BuildContext context) =>
      showModalBottomSheet<AccountEntry>(
        context: context,
        isScrollControlled: true,
        backgroundColor: JuneColors.paper,
        builder: (_) => const _AccountForm(),
      );

  Future<GoalEntry?> _editGoal(BuildContext context) =>
      showModalBottomSheet<GoalEntry>(
        context: context,
        isScrollControlled: true,
        backgroundColor: JuneColors.paper,
        builder: (_) => const _GoalForm(),
      );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onAdd;
  const _SectionHeader({required this.title, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const Spacer(),
        TextButton(
          onPressed: onAdd,
          child: const Text(
            'Add',
            style: TextStyle(color: JuneColors.inkNavy, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final AccountEntry entry;
  const _AccountTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final dollars = (entry.balanceCents / 100).round();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: JuneColors.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name, style: Theme.of(context).textTheme.labelLarge),
                Text(entry.type.label,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          Text('\$$dollars', style: Theme.of(context).textTheme.headlineMedium),
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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: JuneColors.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.label, style: Theme.of(context).textTheme.labelLarge),
                Text(entry.kind.label,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          Text('\$$dollars', style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
    );
  }
}

class _AccountForm extends StatefulWidget {
  const _AccountForm();
  @override
  State<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<_AccountForm> {
  final _name = TextEditingController();
  final _balance = TextEditingController();
  AccountType _type = AccountType.checking;

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add account',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<AccountType>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: AccountType.values
                .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                .toList(),
            onChanged: (t) => setState(() => _type = t ?? AccountType.checking),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _balance,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Balance (USD)',
              prefixText: '\$ ',
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              final balance = double.tryParse(_balance.text) ?? 0;
              Navigator.of(context).pop(AccountEntry(
                name: _name.text.trim().isEmpty ? 'Account' : _name.text.trim(),
                type: _type,
                balanceCents: (balance * 100).round(),
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
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add goal', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _label,
            decoration: const InputDecoration(labelText: 'Goal'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<GoalKind>(
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'Kind'),
            items: GoalKind.values
                .map((k) => DropdownMenuItem(value: k, child: Text(k.label)))
                .toList(),
            onChanged: (k) => setState(() => _kind = k ?? GoalKind.savings),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _target,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Target (USD)',
              prefixText: '\$ ',
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(_target.text) ?? 0;
              Navigator.of(context).pop(GoalEntry(
                label: _label.text.trim().isEmpty ? 'Goal' : _label.text.trim(),
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
