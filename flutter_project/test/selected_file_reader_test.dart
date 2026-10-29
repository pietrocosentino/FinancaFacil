import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:financafacil/core/files/selected_file_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('arquivo de nuvem sem caminho usa stream', () async {
    final file = PlatformFile(
      name: 'drive.xlsx',
      size: 3,
      readStream: Stream.fromIterable([
        [1, 2],
        [3],
      ]),
    );
    expect(await readSelectedFile(file, 10), [1, 2, 3]);
  });
  test('bytes disponíveis não exigem caminho', () async {
    final file = PlatformFile(
      name: 'foto.png',
      size: 2,
      bytes: Uint8List.fromList([1, 2]),
    );
    expect(await readSelectedFile(file, 10), [1, 2]);
  });
  test('metadados incorretos não contornam limite do stream', () async {
    final file = PlatformFile(
      name: 'drive.xlsx',
      size: 1,
      readStream: Stream.fromIterable([
        [1, 2],
        [3, 4],
      ]),
    );
    await expectLater(readSelectedFile(file, 3), throwsFormatException);
  });
  test('bytes reais são limitados mesmo com tamanho informado menor', () async {
    final file = PlatformFile(
      name: 'foto.png',
      size: 1,
      bytes: Uint8List.fromList([1, 2, 3, 4]),
    );
    await expectLater(readSelectedFile(file, 3), throwsFormatException);
  });
  test('stream vazio é rejeitado', () async {
    final file = PlatformFile(
      name: 'vazio.xlsx',
      size: 0,
      readStream: const Stream<List<int>>.empty(),
    );
    await expectLater(readSelectedFile(file, 10), throwsFormatException);
  });
  test('arquivo indisponível não vira cadastro', () async {
    final file = PlatformFile(name: 'offline.xlsx', size: 1);
    await expectLater(readSelectedFile(file, 10), throwsFormatException);
  });
  test('limite de tamanho é inclusivo', () async {
    final file = PlatformFile(
      name: 'limite.xlsx',
      size: 3,
      readStream: Stream.fromIterable([
        [1, 2, 3],
      ]),
    );
    expect(await readSelectedFile(file, 3), [1, 2, 3]);
  });
}
