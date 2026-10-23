import 'package:financafacil/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:financafacil/features/transactions/domain/finance_models.dart';
import 'package:financafacil/features/transactions/presentation/screens/transactions_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/fake_repositories.dart';

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

  testWidgets('Início lista a renda fixa e altera de vez a partir deste mês', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeFinanceRepository()..entries = [_salary()];
    await tester.pumpWidget(
      MaterialApp(home: DashboardScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Suas rendas fixas'), findsOneWidget);
    expect(find.text('Salário'), findsOneWidget);
    await tester.tap(find.text('Alterar'));
    await tester.pumpAndSettle();
    expect(find.text('Alterar renda fixa'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor mensal'),
      '8.750,00',
    );
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();
    final now = DateTime.now();
    expect(repository.incomeChange?.amount, 8750);
    expect(repository.incomeChange?.description, 'Salário');
    expect(repository.incomeChange?.dueDay, 6);
    expect(repository.incomeChangeFrom, DateTime(now.year, now.month));
    expect(
      find.text('Renda fixa atualizada deste mês em diante.'),
      findsOneWidget,
    );
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
  });
}
