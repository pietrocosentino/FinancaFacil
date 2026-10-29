import 'dart:convert';

import 'package:financafacil/core/utils/finance_updates.dart';
import 'package:financafacil/features/transactions/data/finance_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_supabase_backend.dart';

void main() {
  late FakeSupabaseBackend b;
  late SupabaseFinanceRepository r;
  setUp(() async {
    b = FakeSupabaseBackend();
    await b.authenticate();
    r = SupabaseFinanceRepository(b.client);
  });
  tearDown(() => b.dispose());
  test('consultas concorrentes compartilham cinco leituras', () async {
    await Future.wait([
      r.transactions(DateTime(2026, 10)),
      r.transactions(DateTime(2026, 11)),
      r.transactions(DateTime(2026, 12)),
    ]);
    expect(b.requests.length, 5);
    await r.transactions(DateTime(2026, 9));
    expect(b.requests.length, 5);
  });
  test('alteração/recarregamento invalida dados em memória', () async {
    await r.transactions(DateTime(2026, 10));
    notifyFinanceChanged();
    await r.transactions(DateTime(2026, 10));
    expect(b.requests.length, 10);
  });
  test('trocar conta invalida cache e filtra pelo novo usuário', () async {
    await r.transactions(DateTime(2026, 10));
    await b.client.auth.setInitialSession(
      jsonEncode({
        ...FakeSupabaseBackend.session,
        'user': {...FakeSupabaseBackend.user, 'id': 'other'},
      }),
    );
    await r.transactions(DateTime(2026, 10));
    expect(b.requests.length, 10);
    final owned = b.requests
        .skip(5)
        .where((q) => !q.url.path.endsWith('/categories'));
    expect(
      owned.every((q) => q.url.queryParameters['user_id'] == 'eq.other'),
      true,
    );
  });
  test('dados expiram após dois minutos sem timer ou espera real', () async {
    var clock = DateTime(2026, 10, 8, 12);
    final cached = SupabaseFinanceRepository(b.client, now: () => clock);
    await cached.transactions(clock);
    clock = clock.add(const Duration(seconds: 119));
    await cached.transactions(clock);
    expect(b.requests.length, 5);
    clock = clock.add(const Duration(seconds: 1));
    await cached.transactions(clock);
    expect(b.requests.length, 10);
  });
  test('consulta com erro pode ser tentada novamente', () async {
    b.respond = (_) =>
        FakeSupabaseBackend.jsonResponse({'message': 'Falha'}, status: 400);
    await expectLater(r.transactions(DateTime(2026, 10)), throwsException);
    b.respond = (_) => FakeSupabaseBackend.jsonResponse([]);
    expect(await r.transactions(DateTime(2026, 10)), isEmpty);
    expect(b.requests.length, 10);
  });
}
