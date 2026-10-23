import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/finance_updates.dart';
import '../domain/finance_models.dart';
import '../domain/recurrence.dart';

abstract class FinanceRepository {
  Future<List<FinanceEntry>> transactions(DateTime through);
  Future<List<FinanceCategory>> categories(TransactionKind kind);
  Future<List<RecurrencePlan>> plans();
  Future<void> save(TransactionDraft draft);
  Future<void> markPaid(Set<String> ids);
  Future<void> markPending(Set<String> ids);
  Future<void> updateAmount(String id, double amount);
  Future<void> updateFutureAmount(String id, double amount);
  Future<void> stopPlan(String id);
  Future<void> deleteEntry(String id);
}

class SupabaseFinanceRepository implements FinanceRepository {
  SupabaseFinanceRepository(this._client, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final SupabaseClient _client;
  final DateTime Function() _now;
  static const _pageSize = 500;
  Future<_FinanceSnapshot>? _snapshotFuture;
  int _snapshotRevision = -1;
  String? _snapshotOwner;
  DateTime? _snapshotLoadedAt;

  Future<_FinanceSnapshot> _snapshot() async {
    final owner = _userId;
    final revision = financeRevision.value;
    final fresh =
        _snapshotLoadedAt != null &&
        _now().difference(_snapshotLoadedAt!) < const Duration(minutes: 2);
    if (_snapshotFuture == null ||
        _snapshotOwner != owner ||
        _snapshotRevision != revision ||
        !fresh) {
      _snapshotOwner = owner;
      _snapshotRevision = revision;
      _snapshotLoadedAt = _now();
      _snapshotFuture = _loadSnapshot();
    }
    final pending = _snapshotFuture!;
    try {
      return await pending;
    } catch (_) {
      if (identical(_snapshotFuture, pending)) _snapshotFuture = null;
      rethrow;
    }
  }

  Future<_FinanceSnapshot> _loadSnapshot() async {
    final parts = await Future.wait<Object>([
      _read('transactions', select: '*, category:categories(name)'),
      _read('recurrence_rules'),
      _read('recurrence_occurrences'),
      categories(TransactionKind.expense),
      categories(TransactionKind.income),
    ]);
    return _FinanceSnapshot(
      List<Map<String, dynamic>>.from(parts[0] as List),
      List<Map<String, dynamic>>.from(parts[1] as List),
      List<Map<String, dynamic>>.from(parts[2] as List),
      [
        ...parts[3] as List<FinanceCategory>,
        ...parts[4] as List<FinanceCategory>,
      ],
    );
  }

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Sua sessão terminou. Entre novamente.');
    return user.id;
  }

  Future<List<Map<String, dynamic>>> _read(
    String table, {
    String select = '*',
  }) async {
    final owner = _userId;
    final rows = <Map<String, dynamic>>[];
    var offset = 0;
    final occurrences = table == 'recurrence_occurrences';
    while (true) {
      final data = await _client
          .from(table)
          .select(select)
          .eq('user_id', owner)
          .order(occurrences ? 'due_month' : 'id')
          .order(occurrences ? 'rule_id' : 'created_at')
          .range(offset, offset + _pageSize - 1);
      final page = List<Map<String, dynamic>>.from(data);
      rows.addAll(page);
      if (page.length < _pageSize) return rows;
      offset += _pageSize;
    }
  }

  @override
  Future<List<FinanceCategory>> categories(TransactionKind kind) async {
    final rows = <FinanceCategory>[];
    var offset = 0;
    while (true) {
      final data = await _client
          .from('categories')
          .select('id, name')
          .eq('transaction_type', kind.categoryValue)
          .order('name')
          .order('id')
          .range(offset, offset + _pageSize - 1);
      rows.addAll(data.map(FinanceCategory.fromMap));
      if (data.length < _pageSize) return rows;
      offset += _pageSize;
    }
  }

  @override
  Future<List<RecurrencePlan>> plans() async =>
      (await _read('recurrence_rules')).map(RecurrencePlan.fromMap).toList();

