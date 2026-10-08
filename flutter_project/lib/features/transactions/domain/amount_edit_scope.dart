import 'finance_models.dart';

class FutureAmountTarget {
  const FutureAmountTarget(this.id, this.month, this.includesSelected);
  final String id;
  final DateTime month;
  final bool includesSelected;
}

/// Confirmed values only change through an explicit single-entry correction.
/// A salary increase starts after a received month, and never rewrites history.
FutureAmountTarget? futureAmountTarget(FinanceEntry entry, DateTime now) {
  final reference = RecurrenceReference.fromEntryId(entry.id);
  if (reference == null) return null;
  final current = DateTime(now.year, now.month);
  final start = DateTime(
      reference.month.year, reference.month.month + (entry.isPaid ? 1 : 0));
  final month = start.isBefore(current) ? current : start;
  final last = entry.lastDue;
  if (last != null && month.isAfter(DateTime(last.year, last.month))) {
    return null;
  }
  if (entry.totalInstallments != null &&
      entry.installment != null &&
      entry.isPaid &&
      entry.installment! >= entry.totalInstallments!) {
    return null;
  }
  final target = RecurrenceReference(reference.ruleId, month);
  return FutureAmountTarget('r:${reference.ruleId}:${target.databaseMonth}',
      month, !entry.isPaid && month == reference.month);
}
