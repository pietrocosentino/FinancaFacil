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
    this.confirmations = const {},
    this.kinds = const {},
    this.query = '',
  });

  final ConfirmationFilter confirmation;
  final TransactionKind? kind;
  final Set<ConfirmationFilter> confirmations;
  final Set<TransactionKind> kinds;
  final String query;

  StatementFilter copyWith({
    ConfirmationFilter? confirmation,
    TransactionKind? Function()? kind,
    Set<ConfirmationFilter> Function()? confirmations,
    Set<TransactionKind> Function()? kinds,
    String? query,
  }) => StatementFilter(
    confirmation: confirmation ?? this.confirmation,
    kind: kind == null ? this.kind : kind(),
    confirmations: confirmations == null ? this.confirmations : confirmations(),
    kinds: kinds == null ? this.kinds : kinds(),
    query: query ?? this.query,
  );

  bool get isFiltered =>
      confirmation != ConfirmationFilter.all ||
      kind != null ||
      confirmations.isNotEmpty ||
      kinds.isNotEmpty ||
      query.trim().isNotEmpty;

  bool accepts(FinanceEntry entry) {
    final matchesConfirmation = confirmations.isEmpty
        ? confirmation.accepts(entry)
        : confirmations.any((filter) => filter.accepts(entry));
    final matchesKind = kinds.isEmpty
        ? kind == null || entry.kind == kind
        : kinds.contains(entry.kind);
    return matchesConfirmation &&
        matchesKind &&
        entry.description.toLowerCase().contains(query.trim().toLowerCase());
  }

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
/// Lançamentos inativados não entram na soma.
({int incomeCents, int expenseCents}) totalsInCents(
  Iterable<FinanceEntry> entries,
) {
  var income = 0;
  var expense = 0;
  for (final entry in entries.where((entry) => entry.countsInTotals)) {
    if (entry.isIncome) {
      income += entry.amountInCents;
    } else {
      expense += entry.amountInCents;
    }
  }
  return (incomeCents: income, expenseCents: expense);
}