  @override
  Future<List<FinanceEntry>> transactions(DateTime through) async {
    final snapshot = await _snapshot();
    final legacy = snapshot.transactions;
    final rules = snapshot.rules;
    final overrides = snapshot.occurrences;
    final categoryRows = snapshot.categories;
    final names = {
      for (final category in categoryRows) category.id: category.name,
    };
    final projected = projectRecurrences(rules, overrides, through);
    for (final row in projected) {
      row['category'] = {
        'name': names[row['category_id'].toString()] ?? 'Sem categoria',
      };
    }
    final today = _now();
    return [
      ...legacy,
      ...projected,
    ].map((row) => FinanceEntry.fromMap(row, today: today)).toList()..sort(
      (a, b) => (b.dueDate ?? DateTime(0)).compareTo(a.dueDate ?? DateTime(0)),
    );
  }

  @override
  Future<void> save(TransactionDraft draft) async {
    final owner = _userId;
    if (draft.isRecurring) {
      await _client.from('recurrence_rules').insert({
        'user_id': owner,
        'first_due': _date(draft.dueDate),
        'due_day': draft.dueDay,
        'total_installments': draft.totalInstallments,
        'template': draft.template,
      });
    } else {
      await _client.from('transactions').insert({
        ...draft.template,
        'user_id': owner,
        'due_date': _date(draft.dueDate),
        'is_recurrent': false,
        'is_paid': draft.alreadyConfirmed,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
    notifyFinanceChanged();
  }

  @override
  Future<void> markPaid(Set<String> ids) => _update(ids.toList(), isPaid: true);

  @override
  Future<void> markPending(Set<String> ids) =>
      _update(ids.toList(), isPaid: false);

  @override
  Future<void> updateAmount(String id, double amount) {
    if (!amount.isFinite || amount <= 0) {
      throw const FormatException('Informe um valor maior que zero.');
    }
    return _update([id], amount: amount);
  }

  @override
  Future<void> updateFutureAmount(String id, double amount) async {
    if (!amount.isFinite || amount <= 0) {
      throw const FormatException('Valor inválido.');
    }
    final reference = RecurrenceReference.fromEntryId(id);
    if (reference == null) {
      throw const FormatException('Conta sem recorrência mensal.');
    }
    await _client.rpc(
      'set_recurrence_future_amount',
      params: {
        'p_rule_id': reference.ruleId,
        'p_from_month': reference.databaseMonth,
        'p_amount': amount,
      },
    );
    notifyFinanceChanged();
  }

  Future<void> _update(List<String> ids, {bool? isPaid, double? amount}) async {
    if (ids.isEmpty) return;
    final owner = _userId;
    final legacy = <String>[];
    final recurring = <RecurrenceReference>[];
    for (final id in ids.toSet()) {
      final reference = RecurrenceReference.fromEntryId(id);
      if (reference == null) {
        legacy.add(id);
      } else {
        recurring.add(reference);
      }
    }
    try {
      if (legacy.isNotEmpty) {
        final updated = await _client
            .from('transactions')
            .update({
              if (isPaid != null) 'is_paid': isPaid,
              if (amount != null) 'amount': amount,
            })
            .eq('user_id', owner)
            .inFilter('id', legacy)
            .select('id');
        if (updated.length != legacy.length) {
          throw StateError(
            'Recarregue os lançamentos antes de tentar novamente.',
          );
        }
      }
      for (final reference in recurring) {
        await _client.rpc(
          'set_recurrence_occurrence',
          params: {
            'p_rule_id': reference.ruleId,
            'p_due_month': reference.databaseMonth,
            'p_is_paid': isPaid,
            'p_amount': amount,
          },
        );
      }
    } finally {
      // Recarrega também quando apenas parte do lote foi confirmada.
      notifyFinanceChanged();
    }
  }

  @override
  Future<void> deleteEntry(String id) async {
    _userId;
    if (id.isEmpty) throw const FormatException('Registro inválido.');
    RecurrenceReference.fromEntryId(id);
    await _client.rpc('delete_finance_entry', params: {'p_entry_id': id});
    notifyFinanceChanged();
  }

  @override
  Future<void> stopPlan(String id) async {
    _userId;
    await _client.rpc('stop_finance_plan', params: {'p_rule_id': id});
    notifyFinanceChanged();
  }

  String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

/// Apenas um conjunto de dados por conta/revisão, compartilhado entre consultas.
class _FinanceSnapshot {
  const _FinanceSnapshot(
    this.transactions,
    this.rules,
    this.occurrences,
    this.categories,
  );
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> rules;
  final List<Map<String, dynamic>> occurrences;
  final List<FinanceCategory> categories;
}
