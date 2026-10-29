import 'dart:convert';

import 'package:financafacil/core/config/supabase_config.dart';
import 'package:financafacil/core/errors/app_failure.dart';
import 'package:financafacil/features/auth/data/auth_gateway.dart';
import 'package:financafacil/features/auth/data/auth_session_service.dart';
import 'package:financafacil/features/profile/data/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_supabase_backend.dart';

void main() {
  late FakeSupabaseBackend backend;
  late SupabaseAuthGateway auth;
  late AuthSessionService session;
  late SupabaseProfileRepository profile;
  setUp(() {
    backend = FakeSupabaseBackend();
    auth = SupabaseAuthGateway(backend.client);
    session = AuthSessionService(backend.client);
    profile = SupabaseProfileRepository(backend.client);
  });
  tearDown(() => backend.dispose());

  test(
    'login envia credenciais e recupera o perfil da sessão recebida',
    () async {
      backend.respond = (_) =>
          FakeSupabaseBackend.jsonResponse(FakeSupabaseBackend.session);
      await auth.signIn('owner@example.com', 'test-password');
      final request = backend.requests.single;
      expect(request.url.path, '/auth/v1/token');
      final body = jsonDecode(request.body) as Map;
      expect(body['email'], 'owner@example.com');
      expect(body['password'], 'test-password');
      expect(profile.currentProfile?.name, 'Pietro');
      expect(profile.currentProfile?.email, 'owner@example.com');
      expect(profile.currentProfile?.phone, '11999999999');
    },
  );
  test(
    'cadastro envia nome e telefone com o retorno de confirmação por e-mail',
    () async {
      backend.respond = (_) =>
          FakeSupabaseBackend.jsonResponse(FakeSupabaseBackend.user);
      expect(
        await auth.signUp(
          'Pietro',
          'owner@example.com',
          '11999999999',
          'test-password',
        ),
        true,
      );
      final request = backend.requests.single;
      expect(request.url.path, '/auth/v1/signup');
      expect(
        request.url.queryParameters['redirect_to'],
        SupabaseConfig.authRedirect,
      );
      final body = jsonDecode(request.body) as Map;
      expect(body['data'], {'full_name': 'Pietro', 'phone': '11999999999'});
      expect(profile.currentProfile, isNull);
    },
  );
  test(
    'cadastro com sessão imediata não exige nova confirmação na tela',
    () async {
      backend.respond = (_) =>
          FakeSupabaseBackend.jsonResponse(FakeSupabaseBackend.session);
      expect(
        await auth.signUp('Pietro', 'owner@example.com', '', 'test-password'),
        false,
      );
      expect(profile.currentProfile?.email, 'owner@example.com');
    },
  );
  test('recuperação usa o callback específico de nova senha', () async {
    backend.respond = (_) => FakeSupabaseBackend.jsonResponse({});
    await auth.requestPasswordReset('owner@example.com');
    final request = backend.requests.single;
    expect(request.url.path, '/auth/v1/recover');
    expect(
      request.url.queryParameters['redirect_to'],
      SupabaseConfig.recoveryRedirect,
    );
    expect((jsonDecode(request.body) as Map)['email'], 'owner@example.com');
  });
  test('senha atualizada usa a conta autenticada', () async {
    await backend.authenticate();
    backend.respond = (_) =>
        FakeSupabaseBackend.jsonResponse(FakeSupabaseBackend.user);
    await auth.updatePassword('new-test-password');
    final request = backend.requests.single;
    expect(request.url.path, '/auth/v1/user');
    expect(request.method, 'PUT');
    expect((jsonDecode(request.body) as Map)['password'], 'new-test-password');
  });
  test('erro de credenciais vira mensagem compreensível sem expor a resposta técnica', () async {
    backend.respond = (_) => FakeSupabaseBackend.jsonResponse({
      'msg': 'Invalid login credentials',
      'code': 'invalid_credentials',
    }, status: 400);
    await expectLater(
      auth.signIn('owner@example.com', 'wrong-password'),
      throwsA(
        isA<AppFailure>().having(
          (error) => error.message,
          'message',
          'E-mail ou senha incorretos.',
        ),
      ),
    );
  });
  test('editar perfil preserva outros metadados do usuário', () async {
    await backend.client.auth.setInitialSession(
      jsonEncode({
        ...FakeSupabaseBackend.session,
        'user': {
          ...FakeSupabaseBackend.user,
          'user_metadata': {
            'full_name': 'Pietro',
            'phone': '11999999999',
            'custom': 'preservar',
          },
        },
      }),
    );
    backend.respond = (request) => FakeSupabaseBackend.jsonResponse({
      ...FakeSupabaseBackend.user,
      'user_metadata': (jsonDecode(request.body) as Map)['data'],
    });
    await profile.update('  Pietro Cosentino  ', ' 11988887777 ');
    expect((jsonDecode(backend.requests.single.body) as Map)['data'], {
      'full_name': 'Pietro Cosentino',
      'phone': '11988887777',
      'custom': 'preservar',
    });
    expect(profile.currentProfile?.name, 'Pietro Cosentino');
  });
  test('editar perfil sem sessão falha antes de enviar requisição', () async {
    await expectLater(profile.update('Pietro', ''), throwsStateError);
    expect(backend.requests, isEmpty);
  });
  test('sair limpa a sessão e publica o evento para mostrar o login', () async {
    await backend.authenticate();
    final events = <SessionEvent>[];
    final subscription = session.changes.listen(events.add);
    await profile.signOut();
    await Future<void>.delayed(Duration.zero);
    expect(session.userId, isNull);
    expect(profile.currentProfile, isNull);
    expect(events, contains(SessionEvent.signedOut));
    await subscription.cancel();
  });
}
