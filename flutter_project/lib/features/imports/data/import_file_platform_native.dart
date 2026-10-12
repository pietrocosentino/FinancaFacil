import 'dart:io';
import 'dart:typed_data';

Future<Uint8List?> readSelectedPath(String? path) async =>
    path == null ? null : File(path).readAsBytes();

Future<void> writeTemplatePath(String path, Uint8List bytes) async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    await File(path).writeAsBytes(bytes, flush: true);
  }
}

Future<bool> downloadTemplate(Uint8List bytes) async =>
    throw UnsupportedError('Download direto disponivel somente na web.');
