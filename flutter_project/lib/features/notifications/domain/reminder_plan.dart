import '../../dashboard/domain/finance_summary.dart';
import '../../transactions/domain/finance_models.dart';

List<FinanceEntry> pendingBills(List<FinanceEntry> entries, DateTime today) =>
    entries
        .where((entry) =>
            !entry.isIncome &&
            !entry.isPaid &&
            entry.dueDate != null &&
            daysUntil(entry.dueDate!, today) <= 3)
        .toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

class DailyReminder {
  const DailyReminder(this.date, this.count);
  final DateTime date;
  final int count;
  int get id => date.year * 10000 + date.month * 100 + date.day;
}

/// Agrupa contas por dia e respeita o limite de pendências do iOS.
/// A abertura do app ou uma confirmação renova o planejamento.
List<DailyReminder> planReminders(List<FinanceEntry> entries, DateTime now,
    {int horizonDays = 90, int limit = 60, int hour = 9, int minute = 0}) {
  final result = <DailyReminder>[];
  for (var offset = 0;
      offset <= horizonDays && result.length < limit;
      offset++) {
    final date = DateTime(now.year, now.month, now.day + offset, hour, minute);
    if (!date.isAfter(now)) continue;
    final count = pendingBills(entries, date).length;
    if (count > 0) result.add(DailyReminder(date, count));
  }
  return result;
}
