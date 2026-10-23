import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Exercita os adapters e o SDK sem trafegar dados para um servidor real.
class FakeSupabaseBackend {
  FakeSupabaseBackend() {
    client = SupabaseClient(
      'https://unit-tests.invalid',
      'test-public-key',
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: _MemoryAuthStorage(),
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        final response = respond(request);
        return http.Response.bytes(
          response.bodyBytes,
          response.statusCode,
          headers: response.headers,
          request: request,
        );
      }),
    );
  }

  late final SupabaseClient client;
  final requests = <http.Request>[];
  http.Response Function(http.Request) respond = (_) => jsonResponse([]);

  static Map<String, Object> get user => {
    'id': 'owner',
    'email': 'owner@example.com',
    'user_metadata': {'full_name': 'Pietro', 'phone': '11999999999'},
  };
  static Map<String, Object> get session => {
    'access_token': 'fake-test-token',
    'token_type': 'bearer',
    'user': user,
  };
  static http.Response jsonResponse(Object? data, {int status = 200}) =>
      http.Response(
        jsonEncode(data),
        status,
        headers: {'content-type': 'application/json'},
      );

  Future<void> authenticate() =>
      client.auth.setInitialSession(jsonEncode(session));
  Future<void> dispose() => client.dispose();
}

class _MemoryAuthStorage implements GotrueAsyncStorage {
  final _values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => _values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _values.remove(key);
  }
}
