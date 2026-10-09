import 'package:financafacil/core/theme/app_theme.dart';
import 'package:financafacil/features/transactions/presentation/screens/add_transaction_screen.dart';
import 'package:financafacil/features/transactions/presentation/screens/transactions_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/fake_repositories.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  for (final dark in [false, true]) {
    testWidgets(
        'ações visíveis e cadastro acessível no tema ${dark ? "escuro" : "claro"}',
        (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        home: TransactionsListScreen(repository: FakeFinanceRepository()),
      ));
      await tester.pumpAndSettle();
      final upload = find.text('Importar planilha');
      final add = find.text('Adicionar');
      expect(upload.hitTestable(), findsOneWidget);
      expect(add.hitTestable(), findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(add.hitTestable(), findsOneWidget);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(find.byType(AddTransactionScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
