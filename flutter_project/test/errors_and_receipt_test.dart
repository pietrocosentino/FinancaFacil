import 'dart:convert';

import 'package:financafacil/core/errors/app_failure.dart';
import 'package:financafacil/core/errors/app_log.dart';
import 'package:financafacil/core/errors/failure_message.dart';
import 'package:financafacil/core/utils/finance_updates.dart';
import 'package:financafacil/features/dashboard/domain/finance_summary.dart';
import 'package:financafacil/features/transactions/data/finance_repository.dart';
import 'package:financafacil/features/transactions/domain/finance_models.dart';
import 'package:financafacil/features/transactions/domain/recurrence.dart';
import 'package:financafacil/features/transactions/domain/statement.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/fake_supabase_backend.dart';

void main() {
  group('Mensagens de falha', () {
    const fallback = 'Falhou.';
    String message(Object error) => failureMessage(error, fallback: fallback);

    test('mensagens escritas para o usuário aparecem como estão', () {
      expect(message(const AppFailure('Senha incorreta.')), 'Senha incorreta.');
      expect(
        message(const FormatException('Valor inválido.')),
        'Valor inválido.',
      );
      expect(
        message(
          const PostgrestException(message: 'Lote preservado.', code: 'P0001'),
        ),
        'Lote preservado.',
      );
    });

    test('função ou coluna ausente pede atualização do banco', () {
      for (final code in ['42883', '42P01', '42703', 'PGRST202', 'PGRST205']) {
        expect(
          message(PostgrestException(message: 'missing', code: code)),
          outdatedDatabaseFailure,
          reason: code,
        );
      }
    });

    test('falhas de rede e de sessão têm explicação própria', () {
      expect(
        message(Exception('ClientException: Failed host lookup')),
        connectionFailure,
      );
      expect(
        message(StateError('Sua sessão terminou. Entre novamente.')),
        'Sua sessão terminou. Entre novamente.',
      );
      expect(
        message(const AuthException('JWT expired')),
        'Sua sessão terminou. Entre novamente.',
      );
    });

    test('erros desconhecidos usam a mensagem da tela', () {
      expect(message(StateError('interno')), fallback);
      expect(
        message(const PostgrestException(message: 'x', code: '23505')),
        fallback,
      );
    });
  });

  group('Registro de erros', () {
    tearDown(AppLog.reset);

    test('envia ao destino e guarda só as últimas falhas', () {
      final received = <String>[];
      AppLog.sink = (entry) => received.add(entry.context);
      for (var i = 0; i < 60; i++) {
        AppLog.error(StateError('falha $i'), null, 'tela $i');
      }
      expect(received, hasLength(60));
      expect(AppLog.recent, hasLength(50));
      expect(AppLog.recent.first.context, 'tela 10');
      expect(AppLog.recent.last.toString(), contains('falha 59'));
    });

    test('falha do destino não interrompe o app', () {
      AppLog.sink = (_) => throw StateError('destino fora do ar');
      expect(
        () => AppLog.error(StateError('x'), null, 'tela'),
        returnsNormally,
      );
      expect(AppLog.recent, hasLength(1));
    });
  });

  group('Comparação mensal', () {
    test('variação arredondada e sem base de comparação', () {
      expect(percentChange(180, 100), 80);
      expect(percentChange(50, 100), -50);
      expect(percentChange(100.004, 100), 0);
      expect(percentChange(10, 0), isNull);
      expect(
        expenseTrend(120, 100),
        'Despesas 20% maiores que no mês anterior.',
      );
      expect(
        expenseTrend(90, 100),
        'Despesas 10% menores que no mês anterior.',
      );
      expect(
        expenseTrend(100, 100),
        'Mesmo valor de despesas do mês anterior.',
      );
      expect(
        expenseTrend(10, 0),
        'Sem despesas no mês anterior para comparar.',
      );
    });
  });

  group('Filtro do extrato', () {
    test('copyWith troca um critério e permite voltar a todos os tipos', () {
      const base = StatementFilter(kind: TransactionKind.income, query: 'sal');
      final pending = base.copyWith(confirmation: ConfirmationFilter.pending);
      expect(pending.kind, TransactionKind.income);
      expect(pending.query, 'sal');
      expect(pending.copyWith(kind: () => null).kind, isNull);
      expect(const StatementFilter().isFiltered, isFalse);
      expect(const StatementFilter(query: '  ').isFiltered, isFalse);
      expect(pending.isFiltered, isTrue);
    });
  });

  group('Renda não recebida', () {
    Map<String, dynamic> salaryRule() => {
      'id': 'salary',
      'user_id': 'owner',
      'first_due': '2026-01-05',
      'due_day': 5,
      'template': {
        'type': 'receita',
        'amount': 3000,
        'description': 'Salário',
        'category_id': '1',
      },
    };

    test('mês marcado deixa de ser automático; os outros continuam', () {
      final rows = projectRecurrences(
        [salaryRule()],
        [
          {
            'rule_id': 'salary',
            'due_month': '2026-02-01',
            'is_paid': false,
            'manual_receipt': true,
          },
        ],
        DateTime(2026, 3),
      );
      final entries = [
        for (final row in rows)
          FinanceEntry.fromMap(row, today: DateTime(2026, 3, 20)),
      ];
      expect(entries.map((e) => e.isPaid), [true, false, true]);
      expect(entries.map((e) => e.isAutomaticIncome), [true, false, true]);
      expect(entries[1].manualReceipt, isTrue);
    });

    test('confirmação manual vale depois de "Não recebi"', () {
      final rows = projectRecurrences(
        [salaryRule()],
        [
          {
            'rule_id': 'salary',
            'due_month': '2026-01-01',
            'is_paid': true,
            'manual_receipt': true,
          },
        ],
        DateTime(2026, 1),
      );
      final entry = FinanceEntry.fromMap(
        rows.single,
        today: DateTime(2026, 1, 2),
      );
      expect(entry.isPaid, isTrue, reason: 'confirmado antes da data');
      expect(entry.isAutomaticIncome, isFalse);
      final cached = FinanceEntry.fromMap(entry.toMap());
      expect(cached.manualReceipt, isTrue);
      expect(cached.isPaid, isTrue);
    });
  });

  group('Contrato das novas funções', () {
    late FakeSupabaseBackend backend;
    late SupabaseFinanceRepository repository;
    setUp(() async {
      backend = FakeSupabaseBackend();
      await backend.authenticate();
      repository = SupabaseFinanceRepository(backend.client);
    });
    tearDown(() => backend.dispose());

    test('criar categoria envia nome limpo e tipo do banco', () async {
      backend.respond = (_) =>
          FakeSupabaseBackend.jsonResponse({'id': '42', 'name': 'Pet'});
      final revision = financeRevision.value;
      final category = await repository.createCategory(
        TransactionKind.expense,
        '  Pet ',
      );
      expect(category.id, '42');
      expect(category.name, 'Pet');
      final request = backend.requests.single;
      expect(request.url.path, '/rest/v1/rpc/create_category');
      expect(jsonDecode(request.body), {'p_name': 'Pet', 'p_type': 'EXPENSE'});
      expect(financeRevision.value, greaterThan(revision));
    });

    test(
      '"Não recebi" envia regra e mês e recarrega mesmo com falha',
      () async {
        backend.respond = (_) => FakeSupabaseBackend.jsonResponse(null);
        await repository.markNotReceived('r:rule-1:2026-02-01');
        final request = backend.requests.single;
        expect(request.url.path, '/rest/v1/rpc/set_income_not_received');
        expect(jsonDecode(request.body), {
          'p_rule_id': 'rule-1',
          'p_due_month': '2026-02-01',
        });

        backend.respond = (_) => FakeSupabaseBackend.jsonResponse({
          'code': 'PGRST202',
          'message': 'function not found',
        }, status: 404);
        final revision = financeRevision.value;
        await expectLater(
          repository.markNotReceived('r:rule-1:2026-02-01'),
          throwsA(isA<PostgrestException>()),
        );
        expect(financeRevision.value, greaterThan(revision));
      },
    );

    test('lançamento avulso não pode ser marcado como não recebido', () async {
      await expectLater(
        repository.markNotReceived('legacy-id'),
        throwsFormatException,
      );
      expect(backend.requests, isEmpty);
    });
  });
}
