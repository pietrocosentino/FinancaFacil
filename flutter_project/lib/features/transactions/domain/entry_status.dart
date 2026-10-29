import '../../../core/utils/dates.dart';
import 'finance_models.dart';

/// Contas pendentes pedem atenção a partir deste número de dias antes do
/// vencimento; o mesmo prazo vale para os lembretes.
const attentionWindowDays = 3;

/// Aviso exibido antes de confirmar o pagamento de uma conta. Rendas não
/// ficam bloqueadas e não exibem este aviso.
const lockedAfterConfirmWarning =
    'Depois de confirmar o pagamento, esta conta não poderá ser alterada nem excluída. '
    'Se confirmar por engano, você poderá apenas inativá-la para que não entre '
    'nos totais. Em contas mensais, também será possível encerrar os próximos meses.';

/// Nível de atenção de um lançamento; a interface escolhe a cor a partir dele.
enum EntryUrgency { settled, inactive, overdue, dueSoon, normal }

/// Situação de um lançamento em uma data, sem dependência de interface.
class EntryStatus {
  const EntryStatus(this.label, this.urgency);

  factory EntryStatus.of(FinanceEntry entry, DateTime today) {
    if (entry.isInactive) {
      return const EntryStatus(
        'Inativo · fora dos totais',
        EntryUrgency.inactive,
      );
    }
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
