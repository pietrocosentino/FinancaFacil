import 'package:financafacil/features/auth/data/auth_gateway.dart';
import 'package:financafacil/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAuthGateway implements AuthGateway {
  List<String>? registered;
  String? resetEmail;
  String? updatedPassword;
  @override
  Future<void> signIn(String email, String password) async {}
  @override
  Future<bool> signUp(
      String name, String email, String phone, String password) async {
    registered = [name, email, phone, password];
    return true;
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    resetEmail = email;
  }

  @override
  Future<void> updatePassword(String password) async {
    updatedPassword = password;
  }
}

void main() {
  Future<void> show(WidgetTester tester, FakeAuthGateway gateway,
      {bool recovery = false}) async {
    await tester.pumpWidget(
        MaterialApp(home: LoginScreen(gateway: gateway, recovery: recovery)));
  }

  testWidgets('login oferece cadastro e recuperação', (tester) async {
    await show(tester, FakeAuthGateway());
    expect(find.byKey(const ValueKey('E-mail')), findsOneWidget);
    expect(find.byKey(const ValueKey('Senha')), findsOneWidget);
    expect(find.text('Esqueci minha senha'), findsOneWidget);
    expect(find.text('Criar conta com e-mail'), findsOneWidget);
  });
  testWidgets('cadastro envia nome e telefone e informa confirmação',
      (tester) async {
    final gateway = FakeAuthGateway();
    await show(tester, gateway);
    await tester.tap(find.text('Criar conta com e-mail'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('Nome')), 'Pietro Cosentino');
    await tester.enterText(
        find.byKey(const ValueKey('E-mail')), 'pietro@example.com');
    await tester.enterText(
        find.byKey(const ValueKey('Telefone com DDD')), '(11) 99999-9999');
    await tester.enterText(find.byKey(const ValueKey('Senha')), 'senha1234');
    await tester.enterText(
        find.byKey(const ValueKey('Confirmar senha')), 'senha1234');
    await tester.ensureVisible(find.text('Cadastrar'));
    await tester.tap(find.text('Cadastrar'));
    await tester.pumpAndSettle();
    expect(gateway.registered?.take(3).toList(),
        ['Pietro Cosentino', 'pietro@example.com', '11999999999']);
    expect(find.textContaining('confirmar o cadastro'), findsOneWidget);
  });
  testWidgets('recuperação solicita link para e-mail informado',
      (tester) async {
    final gateway = FakeAuthGateway();
    await show(tester, gateway);
    await tester.tap(find.text('Esqueci minha senha'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('E-mail')), 'pietro@example.com');
    await tester.tap(find.text('Enviar link de recuperação'));
    await tester.pumpAndSettle();
    expect(gateway.resetEmail, 'pietro@example.com');
    expect(find.textContaining('Se houver uma conta'), findsOneWidget);
  });
  testWidgets('nova senha exige confirmação igual', (tester) async {
    final gateway = FakeAuthGateway();
    await show(tester, gateway, recovery: true);
    await tester.enterText(
        find.byKey(const ValueKey('Nova senha')), 'senha1234');
    await tester.enterText(
        find.byKey(const ValueKey('Confirmar senha')), 'diferente');
    await tester.tap(find.text('Salvar nova senha'));
    await tester.pumpAndSettle();
    expect(gateway.updatedPassword, isNull);
    expect(find.text('As senhas precisam ser iguais.'), findsOneWidget);
  });
}
