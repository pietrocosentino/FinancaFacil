import 'package:financafacil/core/utils/dates.dart';
import 'package:financafacil/core/utils/single_flight.dart';
import 'package:financafacil/features/notifications/domain/reminder_plan.dart';
import 'package:financafacil/features/transactions/domain/entry_status.dart';
import 'package:financafacil/features/transactions/domain/finance_models.dart';
import 'package:financafacil/features/transactions/domain/recurrence.dart';
import 'package:financafacil/features/transactions/domain/statement.dart';
import 'package:flutter_test/flutter_test.dart';

FinanceEntry entry(
  String id, {
  TransactionKind kind = TransactionKind.expense,
  double amount = 10,
  DateTime? due,
  bool paid = false,
  bool recurring = false,
  String description = 'Conta',
}) => FinanceEntry(
  id: id,
  kind: kind,
  amount: amount,
  description: description,
  dueDate: due ?? DateTime(2026, 5, 10),
  categoryName: 'Categoria',
  isPaid: paid,
  isRecurring: recurring,
);

void main() {
  group('Datas', () {
    test('isoDate completa ano, mês e dia com zeros', () {
      expect(isoDate(DateTime(2026, 1, 5)), '2026-01-05');
      expect(isoDate(DateTime(999, 12, 31)), '0999-12-31');
    });

    test('monthKey usa o primeiro dia e ignora horário', () {
      expect(monthKey(DateTime(2026, 2, 28, 23, 59)), '2026-02-01');
      expect(monthKey(DateTime(2026, 12, 31)), '2026-12-01');
    });

    test('daysUntil conta dias de calendário, inclusive entre anos', () {
      expect(daysUntil(DateTime(2026, 1, 1), DateTime(2025, 12, 31, 23)), 1);
      expect(daysUntil(DateTime(2026, 3, 1), DateTime(2026, 3, 1, 22)), 0);
      expect(daysUntil(DateTime(2026, 2, 27), DateTime(2026, 3, 2)), -3);
    });
  });

  group('AmountSchedule', () {
    test('sem reajustes usa o valor base', () {
      expect(AmountSchedule(90.6, const []).at('2030-01-01'), 90.6);
    });

    test('reajustes valem a partir do mês e aceitam lista fora de ordem', () {
      final schedule = AmountSchedule(100, [
        {'from_month': '2026-06-01', 'amount': 130},
        {'from_month': '2026-03-01', 'amount': 110},
      ]);
      expect(schedule.at('2026-02-01'), 100);
      expect(schedule.at('2026-03-01'), 110);
      expect(schedule.at('2026-05-01'), 110);
      expect(schedule.at('2026-06-01'), 130);
      expect(schedule.at('2027-01-01'), 130);
    });

    test('regra e projeção usam o mesmo cálculo de reajuste', () {
      final rule = {
        'id': 'rent',
        'user_id': 'owner',
        'first_due': '2026-01-10',
        'due_day': 10,
        'total_installments': null,
        'template': {
          'type': 'despesa',
          'amount': 1000,
          'description': 'Aluguel',
          'category_id': '1',
          'future_amounts': [
            {'from_month': '2026-04-01', 'amount': 1100},
          ],
        },
      };
      final projected = projectRecurrences([rule], const [], DateTime(2026, 6));
      final plan = RecurrencePlan.fromMap(rule);
      for (final row in projected) {
        final month = DateTime.parse(row['due_date'] as String);
        expect(row['amount'], plan.amountAt(month), reason: '$month');
      }
      expect(projected.map((row) => row['amount']), [
        1000,
        1000,
        1000,
        1100,
        1100,
        1100,
      ]);
    });
  });

  group('EntryStatus', () {
    final today = DateTime(2026, 5, 10, 15);

    test('pagamentos e recebimentos confirmados ficam resolvidos', () {
      expect(EntryStatus.of(entry('a', paid: true), today).label, 'Pago');
      expect(
        EntryStatus.of(
          entry('b', kind: TransactionKind.income, paid: true),
          today,
        ).label,
        'Recebido',
      );
      final automatic = EntryStatus.of(
        entry('c', kind: TransactionKind.income, paid: true, recurring: true),
        today,
      );
      expect(automatic.label, 'Recebido · automático');
      expect(automatic.urgency, EntryUrgency.settled);
    });

    test('despesas pendentes mudam conforme o vencimento', () {
      EntryStatus at(DateTime due) =>
          EntryStatus.of(entry('x', due: due), today);
      expect(at(DateTime(2026, 5, 9)).label, 'Atrasada');
      expect(at(DateTime(2026, 5, 9)).urgency, EntryUrgency.overdue);
      expect(at(DateTime(2026, 5, 10)).label, 'Vence hoje');
      expect(at(DateTime(2026, 5, 10)).urgency, EntryUrgency.dueSoon);
      expect(at(DateTime(2026, 5, 13)).label, 'Despesa pendente');
      expect(at(DateTime(2026, 5, 13)).urgency, EntryUrgency.dueSoon);
      expect(at(DateTime(2026, 5, 14)).urgency, EntryUrgency.normal);
    });

    test('receitas pendentes nunca aparecem como atrasadas', () {
      final late = EntryStatus.of(
        entry('i', kind: TransactionKind.income, due: DateTime(2026, 5, 1)),
        today,
      );
      expect(late.label, 'Receita pendente');
      expect(late.urgency, EntryUrgency.normal);
      final expected = EntryStatus.of(
        entry(
          'j',
          kind: TransactionKind.income,
          recurring: true,
          due: DateTime(2026, 5, 20),
        ),
        today,
      );
      expect(expected.label, 'Recebimento previsto');
    });
  });

  group('Extrato', () {
    final entries = [
      entry('paid', paid: true, due: DateTime(2026, 5, 2), description: 'Luz'),
      entry('late', due: DateTime(2026, 5, 20), description: 'Água'),
      entry('soon', due: DateTime(2026, 5, 5), description: 'Aluguel'),
      entry(
        'salary',
        kind: TransactionKind.income,
        due: DateTime(2026, 5, 6),
        description: 'Salário',
      ),
      entry('next', due: DateTime(2026, 6, 1), description: 'Aluguel'),
    ];

    test('mês mostra pendentes antes e ordena por vencimento', () {
      final month = monthStatement(entries, DateTime(2026, 5));
      expect(month.map((e) => e.id), ['soon', 'salary', 'late', 'paid']);
    });

    test('filtros combinam confirmação, tipo e busca sem acento extra', () {
      final month = monthStatement(entries, DateTime(2026, 5));
      expect(
        const StatementFilter(confirmation: ConfirmationFilter.pending)
            .apply(month)
            .map((e) => e.id),
        ['soon', 'salary', 'late'],
      );
      expect(
        const StatementFilter(confirmation: ConfirmationFilter.confirmed)
            .apply(month)
            .map((e) => e.id),
        ['paid'],
      );
      expect(
        const StatementFilter(kind: TransactionKind.income)
            .apply(month)
            .map((e) => e.id),
        ['salary'],
      );
      expect(
        const StatementFilter(query: '  ALU ').apply(month).map((e) => e.id),
        ['soon'],
      );
      expect(const StatementFilter().apply(month), hasLength(4));
    });

    test('totais em centavos não acumulam erro de ponto flutuante', () {
      final totals = totalsInCents([
        for (var i = 0; i < 10; i++) entry('e$i', amount: 0.1),
        entry('i', kind: TransactionKind.income, amount: 0.2),
      ]);
      expect(totals.expenseCents, 100);
      expect(totals.incomeCents, 20);
    });
  });

  group('Avisos de vencimento', () {
    test('rótulos de grupo e prazo', () {
      expect(dueGroupLabel(-2), 'Atrasadas');
      expect(dueGroupLabel(0), 'Vencem hoje');
      expect(dueGroupLabel(2), 'Próximos 3 dias');
      expect(dueNotice(-2), 'Atrasada há 2 dia(s)');
      expect(dueNotice(0), 'Vence hoje');
      expect(dueNotice(3), 'Vence em 3 dia(s)');
    });

    test('planejamento conta pendências por dia sem alterar a lista', () {
      final bills = [
        entry('b', due: DateTime(2026, 5, 12)),
        entry('a', due: DateTime(2026, 5, 11)),
      ];
      final plan = planReminders(
        bills,
        DateTime(2026, 5, 10, 8),
        horizonDays: 3,
      );
      expect(plan.map((day) => day.count), [2, 2, 2, 2]);
      expect(bills.map((e) => e.id), ['b', 'a']);
    });
  });

  group('FinanceEntry', () {
    test('toMap e fromMap preservam o lançamento', () {
      final original = FinanceEntry(
        id: 'r:rule:2026-05-01',
        kind: TransactionKind.expense,
        amount: 90.6,
        description: 'Ótica',
        dueDate: DateTime(2026, 5, 8),
        categoryName: 'Saúde',
        isPaid: true,
        notes: 'cartão',
        isRecurring: true,
        installment: 3,
        totalInstallments: 10,
        lastDue: DateTime(2026, 12, 8),
      );
      final copy = FinanceEntry.fromMap(original.toMap());
      expect(copy.toMap(), original.toMap());
    });

    test('copyWith altera só o que foi pedido', () {
      final original = entry('a', amount: 50);
      final paid = original.copyWith(isPaid: true);
      expect(paid.isPaid, isTrue);
      expect(paid.amount, 50);
      expect(paid.description, original.description);
      expect(original.copyWith(amount: 75).amount, 75);
      expect(original.isPaid, isFalse);
    });
  });

  group('SingleFlight', () {
    test('ignora chamadas enquanto a anterior não termina', () async {
      final flight = SingleFlight();
      var calls = 0;
      Future<void> slow() async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      final first = flight.run(slow);
      final second = flight.run(slow);
      expect(flight.isRunning, isTrue);
      await Future.wait([first, second]);
      expect(calls, 1);
      expect(flight.isRunning, isFalse);
      await flight.run(slow);
      expect(calls, 2);
    });

    test('libera nova execução mesmo quando a ação falha', () async {
      final flight = SingleFlight();
      await expectLater(
        flight.run(() async => throw StateError('falha')),
        throwsStateError,
      );
      var ran = false;
      await flight.run(() async => ran = true);
      expect(ran, isTrue);
    });
  });
}
