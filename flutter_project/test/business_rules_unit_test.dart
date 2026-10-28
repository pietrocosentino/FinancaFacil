import 'dart:convert';

import 'package:financafacil/core/utils/dates.dart';
import 'package:financafacil/core/utils/phone_formatter.dart';
import 'package:financafacil/features/dashboard/domain/finance_summary.dart';
import 'package:financafacil/features/notifications/domain/reminder_plan.dart';
import 'package:financafacil/features/transactions/domain/finance_models.dart';
import 'package:financafacil/features/transactions/domain/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

// Datas fixas: os testes não dependem do relógio, da rede ou do Supabase.
Map<String, dynamic> monthlyRule({String id = 'optical', int? count = 10}) => {
  'id': id,
  'user_id': 'owner',
  'first_due': '2026-01-08',
  'due_day': 8,
  'total_installments': count,
  'template': {
    'type': 'despesa',
    'amount': 90.60,
    'description': 'Ótica',
    'category_id': 'health',
    'notes': 'Transferir para meu pai',
  },
};

FinanceEntry bill(
  String id,
  DateTime? due, {
  bool paid = false,
  TransactionKind kind = TransactionKind.expense,
  double amount = 90.60,
}) => FinanceEntry(
  id: id,
  kind: kind,
  amount: amount,
  description: id,
  dueDate: due,
  categoryName: 'Saúde',
  isPaid: paid,
);

