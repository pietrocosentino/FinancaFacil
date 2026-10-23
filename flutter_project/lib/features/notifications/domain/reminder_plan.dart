import '../../../core/utils/dates.dart';
import '../../transactions/domain/entry_status.dart';
import '../../transactions/domain/finance_models.dart';

bool _needsAttention(FinanceEntry entry, DateTime today) =>
    !entry.isIncome &&
    !entry.isPaid &&
    entry.dueDate != null &&
    daysUntil(entry.dueDate!, today) <= attentionWindowDays;

/// Despesas pendentes atrasadas ou que vencem nos próximos dias, por vencimento.
List<FinanceEntry> pendingBills(List<FinanceEntry> entries, DateTime today) =>
    entries.where((entry) => _needsAttention(entry, today)).toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

/// Grupo exibido na lista de notificações.
String dueGroupLabel(int days) => days < 0
    ? 'Atrasadas'
    : days == 0
    ? 'Vencem hoje'
    : 'Próximos $attentionWindowDays dias';

/// Aviso curto sobre o prazo de uma conta pendente.
String dueNotice(int days) => days < 0
    ? 'Atrasada há ${-days} dia(s)'
    : days == 0
    ? 'Vence hoje'
    : 'Vence em $days dia(s)';

class DailyReminder {
  const DailyReminder(this.date, this.count);
  final DateTime date;
  final int count;
  int get id => date.year * 10000 + date.month * 100 + date.day;
}

/// Agrupa contas por dia e respeita o limite de pendências do iOS.
/// A abertura do app ou uma confirmação renova o planejamento.
List<DailyReminder> planReminders(
  List<FinanceEntry> entries,
  DateTime now, {
  int horizonDays = 90,
  int limit = 60,
  int hour = 9,
  int minute = 0,
}) {
  final result = <DailyReminder>[];
  for (
    var offset = 0;
    offset <= horizonDays && result.length < limit;
    offset++
  ) {
    final date = DateTime(now.year, now.month, now.day + offset, hour, minute);
    if (!date.isAfter(now)) continue;
    final count = entries.where((entry) => _needsAttention(entry, date)).length;
    if (count > 0) result.add(DailyReminder(date, count));
  }
  return result;
}
