import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Botão "Adicionar" visível na aba atual (Início ou Extrato).
final addButton = find.byTooltip('Adicionar conta, renda ou planilha');

/// Abre o cadastro pelo botão "Adicionar" e escolhe a opção do menu:
/// 'Conta ou despesa', 'Renda' ou 'Importar planilha'.
Future<void> openAdd(
  WidgetTester tester, [
  String option = 'Conta ou despesa',
]) async {
  await tester.tap(addButton);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option));
  await tester.pumpAndSettle();
}

/// Toca em uma aba da barra inferior: 'Início', 'Extrato' ou 'Perfil'.
Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}
