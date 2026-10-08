import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

/// Small, optional avatars are local and isolated by account.
class ProfilePhotoStore {
  static const maxBytes = 200 * 1024;
  String _key(String account) =>
      'profile_photo:${account.trim().toLowerCase()}';

  Future<Uint8List?> load(String account) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_key(account));
    if (encoded == null) return null;
    try {
      final bytes = base64Decode(encoded);
      return bytes.length <= maxBytes ? bytes : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> save(String account, Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw ArgumentError('Escolha uma foto menor.');
    }
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_key(account), base64Encode(bytes))) {
      throw StateError('Não foi possível salvar a foto.');
    }
  }

  Future<void> remove(String account) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.remove(_key(account))) {
      throw StateError('Não foi possível remover a foto.');
    }
  }
}
