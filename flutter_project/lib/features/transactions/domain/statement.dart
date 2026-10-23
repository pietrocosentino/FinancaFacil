import 'finance_models.dart';

/// Filtro de confirmação usado no extrato.
enum ConfirmationFilter {
  all('Todas'),
  pending('Pendentes'),
  confirmed('Confirmadas');

  const ConfirmationFilter(this.label);
  final String label;

  bool accepts(FinanceEntry entry) => switch (this) {
    ConfirmationFilter.all => true,
    ConfirmationFilter.pending => !entry.isPaid,
    ConfirmationFilter.confirmed => entry.isPaid,
  };
}

/// Critérios combinados do extrato: confirmação, tipo e busca pelo nome.
class StatementFilter {
  const StatementFilter({
    this.confirmation = ConfirmationFilter.all,
    this.kind,
    this.query = '',
  });

  final ConfirmationFilter confirmation;
  final TransactionKind? kind;
  final String query;

  /// [kind] usa uma função para permitir voltar a "todos os tipos" (null).
  StatementFilter copyWith({
    ConfirmationFilter? confirmation,
    TransactionKind? Function()? kind,
    String? query,
  }) => StatementFilter(
    confirmation: confirmation ?? this.confirmation,
    kind: kind == null ? this.kind : kind(),
    query: query ?? this.query,
  );

  bool get isFiltered =>
      confirmation != ConfirmationFilter.all ||
      kind != null ||
      query.trim().isNotEmpty;

  bool accepts(FinanceEntry entry) =>
      confirmation.accepts(entry) &&
      (kind == null || entry.kind == kind) &&
      entry.description.toLowerCase().contains(query.trim().toLowerCase());

  List<FinanceEntry> apply(Iterable<FinanceEntry> entries) =>
      entries.where(accepts).toList();
}

/// Lançamentos do mês: pendentes primeiro, depois por vencimento.
List<FinanceEntry> monthStatement(
  Iterable<FinanceEntry> entries,
  DateTime month,
) {
  final result = entries.where((entry) => entry.belongsToMonth(month)).toList();
  result.sort((a, b) {
    if (a.isPaid != b.isPaid) return a.isPaid ? 1 : -1;
    return (a.dueDate ?? DateTime(2100)).compareTo(b.dueDate ?? DateTime(2100));
  });
  return result;
}

/// Totais em centavos, evitando acumular erros de ponto flutuante.
({int incomeCents, int expenseCents}) totalsInCents(
  Iterable<FinanceEntry> entries,
) {
  var income = 0;
  var expense = 0;
  for (final entry in entries) {
    if (entry.isIncome) {
      income += entry.amountInCents;
    } else {
      expense += entry.amountInCents;
    }
  }
  return (incomeCents: income, expenseCents: expense);
}
