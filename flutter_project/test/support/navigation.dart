import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Botão "Despesa" visível na aba atual (Início ou Extrato).
final addButton = find.byTooltip('Adicionar despesa');

/// Botão "Renda" visível na aba atual (Início ou Extrato).
final addIncomeButton = find.byTooltip('Adicionar renda');

/// Abre um cadastro: 'Conta ou despesa', 'Renda' ou 'Importar planilha'
/// (este último fica no topo do Extrato).
Future<void> openAdd(
  WidgetTester tester, [
  String option = 'Conta ou despesa',
]) async {
  await tester.tap(switch (option) {
    'Renda' => addIncomeButton,
    'Importar planilha' => find.byTooltip('Importar planilha'),
    _ => addButton,
  });
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
