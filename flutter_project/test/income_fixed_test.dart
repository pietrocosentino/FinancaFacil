import 'package:financafacil/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:financafacil/features/transactions/domain/finance_models.dart';
import 'package:financafacil/features/transactions/presentation/screens/recurrence_rules_screen.dart';
import 'package:financafacil/features/transactions/presentation/screens/transactions_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/fake_repositories.dart';

class _RecurrenceRepository extends FakeFinanceRepository {
  @override
  Future<List<RecurrencePlan>> plans() async => [
    RecurrencePlan(
      id: 'expense-rule',
      firstDue: DateTime(2026, 1, 5),
      description: 'Aluguel',
      amount: 1500,
      kind: TransactionKind.expense,
    ),
    RecurrencePlan(
      id: 'income-rule',
      firstDue: DateTime(2026, 1, 10),
      description: 'Salário',
      amount: 5000,
      kind: TransactionKind.income,
    ),
  ];
}

FinanceEntry _salary({String id = 'legacy-1'}) {
  final now = DateTime.now();
  return FinanceEntry(
    id: id,
    kind: TransactionKind.income,
    amount: 9500,
    description: 'Salário',
    dueDate: DateTime(now.year, now.month, 6),
    categoryName: 'Categoria de teste',
    categoryId: '1',
    isPaid: true,
    isRecurring: true,
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('Início não lista rendas fixas', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeFinanceRepository()..entries = [_salary()];
    await tester.pumpWidget(
      MaterialApp(home: DashboardScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Suas rendas fixas'), findsNothing);
    expect(find.text('Salário'), findsNothing);
  });

  testWidgets('lista recorrências do Extrato identifica débitos e créditos', (
    tester,
  ) async {
    final repository = _RecurrenceRepository();
    await tester.pumpWidget(
      MaterialApp(home: RecurrenceRulesScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lançamentos recorrentes'), findsOneWidget);
    expect(find.text('Contas mensais e parcelas'), findsNothing);
    expect(find.text('Despesa'), findsOneWidget);
    expect(find.text('Receita'), findsOneWidget);
  });

  testWidgets('Extrato oferece alterar só o mês ou a renda fixa de vez', (
    tester,
  ) async {
    final repository = FakeFinanceRepository()..entries = [_salary()];
    await tester.pumpWidget(
      MaterialApp(home: TransactionsListScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Editar só este mês'), findsOneWidget);
    expect(
      find.text('Alterar renda fixa (deste mês em diante)'),
      findsOneWidget,
    );
    expect(
      find.text('Excluir renda fixa (deste mês em diante)'),
      findsOneWidget,
    );
    await tester.tap(find.text('Excluir renda fixa (deste mês em diante)'));
    await tester.pumpAndSettle();
    expect(find.text('Excluir renda fixa?'), findsOneWidget);
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(repository.deletedIncome?.id, 'legacy-1');
  });
}
