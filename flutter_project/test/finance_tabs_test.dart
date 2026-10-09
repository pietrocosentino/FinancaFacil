import 'package:financafacil/features/transactions/domain/finance_models.dart';
import 'package:financafacil/features/transactions/presentation/screens/add_transaction_screen.dart';
import 'package:financafacil/shared/widgets/main_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/fake_repositories.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('Finanças cadastra e Extrato consulta sem ações de cadastro',
      (t) async {
    await t.pumpWidget(MaterialApp(
        home: MainLayout(
            financeRepository: FakeFinanceRepository(),
            profileRepository: FakeProfileRepository())));
    await t.pumpAndSettle();
    final nav = find.byType(BottomNavigationBar);
    expect(t.widget<BottomNavigationBar>(nav).items.length, 4);
    await t.tap(find.descendant(of: nav, matching: find.text('Finanças')));
    await t.pumpAndSettle();
    expect(find.text('Adicionar conta'), findsOneWidget);
    expect(find.text('Adicionar renda'), findsOneWidget);
    expect(find.text('Importar planilha'), findsOneWidget);
    await t.tap(find.text('Adicionar renda'));
    await t.pumpAndSettle();
    expect(
        t
            .widget<AddTransactionScreen>(find.byType(AddTransactionScreen))
            .initialKind,
        TransactionKind.income);
    await t.tap(find.descendant(of: nav, matching: find.text('Extrato')));
    await t.pumpAndSettle();
    expect(find.text('Adicionar conta'), findsNothing);
    expect(find.text('Importar planilha'), findsNothing);
    expect(find.text('Adicionar'), findsNothing);
    expect(t.widget<BottomNavigationBar>(nav).currentIndex, 2);
    expect(t.takeException(), isNull);
  });
}
