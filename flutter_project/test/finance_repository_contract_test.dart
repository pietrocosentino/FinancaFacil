import 'dart:async';
import 'dart:convert';

import 'package:financafacil/core/utils/finance_updates.dart';
import 'package:financafacil/features/transactions/data/finance_repository.dart';
import 'package:financafacil/features/transactions/domain/finance_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/fake_supabase_backend.dart';

// Contratos HTTP reais do adapter, sem acessar o projeto Supabase do usuário.
void main() {
  late FakeSupabaseBackend backend;
  late SupabaseFinanceRepository repository;

  setUp(() async {
    backend = FakeSupabaseBackend();
    await backend.authenticate();
    repository = SupabaseFinanceRepository(backend.client);
  });
  tearDown(() => backend.dispose());

  TransactionDraft draft({bool recurring = true, int? count}) =>
      TransactionDraft(
        kind: TransactionKind.expense,
        amount: 90.6,
        description: 'Ótica',
        dueDate: DateTime(2027, 1, 8),
        categoryId: 'category',
        dueDay: 8,
        isRecurring: recurring,
        totalInstallments: count,
      );

  test(
    'dez parcelas salvam uma única regra e nenhuma ocorrência antecipada',
    () async {
      await repository.save(draft(count: 10));
      expect(backend.requests, hasLength(1));
      expect(backend.requests.single.url.path, '/rest/v1/recurrence_rules');
      expect(backend.requests.single.method, 'POST');
      final body = jsonDecode(backend.requests.single.body) as Map;
      expect(body['user_id'], 'owner');
      expect(body['total_installments'], 10);
      expect(body['first_due'], '2027-01-08');
      expect(body['template']['amount'], 90.6);
    },
  );
  test(
    'recorrência sem fim mantém a quantidade opcional no contrato',
    () async {
      await repository.save(draft());
      final body = jsonDecode(backend.requests.single.body) as Map;
      expect(body['total_installments'], isNull);
      expect(body['due_day'], 8);
    },
  );
  test('lançamento avulso usa transactions e não cria regra', () async {
    await repository.save(draft(recurring: false));
    expect(backend.requests, hasLength(1));
    expect(backend.requests.single.url.path, '/rest/v1/transactions');
    final body = jsonDecode(backend.requests.single.body) as Map;
    expect(body['is_paid'], false);
    expect(body['is_recurrent'], false);
    expect(body['due_date'], '2027-01-08');
  });
  test('confirmar recorrência altera somente a ocorrência escolhida', () async {
    backend.respond = (_) => http.Response(
      'null',
      200,
      headers: {'content-type': 'application/json'},
    );
    await repository.markPaid({'r:rule:2027-02-01'});
    expect(backend.requests, hasLength(1));
    expect(
      backend.requests.single.url.path,
      '/rest/v1/rpc/set_recurrence_occurrence',
    );
    expect(jsonDecode(backend.requests.single.body), {
      'p_rule_id': 'rule',
      'p_due_month': '2027-02-01',
      'p_is_paid': true,
      'p_amount': null,
    });
  });
  test('atualizar valor recorrente não sobrescreve a confirmação', () async {
    backend.respond = (_) => http.Response(
      'null',
      200,
      headers: {'content-type': 'application/json'},
    );
    await repository.updateAmount('r:rule:2027-02-01', 100);
    final body = jsonDecode(backend.requests.single.body) as Map;
    expect(body['p_is_paid'], isNull);
    expect(body['p_amount'], 100);
  });
  test(
    'corrigir valor avulso confirmado envia somente amount e filtra dono',
    () async {
      backend.respond = (_) => http.Response(
        '[{"id":"one"}]',
        200,
        headers: {'content-type': 'application/json'},
      );
      await repository.updateAmount('one', 3250.50);
      final request = backend.requests.single;
      expect(request.method, 'PATCH');
      expect(request.url.queryParameters['user_id'], 'eq.owner');
      expect(jsonDecode(request.body), {'amount': 3250.50});
    },
  );
  test('alteração futura envia mês e valor para a RPC específica', () async {
    backend.respond = (_) => http.Response(
      'null',
      200,
      headers: {'content-type': 'application/json'},
    );
    await repository.updateFutureAmount('r:rule:2027-02-01', 100);
    expect(
      backend.requests.single.url.path,
      '/rest/v1/rpc/set_recurrence_future_amount',
    );
    expect(jsonDecode(backend.requests.single.body), {
      'p_rule_id': 'rule',
      'p_from_month': '2027-02-01',
      'p_amount': 100.0,
    });
  });
  test(
    'lote incompleto falha e ainda solicita atualização da interface',
    () async {
      final revision = financeRevision.value;
      await expectLater(repository.markPaid({'one', 'two'}), throwsStateError);
      expect(
        backend.requests.single.url.queryParameters['user_id'],
        'eq.owner',
      );
      expect(backend.requests.single.method, 'PATCH');
      expect(financeRevision.value, greaterThan(revision));
    },
  );
  test(
    'consulta pagina todos os registros e filtra as tabelas pelo usuário',
    () async {
      backend.respond = (request) {
        final path = request.url.path;
        final offset = int.parse(request.url.queryParameters['offset'] ?? '0');
        final data = path == '/rest/v1/transactions'
            ? List.generate(
                offset == 0 ? 500 : 1,
                (index) => {
                  'id': '${offset + index}',
                  'type': 'despesa',
                  'amount': 1,
                  'description': 'Conta ${offset + index}',
                  'due_date': '2027-01-08',
                  'is_paid': false,
                },
              )
            : [];
        return http.Response(
          jsonEncode(data),
          200,
          headers: {'content-type': 'application/json'},
        );
      };
      final entries = await repository.transactions(DateTime(2027, 1));
      expect(entries, hasLength(501));
      expect(entries.map((entry) => entry.id).toSet(), hasLength(501));
      final owned = backend.requests.where(
        (request) => !request.url.path.endsWith('/categories'),
      );
      expect(
        owned.every(
          (request) => request.url.queryParameters['user_id'] == 'eq.owner',
        ),
        true,
      );
    },
  );
  test('consulta inicial termina com timeout e permite nova tentativa', () async {
    final response = Completer<http.Response>();
    backend.respond = (_) => response.future;
    repository = SupabaseFinanceRepository(
      backend.client,
      snapshotTimeout: const Duration(milliseconds: 20),
    );

    await expectLater(
      repository.transactions(DateTime(2027, 1)),
      throwsA(isA<TimeoutException>()),
    );

    response.complete(FakeSupabaseBackend.jsonResponse([]));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    backend.respond = (_) => FakeSupabaseBackend.jsonResponse([]);
    expect(await repository.transactions(DateTime(2027, 1)), isEmpty);
  });
  test('sem sessão não envia transações nem gravações ao backend', () async {
    final anonymous = FakeSupabaseBackend();
    anonymous.respond = (_) => throw StateError('HTTP inesperado');
    addTearDown(() => anonymous.dispose());
    final unauthenticated = SupabaseFinanceRepository(anonymous.client);
    await expectLater(unauthenticated.save(draft()), throwsStateError);
    await expectLater(
      unauthenticated.transactions(DateTime(2027, 1)),
      throwsStateError,
    );
  });
}
