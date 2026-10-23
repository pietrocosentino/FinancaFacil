import 'dart:io';

import 'package:flutter/services.dart';

/// Onde o usuário quer buscar ou guardar um arquivo.
enum FileLocation {
  device('Do celular', 'No celular'),
  drive('Do Google Drive', 'No Google Drive');

  const FileLocation(this.pickLabel, this.saveLabel);
  final String pickLabel;
  final String saveLabel;
}

/// Aplicativos Google abertos diretamente no Android.
enum CloudApp {
  drive('com.google.android.apps.docs', 'Google Drive'),
  photos('com.google.android.apps.photos', 'Google Fotos');

  const CloudApp(this.packageName, this.label);
  final String packageName;
  final String label;
}

class PickedFile {
  const PickedFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

/// O aplicativo não está instalado ou a plataforma não oferece o atalho;
/// quem chama usa o seletor padrão do sistema.
class CloudAppUnavailable implements Exception {
  const CloudAppUnavailable(this.app);
  final CloudApp app;
}

/// O aplicativo abriu e fechou na hora, sem o usuário escolher nada. Acontece
/// quando não há conta Google no aparelho (o Drive exige uma).
class CloudAppNotReady implements Exception {
  const CloudAppNotReady(this.app);
  final CloudApp app;

  String get message =>
      'O ${app.label} não abriu. Entre com uma conta Google no celular '
      '(Configurações > Contas) e abra o ${app.label} uma vez. Depois, tente de novo.';
}

/// Atalhos para Google Drive e Google Fotos usando os aplicativos do aparelho.
/// Não há login próprio: o arquivo passa pelo app instalado e conectado.
class CloudFiles {
  const CloudFiles();
  static const _channel = MethodChannel('financafacil/cloud_files');
  static const instantCancel = Duration(milliseconds: 1500);

  bool get _supported => Platform.isAndroid;

  /// Abre o aplicativo para escolher um arquivo. `null` quando cancelado.
  Future<PickedFile?> pick(
    CloudApp app, {
    required List<String> mimeTypes,
    required int maxBytes,
  }) async {
    if (!_supported) throw CloudAppUnavailable(app);
    final clock = Stopwatch()..start();
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'pickFromApp',
        {
          'package': app.packageName,
          'mimeTypes': mimeTypes,
          'maxBytes': maxBytes,
        },
      );
      if (result == null) {
        // Ninguém escolhe e cancela em menos de um segundo e meio: o app
        // recusou abrir (normalmente por falta de conta Google).
        if (clock.elapsed < instantCancel) throw CloudAppNotReady(app);
        return null;
      }
      final bytes = result['bytes'] as Uint8List?;
      if (bytes == null || bytes.isEmpty) {
        throw const FormatException('Arquivo vazio.');
      }
      return PickedFile(result['name']?.toString() ?? 'arquivo', bytes);
    } on PlatformException catch (error) {
      throw _translate(app, error);
    } on MissingPluginException {
      throw CloudAppUnavailable(app);
    }
  }

  /// Entrega o arquivo ao aplicativo (no Drive, abre "Salvar no Drive").
  Future<void> send(
    CloudApp app, {
    required String name,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (!_supported) throw CloudAppUnavailable(app);
    try {
      await _channel.invokeMethod<bool>('sendToApp', {
        'package': app.packageName,
        'name': name,
        'bytes': bytes,
        'mimeType': mimeType,
      });
    } on PlatformException catch (error) {
      throw _translate(app, error);
    } on MissingPluginException {
      throw CloudAppUnavailable(app);
    }
  }

  Object _translate(CloudApp app, PlatformException error) =>
      switch (error.code) {
        'APP_NOT_FOUND' => CloudAppUnavailable(app),
        'TOO_LARGE' => const FormatException(
          'Arquivo acima do tamanho permitido.',
        ),
        _ => error,
      };
}
