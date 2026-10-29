import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:financafacil/features/profile/data/profile_image_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('foto grande é reduzida preservando proporção', () async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xFF336699), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(1024, 512);
    final encoded = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    final bytes = await prepareProfileImage(encoded!.buffer.asUint8List());
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    expect(frame.image.width, 256);
    expect(frame.image.height, 128);
    expect(bytes.length, lessThanOrEqualTo(200 * 1024));
    frame.image.dispose();
    codec.dispose();
  });
  test('imagem vazia e imagem acima de 5 MB são rejeitadas', () async {
    await expectLater(prepareProfileImage(Uint8List(0)), throwsFormatException);
    await expectLater(
      prepareProfileImage(Uint8List(5 * 1024 * 1024 + 1)),
      throwsFormatException,
    );
  });
  test('conteúdo não reconhecido como imagem é rejeitado', () async {
    await expectLater(
      prepareProfileImage(Uint8List.fromList([1, 2, 3])),
      throwsException,
    );
  });
}
