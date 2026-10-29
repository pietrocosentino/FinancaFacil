import 'package:financafacil/features/dashboard/domain/finance_summary.dart';
import 'package:financafacil/features/notifications/domain/reminder_plan.dart';
import 'package:financafacil/features/transactions/domain/finance_models.dart';
import 'package:flutter_test/flutter_test.dart';

FinanceEntry entry(
  String id,
  double amount,
  TransactionKind kind,
  DateTime due, {
  bool paid = false,
  String category = 'Moradia',
}) => FinanceEntry(
  id: id,
  kind: kind,
  amount: amount,
  description: id,
  dueDate: due,
  categoryName: category,
  isPaid: paid,
);

void main() {
  test('saldo e categorias consideram somente o mês selecionado', () {
    final summary = FinanceSummary.forMonth([
      entry('income', 1000, TransactionKind.income, DateTime(2026, 10, 1)),
      entry('rent', 500, TransactionKind.expense, DateTime(2026, 10, 5)),
      entry(
        'food',
        100,
        TransactionKind.expense,
        DateTime(2026, 10, 5),
        category: 'Alimentação',
      ),
      entry('future', 9999, TransactionKind.expense, DateTime(2026, 11, 5)),
    ], DateTime(2026, 10));
    expect(summary.predictedBalance, 400);
    expect(summary.expensesByCategory, {'Moradia': 500, 'Alimentação': 100});
  });
  test('soma valores em centavos para evitar acumular erro binário', () {
    final summary = FinanceSummary.forMonth([
      entry('a', .10, TransactionKind.expense, DateTime(2026, 10, 1)),
      entry('b', .20, TransactionKind.expense, DateTime(2026, 10, 1)),
    ], DateTime(2026, 10));
    expect(summary.expenses, .30);
  });
  test('alertas incluem vencidos e 3 dias, excluem pagos e receitas', () {
    final today = DateTime(2026, 10, 6);
    final alerts = pendingBills([
      entry('late', 500, TransactionKind.expense, DateTime(2026, 10, 1)),
      entry('soon', 500, TransactionKind.expense, DateTime(2026, 10, 9)),
      entry('far', 500, TransactionKind.expense, DateTime(2026, 10, 10)),
      entry('paid', 500, TransactionKind.expense, today, paid: true),
      entry('income', 500, TransactionKind.income, today),
    ], today);
    expect(alerts.map((entry) => entry.id), ['late', 'soon']);
  });
  test('identificador inválido de ocorrência é rejeitado', () {
    expect(
      () => RecurrenceReference.fromEntryId('r:bad'),
      throwsFormatException,
    );
    expect(RecurrenceReference.fromEntryId('legacy'), isNull);
  });
  test('rascunho impede valor inválido e parcelamento incoerente', () {
    expect(
      () => TransactionDraft(
        kind: TransactionKind.expense,
        amount: double.nan,
        description: 'x',
        dueDate: DateTime(2026),
        categoryId: '1',
      ),
      throwsFormatException,
    );
    expect(
      () => TransactionDraft(
        kind: TransactionKind.expense,
        amount: 10,
        description: 'x',
        dueDate: DateTime(2026),
        categoryId: '1',
        totalInstallments: 3,
      ),
      throwsFormatException,
    );
  });
}
