import 'package:financafacil/features/dashboard/domain/finance_summary.dart';
import 'package:financafacil/features/notifications/data/reminder_service.dart';
import 'package:financafacil/features/notifications/domain/reminder_plan.dart';
import 'package:financafacil/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:financafacil/features/transactions/domain/finance_models.dart';
import 'package:financafacil/features/transactions/domain/recurrence.dart';
import 'package:financafacil/shared/widgets/main_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/fake_repositories.dart';

FinanceEntry bill(
  String id,
  DateTime due, {
  bool paid = false,
  TransactionKind kind = TransactionKind.expense,
  double amount = 90.60,
}) => FinanceEntry(
  id: id,
  kind: kind,
  amount: amount,
  description: 'Ótica',
  dueDate: due,
  categoryName: 'Saúde',
  isPaid: paid,
  notes: 'Transferir para meu pai',
);

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  test('ótica em 10 meses lembra no dia 5 e termina no décimo vencimento', () {
    final rules = [
      {
        'id': 'optical',
        'user_id': 'owner',
        'first_due': '2026-10-08',
        'due_day': 8,
        'total_installments': 10,
        'template': {
          'type': 'despesa',
          'amount': 90.60,
          'description': 'Ótica',
          'notes': 'Transferir para meu pai',
          'category_id': '1',
        },
      },
    ];
    final entries = projectRecurrences(
      rules,
      [],
      DateTime(2027, 8),
    ).map(FinanceEntry.fromMap).toList();
    expect(entries.length, 10);
    expect(entries.last.dueDate, DateTime(2027, 7, 8));
    expect(entries.last.lastDue, DateTime(2027, 7, 8));
    expect(pendingBills(entries, DateTime(2026, 10, 4)), isEmpty);
    expect(pendingBills(entries, DateTime(2026, 10, 5)).single.amount, 90.60);
    expect(entries.first.notes, 'Transferir para meu pai');
    final paid = projectRecurrences(rules, [
      {'rule_id': 'optical', 'due_month': '2026-10-01', 'is_paid': true},
    ], DateTime(2026, 11)).map(FinanceEntry.fromMap).toList();
    expect(pendingBills(paid, DateTime(2026, 10, 8)), isEmpty);
    expect(pendingBills(paid, DateTime(2026, 11, 5)).single.installment, 2);
  });
  test('dia 31 iniciado em fevereiro volta ao dia 31 no mês seguinte', () {
    final projected = projectRecurrences(
      [
        {
          'id': 'rent',
          'first_due': '2027-02-28',
          'due_day': 31,
          'template': {
            'type': 'despesa',
            'amount': 500,
            'description': 'Aluguel',
            'category_id': '1',
          },
        },
      ],
      [],
      DateTime(2027, 3),
    );
    expect(DateTime.parse(projected.first['due_date']), DateTime(2027, 2, 28));
    expect(DateTime.parse(projected.last['due_date']), DateTime(2027, 3, 31));
  });
  test('pagar altera o disponível, sem descontar duas vezes do previsto', () {
    final month = DateTime(2026, 10);
    final income = bill(
      'salary',
      month,
      kind: TransactionKind.income,
      amount: 1000,
      paid: true,
    );
    final before = FinanceSummary.forMonth([
      income,
      bill('optical', month),
    ], month);
    final after = FinanceSummary.forMonth([
      income,
      bill('optical', month, paid: true),
    ], month);
    expect(before.availableBalance, 1000);
    expect(after.availableBalance, 909.40);
    expect(before.predictedBalance, 909.40);
    expect(after.predictedBalance, before.predictedBalance);
    expect(
      FinanceSummary.forMonth([
        bill('salary', month, kind: TransactionKind.income, amount: 1000),
      ], month).availableBalance,
      0,
    );
  });
  test('planejamento agrupa contas e limita a 60 datas futuras', () {
    final plan = planReminders([
      bill('one', DateTime(2026, 10, 8)),
      bill('two', DateTime(2026, 10, 8)),
      bill('paid', DateTime(2026, 10, 8), paid: true),
      bill('income', DateTime(2026, 10, 8), kind: TransactionKind.income),
    ], DateTime(2026, 10, 4, 10));
    expect(plan.length, 60);
    expect(plan.first.date, DateTime(2026, 10, 5, 9));
    expect(plan.first.count, 2);
    expect(plan.map((entry) => entry.id).toSet().length, plan.length);
    expect(
      planReminders([
        bill('paid', DateTime(2026, 10, 8), paid: true),
      ], DateTime(2026, 10, 4)),
      isEmpty,
    );
  });
  test('horário já passado não é agendado e contas atrasadas continuam', () {
    final plan = planReminders([
      bill('late', DateTime(2026, 10, 1)),
    ], DateTime(2026, 10, 9, 10));
    expect(plan.first.date, DateTime(2026, 10, 10, 9));
    expect(
      pendingBills([
        bill('late', DateTime(2026, 10, 1)),
      ], DateTime(2026, 11, 1)).length,
      1,
    );
  });
  testWidgets('notificação não marca pagamento antes da confirmação', (
    tester,
  ) async {
    final repository = FakeFinanceRepository()
      ..entries = [bill('optical', DateTime.now())];
    await tester.pumpWidget(
      MaterialApp(home: NotificationsScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Transferir para meu pai'), findsOneWidget);
    expect(find.text('Manter pendente'), findsNothing);
    await tester.tap(find.text('Confirmar pagamento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ainda não'));
    await tester.pumpAndSettle();
    expect(repository.paidIds, isNull);
    await tester.tap(find.text('Confirmar pagamento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tenho certeza, paguei'));
    await tester.pumpAndSettle();
    expect(repository.paidIds, {'optical'});
    expect(find.text('Confirmar pagamento'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('sino abre lista e menu fixo continua disponível', (
    tester,
  ) async {
    final repository = FakeFinanceRepository()
      ..entries = [bill('optical', DateTime.now())];
    await tester.pumpWidget(
      MaterialApp(
        home: MainLayout(
          financeRepository: repository,
          profileRepository: FakeProfileRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Notificações'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmar pagamento'), findsOneWidget);
    expect(find.text('Perfil'), findsNothing);
    expect(find.text('Extrato'), findsOneWidget);
    await tester.tap(find.text('Confirmar pagamento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tenho certeza, paguei'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Início'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Notificações'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('falha de confirmação conserva o pagamento pendente', (
    tester,
  ) async {
    final repository = _FailingPaymentRepository()
      ..entries = [bill('optical', DateTime.now())];
    await tester.pumpWidget(
      MaterialApp(home: NotificationsScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar pagamento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tenho certeza, paguei'));
    await tester.pumpAndSettle();
    expect(repository.entries.single.isPaid, false);
    expect(find.text('Confirmar pagamento'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('notificações com fonte grande e pouca altura podem rolar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final reminders = FakeReminderService();
    reminders.status.value = ReminderStatus(
      enabled: true,
      message: 'Lembretes ativados.',
      coveredUntil: DateTime(2026, 12, 31),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: NotificationsScreen(
            repository: FakeFinanceRepository(),
            reminders: reminders,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('consulta sem conexão mostra cache e impede confirmação local', (
    tester,
  ) async {
    final reminders = FakeReminderService()
      ..cached = [bill('optical', DateTime.now())];
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsScreen(
          repository: _OfflineRepository(),
          reminders: reminders,
          owner: 'owner',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Sem atualização do banco.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Confirmar pagamento'), 200);
    final confirm = tester.widget<ElevatedButton>(
      find.byWidgetPredicate((widget) => widget is ElevatedButton),
    );
    expect(confirm.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}

class _FailingPaymentRepository extends FakeFinanceRepository {
  @override
  Future<void> markPaid(Set<String> ids) async =>
      throw StateError('Sem conexão');
}

class _OfflineRepository extends FakeFinanceRepository {
  @override
  Future<List<FinanceEntry>> transactions(DateTime through) async =>
      throw StateError('Sem conexão');
}
