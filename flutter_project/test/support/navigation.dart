import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ação única de cadastro visível no Início.
final addButton = find.text('Adicionar lançamento');

/// Abre um cadastro: 'Despesa ou conta', 'Renda' ou 'Importar planilha'.
Future<void> openAdd(
  WidgetTester tester, [
  String option = 'Despesa ou conta',
]) async {
  if (option == 'Importar planilha') {
    await tester.tap(find.byTooltip('Importar planilha'));
  } else {
    await tester.tap(addButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text(option));
  }
  await tester.pumpAndSettle();
}

/// Toca em uma aba da barra inferior: 'Início' ou 'Extrato'.
Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}
