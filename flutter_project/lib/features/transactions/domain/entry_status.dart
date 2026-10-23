import '../../../core/utils/dates.dart';
import 'finance_models.dart';

/// Contas pendentes pedem atenção a partir deste número de dias antes do
/// vencimento; o mesmo prazo vale para os lembretes.
const attentionWindowDays = 3;

/// Nível de atenção de um lançamento; a interface escolhe a cor a partir dele.
enum EntryUrgency { settled, overdue, dueSoon, normal }

/// Situação de um lançamento em uma data, sem dependência de interface.
class EntryStatus {
  const EntryStatus(this.label, this.urgency);

  factory EntryStatus.of(FinanceEntry entry, DateTime today) {
    if (entry.isPaid) {
      return EntryStatus(
        entry.isAutomaticIncome
            ? 'Recebido · automático'
            : entry.isIncome
            ? 'Recebido'
            : 'Pago',
        EntryUrgency.settled,
      );
    }
    final days = entry.dueDate == null
        ? null
        : daysUntil(entry.dueDate!, today);
    if (!entry.isIncome && days != null) {
      if (days < 0) return const EntryStatus('Atrasada', EntryUrgency.overdue);
      if (days == 0) {
        return const EntryStatus('Vence hoje', EntryUrgency.dueSoon);
      }
    }
    final label = entry.isAutomaticIncome
        ? 'Recebimento previsto'
        : '${entry.kind.label} pendente';
    final soon = !entry.isIncome && days != null && days <= attentionWindowDays;
    return EntryStatus(
      label,
      soon ? EntryUrgency.dueSoon : EntryUrgency.normal,
    );
  }

  final String label;
  final EntryUrgency urgency;
}
