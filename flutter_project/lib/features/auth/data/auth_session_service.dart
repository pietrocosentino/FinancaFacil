import 'package:supabase_flutter/supabase_flutter.dart';

enum SessionEvent { changed, passwordRecovery, signedOut }

class AuthSessionService {
  AuthSessionService(this._client);
  final SupabaseClient _client;
  String? get userId => _client.auth.currentSession?.user.id;
  Stream<SessionEvent> get changes =>
      _client.auth.onAuthStateChange.map((state) {
        if (state.event == AuthChangeEvent.passwordRecovery) {
          return SessionEvent.passwordRecovery;
        }
        if (state.event == AuthChangeEvent.signedOut) {
          return SessionEvent.signedOut;
        }
        return SessionEvent.changed;
      });
  Future<void> signOut() => _client.auth.signOut();
}
