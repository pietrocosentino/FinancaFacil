import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/errors/app_failure.dart';

abstract class AuthGateway {
  Future<void> signIn(String email, String password);
  Future<bool> signUp(String name, String email, String phone, String password);
  Future<void> requestPasswordReset(String email);
  Future<void> updatePassword(String password);
}

class SupabaseAuthGateway implements AuthGateway {
  final SupabaseClient client;
  SupabaseAuthGateway(this.client);

  @override
  Future<void> signIn(String email, String password) async {
    await _perform(() async {
      await client.auth.signInWithPassword(email: email, password: password);
    });
  }

  @override
  Future<bool> signUp(
    String name,
    String email,
    String phone,
    String password,
  ) async {
    return _perform(() async {
      final result = await client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name, 'phone': phone},
        emailRedirectTo: SupabaseConfig.authRedirect,
      );
      return result.session == null;
    });
  }

  @override
  Future<void> requestPasswordReset(String email) => _perform(
    () => client.auth.resetPasswordForEmail(
      email,
      redirectTo: SupabaseConfig.recoveryRedirect,
    ),
  );

  @override
  Future<void> updatePassword(String password) async {
    await _perform(() async {
      await client.auth.updateUser(UserAttributes(password: password));
    });
  }

  Future<T> _perform<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on AuthException catch (error) {
      throw AppFailure(_authError(error));
    }
  }

  String _authError(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login')) return 'E-mail ou senha incorretos.';
    if (message.contains('email not confirmed')) {
      return 'Confirme seu e-mail antes de entrar.';
    }
    if (message.contains('already registered')) {
      return 'Não foi possível cadastrar. Tente entrar ou recuperar sua senha.';
    }
    if (message.contains('rate') || message.contains('too many')) {
      return 'Muitas tentativas. Aguarde alguns minutos e tente novamente.';
    }
    if (message.contains('password')) {
      return 'A senha não atende às regras da conta. Use uma senha mais forte.';
    }
    return 'Não foi possível concluir. Confira os dados e tente novamente.';
  }
}
