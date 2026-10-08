import 'package:financafacil/features/transactions/domain/finance_models.dart';
import 'package:financafacil/features/transactions/domain/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> rule({int? count, String? end}) => {
      'id': 'rule-1',
      'user_id': 'user-1',
      'first_due': '2024-01-31',
      'total_installments': count,
      'end_date': end,
      'created_at': '2024-01-01',
      'template': {
        'amount': 500,
        'type': 'despesa',
        'description': 'Aluguel',
        'category_id': '1'
      },
    };

void main() {
  test('aluguel continua além de doze meses sem fim obrigatório', () {
    final rows = projectRecurrences([rule()], [], DateTime(2025, 3));
    expect(rows.length, 15);
    expect(rows.last['due_date'], '2025-03-31T00:00:00.000');
    expect(FinanceEntry.fromMap(rows.last).recurrenceDescription,
        'Mensal • sem data final');
  });
  test('vencimento 31 conserva o dia após fevereiro bissexto', () {
    final rows = projectRecurrences([rule()], [], DateTime(2024, 3));
    expect(rows[1]['due_date'], '2024-02-29T00:00:00.000');
    expect(rows[2]['due_date'], '2024-03-31T00:00:00.000');
  });
  test('fevereiro comum usa dia 28', () {
    final rows = projectRecurrences([rule()], [], DateTime(2025, 2));
    expect(rows.last['due_date'], '2025-02-28T00:00:00.000');
  });
  test('compra parcelada termina na quantidade informada', () {
    final rows = projectRecurrences([rule(count: 3)], [], DateTime(2026, 12));
    expect(rows.length, 3);
    expect(FinanceEntry.fromMap(rows.last).recurrenceDescription,
        'Parcela 3 de 3');
    expect(rows.first['_last_due'], '2024-03-31T00:00:00.000');
  });
  test('não antecipa parcelas além do mês consultado', () {
    expect(
        projectRecurrences([rule(count: 12)], [], DateTime(2024, 1)).length, 1);
    expect(projectRecurrences([rule()], [], DateTime(2023, 12)), isEmpty);
  });
  test('pagamento e valor alterado afetam somente a ocorrência correspondente',
      () {
    final rows = projectRecurrences([
      rule()
    ], [
      {
        'rule_id': 'rule-1',
        'due_month': '2024-02-01',
        'is_paid': true,
        'amount': 550
      },
    ], DateTime(2024, 3));
    expect(rows[0]['is_paid'], false);
    expect(rows[1]['is_paid'], true);
    expect(rows[1]['amount'], 550);
    expect(rows[2]['amount'], 500);
    expect(rows[2]['is_paid'], false);
    expect(rows.map((r) => r['id']).toSet().length, 3);
  });
  test(
      'encerramento remove previsões mas conserva pagamentos futuros já feitos',
      () {
    final rows = projectRecurrences([
      rule(end: '2024-02-29')
    ], [
      {'rule_id': 'rule-1', 'due_month': '2024-04-01', 'is_paid': true},
    ], DateTime(2024, 5));
    expect(rows.length, 3);
    expect(rows.last['due_date'], '2024-04-30T00:00:00.000');
    expect(rows.last['is_paid'], true);
  });
  test('mesma consulta produz mesmos identificadores e não modifica regra', () {
    final source = rule();
    final a = projectRecurrences([source], [], DateTime(2024, 2));
    final b = projectRecurrences([source], [], DateTime(2024, 2));
    expect(a, b);
    expect((source['template'] as Map).containsKey('id'), false);
  });
}