void main() {
  group('Compra em dez meses e conta sem prazo', () {
    test('a ótica custa uma parcela por mês e termina em outubro', () {
      final rows = projectRecurrences([monthlyRule()], [], DateTime(2027, 12));
      expect(rows, hasLength(10));
      expect(rows.every((row) => row['amount'] == 90.60), isTrue);
      expect(rows.last['due_date'], '2026-10-08T00:00:00.000');
      expect(rows.last['_installment'], 10);
      expect(rows.first['_last_due'], rows.last['due_date']);
    });
    test('confirmar janeiro não confirma fevereiro', () {
      final rows = projectRecurrences(
        [monthlyRule()],
        [
          {'rule_id': 'optical', 'due_month': '2026-01-01', 'is_paid': true},
        ],
        DateTime(2026, 2),
      );
      expect(rows.map((row) => row['is_paid']), [true, false]);
    });
    test('consultar janeiro não acumula dez parcelas no saldo', () {
      final entries = projectRecurrences(
        [monthlyRule()],
        [],
        DateTime(2026, 10),
      ).map(FinanceEntry.fromMap).toList();
      final summary = FinanceSummary.forMonth(entries, DateTime(2026, 1));
      expect(summary.expenses, 90.60);
      expect(summary.predictedBalance, -90.60);
    });
    test('aluguel continua por anos sem quantidade obrigatória', () {
      final rows = projectRecurrences(
        [monthlyRule(count: null)],
        [],
        DateTime(2029, 12),
      );
      expect(rows, hasLength(48));
      expect(rows.last['_last_due'], isNull);
      expect(rows.last['_total_installments'], isNull);
    });
    test('regras distintas não compartilham confirmação', () {
      final rows = projectRecurrences(
        [monthlyRule(), monthlyRule(id: 'rent')],
        [
          {'rule_id': 'optical', 'due_month': '2026-01-01', 'is_paid': true},
        ],
        DateTime(2026, 1),
      );
      expect(rows.map((row) => row['is_paid']), [true, false]);
    });
    test('a projeção preserva observações em todos os meses', () {
      final rows = projectRecurrences([monthlyRule()], [], DateTime(2026, 3));
      expect(
        rows.every((row) => row['notes'] == 'Transferir para meu pai'),
        isTrue,
      );
    });
  });

  group('Mudanças de valor e correção de pagamento', () {
    Map<String, dynamic> changedRule() {
      final rule = monthlyRule();
      (rule['template'] as Map)['future_amounts'] = [
        {'from_month': '2026-04-01', 'amount': 120.0},
        {'from_month': '2026-02-01', 'amount': 100.0},
      ];
      return rule;
    }

    test('mudanças fora de ordem respeitam a vigência de cada mês', () {
      final rows = projectRecurrences([changedRule()], [], DateTime(2026, 5));
      expect(rows.map((row) => row['amount']), [
        90.60,
        100.0,
        100.0,
        120.0,
        120.0,
      ]);
    });
    test('ajuste específico de março prevalece sobre a previsão', () {
      final rows = projectRecurrences(
        [changedRule()],
        [
          {'rule_id': 'optical', 'due_month': '2026-03-01', 'amount': 105.75},
        ],
        DateTime(2026, 4),
      );
      expect(rows.map((row) => row['amount']), [90.60, 100.0, 105.75, 120.0]);
    });
    test('valor confirmado preservado não acompanha reajuste posterior', () {
      final rows = projectRecurrences(
        [changedRule()],
        [
          {
            'rule_id': 'optical',
            'due_month': '2026-04-01',
            'amount': 90.60,
            'is_paid': true,
          },
        ],
        DateTime(2026, 5),
      );
      expect(rows[3]['amount'], 90.60);
      expect(rows[3]['is_paid'], true);
      expect(rows[4]['amount'], 120.0);
    });
    test('corrigir confirmação devolve a ocorrência aos lembretes', () {
      final rows = projectRecurrences(
        [monthlyRule()],
        [
          {'rule_id': 'optical', 'due_month': '2026-01-01', 'is_paid': false},
        ],
        DateTime(2026, 1),
      );
      expect(
        pendingBills(
          rows.map(FinanceEntry.fromMap).toList(),
          DateTime(2026, 1, 8),
        ),
        hasLength(1),
      );
    });
    test('corrigir ocorrência após encerramento não reativa a regra', () {
      final rule = monthlyRule()..['end_date'] = '2026-01-31';
      final rows = projectRecurrences(
        [rule],
        [
          {'rule_id': 'optical', 'due_month': '2026-02-01', 'is_paid': false},
        ],
        DateTime(2026, 4),
      );
      expect(rows, hasLength(1));
      expect(rows.single['_installment'], 1);
    });
    test('consulta não modifica regras nem ajustes recebidos', () {
      final rule = changedRule();
      final overrides = [
        {'rule_id': 'optical', 'due_month': '2026-02-01', 'amount': 99.0},
      ];
      final before = jsonEncode([rule, overrides]);
      projectRecurrences([rule], overrides, DateTime(2026, 5));
      expect(jsonEncode([rule, overrides]), before);
    });
    test('resumo da regra usa o valor vigente no mês solicitado', () {
      final plan = RecurrencePlan.fromMap(changedRule());
      expect(plan.amountAt(DateTime(2026, 1)), 90.60);
      expect(plan.amountAt(DateTime(2026, 3)), 100.0);
      expect(plan.amountAt(DateTime(2026, 4)), 120.0);
    });
  });

  group('Saldos mensais', () {
    final month = DateTime(2026, 1);
    test('renda futura não fica disponível antes do recebimento', () {
      final summary = FinanceSummary.forMonth([
        bill('salary', month, kind: TransactionKind.income, amount: 1000),
      ], month);
      expect(summary.availableBalance, 0);
      expect(summary.predictedBalance, 1000);
    });
    test('pagar muda o confirmado, sem descontar duas vezes do previsto', () {
      FinanceSummary summary(bool paid) => FinanceSummary.forMonth([
        bill(
          'salary',
          month,
          kind: TransactionKind.income,
          amount: 1000,
          paid: true,
        ),
        bill('optical', month, paid: paid),
      ], month);
      expect(summary(false).availableBalance, 1000);
      expect(summary(true).availableBalance, 909.40);
      expect(summary(false).predictedBalance, summary(true).predictedBalance);
    });
    test('receita de outro ano e conta sem vencimento não entram no mês', () {
      final summary = FinanceSummary.forMonth([
        bill(
          'old',
          DateTime(2025, 1),
          kind: TransactionKind.income,
          amount: 1000,
          paid: true,
        ),
        bill('undated', null),
      ], month);
      expect(summary.income, 0);
      expect(summary.expenses, 0);
    });
    test('centavos de parcelas e renda não acumulam erro de soma', () {
      final summary = FinanceSummary.forMonth([
        bill(
          'income',
          month,
          kind: TransactionKind.income,
          amount: 181.20,
          paid: true,
        ),
        bill('one', month, paid: true),
        bill('two', month, paid: true),
      ], month);
      expect(summary.availableBalance, 0);
      expect(summary.predictedBalance, 0);
    });
  });

  group('Lembretes', () {
    test('vence dia 8 começa a lembrar dia 5 e não dia 4', () {
      final entries = [bill('optical', DateTime(2026, 1, 8))];
      expect(pendingBills(entries, DateTime(2026, 1, 4)), isEmpty);
      expect(pendingBills(entries, DateTime(2026, 1, 5)), hasLength(1));
    });
    test('horário ignora diferença de horas ao classificar vencimento', () {
      expect(daysUntil(DateTime(2026, 1, 8, 23), DateTime(2026, 1, 5, 1)), 3);
      expect(daysUntil(DateTime(2026, 1, 8, 1), DateTime(2026, 1, 5, 23)), 3);
    });
    test('horário escolhido é respeitado', () {
      final reminders = planReminders(
        [bill('optical', DateTime(2026, 1, 8))],
        DateTime(2026, 1, 5),
        hour: 18,
        minute: 30,
        horizonDays: 1,
      );
      expect(reminders.first.date, DateTime(2026, 1, 5, 18, 30));
    });
    test('horário de hoje já passado agenda no horário escolhido amanhã', () {
      final reminders = planReminders(
        [bill('optical', DateTime(2026, 1, 8))],
        DateTime(2026, 1, 5, 18, 31),
        hour: 18,
        minute: 30,
        horizonDays: 1,
      );
      expect(reminders.single.date, DateTime(2026, 1, 6, 18, 30));
    });
    test('receita, conta paga e data ausente não geram avisos', () {
      final reminders = planReminders([
        bill('paid', DateTime(2026, 1, 8), paid: true),
        bill('income', DateTime(2026, 1, 8), kind: TransactionKind.income),
        bill('undated', null),
      ], DateTime(2026, 1, 5));
      expect(reminders, isEmpty);
    });
    test('duas contas no mesmo dia geram um aviso com contagem dois', () {
      final reminders = planReminders(
        [bill('one', DateTime(2026, 1, 8)), bill('two', DateTime(2026, 1, 8))],
        DateTime(2026, 1, 5),
        horizonDays: 0,
      );
      expect(reminders, hasLength(1));
      expect(reminders.single.count, 2);
    });
    test('agenda atravessa ano sem repetir identificadores', () {
      final reminders = planReminders(
        [bill('late', DateTime(2026, 12, 1))],
        DateTime(2026, 12, 30),
        horizonDays: 4,
      );
      expect(reminders.map((r) => r.id).toSet(), hasLength(reminders.length));
      expect(reminders.last.date, DateTime(2027, 1, 3, 9));
    });
  });

  group('Dados de cadastro', () {
    TransactionDraft draft({
      double amount = 90.60,
      int day = 8,
      int? count,
      bool recurring = true,
      bool confirmed = false,
      String category = 'health',
    }) => TransactionDraft(
      kind: TransactionKind.expense,
      amount: amount,
      description: ' Ótica ',
      dueDate: DateTime(2026, 1, 8),
      dueDay: day,
      categoryId: category,
      isRecurring: recurring,
      totalInstallments: count,
      alreadyConfirmed: confirmed,
      notes: ' Transferir ',
    );
    test('valores não finitos ou não positivos são rejeitados', () {
      for (final amount in [
        double.nan,
        double.infinity,
        double.negativeInfinity,
        -1.0,
        0.0,
      ]) {
        expect(
          () => draft(amount: amount),
          throwsFormatException,
          reason: '$amount',
        );
      }
    });
    test('dia mensal deve estar entre 1 e 31', () {
      expect(() => draft(day: 0), throwsFormatException);
      expect(() => draft(day: 32), throwsFormatException);
      expect(draft(day: 31).dueDay, 31);
    });
    test('quantidade opcional aceita limites válidos', () {
      expect(draft().totalInstallments, isNull);
      expect(draft(count: 2).totalInstallments, 2);
      expect(draft(count: 1200).totalInstallments, 1200);
      expect(() => draft(count: 1), throwsFormatException);
      expect(() => draft(count: 1201), throwsFormatException);
    });
    test('conta mensal não confirma todos os pagamentos no cadastro', () {
      expect(() => draft(confirmed: true), throwsFormatException);
      expect(draft(recurring: false, confirmed: true).alreadyConfirmed, isTrue);
    });
    test('categoria ausente é rejeitada e textos são normalizados', () {
      expect(() => draft(category: ''), throwsFormatException);
      expect(draft().description, 'Ótica');
      expect(draft().template['notes'], 'Transferir');
    });
    test('telefone brasileiro formata e normaliza sem perder dígitos', () {
      expect(formatPhone('11999999999'), '(11) 99999-9999');
      expect(formatPhone('1133334444'), '(11) 3333-4444');
      expect(phoneDigits('(11) 99999-9999'), '11999999999');
      expect(formatPhone(''), '');
      expect(formatPhone('5511999999999'), '5511999999999');
    });
  });
}
