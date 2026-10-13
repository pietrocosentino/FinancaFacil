import 'package:financafacil/core/theme/app_theme.dart';
import 'package:financafacil/features/notifications/data/reminder_service.dart';
import 'package:financafacil/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:financafacil/features/transactions/domain/finance_models.dart';
import 'package:financafacil/features/transactions/presentation/screens/add_transaction_screen.dart';
import 'package:financafacil/features/transactions/presentation/screens/transactions_list_screen.dart';
import 'package:financafacil/shared/widgets/main_layout.dart';
import 'package:financafacil/shared/widgets/month_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/fake_repositories.dart';

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

  testWidgets('toques rápidos no cadastro abrem somente um formulário',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: MainLayout(
            financeRepository: FakeFinanceRepository(),
            profileRepository: FakeProfileRepository())));
    await tester.pumpAndSettle();
    expect(find.text('Cadastrar conta ou renda'), findsNothing);
    await tester.tap(find.text('Finanças'));
    await tester.pumpAndSettle();
    final add = find.text('Adicionar conta');
    await tester.tap(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Novo lançamento'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Novo lançamento'), findsNothing);
    expect(find.text('Adicionar conta'), findsOneWidget);
  });

  testWidgets('voltar do Android respeita o formulário não salvo',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: MainLayout(
            financeRepository: FakeFinanceRepository(),
            profileRepository: FakeProfileRepository())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finanças'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar conta'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor'), '90,60');
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
    expect(find.text('Novo lançamento'), findsNothing);
    expect(find.text('Adicionar conta'), findsOneWidget);
  });

  testWidgets('mudança apenas do tipo também protege o cadastro',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: MainLayout(
            financeRepository: FakeFinanceRepository(),
            profileRepository: FakeProfileRepository())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finanças'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar conta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Receita'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Descartar cadastro?'), findsOneWidget);
    await tester.tap(find.text('Continuar preenchendo'));
    await tester.pumpAndSettle();
    expect(find.text('Novo lançamento'), findsOneWidget);
  });

  testWidgets('categoria é obrigatória e volta vazia no cadastro seguinte',
      (tester) async {
    final repository = _TwoCategoriesRepository();
    await tester.pumpWidget(
        MaterialApp(home: AddTransactionScreen(repository: repository)));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor'), '90,60');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome da conta ou renda'), 'Ótica');
    await tester.tap(find.text('Salvar lançamento'));
    await tester.pumpAndSettle();
    expect(repository.saved, isNull);
    expect(find.text('Escolha uma categoria.'), findsOneWidget);
    final dropdown = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saúde').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar lançamento'));
    await tester.pumpAndSettle();
    expect(repository.saved?.categoryId, '2');
    await tester.tap(find.text('Cadastrar outra'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<DropdownButtonFormField<String>>(dropdown).initialValue,
        isNull);
    await tester.ensureVisible(find.widgetWithText(TextFormField, 'Valor'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Valor'), '100');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome da conta ou renda'),
        'Outra conta');
    await tester.tap(find.text('Salvar lançamento'));
    await tester.pumpAndSettle();
    expect(find.text('Escolha uma categoria.'), findsOneWidget);
    expect(repository.saved?.description, 'Ótica');
  });

  testWidgets('mudar o primeiro mês conserva o dia mensal escolhido',
      (tester) async {
    final repository = FakeFinanceRepository();
    await tester.pumpWidget(
        MaterialApp(home: AddTransactionScreen(repository: repository)));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Valor'), '500');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome da conta ou renda'),
        'Aluguel');
    await tester.tap(find.text('Todo mês'));
    await tester.pumpAndSettle();
    final day = find.byType(DropdownButtonFormField<int>);
    await tester.ensureVisible(day);
    await tester.tap(day);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Dia 31'), 150,
        scrollable: find.byType(Scrollable).last);
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
    expect(repository.saved?.dueDate.day,
        DateTime(repository.saved!.dueDate.year, 3, 0).day);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
        'finanças rola com teclado e fonte grande no tema ${brightness.name}',
        (tester) async {
      tester.view.physicalSize = const Size(320, 560);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          theme: brightness == Brightness.dark
              ? AppTheme.darkTheme
              : AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  viewInsets: const EdgeInsets.only(bottom: 240)),
              child: child!),
          home: TransactionsListScreen(repository: FakeFinanceRepository())));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Buscar contas'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Todas'), findsOneWidget);
    });
  }

  testWidgets('permissão dos lembretes continua acessível sem conexão',
      (tester) async {
    final service = FakeReminderService();
    service.status.value = const ReminderStatus();
    await tester.pumpWidget(MaterialApp(
        home: NotificationsScreen(
            repository: _OfflineRepository(), reminders: service)));
    await tester.pumpAndSettle();
    expect(find.text('Ativar lembretes no aparelho'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('seletor mensal permite dezembro do último ano', (tester) async {
    DateTime? selected;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      selected = await showMonthPicker(
                          context: context, initialMonth: DateTime(2100, 12));
                    },
                    child: const Text('Escolher'))))));
    await tester.tap(find.text('Escolher'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<IconButton>(find.ancestor(
                of: find.byTooltip('Próximo ano'),
                matching: find.byType(IconButton)))
            .onPressed,
        isNull);
    await tester.tap(find.text('dez.'));
    await tester.pumpAndSettle();
    expect(selected, DateTime(2100, 12));
    expect(tester.takeException(), isNull);
  });
}
