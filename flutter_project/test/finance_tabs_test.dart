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

  testWidgets('três abas e botão Adicionar no Início e no Extrato', (t) async {
    await showApp(t);
    final nav = find.byType(BottomNavigationBar);
    expect(t.widget<BottomNavigationBar>(nav).items.map((item) => item.label), [
      'Início',
      'Extrato',
      'Perfil',
    ]);
    expect(addButton, findsOneWidget);
    await openTab(t, 'Extrato');
    expect(t.widget<BottomNavigationBar>(nav).currentIndex, 1);
    expect(addButton, findsOneWidget);
    await openTab(t, 'Perfil');
    expect(addButton, findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('Renda abre direto o cadastro de renda; planilha no Extrato', (
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
    await openTab(t, 'Extrato');
    await openAdd(t, 'Importar planilha');
    expect(find.byType(ImportScreen), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('Despesa abre direto o cadastro de conta, sem menu', (t) async {
    await showApp(t);
    await openAdd(t);
    expect(find.text('Nova conta'), findsOneWidget);
    expect(find.text('Nome da renda'), findsNothing);
  });
}
