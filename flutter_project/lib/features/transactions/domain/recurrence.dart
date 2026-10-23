import '../../../core/utils/finance_utils.dart';

String monthKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-01';

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
    final futureAmounts =
        List<Map<String, dynamic>>.from(
          template['future_amounts'] as List? ?? [],
        )..sort(
          (a, b) =>
              a['from_month'].toString().compareTo(b['from_month'].toString()),
        );
    final months =
        (through.year - first.year) * 12 + through.month - first.month;
    if (months > 1200) throw StateError('Período de recorrência inválido.');
    for (var index = 0; index <= months; index++) {
      if (count != null && index >= count) break;
      final date = monthlyDueDate(first, index, day: dueDay);
      final key = monthKey(date);
      final change = changes['${rule['id']}:$key'];
      if (change?['is_deleted'] == true) continue;
      var plannedAmount = template['amount'];

      for (final value in futureAmounts) {
        if (value['from_month'].toString().compareTo(key) <= 0) {
          plannedAmount = value['amount'];
        }
      }
      // Pagamentos realizados permanecem no histórico após encerrar a regra.
      if (end != null && date.isAfter(end) && change?['is_paid'] != true) {
        continue;
      }
      result.add({
        ...template,
        'id': 'r:${rule['id']}:$key',
        'user_id': rule['user_id'],
        'amount': change?['amount'] ?? plannedAmount,
        'due_date': date.toIso8601String(),
        'is_paid': change?['is_paid'] == true,
        'is_recurrent': true,
        '_installment': index + 1,
        '_total_installments': count,
        '_last_due': count == null
            ? null
            : monthlyDueDate(first, count - 1, day: dueDay).toIso8601String(),
        'created_at': rule['created_at'],
      });
    }
  }
  return result;
}
