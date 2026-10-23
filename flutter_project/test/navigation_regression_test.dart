import 'package:financafacil/core/theme/app_theme.dart';
import 'package:financafacil/features/notifications/data/reminder_service.dart';
import 'package:financafacil/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:financafacil/features/transactions/domain/finance_models.dart';
import 'package:financafacil/features/transactions/presentation/screens/add_transaction_screen.dart';
import 'package:financafacil/features/transactions/presentation/screens/transactions_list_screen.dart';
import 'package:financafacil/shared/widgets/main_header.dart';
import 'package:financafacil/shared/widgets/main_layout.dart';
import 'package:financafacil/shared/widgets/month_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/fake_repositories.dart';
import 'support/navigation.dart';

class _TwoCategoriesRepository extends FakeFinanceRepository {
  @override
  Future<List<FinanceCategory>> categories(TransactionKind kind) async =>
      const [
        FinanceCategory(id: '1', name: 'Moradia'),
        FinanceCategory(id: '2', name: 'Saúde'),
      ];
}

class _OfflineRepository extends FakeFinanceRepository {
  @override
  Future<List<FinanceEntry>> transactions(DateTime through) async =>
      throw StateError('Offline');
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  _keyboardTests();

  testWidgets('toques rápidos no cadastro abrem somente um formulário', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MainLayout(
          financeRepository: FakeFinanceRepository(),
          profileRepository: FakeProfileRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cadastrar conta ou renda'), findsNothing);
    await tester.tap(addButton);
    await tester.tap(addButton, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Nova conta'), findsOneWidget);
    expect(find.byType(AddTransactionScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Nova conta'), findsNothing);
    expect(addButton, findsOneWidget);
  });

  testWidgets('voltar do Android respeita o formulário não salvo', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MainLayout(
          financeRepository: FakeFinanceRepository(),
          profileRepository: FakeProfileRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await openAdd(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor da conta'),
      '90,60',
    );
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Descartar cadastro?'), findsOneWidget);
    await tester.tap(find.text('Continuar preenchendo'));
    await tester.pumpAndSettle();
    expect(find.text('90,60'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.text('Nova conta'), findsNothing);
    expect(addButton, findsOneWidget);
  });

  testWidgets('mudança apenas da frequência também protege o cadastro', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MainLayout(
          financeRepository: FakeFinanceRepository(),
          profileRepository: FakeProfileRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await openAdd(tester);
    await tester.tap(find.text('Todo mês'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Descartar cadastro?'), findsOneWidget);
    await tester.tap(find.text('Continuar preenchendo'));
    await tester.pumpAndSettle();
    expect(find.text('Nova conta'), findsOneWidget);
  });

  testWidgets('categoria é opcional, aceita a lista ou texto e volta vazia', (
    tester,
  ) async {
    final repository = _TwoCategoriesRepository();
    await tester.pumpWidget(
      MaterialApp(home: AddTransactionScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    final category = find.descendant(
      of: find.byType(DropdownMenu<String>),
      matching: find.byType(TextField),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor da conta'),
      '90,60',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome da conta'),
      'Ótica',
    );
    await tester.tap(find.text('Salvar conta'));
    await tester.pumpAndSettle();
    // Sem categoria: vai para a padrão, criada quando ainda não existe.
    expect(repository.saved?.description, 'Ótica');
    expect(repository.saved?.categoryId, 'new-Outras despesas');
    await tester.tap(find.text('Cadastrar outra conta'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(category).controller?.text, isEmpty);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor da conta'),
      '100',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome da conta'),
      'Consulta',
    );
    await tester.ensureVisible(category);
    await tester.enterText(category, 'saúde');
    // Fecha a lista de sugestões, como o primeiro toque fora dela no app.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar conta'));
    await tester.pumpAndSettle();
    // Nome existente (sem diferenciar maiúsculas) usa a categoria da lista.
    expect(repository.saved?.categoryId, '2');
    expect(repository.createdCategories.map((c) => c.name), [
      'Outras despesas',
    ]);
  });

  testWidgets('mudar o primeiro mês conserva o dia mensal escolhido', (
    tester,
  ) async {
    final repository = FakeFinanceRepository();
    await tester.pumpWidget(
      MaterialApp(home: AddTransactionScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor da conta'),
      '500',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome da conta'),
      'Aluguel',
    );
    await tester.tap(find.text('Todo mês'));
    await tester.pumpAndSettle();
    final day = find.byType(DropdownButtonFormField<int>);
    await tester.ensureVisible(day);
    await tester.tap(day);
    await tester.pumpAndSettle();
    // O menu abre centralizado no dia atual; ensureVisible rola até o dia 31
    // em qualquer data, sem depender da posição inicial da lista.
    await tester.ensureVisible(find.text('Dia 31').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dia 31').last);
    await tester.pumpAndSettle();
    final first = find.textContaining('Primeiro vencimento:');
    await tester.ensureVisible(first);
    await tester.tap(first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('fev.'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar conta mensal'));
    await tester.pumpAndSettle();
    expect(repository.saved?.dueDay, 31);
    expect(repository.saved?.dueDate.month, 2);
    expect(
      repository.saved?.dueDate.day,
      DateTime(repository.saved!.dueDate.year, 3, 0).day,
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'finanças rola com teclado e fonte grande no tema ${brightness.name}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 560);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: brightness == Brightness.dark
                ? AppTheme.darkTheme
                : AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                viewInsets: const EdgeInsets.only(bottom: 240),
              ),
              child: child!,
            ),
            home: TransactionsListScreen(repository: FakeFinanceRepository()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Buscar contas'));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(CustomScrollView), const Offset(0, 600));
        await tester.pumpAndSettle();
        expect(find.text('Todas'), findsOneWidget);
        expect(find.text('Buscar pelo nome da conta'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('permissão dos lembretes continua acessível sem conexão', (
    tester,
  ) async {
    final service = FakeReminderService();
    service.status.value = const ReminderStatus();
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsScreen(
          repository: _OfflineRepository(),
          reminders: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ativar lembretes no aparelho'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('seletor mensal permite dezembro do último ano', (tester) async {
    DateTime? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await showMonthPicker(
                  context: context,
                  initialMonth: DateTime(2100, 12),
                );
              },
              child: const Text('Escolher'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Escolher'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('Próximo ano'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('dez.'));
    await tester.pumpAndSettle();
    expect(selected, DateTime(2100, 12));
    expect(tester.takeException(), isNull);
  });
}

void _keyboardTests() {
  testWidgets('teclado aberto esconde o menu inferior e não encolhe a base', (
    tester,
  ) async {
    Widget app(double keyboard) => MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(viewInsets: EdgeInsets.only(bottom: keyboard)),
          child: MainLayout(
            financeRepository: FakeFinanceRepository(),
            profileRepository: FakeProfileRepository(),
          ),
        ),
      ),
    );
    await tester.pumpWidget(app(0));
    await tester.pumpAndSettle();
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    await tester.pumpWidget(app(300));
    await tester.pump();
    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(find.byType(MainHeader), findsNothing);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.resizeToAvoidBottomInset, false);
  });
}
