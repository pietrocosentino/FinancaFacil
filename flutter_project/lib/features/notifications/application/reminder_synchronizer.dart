import '../../../core/errors/app_log.dart';
import '../../transactions/domain/finance_models.dart';
import '../data/reminder_service.dart';

/// Mantém os lembretes do aparelho alinhados aos lançamentos da conta.
///
/// Pedidos feitos durante uma sincronização não são descartados nem executados
/// em paralelo: são agrupados em uma única nova rodada ao final da atual.
class ReminderSynchronizer {
  ReminderSynchronizer({
    required this.reminders,
    required this.owner,
    required this.loadEntries,
  });

  static const failureMessage =
      'Não foi possível atualizar os lembretes. Confira a conexão e as permissões do aparelho.';

  final ReminderService reminders;
  final String owner;
  final Future<List<FinanceEntry>> Function() loadEntries;

  bool _running = false;
  bool _pending = false;
  bool _disposed = false;

  Future<void> run() async {
    if (_disposed) return;
    if (_running) {
      _pending = true;
      return;
    }
    _running = true;
    try {
      do {
        _pending = false;
        await _syncOnce();
      } while (_pending && !_disposed);
    } finally {
      _running = false;
    }
  }

  Future<void> _syncOnce() async {
    try {
      await reminders.activateOwner(owner);
      final entries = await loadEntries();
      if (!_disposed) await reminders.sync(owner, entries);
    } catch (error, stack) {
      AppLog.error(error, stack, 'sincronizar lembretes');
      if (!_disposed) {
        reminders.status.value = reminders.status.value.withMessage(
          failureMessage,
        );
      }
    }
  }

  /// Interrompe novas rodadas; a rodada em andamento termina sem efeitos.
  void dispose() => _disposed = true;
}
