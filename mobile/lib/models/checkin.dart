// Hand-written Dart models matching the Zod schemas in backend/src/schemas.ts.
// Single source of truth is the backend; this is the mirror.

/// A coarse mood label produced server-side from the day's check-in.
/// Drives the status pill on the entry screen.
enum Feeling { green, attention, quiet }

Feeling? _parseFeeling(dynamic raw) {
  if (raw is! String) return null;
  switch (raw) {
    case 'green':
      return Feeling.green;
    case 'attention':
      return Feeling.attention;
    case 'quiet':
      return Feeling.quiet;
    default:
      return null;
  }
}

class CheckIn {
  final String standing;
  final List<BalanceLine> balances;
  final List<ActionItem> actions;
  final PaycheckPlan? paycheckPlan;
  // Server-set mood label. Only populated by /checkin/latest today; the
  // legacy /checkin/generate response may omit it, in which case this stays
  // null and the UI treats it as "no pill".
  final Feeling? feeling;

  CheckIn({
    required this.standing,
    required this.balances,
    required this.actions,
    this.paycheckPlan,
    this.feeling,
  });

  factory CheckIn.fromJson(Map<String, dynamic> json) {
    return CheckIn(
      standing: json['standing'] as String,
      balances: (json['balances'] as List<dynamic>)
          .map((e) => BalanceLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      actions: (json['actions'] as List<dynamic>)
          .map((e) => ActionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      paycheckPlan: json['paycheck_plan'] == null
          ? null
          : PaycheckPlan.fromJson(json['paycheck_plan'] as Map<String, dynamic>),
      feeling: _parseFeeling(json['feeling']),
    );
  }
}

class BalanceLine {
  final String label;
  final num amount;
  final String? subtext;

  BalanceLine({required this.label, required this.amount, this.subtext});

  factory BalanceLine.fromJson(Map<String, dynamic> json) => BalanceLine(
        label: json['label'] as String,
        amount: json['amount'] as num,
        subtext: json['subtext'] as String?,
      );
}

class ActionItem {
  final String title;
  final String detail;
  final String severity; // 'ok' | 'attention' | 'info'

  ActionItem({
    required this.title,
    required this.detail,
    required this.severity,
  });

  factory ActionItem.fromJson(Map<String, dynamic> json) => ActionItem(
        title: json['title'] as String,
        detail: json['detail'] as String,
        severity: json['severity'] as String,
      );
}

class PaycheckPlan {
  final String nextPaycheckDate;
  final num amount;
  final List<Allocation> allocations;

  PaycheckPlan({
    required this.nextPaycheckDate,
    required this.amount,
    required this.allocations,
  });

  factory PaycheckPlan.fromJson(Map<String, dynamic> json) => PaycheckPlan(
        nextPaycheckDate: json['next_paycheck_date'] as String,
        amount: json['amount'] as num,
        allocations: (json['allocations'] as List<dynamic>)
            .map((e) => Allocation.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class Allocation {
  final String label;
  final num amount;
  Allocation({required this.label, required this.amount});

  factory Allocation.fromJson(Map<String, dynamic> json) => Allocation(
        label: json['label'] as String,
        amount: json['amount'] as num,
      );
}
