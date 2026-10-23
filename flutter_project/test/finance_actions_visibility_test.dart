import 'package:financafacil/core/theme/app_theme.dart';
import 'package:financafacil/features/transactions/domain/finance_models.dart';
import 'package:financafacil/features/transactions/presentation/screens/add_transaction_screen.dart';
import 'package:financafacil/features/transactions/presentation/screens/transactions_list_screen.dart';
import 'package:financafacil/shared/widgets/main_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_repositories.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  void phoneScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  for (final dark in [false, true]) {
    final theme = dark ? 'escuro' : 'claro';

    testWidgets('cadastro e importação acessíveis em Finanças no tema $theme', (
      tester,
    ) async {
      phoneScreen(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          home: MainLayout(
            financeRepository: FakeFinanceRepository(),
            profileRepository: FakeProfileRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final nav = find.byType(BottomNavigationBar);
      await tester.tap(
        find.descendant(of: nav, matching: find.text('Finanças')),
      );
      await tester.pumpAndSettle();
      for (final label in [
        'Adicionar conta',
        'Adicionar renda',
        'Importar planilha',
      ]) {
        expect(find.text(label).hitTestable(), findsOneWidget);
        final tile = find.ancestor(
          of: find.text(label),
          matching: find.byType(ListTile),
        );
        expect(tester.getSize(tile).height, greaterThanOrEqualTo(48));
      }
      await tester.tap(find.text('Adicionar conta'));
      await tester.pumpAndSettle();
      expect(find.byType(AddTransactionScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('confirmação em lote visível no Extrato no tema $theme', (
      tester,
    ) async {
      phoneScreen(tester);
      final repository = FakeFinanceRepository()
        ..entries = [
          FinanceEntry(
            id: 'rent',
            kind: TransactionKind.expense,
            amount: 1500,
            description: 'Aluguel',
            dueDate: DateTime.now(),
            categoryName: 'Moradia',
            isPaid: false,
          ),
        ];
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          home: TransactionsListScreen(repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Confirmar selecionados'), findsNothing);
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      final confirm = find.text('Confirmar selecionados (1)');
      expect(confirm.hitTestable(), findsOneWidget);
      final button = find.ancestor(
        of: confirm,
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      );
      expect(tester.getSize(button).width, lessThan(320));
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    });
  }
}
