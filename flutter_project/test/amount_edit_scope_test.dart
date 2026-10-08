import 'package:financafacil/features/transactions/domain/amount_edit_scope.dart';
import 'package:financafacil/features/transactions/domain/finance_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FinanceEntry entry(
          {bool paid = false,
          String id = 'r:salary:2026-12-01',
          int? count,
          int installment = 1,
          DateTime? last}) =>
      FinanceEntry(
          id: id,
          kind: TransactionKind.income,
          amount: 3000,
          description: 'Salário',
          dueDate: DateTime(2026, 12, 8),
          categoryName: 'Salário',
          isPaid: paid,
          isRecurring: true,
          installment: installment,
          totalInstallments: count,
          lastDue: last);
  test('salário recebido atualiza a partir do próximo mês e atravessa o ano',
      () {
    final target =
        futureAmountTarget(entry(paid: true), DateTime(2026, 12, 10))!;
    expect(target.id, 'r:salary:2027-01-01');
    expect(target.includesSelected, false);
  });
  test('renda pendente permite mês escolhido e seguintes', () {
    final target = futureAmountTarget(entry(), DateTime(2026, 12, 10))!;
    expect(target.id, 'r:salary:2026-12-01');
    expect(target.includesSelected, true);
  });
  test('mudança futura não reescreve meses passados', () {
    final target =
        futureAmountTarget(entry(paid: true), DateTime(2027, 3, 10))!;
    expect(target.id, 'r:salary:2027-03-01');
    expect(target.includesSelected, false);
  });
  test('avulso e última parcela recebida não oferecem mudança futura', () {
    expect(futureAmountTarget(entry(id: 'salary'), DateTime(2026, 12, 10)),
        isNull);
    expect(
        futureAmountTarget(entry(paid: true, count: 10, installment: 10),
            DateTime(2026, 12, 10)),
        isNull);
    expect(
        futureAmountTarget(entry(paid: true, last: DateTime(2026, 12, 8)),
            DateTime(2026, 12, 10)),
        isNull);
  });
}
