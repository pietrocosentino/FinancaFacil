import 'package:flutter/material.dart';

import '../../../../core/services/app_services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/finance_updates.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/async_panel.dart';
import '../../../notifications/data/reminder_service.dart';
import '../../../notifications/domain/reminder_plan.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../transactions/data/finance_repository.dart';
import '../../../transactions/domain/finance_models.dart';
import '../../../transactions/presentation/screens/finance_entry_card.dart';
import '../../domain/finance_summary.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen(
      {super.key,
      this.onNavigateToNotifications,
      this.repository,
      this.reminders,
      this.showHeader = true});
  final VoidCallback? onNavigateToNotifications;
  final FinanceRepository? repository;
  final ReminderService? reminders;
  final bool showHeader;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final FinanceRepository _repository;
  late Future<List<FinanceEntry>> _future;
  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? AppServices.finance;
    _future = _load();
    financeRevision.addListener(_reload);
  }

  Future<List<FinanceEntry>> _load() =>
      _repository.transactions(DateTime.now().add(const Duration(days: 3)));
  void _reload() {
    if (mounted) {
      setState(() {
        _future = _load();
      });
    }
  }

  Future<void> _refresh() async {
    notifyFinanceChanged();
    try {
      await _future;
    } catch (_) {/* AsyncPanel mostra a opção de tentar novamente. */}
  }

  @override
  void dispose() {
    financeRevision.removeListener(_reload);
    super.dispose();
  }

  void _openNotifications() {
    if (widget.onNavigateToNotifications != null) {
      widget.onNavigateToNotifications!();
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => NotificationsScreen(
            repository: _repository, reminders: widget.reminders)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: widget.showHeader
          ? AppBar(title: const Text('FinançaFácil'), actions: [
              FutureBuilder<List<FinanceEntry>>(
                  future: _future,
                  builder: (_, snapshot) {
                    final count = snapshot.hasError
                        ? 0
                        : pendingBills(snapshot.data ?? [], DateTime.now())
                            .length;
                    return IconButton(
                        tooltip: 'Notificações',
                        onPressed: _openNotifications,
                        icon: Badge(
                            label: Text('$count'),
                            isLabelVisible: count > 0,
                            child: const Icon(Icons.notifications_outlined)));
                  })
            ])
          : null,
      body: SafeArea(
          child: AsyncPanel<List<FinanceEntry>>(
        future: _future,
        onRetry: _reload,
        errorMessage:
            'Não foi possível carregar suas finanças. Verifique sua conexão e tente novamente.',
        builder: (entries) {
          final now = DateTime.now();
          final summary = FinanceSummary.forMonth(entries, now);
          final alerts = pendingBills(entries, now);
          return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  if (widget.reminders != null)
                    ValueListenableBuilder<ReminderStatus>(
                        valueListenable: widget.reminders!.status,
                        builder: (_, status, __) => status.enabled
                            ? const SizedBox.shrink()
                            : Card(
                                child: ListTile(
                                    leading: Icon(
                                        Icons.notifications_off_outlined,
                                        color: AppTheme.semanticColor(
                                            context, Colors.amber)),
                                    title: const Text(
                                        'Lembretes no aparelho estão desativados'),
                                    subtitle: const Text(
                                        'Ative para receber avisos antes do vencimento.'),
                                    onTap: _openNotifications))),
                  const SizedBox(height: 12),
                  Text('O que precisa de atenção',
                      style: Theme.of(context).textTheme.titleMedium),
                  if (alerts.isEmpty)
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                            'Nenhuma conta atrasada ou vencendo nos próximos 3 dias.')),
                  for (final entry in alerts.take(3))
                    FinanceEntryCard(
                        entry: entry,
                        actions: OutlinedButton(
                            onPressed: _openNotifications,
                            child:
                                const Text('Consultar e confirmar pagamento'))),
                  if (alerts.length > 3)
                    TextButton(
                        onPressed: _openNotifications,
                        child:
                            Text('Ver todas as ${alerts.length} pendências')),
                  if (entries.isEmpty)
                    const Card(
                        child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                                'Comece cadastrando sua renda e sua primeira conta. Depois, ative os lembretes para acompanhar os vencimentos.'))),
                  const SizedBox(height: 16),
                  Text(AppFormatters.monthYear.format(now),
                      style: Theme.of(context).textTheme.titleMedium),
                  _BalanceCard(
                      title: 'Saldo confirmado do mês',
                      value: summary.availableBalance,
                      color: summary.availableBalance < 0
                          ? Colors.redAccent
                          : AppTheme.mintNeon),
                  const ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text('Como calculamos o saldo?'),
                      childrenPadding: EdgeInsets.only(bottom: 12),
                      children: [
                        Text(
                            'Confirmado: recebido menos pago. Previsto: rendas menos contas do mês. Esses valores representam seus registros neste mês, sem saldo bancário acumulado.')
                      ]),
                  _BalanceCard(
                      title: 'Saldo previsto do mês',
                      value: summary.predictedBalance,
                      color: summary.predictedBalance < 0
                          ? Colors.redAccent
                          : AppTheme.mintNeon),
                  _BalanceCard(
                      title: 'Ainda a pagar neste mês',
                      value: summary.expenses - summary.paidExpenses,
                      color: AppTheme.textPrimary),
                  Wrap(spacing: 16, runSpacing: 8, children: [
                    Text(
                        'Recebido: ${AppFormatters.currency.format(summary.receivedIncome)}'),
                    Text(
                        'Pago: ${AppFormatters.currency.format(summary.paidExpenses)}')
                  ]),
                  const SizedBox(height: 24),
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Para onde vai o seu dinheiro?',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 16),
                              if (summary.expensesByCategory.isEmpty)
                                const Text(
                                    'Ainda não existem despesas neste mês.'),
                              for (final category
                                  in summary.expensesByCategory.entries)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(category.key),
                                        Wrap(
                                            spacing: 8,
                                            runSpacing: 4,
                                            children: [
                                              Text(AppFormatters.currency
                                                  .format(category.value)),
                                              Text(
                                                  '${(category.value / summary.expenses * 100).round()}%'),
                                            ]),
                                        const SizedBox(height: 6),
                                        LinearProgressIndicator(
                                            value: (category.value /
                                                    summary.expenses)
                                                .clamp(0.0, 1.0)),
                                      ]),
                                ),
                            ],
                          ))),
                  const SizedBox(height: 16),
                ],
              ));
        },
      )));
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard(
      {required this.title, required this.value, required this.color});
  final String title;
  final double value;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title),
              const SizedBox(height: 8),
              Text(AppFormatters.currency.format(value),
                  style: TextStyle(
                      color: AppTheme.semanticColor(context, color),
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
            ],
          )));
}
