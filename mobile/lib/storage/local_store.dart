import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/entry.dart';

/// Small JSON-backed persistence for the Phase 0 manual entries.
/// Lists are written under three keys on SharedPreferences:
///   - `june.accounts`
///   - `june.goals`
///   - `june.paychecks`
///   - `june.user_name`
class LocalStore {
  static const _kAccounts = 'june.accounts';
  static const _kGoals = 'june.goals';
  static const _kPaychecks = 'june.paychecks';
  static const _kUserName = 'june.user_name';

  static String _dateToIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime? _isoToDate(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  static AccountType _accountTypeFromWire(String wire) {
    for (final t in AccountType.values) {
      if (t.wire == wire) return t;
    }
    return AccountType.checking;
  }

  static GoalKind _goalKindFromWire(String wire) {
    for (final k in GoalKind.values) {
      if (k.wire == wire) return k;
    }
    return GoalKind.savings;
  }

  static PaycheckRecurrence? _recurrenceFromWire(String? wire) {
    if (wire == null) return null;
    for (final r in PaycheckRecurrence.values) {
      if (r.wire == wire) return r;
    }
    return null;
  }

  static Map<String, dynamic> _accountToJson(AccountEntry a) => {
        'name': a.name,
        'type': a.type.wire,
        'balance_cents': a.balanceCents,
        'statement_balance_cents': a.statementBalanceCents,
        'statement_close_date':
            a.statementCloseDate == null ? null : _dateToIso(a.statementCloseDate!),
        'due_date': a.dueDate == null ? null : _dateToIso(a.dueDate!),
      };

  static AccountEntry _accountFromJson(Map<String, dynamic> m) => AccountEntry(
        name: (m['name'] as String?) ?? '',
        type: _accountTypeFromWire((m['type'] as String?) ?? 'checking'),
        balanceCents: (m['balance_cents'] as num?)?.toInt() ?? 0,
        statementBalanceCents:
            (m['statement_balance_cents'] as num?)?.toInt(),
        statementCloseDate: _isoToDate(m['statement_close_date'] as String?),
        dueDate: _isoToDate(m['due_date'] as String?),
      );

  static Map<String, dynamic> _goalToJson(GoalEntry g) => {
        'label': g.label,
        'target_amount_cents': g.targetAmountCents,
        'target_date': g.targetDate == null ? null : _dateToIso(g.targetDate!),
        'kind': g.kind.wire,
      };

  static GoalEntry _goalFromJson(Map<String, dynamic> m) => GoalEntry(
        label: (m['label'] as String?) ?? '',
        targetAmountCents: (m['target_amount_cents'] as num?)?.toInt() ?? 0,
        targetDate: _isoToDate(m['target_date'] as String?),
        kind: _goalKindFromWire((m['kind'] as String?) ?? 'savings'),
      );

  static Map<String, dynamic> _paycheckToJson(PaycheckEntry p) => {
        'date': _dateToIso(p.date),
        'amount_cents': p.amountCents,
        'recurrence': p.recurrence?.wire,
      };

  static PaycheckEntry _paycheckFromJson(Map<String, dynamic> m) =>
      PaycheckEntry(
        date: _isoToDate(m['date'] as String?) ?? DateTime.now(),
        amountCents: (m['amount_cents'] as num?)?.toInt() ?? 0,
        recurrence: _recurrenceFromWire(m['recurrence'] as String?),
      );

  static List<T> _decodeList<T>(
    String? raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (raw == null || raw.isEmpty) return <T>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <T>[];
      return decoded
          .whereType<Map>()
          .map((m) => fromJson(m.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return <T>[];
    }
  }

  static Future<
      ({
        List<AccountEntry> accounts,
        List<GoalEntry> goals,
        List<PaycheckEntry> paychecks,
      })> load() async {
    final prefs = await SharedPreferences.getInstance();
    final accounts =
        _decodeList<AccountEntry>(prefs.getString(_kAccounts), _accountFromJson);
    final goals =
        _decodeList<GoalEntry>(prefs.getString(_kGoals), _goalFromJson);
    final paychecks = _decodeList<PaycheckEntry>(
        prefs.getString(_kPaychecks), _paycheckFromJson);
    return (accounts: accounts, goals: goals, paychecks: paychecks);
  }

  static Future<void> save({
    required List<AccountEntry> accounts,
    required List<GoalEntry> goals,
    required List<PaycheckEntry> paychecks,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kAccounts, jsonEncode(accounts.map(_accountToJson).toList()));
    await prefs.setString(
        _kGoals, jsonEncode(goals.map(_goalToJson).toList()));
    await prefs.setString(
        _kPaychecks, jsonEncode(paychecks.map(_paycheckToJson).toList()));
  }

  /// Returns the stored first name, or null if onboarding hasn't completed.
  static Future<String?> loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUserName);
    if (raw == null) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Persists the user's display name. Trims whitespace.
  static Future<void> saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserName, name.trim());
  }

  /// Clears all known June keys. Dev convenience only.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccounts);
    await prefs.remove(_kGoals);
    await prefs.remove(_kPaychecks);
    await prefs.remove(_kUserName);
  }
}

/// Derive display initials from a name. Single word → first letter; multi-word
/// → first letter of each of the first 2 words. Empty input → 'T' (for "there").
String initialsFromName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'T';
  final parts =
      trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'T';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
}
