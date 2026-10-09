import 'dart:typed_data';
import 'package:financafacil/features/profile/data/profile_photo_store.dart';
import 'package:financafacil/features/profile/presentation/profile_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_repositories.dart';

class _Photos extends ProfilePhotoStore {
  int loads = 0;
  bool fail = false;
  Uint8List? bytes;
  @override
  Future<Uint8List?> load(String account) async {
    loads++;
    return bytes;
  }

  @override
  Future<void> save(String account, Uint8List value) async {
    if (fail) throw StateError('Falha');
    bytes = value;
  }

  @override
  Future<void> remove(String account) async {
    bytes = null;
  }
}

void main() {
  test('avatar é carregado uma vez e compartilhado entre consumidores',
      () async {
    final store = _Photos();
    final c = ProfileController(FakeProfileRepository(), photos: store);
    addTearDown(c.dispose);
    await Future.wait([c.loadPhoto(), c.loadPhoto()]);
    await c.loadPhoto();
    expect(store.loads, 1);
  });
  test('salvar/remover foto notifica estado somente depois de persistir',
      () async {
    final store = _Photos();
    final c = ProfileController(FakeProfileRepository(), photos: store);
    addTearDown(c.dispose);
    var changes = 0;
    c.addListener(() => changes++);
    final bytes = Uint8List.fromList([1, 2, 3]);
    await c.savePhoto(bytes);
    expect(c.photo, bytes);
    expect(changes, 1);
    await c.removePhoto();
    expect(c.photo, isNull);
    expect(changes, 2);
  });
  test('falha de persistência preserva avatar anterior', () async {
    final store = _Photos();
    final c = ProfileController(FakeProfileRepository(), photos: store);
    addTearDown(c.dispose);
    final bytes = Uint8List.fromList([1]);
    await c.savePhoto(bytes);
    store.fail = true;
    await expectLater(c.savePhoto(Uint8List.fromList([2])), throwsStateError);
    expect(c.photo, bytes);
  });
  test('refresh publica nome atualizado sem reler a foto', () async {
    final r = FakeProfileRepository();
    final store = _Photos();
    final c = ProfileController(r, photos: store);
    addTearDown(c.dispose);
    await c.loadPhoto();
    await r.update('Novo nome', '11999999999');
    c.refresh();
    expect(c.profile!.name, 'Novo nome');
    expect(store.loads, 1);
  });
}
