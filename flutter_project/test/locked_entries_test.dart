import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:financafacil/features/dashboard/domain/finance_summary.dart';
import 'package:financafacil/features/imports/data/xlsx_export_writer.dart';
import 'package:financafacil/features/transactions/data/finance_repository.dart';
import 'package:financafacil/features/transactions/domain/entry_status.dart';
import 'package:financafacil/features/transactions/domain/finance_models.dart';
import 'package:financafacil/features/transactions/domain/recurrence.dart';
import 'package:financafacil/features/transactions/domain/statement.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';

import 'support/fake_supabase_backend.dart';

FinanceEntry _entry(
  String id, {
  TransactionKind kind = TransactionKind.expense,
  double amount = 100,
  bool paid = true,
  bool inactive = false,
  bool recurring = false,
  String description = 'Conta',
}) => FinanceEntry(
  id: id,
  kind: kind,
  amount: amount,
  description: description,
  dueDate: DateTime(2026, 10, 5),
  categoryName: 'Moradia',
  isPaid: paid,
  isInactive: inactive,
  isRecurring: recurring,
);

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('bloqueio após confirmação', () {
    test('conta paga fica bloqueada; pendente e renda não', () {
      expect(_entry('a').isLocked, true);
      expect(_entry('a', paid: false).isLocked, false);
      expect(_entry('a', kind: TransactionKind.income).isLocked, false);
      final salary = _entry(
        'r:rule:2026-10-01',
        kind: TransactionKind.income,
        recurring: true,
      );
      expect(salary.isAutomaticIncome, true);
      expect(salary.isLocked, false);
    });

    test('inativo sai dos totais do extrato e do resumo do mês', () {
      final entries = [
        _entry('rent', amount: 1200),
        _entry('mistake', amount: 300, inactive: true),
        _entry('salary', kind: TransactionKind.income, amount: 5000),
      ];
      final totals = totalsInCents(entries);
      expect(totals.expenseCents, 120000);
      expect(totals.incomeCents, 500000);
      final summary = FinanceSummary.forMonth(entries, DateTime(2026, 10));
      expect(summary.expenses, 1200);
      expect(summary.availableBalance, 3800);
    });

    test('situação mostra inativo antes de pago', () {
      final status = EntryStatus.of(
        _entry('a', inactive: true),
        DateTime(2026, 10, 1),
      );
      expect(status.label, 'Inativo · fora dos totais');
      expect(status.urgency, EntryUrgency.inactive);
    });

    test('ocorrência inativada continua na projeção, marcada como inativa', () {
      final rows = projectRecurrences(
        [
          {
            'id': 'rule',
            'user_id': 'owner',
            'first_due': '2026-09-05',
            'due_day': 5,
            'template': {
              'type': 'despesa',
              'amount': 80,
              'description': 'Internet',
              'category_id': '1',
            },
          },
        ],
        [
          {
            'rule_id': 'rule',
            'due_month': '2026-10-01',
            'is_paid': true,
            'is_inactive': true,
          },
        ],
        DateTime(2026, 10),
      );
      final entries = rows.map(FinanceEntry.fromMap).toList();
      expect(entries.map((e) => e.isInactive), [false, true]);
      expect(entries.last.isPaid, true);
      expect(entries.last.categoryId, '1');
    });

    test('dados de edição validam nome, valor e dia', () {
      expect(
        () => EntryDetails(
          description: ' ',
          amount: 10,
          dueDate: DateTime(2026),
          categoryId: '1',
        ),
        throwsFormatException,
      );
      expect(
        () => IncomeRuleDetails(
          description: 'Salário',
          categoryId: '1',
          dueDay: 32,
        ),
        throwsFormatException,
      );
      final details = EntryDetails(
        description: ' Luz ',
        amount: 99.9,
        dueDate: DateTime(2026, 11, 3),
        categoryId: '7',
        notes: ' débito ',
      );
      expect(details.toMap(), {
        'description': 'Luz',
        'amount': 99.9,
        'due_date': '2026-11-03',
        'category_id': '7',
        'notes': 'débito',
      });
    });
  });

  group('contratos com o banco', () {
    late FakeSupabaseBackend backend;
    late SupabaseFinanceRepository repository;

    setUp(() async {
      backend = FakeSupabaseBackend();
      await backend.authenticate();
      repository = SupabaseFinanceRepository(backend.client);
    });
    tearDown(() => backend.dispose());

    http.Response json(Object? body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );

    test(
      'inativar usa a RPC própria com o identificador do lançamento',
      () async {
        backend.respond = (_) => json(null);
        await repository.setInactive('r:rule:2026-10-01', true);
        expect(
          backend.requests.single.url.path,
          '/rest/v1/rpc/set_entry_inactive',
        );
        expect(jsonDecode(backend.requests.single.body), {
          'p_entry_id': 'r:rule:2026-10-01',
          'p_inactive': true,
        });
      },
    );

    test('editar avulso altera somente se ainda estiver pendente', () async {
      backend.respond = (_) => json([
        {'id': 'one'},
      ]);
      await repository.updateDetails(
        'one',
        EntryDetails(
          description: 'Luz',
          amount: 120,
          dueDate: DateTime(2026, 10, 9),
          categoryId: '3',
        ),
      );
      final request = backend.requests.single;
      expect(request.method, 'PATCH');
      expect(request.url.path, '/rest/v1/transactions');
      expect(
        request.url.queryParameters['or'],
        '(is_paid.eq.false,type.eq.receita)',
      );
      expect(request.url.queryParameters['user_id'], 'eq.owner');
      expect((jsonDecode(request.body) as Map)['due_date'], '2026-10-09');
    });

    test('editar avulso já confirmado é recusado', () async {
      backend.respond = (_) => json([]);
      await expectLater(
        repository.updateDetails(
          'one',
          EntryDetails(
            description: 'Luz',
            amount: 120,
            dueDate: DateTime(2026, 10, 9),
            categoryId: '3',
          ),
        ),
        throwsStateError,
      );
    });

    test('renda mensal altera nome, categoria e dia pela RPC', () async {
      backend.respond = (_) => json(null);
      await repository.updateIncomeRule(
        'rule',
        IncomeRuleDetails(description: 'Salário', categoryId: '9', dueDay: 6),
      );
      expect(
        backend.requests.single.url.path,
        '/rest/v1/rpc/update_income_rule',
      );
      expect(jsonDecode(backend.requests.single.body), {
        'p_rule_id': 'rule',
        'p_description': 'Salário',
        'p_category_id': '9',
        'p_due_day': 6,
      });
    });
  });

  group('exportação para Excel', () {
    test(
      'gera planilha válida com valores, situação e totais sem inativos',
      () {
        final bytes = XlsxExportWriter().write(
          [
            _entry('a', amount: 1200, description: 'Aluguel & condomínio'),
            _entry('b', amount: 300, inactive: true, description: 'Engano'),
            _entry(
              'c',
              kind: TransactionKind.income,
              amount: 5000,
              description: 'Salário',
            ),
          ],
          from: DateTime(2026, 10),
          to: DateTime(2026, 10),
          today: DateTime(2026, 10, 20),
        );
        final files = {
          for (final file in ZipDecoder().decodeBytes(bytes)) file.name: file,
        };
        expect(
          files.keys,
          containsAll([
            '[Content_Types].xml',
            'xl/workbook.xml',
            'xl/styles.xml',
            'xl/worksheets/sheet1.xml',
          ]),
        );
        final sheet = utf8.decode(
          files['xl/worksheets/sheet1.xml']!.content as List<int>,
        );
        expect(sheet, contains('Aluguel &amp; condomínio'));
        expect(sheet, contains('Inativo · fora dos totais'));
        expect(sheet, contains('<v>-1200.00</v>'));
        expect(sheet, contains('<v>5000.00</v>'));
        // Saldo ignora o lançamento inativado: 5000 - 1200.
        expect(sheet, contains('<v>3800.00</v>'));
        expect(sheet, isNot(contains('<f>')));
      },
    );

    test('nome do arquivo indica o período', () {
      expect(
        XlsxExportWriter.fileName(DateTime(2026, 1), DateTime(2026, 12)),
        'financafacil_2026-01_a_2026-12.xlsx',
      );
    });
  });
}
