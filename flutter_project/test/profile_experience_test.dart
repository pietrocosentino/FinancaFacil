import 'package:financafacil/features/profile/presentation/screens/profile_screen.dart';
import 'package:financafacil/shared/widgets/main_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_repositories.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> show(WidgetTester t, FakeProfileRepository r) async {
    await t.pumpWidget(MaterialApp(home: ProfileScreen(repository: r)));
    await t.pumpAndSettle();
  }

  /// Nome e foto ficam no cabeçalho do aplicativo; o menu fica na aba Perfil.
  Future<void> showApp(WidgetTester t, FakeProfileRepository r) async {
    await t.pumpWidget(
      MaterialApp(
        home: MainLayout(
          financeRepository: FakeFinanceRepository(),
          profileRepository: r,
        ),
      ),
    );
    await t.pumpAndSettle();
    final nav = find.byType(BottomNavigationBar);
    await t.tap(find.descendant(of: nav, matching: find.text('Perfil')));
    await t.pumpAndSettle();
  }

  testWidgets('contato fica na tela de dados pessoais', (t) async {
    await showApp(t, FakeProfileRepository());
    expect(find.text('Pietro'), findsOneWidget);
    expect(find.text('pietro@example.com'), findsNothing);
    await t.tap(find.text('Dados pessoais'));
    await t.pumpAndSettle();
    expect(find.text('pietro@example.com'), findsOneWidget);
  });
  testWidgets('salvar atualiza nome no cabeçalho', (t) async {
    final r = FakeProfileRepository();
    await showApp(t, r);
    await t.tap(find.text('Dados pessoais'));
    await t.pumpAndSettle();
    await t.tap(find.text('Alterar'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).first, 'Pietro Ferreira');
    await t.ensureVisible(find.text('Salvar dados'));
    await t.tap(find.text('Salvar dados'));
    await t.pumpAndSettle();
    expect(r.currentProfile!.email, 'pietro@example.com');
    await t.pageBack();
    await t.pumpAndSettle();
    expect(find.text('Pietro Ferreira'), findsOneWidget);
  });
  testWidgets('cancelar edição preserva dados', (t) async {
    final r = FakeProfileRepository();
    await show(t, r);
    await t.tap(find.text('Dados pessoais'));
    await t.pumpAndSettle();
    await t.tap(find.text('Alterar'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).first, 'Outro nome');
    await t.ensureVisible(find.text('Cancelar'));
    await t.tap(find.text('Cancelar'));
    await t.pumpAndSettle();
    expect(r.currentProfile!.name, 'Pietro');
  });
  testWidgets('cancelar saída mantém sessão', (t) async {
    final r = FakeProfileRepository();
    await show(t, r);
    await t.scrollUntilVisible(
      find.text('Sair da conta'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(find.text('Sair da conta'));
    await t.pumpAndSettle();
    await t.tap(find.text('Sair da conta'));
    await t.pumpAndSettle();
    await t.tap(find.text('Cancelar'));
    await t.pumpAndSettle();
    expect(r.currentProfile, isNotNull);
  });
}
