import 'package:financafacil/core/utils/finance_utils.dart';
import 'package:financafacil/features/transactions/domain/finance_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('valores BRL preservam milhares e centavos', () {
    expect(parseMoney(r'R$ 1.234,56'), 1234.56);
    expect(parseMoney('1234.56'), 1234.56);
    expect(parseMoney('10,50'), 10.5);
    for (final value in ['NaN', 'Infinity', '-10', '0', 'abc', '']) {
      expect(parseMoney(value), isNull, reason: value);
    }
  });
  test('recorrência conserva o mês, inclusive em ano bissexto', () {
    expect(monthlyDueDate(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
    expect(monthlyDueDate(DateTime(2024, 1, 31), 1), DateTime(2024, 2, 29));
    expect(monthlyDueDate(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 31));
    expect(monthlyDueDate(DateTime(2026, 1, 31), 2), DateTime(2026, 3, 31));
  });
  test('tipos antigos e atuais são interpretados da mesma forma', () {
    expect(TransactionKind.fromDatabase(' INCOME '), TransactionKind.income);
    expect(TransactionKind.fromDatabase('receita'), TransactionKind.income);
    expect(TransactionKind.fromDatabase('EXPENSE'), TransactionKind.expense);
  });
}
