import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_failure.dart';

const connectionFailure =
    'Sem conexão com o servidor. Confira a internet e tente novamente.';
const outdatedDatabaseFailure =
    'O banco de dados precisa ser atualizado. Execute os scripts da pasta '
    'supabase, na ordem do README, e tente novamente.';

/// Mensagem para o usuário a partir de uma falha. Mensagens já escritas para o
/// usuário (validação do app e exceções das funções do banco) são mostradas
/// como estão; o restante recebe uma explicação do tipo de problema ou
/// [fallback].
String failureMessage(Object error, {required String fallback}) {
  if (error is AppFailure) return error.message;
  if (error is FormatException) return error.message;
  if (error is PostgrestException) {
    if (const [
      '42883',
      '42P01',
      '42703',
      'PGRST202',
      'PGRST204',
      'PGRST205',
    ].contains(error.code)) {
      return outdatedDatabaseFailure;
    }
    // RAISE EXCEPTION das funções do app: textos em português para o usuário.
    if (error.code == 'P0001') return error.message;
    if (error.code == 'PGRST301' || error.code == '401') {
      return 'Sua sessão terminou. Entre novamente.';
    }
    return fallback;
  }
  if (error is AuthException) return 'Sua sessão terminou. Entre novamente.';
  if (error is TimeoutException) return connectionFailure;
  final text = error.toString();
  if (const [
    'SocketException',
    'ClientException',
    'Failed host lookup',
    'Connection refused',
    'Network is unreachable',
  ].any(text.contains)) {
    return connectionFailure;
  }
  if (error is StateError && error.message.contains('sessão')) {
    return error.message;
  }
  return fallback;
}
