import '../../transactions/domain/finance_models.dart';

class FinanceSummary {
  const FinanceSummary({
    required this.income,
    required this.expenses,
    required this.expensesByCategory,
    required this.receivedIncome,
    required this.paidExpenses,
  });
  final double income;
  final double expenses;
  final Map<String, double> expensesByCategory;
  final double receivedIncome;
  final double paidExpenses;
  double get predictedBalance =>
      ((income * 100).round() - (expenses * 100).round()) / 100;
  double get availableBalance =>
      ((receivedIncome * 100).round() - (paidExpenses * 100).round()) / 100;

  factory FinanceSummary.forMonth(List<FinanceEntry> entries, DateTime month) {
    var income = 0;
    var expenses = 0;
    var receivedIncome = 0;
    var paidExpenses = 0;
    final categories = <String, int>{};
    for (final entry in entries.where((entry) => entry.belongsToMonth(month))) {
      if (entry.isIncome) {
        income += entry.amountInCents;
        if (entry.isPaid) receivedIncome += entry.amountInCents;
      } else {
        expenses += entry.amountInCents;
        if (entry.isPaid) paidExpenses += entry.amountInCents;
        categories.update(
          entry.categoryName,
          (total) => total + entry.amountInCents,
          ifAbsent: () => entry.amountInCents,
        );
      }
    }
    final sorted = categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return FinanceSummary(
      income: income / 100,
      expenses: expenses / 100,
      receivedIncome: receivedIncome / 100,
      paidExpenses: paidExpenses / 100,
      expensesByCategory: Map.unmodifiable({
        for (final entry in sorted) entry.key: entry.value / 100,
      }),
    );
  }
}

/// Variação percentual de [current] em relação a [previous], arredondada.
/// `null` quando não há base de comparação (mês anterior sem valor).
int? percentChange(double current, double previous) {
  final base = (previous * 100).round();
  if (base <= 0) return null;
  return (((current * 100).round() - base) * 100 / base).round();
}

/// Frase curta comparando as despesas com as do mês anterior.
String expenseTrend(double current, double previous) {
  final change = percentChange(current, previous);
  if (change == null) return 'Sem despesas no mês anterior para comparar.';
  if (change == 0) return 'Mesmo valor de despesas do mês anterior.';
  return change > 0
      ? 'Despesas $change% maiores que no mês anterior.'
      : 'Despesas ${-change}% menores que no mês anterior.';
}
