// Local-only models the Phase 0 manual entry screen builds in memory before
// (later) syncing to the backend. Cents-as-int to match the DB.

enum AccountType { checking, savings, creditCard }

extension AccountTypeX on AccountType {
  String get wire => switch (this) {
        AccountType.checking => 'checking',
        AccountType.savings => 'savings',
        AccountType.creditCard => 'credit_card',
      };
  String get label => switch (this) {
        AccountType.checking => 'Checking',
        AccountType.savings => 'Savings',
        AccountType.creditCard => 'Credit card',
      };
}

class AccountEntry {
  final String name;
  final AccountType type;
  final int balanceCents;
  final int? statementBalanceCents;
  final DateTime? statementCloseDate;
  final DateTime? dueDate;

  AccountEntry({
    required this.name,
    required this.type,
    required this.balanceCents,
    this.statementBalanceCents,
    this.statementCloseDate,
    this.dueDate,
  });
}

enum GoalKind { savings, expense, debt }

extension GoalKindX on GoalKind {
  String get wire => switch (this) {
        GoalKind.savings => 'savings',
        GoalKind.expense => 'expense',
        GoalKind.debt => 'debt',
      };
  String get label => switch (this) {
        GoalKind.savings => 'Savings',
        GoalKind.expense => 'Expense',
        GoalKind.debt => 'Debt',
      };
}

class GoalEntry {
  final String label;
  final int targetAmountCents;
  final DateTime? targetDate;
  final GoalKind kind;

  GoalEntry({
    required this.label,
    required this.targetAmountCents,
    this.targetDate,
    required this.kind,
  });
}
