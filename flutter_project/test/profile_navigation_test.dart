import 'package:financafacil/features/profile/presentation/profile_menu_item.dart';
import 'package:financafacil/features/profile/presentation/screens/personal_data_screen.dart';
import 'package:financafacil/features/profile/presentation/screens/profile_screen.dart';
import 'package:financafacil/shared/widgets/main_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_repositories.dart';
import 'support/navigation.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('dados separados ficam somente leitura até Alterar', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: PersonalDataScreen(repository: FakeProfileRepository()),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Nome'), findsOneWidget);
    expect(find.text('Telefone'), findsOneWidget);
    await t.tap(find.text('Alterar'));
    await t.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('pietro@example.com'), findsOneWidget);
  });
  testWidgets('menu aceita nova opção sem alterar o cabeçalho', (t) async {
    var tapped = false;
    await t.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          repository: FakeProfileRepository(),
          extraItems: [
            ProfileMenuItem(
              title: 'Nova ideia',
              icon: Icons.star_outline,
              onTap: () => tapped = true,
            ),
          ],
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Nova ideia'));
    expect(tapped, true);
    expect(find.text('Dados pessoais'), findsOneWidget);
  });
  testWidgets('nome no cabeçalho leva à aba Perfil e preserva o sino', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: MainLayout(
          financeRepository: FakeFinanceRepository(),
          profileRepository: FakeProfileRepository(),
        ),
      ),
    );
    await t.pumpAndSettle();
    final nav = find.byType(BottomNavigationBar);
    await t.tap(find.text('Pietro'));
    await t.pumpAndSettle();
    expect(t.widget<BottomNavigationBar>(nav).currentIndex, 2);
    expect(find.text('FinançaFácil'), findsOneWidget);
    expect(find.text('Dados pessoais'), findsOneWidget);
    expect(find.byTooltip('Notificações'), findsOneWidget);
    expect(find.text('Minhas notificações'), findsNothing);
    await t.tap(find.text('Dados pessoais'));
    await t.pumpAndSettle();
    await t.tap(find.text('Alterar'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).first, 'Pietro Ferreira');
    await t.ensureVisible(find.text('Salvar dados'));
    await t.tap(find.text('Salvar dados'));
    await t.pumpAndSettle();
    // Cabeçalho e formulário atualizados juntos.
    expect(find.text('Pietro Ferreira'), findsNWidgets(2));
    await openTab(t, 'Início');
    expect(t.widget<BottomNavigationBar>(nav).currentIndex, 0);
    expect(find.text('Pietro Ferreira'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('voltar com dados alterados pede descarte e preserva edição', (
    t,
  ) async {
    final r = FakeProfileRepository();
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PersonalDataScreen(repository: r),
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Abrir'));
    await t.pumpAndSettle();
    await t.tap(find.text('Alterar'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).first, 'Outro nome');
    await t.pump();
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text('Descartar alterações?'), findsOneWidget);
    await t.tap(find.text('Continuar editando'));
    await t.pumpAndSettle();
    expect(find.text('Outro nome'), findsOneWidget);
    expect(r.currentProfile!.name, 'Pietro');
  });
}
