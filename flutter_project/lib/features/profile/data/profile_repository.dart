import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/user_profile.dart';

abstract class ProfileRepository {
  UserProfileData? get currentProfile;
  Future<void> update(String name, String phone);
  Future<void> signOut();
}

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);
  final SupabaseClient _client;
  @override
  UserProfileData? get currentProfile {
    final user = _client.auth.currentUser;
    return user == null
        ? null
        : UserProfileData.fromMetadata(user.email, user.userMetadata);
  }

  @override
  Future<void> update(String name, String phone) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Sua sessão terminou. Entre novamente.');
    await _client.auth.updateUser(UserAttributes(data: {
      ...?user.userMetadata,
      'full_name': name.trim(),
      'phone': phone.trim(),
    }));
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}
