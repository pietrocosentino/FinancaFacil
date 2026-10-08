import 'package:flutter/material.dart';

import '../../../../core/services/reminder_preferences.dart';
import '../../../../core/utils/finance_updates.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/async_panel.dart';
import '../../../dashboard/domain/finance_summary.dart';
import '../../../transactions/data/finance_repository.dart';
import '../../../transactions/domain/finance_models.dart';
import '../../../transactions/presentation/screens/finance_entry_card.dart';
import '../../data/reminder_service.dart';
import '../../domain/reminder_plan.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen(
      {super.key, required this.repository, this.reminders, this.owner});
  final FinanceRepository repository;
  final ReminderService? reminders;
  final String? owner;
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<({List<FinanceEntry> entries, bool cached})> _future;
  String? _busyId;
  bool _requesting = false;
  bool _reviewing = false;
  @override
  void initState() {
    super.initState();
    _future = _load();
    financeRevision.addListener(_reload);
  }

  @override
  void dispose() {
    financeRevision.removeListener(_reload);
    super.dispose();
  }

  Future<({List<FinanceEntry> entries, bool cached})> _load() async {
    final now = DateTime.now();
    try {
      final entries = await widget.repository
          .transactions(now.add(const Duration(days: 3)));
      return (entries: pendingBills(entries, now), cached: false);
    } catch (_) {
      final owner = widget.owner;
      final cached =
          owner == null ? null : await widget.reminders?.cachedEntries(owner);
      if (cached == null) rethrow;
      return (entries: pendingBills(cached, now), cached: true);
    }
  }

  void _reload() {
    if (mounted) {
      setState(() {
        _future = _load();
      });
    }
  }

  Future<void> _enable() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    try {
      await widget.reminders?.requestPermission();
      notifyFinanceChanged();
    } catch (_) {
      if (mounted) {
        _message(
            'Não foi possível ativar. Confira as configurações do aparelho.');
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  void _message(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _confirm(FinanceEntry entry) async {
    if (_busyId != null || _reviewing) return;
    _reviewing = true;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              scrollable: true,
              title: const Text('Confirmar pagamento?'),
              content: Text(
                  '${entry.description}\n${AppFormatters.currency.format(entry.amount)}\n'
                  'Vencimento: ${AppFormatters.date.format(entry.dueDate!)}\n\n'
                  'Confirme somente após pagar ou transferir o valor. O aplicativo não realiza pagamentos.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Ainda não')),
                ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Sim, paguei')),
              ],
            ));
    _reviewing = false;
    if (confirmed != true || !mounted) return;
    setState(() => _busyId = entry.id);
    try {
      await widget.repository.markPaid({entry.id});
      if (mounted) {
        _message('Pagamento confirmado. O lembrete deste mês foi removido.');
        notifyFinanceChanged();
      }
    } catch (_) {
      if (mounted) {
        _message(
            'Não foi possível confirmar. O lembrete continua pendente; tente novamente com conexão.');
      }
    } finally {
      if (mounted) {
        setState(() => _busyId = null);
        _reload();
      }
    }
  }

  Widget _permissionPanel() => widget.reminders == null
      ? const SizedBox.shrink()
      : ValueListenableBuilder<ReminderStatus>(
          valueListenable: widget.reminders!.status,
          builder: (_, status, __) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(status.message),
                  if (status.coveredUntil != null)
                    Text(
                        'Agenda preparada até ${AppFormatters.date.format(status.coveredUntil!)}. Lembretes por volta das ${ReminderPreferences.time.value.hour.toString().padLeft(2, '0')}:${ReminderPreferences.time.value.minute.toString().padLeft(2, '0')}.'),
                  if (!status.enabled)
                    OutlinedButton.icon(
                        onPressed: _requesting ? null : _enable,
                        icon: const Icon(Icons.notifications_active_outlined),
                        label: Text(_requesting
                            ? 'Ativando...'
                            : 'Ativar lembretes no aparelho')),
                ]),
          ),
        );

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Notificações'), actions: [
        IconButton(
            onPressed: _busyId == null ? _reload : null,
            tooltip: 'Atualizar notificações',
            icon: const Icon(Icons.refresh)),
      ]),
      body: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: () async {
              _reload();
              try {
                await _future;
              } catch (_) {/* A lista mostra o erro. */}
            },
            child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                      child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: _permissionPanel())),
                  AsyncSliverPanel<({List<FinanceEntry> entries, bool cached})>(
                    future: _future,
                    onRetry: _reload,
                    errorMessage:
                        'Não foi possível consultar as notificações. Verifique a conexão.',
                    builder: (feed) => SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        sliver: SliverList.list(children: [
                          if (feed.cached) ...[
                            const Text(
                                'Sem atualização do banco. Exibindo a última consulta; conecte-se para confirmar pagamentos.'),
                            OutlinedButton(
                                onPressed: _reload,
                                child: const Text('Tentar conexão novamente')),
                          ],
                          if (feed.entries.isEmpty)
                            const Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                    'Nenhum pagamento pendente nos próximos 3 dias. As contas pagas saem desta lista.',
                                    textAlign: TextAlign.center)),
                          for (var index = 0;
                              index < feed.entries.length;
                              index++) ...[
                            if (index == 0 ||
                                _group(feed.entries[index]) !=
                                    _group(feed.entries[index - 1]))
                              Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  child: Text(_group(feed.entries[index]),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium)),
                            FinanceEntryCard(
                                entry: feed.entries[index],
                                notice: _notice(feed.entries[index]),
                                actions:
                                    Wrap(spacing: 8, runSpacing: 8, children: [
                                  ElevatedButton.icon(
                                      onPressed: _busyId != null || feed.cached
                                          ? null
                                          : () => _confirm(feed.entries[index]),
                                      icon: const Icon(Icons.check),
                                      label: Text(
                                          _busyId == feed.entries[index].id
                                              ? 'Confirmando...'
                                              : 'Confirmar pagamento')),
                                  TextButton(
                                      onPressed: _busyId != null
                                          ? null
                                          : () => _message(
                                              'Conta mantida como pendente.'),
                                      child: const Text('Manter pendente')),
                                ])),
                            const SizedBox(height: 8),
                          ],
                        ])),
                  ),
                ]),
          )));

  String _group(FinanceEntry entry) {
    final days = daysUntil(entry.dueDate!, DateTime.now());
    return days < 0
        ? 'Atrasadas'
        : days == 0
            ? 'Vencem hoje'
            : 'Próximos 3 dias';
  }

  String _notice(FinanceEntry entry) {
    final days = daysUntil(entry.dueDate!, DateTime.now());
    return days < 0
        ? 'Atrasada há ${-days} dia(s)'
        : days == 0
            ? 'Vence hoje'
            : 'Vence em $days dia(s)';
  }
}
