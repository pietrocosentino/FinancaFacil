import 'package:financafacil/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:financafacil/features/transactions/domain/finance_models.dart';
import 'package:financafacil/features/transactions/presentation/screens/add_transaction_screen.dart';
import 'package:financafacil/features/transactions/presentation/screens/finance_entry_card.dart';
import 'package:financafacil/features/transactions/presentation/screens/transactions_list_screen.dart';
import 'package:financafacil/shared/widgets/async_panel.dart';
import 'package:financafacil/shared/widgets/main_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/fake_repositories.dart';
import 'support/navigation.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });
  testWidgets('cartão não transborda com descrição longa e fonte grande', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: FinanceEntryCard(
                entry: FinanceEntry(
                  id: '1',
                  kind: TransactionKind.expense,
                  amount: 123456789,
                  description: 'Descrição muito longa para uma conta recorrente de aluguel residencial',
                  dueDate: DateTime(2026, 10, 31),
                  categoryName: 'Moradia',
                  isPaid: false,
                  isRecurring: true,
                  installment: 3,
                  totalInstallments: 12,
                  lastDue: DateTime(2027, 7, 31),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('menu permanece no novo lançamento e permite abrir perfil', (
    tester,
  ) async {
    final finance = FakeFinanceRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: MainLayout(
          financeRepository: finance,
          profileRepository: FakeProfileRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await openAdd(tester);
    expect(find.text('Nova conta'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
    expect(find.text('Extrato'), findsOneWidget);
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Dados pessoais'), findsOneWidget);
    expect(find.text('pietro@example.com'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'recorrência sem fim envia uma regra sem quantidade de parcelas',
    (tester) async {
      final repository = FakeFinanceRepository();
      await tester.pumpWidget(
        MaterialApp(home: AddTransactionScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor da conta'),
        '500,00',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome da conta'),
        'Aluguel',
      );
      await tester.tap(find.text('Todo mês'));
      await tester.pumpAndSettle();
      final save = find.text('Salvar conta mensal');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repository.saved?.isRecurring, true);
      expect(repository.saved?.totalInstallments, isNull);
      expect(repository.saved?.amount, 500);
    },
  );
  testWidgets('dashboard estreito com fonte grande não transborda', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeFinanceRepository();
    repository.entries = [
      FinanceEntry(
        id: '1',
        kind: TransactionKind.expense,
        amount: 500,
        description: 'Aluguel',
        dueDate: DateTime.now(),
        categoryName: 'Categoria com nome bastante longo',
        isPaid: false,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: DashboardScreen(repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('painel aceita inicialização concluída sem valor de retorno', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AsyncPanel<void>(
          future: Future<void>.value(),
          onRetry: () {},
          errorMessage: 'Falhou',
          builder: (_) => const Text('Pronto'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pronto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pagamento usa somente os IDs selecionados', (tester) async {
    final repository = FakeFinanceRepository();
    repository.entries = [
      FinanceEntry(
        id: 'one',
        kind: TransactionKind.expense,
        amount: 500,
        description: 'Aluguel',
        dueDate: DateTime.now(),
        categoryName: 'Moradia',
        isPaid: false,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(home: TransactionsListScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar selecionados (1)'));
    await tester.pumpAndSettle();
    expect(repository.paidIds, isNull);
    expect(
      find.textContaining('não poderá ser alterada nem excluída'),
      findsOneWidget,
    );
    await tester.tap(find.text('Tenho certeza, confirmar'));
    await tester.pumpAndSettle();
    expect(repository.paidIds, {'one'});
    expect(tester.takeException(), isNull);
  });
  testWidgets('edição de pendente aceita centavos em formato brasileiro', (
    tester,
  ) async {
    final repository = FakeFinanceRepository();
    repository.entries = [
      FinanceEntry(
        id: 'one',
        kind: TransactionKind.expense,
        amount: 500,
        description: 'Aluguel',
        dueDate: DateTime.now(),
        categoryName: 'Categoria de teste',
        categoryId: '1',
        isPaid: false,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(home: TransactionsListScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Editar lançamento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar lançamento'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor'),
      '550,50',
    );
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();
    expect(repository.updatedDetails?.amount, 550.50);
    expect(repository.updatedDetails?.categoryId, '1');
    expect(find.text('Lançamento atualizado.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
