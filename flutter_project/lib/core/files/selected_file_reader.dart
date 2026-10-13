import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Cloud providers can return a stream without a usable local path.
Future<Uint8List> readSelectedFile(PlatformFile file, int maxBytes) async {
  if (file.size > maxBytes) {
    throw const FormatException('Arquivo acima do tamanho permitido.');
  }
  final data = file.bytes;
  if (data != null) {
    if (data.isEmpty || data.length > maxBytes) {
      throw const FormatException('Arquivo vazio ou acima do limite.');
    }
    return data;
  }
  final stream = file.readStream ??
      (file.path == null ? null : File(file.path!).openRead());
  if (stream == null) {
    throw const FormatException('Não foi possível abrir o arquivo escolhido.');
  }
  final builder = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    if (builder.length + chunk.length > maxBytes) {
      throw const FormatException('Arquivo acima do tamanho permitido.');
    }
    builder.add(chunk);
  }
  if (builder.length == 0) throw const FormatException('Arquivo vazio.');
  return builder.takeBytes();
}
