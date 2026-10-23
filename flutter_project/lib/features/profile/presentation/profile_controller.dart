import 'package:flutter/foundation.dart';

import '../../../core/errors/app_log.dart';
import '../data/profile_photo_store.dart';
import '../data/profile_repository.dart';
import '../domain/user_profile.dart';

/// Estado compartilhado do cabeçalho e do menu, sem consultas periódicas.
class ProfileController extends ChangeNotifier {
  ProfileController(this.repository, {ProfilePhotoStore? photos})
    : photos = photos ?? ProfilePhotoStore();
  final ProfileRepository repository;
  final ProfilePhotoStore photos;
  Uint8List? photo;
  Future<void>? _loading;
  bool _disposed = false;
  UserProfileData? get profile => repository.currentProfile;
  void refresh() {
    if (!_disposed) notifyListeners();
  }

  Future<void> loadPhoto() => _loading ??= _loadPhoto();
  Future<void> _loadPhoto() async {
    final account = profile?.email;
    if (account == null) return;
    try {
      photo = await photos.load(account);
      refresh();
    } catch (error, stack) {
      AppLog.error(error, stack, 'carregar foto');
      /* Avatar indisponível não bloqueia a conta. */
    }
  }

  Future<void> savePhoto(Uint8List bytes) async {
    final account = profile?.email;
    if (account == null) throw StateError('Sessão encerrada.');
    await photos.save(account, bytes);
    photo = bytes;
    refresh();
  }

  Future<void> removePhoto() async {
    final account = profile?.email;
    if (account == null) throw StateError('Sessão encerrada.');
    await photos.remove(account);
    photo = null;
    refresh();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
