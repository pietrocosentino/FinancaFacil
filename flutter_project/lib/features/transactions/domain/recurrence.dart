import '../../../core/utils/dates.dart';
import '../../../core/utils/finance_utils.dart';

/// Valor de uma regra mensal ao longo do tempo: valor base mais reajustes
/// registrados em `future_amounts` (cada um vale a partir de `from_month`).
class AmountSchedule {
  AmountSchedule(this.base, Iterable<Map<String, dynamic>> changes)
    : _changes = [...changes]
        ..sort(
          (a, b) =>
              a['from_month'].toString().compareTo(b['from_month'].toString()),
        );

  factory AmountSchedule.fromTemplate(Map<String, dynamic> template) =>
      AmountSchedule(
        template['amount'] as num,
        List<Map<String, dynamic>>.from(
          template['future_amounts'] as List? ?? const [],
        ),
      );

  final num base;
  final List<Map<String, dynamic>> _changes;

  /// Valor planejado para o mês identificado por [monthKey] (AAAA-MM-01).
  num at(String monthKey) {
    var amount = base;
    for (final change in _changes) {
      if (change['from_month'].toString().compareTo(monthKey) > 0) break;
      amount = change['amount'] as num;
    }
    return amount;
  }
}

/// Uma regra gera previsões em memória; nunca insere parcelas antecipadas.
List<Map<String, dynamic>> projectRecurrences(
  List<Map<String, dynamic>> rules,
  List<Map<String, dynamic>> overrides,
  DateTime through,
) {
  final changes = {
    for (final item in overrides)
      '${item['rule_id']}:${item['due_month']}': item,
  };
  final result = <Map<String, dynamic>>[];
  for (final rule in rules) {
    final first = DateTime.parse(rule['first_due'].toString());
    final end = DateTime.tryParse(rule['end_date']?.toString() ?? '');
    final dueDay = (rule['due_day'] as num?)?.toInt() ?? first.day;
    final count = (rule['total_installments'] as num?)?.toInt();
    final template = Map<String, dynamic>.from(rule['template'] as Map);
    final schedule = AmountSchedule.fromTemplate(template);
    final lastDue = count == null
        ? null
        : monthlyDueDate(first, count - 1, day: dueDay).toIso8601String();
    final months =
        (through.year - first.year) * 12 + through.month - first.month;
    if (months > 1200) throw StateError('Período de recorrência inválido.');
    for (var index = 0; index <= months; index++) {
      if (count != null && index >= count) break;
      final date = monthlyDueDate(first, index, day: dueDay);
      final key = monthKey(date);
      final change = changes['${rule['id']}:$key'];
      if (change?['is_deleted'] == true) continue;
      // Pagamentos realizados permanecem no histórico após encerrar a regra.
      if (end != null && date.isAfter(end) && change?['is_paid'] != true) {
        continue;
      }
      result.add({
        ...template,
        'id': 'r:${rule['id']}:$key',
        'user_id': rule['user_id'],
        'amount': change?['amount'] ?? schedule.at(key),
        'due_date': date.toIso8601String(),
        'is_paid': change?['is_paid'] == true,
        'is_recurrent': true,
        '_installment': index + 1,
        '_total_installments': count,
        '_last_due': lastDue,
        '_manual_receipt': change?['manual_receipt'] == true,
        'created_at': rule['created_at'],
      });
    }
  }
  return result;
}
