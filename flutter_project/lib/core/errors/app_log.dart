import 'dart:collection';

import 'package:flutter/foundation.dart';

/// Registro das falhas do app. Em vez de engolir exceções com `catch (_)`,
/// as telas registram aqui o erro e o contexto. O destino padrão é o console
/// de depuração; um serviço externo (Sentry, Crashlytics) pode ser ligado
/// trocando [sink] na inicialização, sem alterar as telas.
abstract final class AppLog {
  static const _capacity = 50;
  static final _recent = ListQueue<AppLogEntry>();

  static void Function(AppLogEntry entry) sink = _debugSink;

  /// Últimas falhas registradas nesta execução, da mais antiga à mais recente.
  static List<AppLogEntry> get recent => List.unmodifiable(_recent);

  static void error(Object error, StackTrace? stack, String context) {
    final entry = AppLogEntry(DateTime.now(), context, error, stack);
    _recent.addLast(entry);
    while (_recent.length > _capacity) {
      _recent.removeFirst();
    }
    try {
      sink(entry);
    } catch (_) {
      // Uma falha no destino do registro nunca derruba o app.
    }
  }

  /// Captura erros não tratados do Flutter e do Dart.
  static void installGlobalHandlers() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      error(details.exception, details.stack, 'flutter');
      previous?.call(details);
    };
    PlatformDispatcher.instance.onError = (exception, stack) {
      error(exception, stack, 'plataforma');
      return true;
    };
  }

  @visibleForTesting
  static void reset() {
    _recent.clear();
    sink = _debugSink;
  }

  static void _debugSink(AppLogEntry entry) {
    if (kDebugMode) debugPrint('[FinançaFácil] $entry');
  }
}

class AppLogEntry {
  const AppLogEntry(this.time, this.context, this.error, this.stack);
  final DateTime time;
  final String context;
  final Object error;
  final StackTrace? stack;

  @override
  String toString() => '$context: $error';
}
