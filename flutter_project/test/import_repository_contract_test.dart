import 'dart:convert';

import 'package:financafacil/features/imports/data/import_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_supabase_backend.dart';

void main() {
  late FakeSupabaseBackend backend;
  late SupabaseImportRepository repository;
  setUp(() async {
    backend = FakeSupabaseBackend();
    await backend.authenticate();
    repository = SupabaseImportRepository(backend.client);
  });
  tearDown(() => backend.dispose());
  const row = {'line': 2, 'amount': 90.6, 'recurring': true, 'months': 10};
  test('lote é enviado em uma RPC única e não inclui user_id vindo do arquivo',
      () async {
    backend.respond = (_) => FakeSupabaseBackend.jsonResponse(
        {'batch_id': 'b', 'count': 1, 'already_imported': false});
    final receipt = await repository.save('contas.xlsx', 'a' * 64, [row],
        allowSimilar: false);
    expect(backend.requests, hasLength(1));
    expect(
        backend.requests.single.url.path, '/rest/v1/rpc/import_finance_batch');
    expect(jsonDecode(backend.requests.single.body), {
      'p_file_name': 'contas.xlsx',
      'p_file_hash': 'a' * 64,
      'p_rows': [row],
      'p_allow_similar': false
    });
    expect(receipt.count, 1);
  });
  test('prévia traduz números de linha e não cadastra', () async {
    backend.respond = (_) => FakeSupabaseBackend.jsonResponse([2, 4]);
    expect(await repository.similarLines([row]), {2, 4});
    expect(backend.requests.single.url.path,
        '/rest/v1/rpc/preview_finance_import');
  });
  test('histórico filtra a conta autenticada', () async {
    await repository.history();
    expect(backend.requests.single.url.queryParameters['user_id'], 'eq.owner');
    expect(backend.requests.single.url.queryParameters['limit'], '100');
  });
  test('desfazer usa RPC sem DELETE direto nas tabelas', () async {
    backend.respond = (_) => FakeSupabaseBackend.jsonResponse(1);
    expect(await repository.undo('b'), 1);
    expect(
        backend.requests.single.url.path, '/rest/v1/rpc/undo_finance_import');
    expect(backend.requests.single.method, 'POST');
  });
  test('sessão ausente impede importação antes de fazer HTTP', () async {
    await backend.client.auth.signOut();
    backend.requests.clear();
    await expectLater(
        repository.save('contas.xlsx', 'a' * 64, [row], allowSimilar: false),
        throwsStateError);
    expect(backend.requests, isEmpty);
  });
  for (final status in [401, 403, 429, 500, 503]) {
    test('falha HTTP $status não é tratada como importação concluída', () async {
      backend.respond = (_) => FakeSupabaseBackend.jsonResponse(
          {'message': 'Falha simulada', 'code': '$status'}, status: status);
      await expectLater(repository.save('massa.xlsx', 'a' * 64, [row],
          allowSimilar: false), throwsException);
      expect(backend.requests, hasLength(1));
      backend.respond = (_) => FakeSupabaseBackend.jsonResponse(
          {'batch_id': 'retry', 'count': 1, 'already_imported': true});
      final retry = await repository.save('massa.xlsx', 'a' * 64, [row],
          allowSimilar: false);
      expect(retry.alreadyImported, true);
      expect(backend.requests, hasLength(2));
    });
  }

}
