import 'dart:typed_data';
import 'package:financafacil/features/profile/data/profile_photo_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('foto persiste, fica isolada por conta e pode ser removida', () async {
    final store = ProfilePhotoStore();
    await store.save('one', Uint8List.fromList([1, 2, 3]));
    expect(await ProfilePhotoStore().load('one'), [1, 2, 3]);
    expect(await store.load('two'), isNull);
    await store.remove('one');
    expect(await store.load('one'), isNull);
  });
  test('foto inválida não substitui a anterior', () async {
    final store = ProfilePhotoStore();
    await store.save('one', Uint8List.fromList([1]));
    await expectLater(store.save('one', Uint8List(0)), throwsArgumentError);
    await expectLater(
        store.save('one', Uint8List(ProfilePhotoStore.maxBytes + 1)),
        throwsArgumentError);
    expect(await store.load('one'), [1]);
  });
  test('cache corrompido não bloqueia o perfil', () async {
    SharedPreferences.setMockInitialValues({'profile_photo:one': '***'});
    expect(await ProfilePhotoStore().load('one'), isNull);
  });
}
