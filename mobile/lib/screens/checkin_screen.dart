import 'package:flutter/material.dart';

import '../api/june_client.dart';
import '../models/checkin.dart';
import '../models/entry.dart';
import '../theme.dart';

class CheckInScreen extends StatefulWidget {
  final List<AccountEntry> accounts;
  final List<GoalEntry> goals;
  const CheckInScreen({super.key, required this.accounts, required this.goals});

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

  Future<CheckIn> _fetch() {
    final client = JuneClient();
    // Phase 0: no auth/users; the API takes inline context.
    // See backend/src/schemas.ts → InlineFinancialContext.
    return client.generateCheckIn(
      today: DateTime.now(),
      context: _buildContext(),
    );
  }

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
                'statement_close_date':
                    a.statementCloseDate?.toIso8601String().substring(0, 10),
                'due_date': a.dueDate?.toIso8601String().substring(0, 10),
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
                    g.targetDate?.toIso8601String().substring(0, 10),
                'kind': g.kind.wire,
                'priority': 0,
              })
          .toList(),
      'budget_targets': <Map<String, dynamic>>[],
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('today',
            style: Theme.of(context).textTheme.headlineMedium),
      ),
      body: SafeArea(
        child: FutureBuilder<CheckIn>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _Thinking();
            }
            if (snapshot.hasError) {
              return _Error(message: _errorCopy(snapshot.error));
            }
            final c = snapshot.data!;
            return _CheckInView(checkin: c);
          },
        ),
      ),
    );
  }
}

// June's voice for failure modes, per personality spec §7.
String _errorCopy(Object? err) {
  if (err is JuneApiException && err.status == 400) {
    return 'I couldn\'t read what you sent. Try entering an account again.';
  }
  return "I'm having trouble thinking this through. Try again in a moment.";
}

class _Thinking extends StatelessWidget {
  const _Thinking();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: JuneColors.inkNavy,
            ),
          ),
          const SizedBox(height: 16),
          Text('reading your numbers',
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
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(message,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center),
      ),
    );
  }
}

class _CheckInView extends StatelessWidget {
  final CheckIn checkin;
  const _CheckInView({required this.checkin});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(checkin.standing,
            style: Theme.of(context).textTheme.displayLarge),
        const SizedBox(height: 32),
        if (checkin.balances.isNotEmpty) ...[
          Text('balances',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          ...checkin.balances.map((b) => _BalanceRow(line: b)),
          const SizedBox(height: 32),
        ],
        if (checkin.actions.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: JuneColors.hairline),
            ),
            child: Text(
              'Nothing needs doing today.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          )
        else ...[
          Text('today',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          ...checkin.actions.map((a) => _ActionCard(action: a)),
        ],
        if (checkin.paycheckPlan != null) ...[
          const SizedBox(height: 32),
          Text('paycheck plan',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          _PaycheckPlanCard(plan: checkin.paycheckPlan!),
        ],
      ],
    );
  }
}

class _BalanceRow extends StatelessWidget {
  final BalanceLine line;
  const _BalanceRow({required this.line});

  @override
  Widget build(BuildContext context) {
    final amount = line.amount.round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.label,
                    style: Theme.of(context).textTheme.labelLarge),
                if (line.subtext != null && line.subtext!.isNotEmpty)
                  Text(line.subtext!,
                      style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          Text('\$$amount',
              style: Theme.of(context).textTheme.headlineMedium),
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
    final color = severityColor(action.severity);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(action.title,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: JuneColors.inkNavy)),
          const SizedBox(height: 4),
          Text(action.detail,
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _PaycheckPlanCard extends StatelessWidget {
  final PaycheckPlan plan;
  const _PaycheckPlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: JuneColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Next paycheck on ${plan.nextPaycheckDate} — \$${plan.amount.round()}',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 12),
          ...plan.allocations.map(
            (a) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(a.label,
                        style: Theme.of(context).textTheme.bodyLarge),
                  ),
                  Text('\$${a.amount.round()}',
                      style: Theme.of(context).textTheme.labelLarge),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
