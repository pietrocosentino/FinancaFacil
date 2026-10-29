import 'package:financafacil/features/dashboard/domain/finance_summary.dart';
import 'package:financafacil/features/imports/data/xlsx_import_reader.dart';
import 'package:financafacil/features/imports/domain/import_models.dart';
import 'package:financafacil/features/transactions/data/finance_repository.dart';
import 'package:financafacil/features/transactions/domain/finance_models.dart';
import 'package:financafacil/features/transactions/domain/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_supabase_backend.dart';
import 'support/import_workbook_fixture.dart';

void main() {
  test('500 linhas Excel preservam centavos; 501 são rejeitadas', () {
    final reader = XlsxImportReader();
    final rows = List.generate(500, (i) => validRow(i + 2)).join();
    final parsed = reader.read(workbook(header + rows));
    expect(parsed.length, 500);
    expect(parsed.every((r) => r.amount == 90.6 && r.months == 10), true);
    expect(
      () => reader.read(workbook(header + rows + validRow(502))),
      throwsFormatException,
    );
  });
  test('100 mil lançamentos somam centavos sem perder precisão', () {
    final entries = List.generate(
      100000,
      (i) => FinanceEntry(
        id: '$i',
        kind: i.isEven ? TransactionKind.income : TransactionKind.expense,
        amount: 0.01,
        description: 'Massa $i',
        dueDate: DateTime(2026, 10, 8),
        categoryName: 'Teste',
        isPaid: true,
      ),
    );
    final result = FinanceSummary.forMonth(entries, DateTime(2026, 10));
    expect(result.income, 500);
    expect(result.expenses, 500);
    expect(result.availableBalance, 0);
    expect(result.expensesByCategory['Teste'], 500);
  });
  test('100 consultas simultâneas fazem somente cinco leituras', () async {
    final backend = FakeSupabaseBackend();
    try {
      await backend.authenticate();
      final repository = SupabaseFinanceRepository(backend.client);
      await Future.wait(
        List.generate(100, (i) => repository.transactions(DateTime(2026, 10))),
      );
      expect(backend.requests.length, 5);
    } finally {
      await backend.dispose();
    }
  });
  test('recorrência de 1200 parcelas tem IDs únicos e datas válidas', () {
    final rules = [
      <String, dynamic>{
        'id': 'volume',
        'user_id': 'owner',
        'first_due': '2020-01-31',
        'due_day': 31,
        'total_installments': 1200,
        'template': {'amount': 90.6, 'type': 'receita'},
      },
    ];
    final result = projectRecurrences(rules, [], DateTime(2119, 12));
    expect(result.length, 1200);
    expect(result.map((r) => r['id']).toSet().length, 1200);
    expect(
      result.every((r) => DateTime.parse(r['due_date'] as String).day >= 28),
      true,
    );
    expect(
      () => projectRecurrences(rules, [], DateTime(2121, 1)),
      throwsStateError,
    );
  });
  test('calendário completo 2020–2100 rejeita dia além do mês', () {
    for (var year = 2020; year <= 2100; year++) {
      for (var month = 1; month <= 12; month++) {
        final last = DateTime(year, month + 1, 0).day;
        for (var day = 1; day <= last; day++) {
          final text =
              '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
          expect(parseImportDate(text), DateTime(year, month, day));
        }
        final invalid = '$year-${month.toString().padLeft(2, '0')}-${last + 1}';
        expect(parseImportDate(invalid), null);
      }
    }
  });
  test('valores não finitos e zero nunca viram lançamentos', () {
    for (final amount in [
      double.nan,
      double.infinity,
      double.negativeInfinity,
      0.0,
      -0.01,
    ]) {
      expect(
        () => TransactionDraft(
          kind: TransactionKind.income,
          amount: amount,
          description: 'Inválido',
          dueDate: DateTime(2026, 10),
          categoryId: 'test',
        ),
        throwsFormatException,
      );
    }
  });
}
