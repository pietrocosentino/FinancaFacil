import 'package:financafacil/features/imports/presentation/import_screen.dart';
import 'package:financafacil/features/transactions/domain/finance_models.dart';
import 'package:financafacil/features/transactions/presentation/screens/add_transaction_screen.dart';
import 'package:financafacil/shared/widgets/main_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_import_repository.dart';
import 'support/fake_repositories.dart';
import 'support/navigation.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> showApp(WidgetTester t) async {
    await t.pumpWidget(
      MaterialApp(
        home: MainLayout(
          financeRepository: FakeFinanceRepository(),
          profileRepository: FakeProfileRepository(),
          importRepository: FakeImportRepository(),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('duas abas e cadastro somente no Início; perfil pela foto', (
    t,
  ) async {
    await showApp(t);
    final nav = find.byType(NavigationBar);
    expect(
      t
          .widget<NavigationBar>(nav)
          .destinations
          .whereType<NavigationDestination>()
          .map((item) => item.label),
      ['Início', 'Extrato'],
    );
    expect(addButton, findsOneWidget);
    await openTab(t, 'Extrato');
    expect(t.widget<NavigationBar>(nav).selectedIndex, 1);
    expect(addButton, findsNothing);
    expect(find.byTooltip('Importar planilha'), findsNothing);
    expect(find.byTooltip('Baixar lançamentos em Excel'), findsOneWidget);
    await t.tap(find.byTooltip('Abrir perfil'));
    await t.pumpAndSettle();
    expect(find.text('Dados pessoais'), findsOneWidget);
    expect(t.widget<NavigationBar>(nav).selectedIndex, 1);
    expect(addButton, findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('Renda abre direto; importar planilha fica no Início', (
    t,
  ) async {
    await showApp(t);
    await openAdd(t, 'Renda');
    expect(
      t
          .widget<AddTransactionScreen>(find.byType(AddTransactionScreen))
          .initialKind,
      TransactionKind.income,
    );
    await t.pageBack();
    await t.pumpAndSettle();
    await openTab(t, 'Início');
    await t.tap(find.text('Importar planilha'));
    await t.pumpAndSettle();
    expect(find.byType(ImportScreen), findsOneWidget);
    expect(find.text('Baixar modelo Excel'), findsOneWidget);
    expect(find.text('Baixar meus lançamentos em Excel'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('despesa ou conta abre o cadastro de conta', (t) async {
    await showApp(t);
    await openAdd(t);
    expect(find.text('Nova conta'), findsOneWidget);
    expect(find.text('Nome da renda'), findsNothing);
  });
}
