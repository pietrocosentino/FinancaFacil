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

  testWidgets('Adicionar oferece conta, renda e planilha', (t) async {
    await showApp(t);
    await t.tap(addButton);
    await t.pumpAndSettle();
    expect(find.text('Conta ou despesa'), findsOneWidget);
    expect(find.text('Renda'), findsOneWidget);
    expect(find.text('Importar planilha'), findsOneWidget);
    await t.tap(find.text('Renda'));
    await t.pumpAndSettle();
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

  testWidgets('fechar a escolha sem selecionar não abre nada', (t) async {
    await showApp(t);
    await t.tap(addButton);
    await t.pumpAndSettle();
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    expect(find.byType(AddTransactionScreen), findsNothing);
    expect(addButton, findsOneWidget);
  });
}
