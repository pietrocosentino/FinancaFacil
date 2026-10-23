import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Decode a bounded input at avatar resolution instead of full camera size.
Future<Uint8List> prepareProfileImage(Uint8List bytes) async {
  if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
    throw const FormatException('Escolha uma imagem de até 5 MB.');
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.ImageDescriptor? descriptor;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final scale = math.min(
      1.0,
      256 / math.max(descriptor.width, descriptor.height),
    );
    final codec = await descriptor.instantiateCodec(
      targetWidth: math.max(1, (descriptor.width * scale).round()),
      targetHeight: math.max(1, (descriptor.height * scale).round()),
    );
    try {
      final frame = await codec.getNextFrame();
      try {
        final encoded = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (encoded == null) throw const FormatException('Imagem inválida.');
        return encoded.buffer.asUint8List(
          encoded.offsetInBytes,
          encoded.lengthInBytes,
        );
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  } finally {
    descriptor?.dispose();
    buffer.dispose();
  }
}
