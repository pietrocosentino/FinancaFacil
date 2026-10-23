import 'package:financafacil/features/transactions/domain/finance_models.dart';
import 'package:financafacil/features/transactions/domain/recurrence.dart';
import 'package:financafacil/features/transactions/presentation/screens/transactions_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'recurrence_test.dart' show rule;
import 'support/fake_repositories.dart';

class _FailDelete extends FakeFinanceRepository {
  @override
  Future<void> deleteEntry(String id) async => throw StateError('Offline');
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  test('exclusão mensal persiste sem eliminar regra ou próximos meses', () {
    final source = rule();
    final overrides = [
      {
        'rule_id': 'rule-1',
        'due_month': '2024-02-01',
        'is_deleted': true,
        'is_paid': false,
      },
    ];
    final first = projectRecurrences([source], overrides, DateTime(2024, 3));
    expect(first.map((r) => r['_installment']), [1, 3]);
    expect(projectRecurrences([source], overrides, DateTime(2024, 3)), first);
    expect(source['total_installments'], isNull);
  });
  for (final failure in [false, true]) {
    testWidgets(
      'exclusão exige confirmação e mantém registro em erro ($failure)',
      (t) async {
        final r = failure ? _FailDelete() : FakeFinanceRepository();
        r.entries = [
          FinanceEntry(
            id: '1',
            kind: TransactionKind.income,
            amount: 100,
            description: 'Crédito',
            dueDate: DateTime.now(),
            categoryName: 'Renda',
            isPaid: false,
          ),
        ];
        await t.pumpWidget(
          MaterialApp(home: TransactionsListScreen(repository: r)),
        );
        await t.pumpAndSettle();
        Future<void> open() async {
          await t.tap(find.byType(PopupMenuButton<String>));
          await t.pumpAndSettle();
          await t.tap(find.text('Excluir lançamento'));
          await t.pumpAndSettle();
        }

        await open();
        expect(r.deletedId, isNull);
        await t.tap(find.text('Cancelar'));
        await t.pumpAndSettle();
        expect(r.entries.length, 1);
        await open();
        await t.tap(find.text('Excluir'));
        await t.pumpAndSettle();
        expect(r.entries.length, failure ? 1 : 0);
        expect(r.deletedId, failure ? isNull : '1');
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets('excluir mês recorrente é separado de encerrar a regra', (
    t,
  ) async {
    final r = FakeFinanceRepository()
      ..entries = [
        FinanceEntry(
          id: 'r:rule-1:2026-10-01',
          kind: TransactionKind.income,
          amount: 3000,
          description: 'Salário',
          dueDate: DateTime.now(),
          categoryName: 'Renda',
          isPaid: true,
          isRecurring: true,
        ),
      ];
    await t.pumpWidget(
      MaterialApp(home: TransactionsListScreen(repository: r)),
    );
    await t.pumpAndSettle();
    await t.tap(find.byType(PopupMenuButton<String>));
    await t.pumpAndSettle();
    expect(find.text('Excluir somente este mês'), findsOneWidget);
    expect(find.text('Encerrar próximos meses'), findsOneWidget);
  });
}
