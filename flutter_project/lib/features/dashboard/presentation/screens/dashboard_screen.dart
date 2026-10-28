import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/finance_updates.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/async_panel.dart';
import '../../../../shared/widgets/month_picker.dart';
import '../../../notifications/data/reminder_service.dart';
import '../../../notifications/domain/reminder_plan.dart';
import '../../../transactions/data/finance_repository.dart';
import '../../../transactions/domain/entry_status.dart';
import '../../../transactions/domain/finance_models.dart';
import '../../../transactions/presentation/screens/add_choice_sheet.dart';
import '../../../transactions/presentation/screens/finance_entry_card.dart';
import '../../domain/finance_summary.dart';

/// Início: pendências de hoje e o resumo do mês escolhido.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.repository,
    this.onNavigateToNotifications,
    this.onAdd,
    this.onOpenStatement,
    this.reminders,
  });
  final FinanceRepository repository;
  final VoidCallback? onNavigateToNotifications;

  /// Abre o cadastro de despesa ou de renda; sem ele os botões não aparecem.
  final ValueChanged<AddChoice>? onAdd;
  final VoidCallback? onOpenStatement;
  final ReminderService? reminders;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<FinanceEntry>> _future;
  DateTime _month = _currentMonth();

  static DateTime _currentMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  bool get _isCurrentMonth => _month == _currentMonth();

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

  /// Carrega até o fim do mês escolhido e, no mínimo, até os próximos dias
  /// usados nas pendências.
  Future<List<FinanceEntry>> _load() {
    final monthEnd = DateTime(_month.year, _month.month + 1, 0);
    final attention = DateTime.now().add(
      const Duration(days: attentionWindowDays),
    );
    return widget.repository.transactions(
      monthEnd.isAfter(attention) ? monthEnd : attention,
    );
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = _load();
    });
  }

  void _setMonth(DateTime month) {
    if (!MonthRange.contains(month)) return;
    setState(() {
      _month = DateTime(month.year, month.month);
      _future = _load();
    });
  }

  Future<void> _pickMonth() async {
    final month = await showMonthPicker(context: context, initialMonth: _month);
    if (month != null && mounted) _setMonth(month);
  }

  Future<void> _refresh() async {
    notifyFinanceChanged();
    try {
      await _future;
    } catch (_) {
      /* AsyncPanel mostra a opção de tentar novamente. */
    }
  }

  void _openNotifications() => widget.onNavigateToNotifications?.call();

  Widget _monthNavigation() {
    bool reachable(int delta) =>
        MonthRange.contains(DateTime(_month.year, _month.month + delta));
    return Row(
      children: [
        IconButton(
          tooltip: 'Mês anterior',
          icon: const Icon(Icons.chevron_left),
          onPressed: reachable(-1)
              ? () => _setMonth(DateTime(_month.year, _month.month - 1))
              : null,
        ),
        Expanded(
          child: TextButton(
            onPressed: _pickMonth,
            child: Text(
              AppFormatters.monthYear.format(_month),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Próximo mês',
          icon: const Icon(Icons.chevron_right),
          onPressed: reachable(1)
              ? () => _setMonth(DateTime(_month.year, _month.month + 1))
              : null,
        ),
      ],
    );
  }

  Widget _remindersOff() => ValueListenableBuilder<ReminderStatus>(
    valueListenable: widget.reminders!.status,
    builder: (_, status, __) => status.enabled
        ? const SizedBox.shrink()
        : Card(
            child: ListTile(
              leading: Icon(
                Icons.notifications_off_outlined,
                color: AppColors.of(context).warning,
              ),
              title: const Text('Lembretes no aparelho estão desativados'),
              subtitle: const Text(
                'Ative para receber avisos antes do vencimento.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openNotifications,
            ),
          ),
  );

  List<Widget> _attention(List<FinanceEntry> alerts) => [
    const _SectionTitle('O que precisa de atenção'),
    if (alerts.isEmpty)
      const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Text('Nenhuma conta atrasada ou vencendo nos próximos 3 dias.'),
      ),
    for (final entry in alerts.take(3))
      FinanceEntryCard(
        entry: entry,
        actions: OutlinedButton.icon(
          onPressed: _openNotifications,
          icon: const Icon(Icons.check),
          label: const Text('Confirmar pagamento'),
        ),
      ),
    if (alerts.length > 3)
      TextButton(
        onPressed: _openNotifications,
        child: Text('Ver todas as ${alerts.length} pendências'),
      ),
  ];

  Widget _firstSteps() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Comece por aqui',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Cadastre sua renda e suas contas do mês. Depois, ative os lembretes para ser avisado antes dos vencimentos.',
          ),
          if (widget.onAdd != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => widget.onAdd!(AddChoice.income),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Cadastrar renda'),
                ),
                OutlinedButton.icon(
                  onPressed: () => widget.onAdd!(AddChoice.expense),
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('Cadastrar despesa'),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          // Fixa no topo, acima do saldo: não rola com a lista.
          if (widget.onAdd != null) QuickAddBar(onAdd: widget.onAdd!),
          Expanded(child: _content()),
        ],
      ),
    ),
  );

  Widget _content() => AsyncPanel<List<FinanceEntry>>(
    future: _future,
    onRetry: _reload,
    errorMessage: 'Não foi possível carregar suas finanças. Verifique sua conexão e tente novamente.',
    builder: (entries) {
      final summary = FinanceSummary.forMonth(entries, _month);
      final previous = FinanceSummary.forMonth(
        entries,
        DateTime(_month.year, _month.month - 1),
      );
      final empty = entries.isEmpty;
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            if (widget.reminders != null && !empty) _remindersOff(),
            if (empty) _firstSteps(),
            if (_isCurrentMonth && !empty)
              ..._attention(pendingBills(entries, DateTime.now())),
            const SizedBox(height: 8),
            _monthNavigation(),
            _MonthSummaryCard(summary: summary),
            if (summary.expenses > 0 || previous.expenses > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  expenseTrend(summary.expenses, previous.expenses),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            _CategoriesCard(summary: summary),
            if (widget.onOpenStatement != null && !empty)
              TextButton.icon(
                onPressed: widget.onOpenStatement,
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Ver lançamentos no Extrato'),
              ),
          ],
        ),
      );
    },
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

/// Saldo previsto em destaque e o detalhamento do que já aconteceu no mês.
class _MonthSummaryCard extends StatelessWidget {
  const _MonthSummaryCard({required this.summary});
  final FinanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final money = AppFormatters.currency.format;
    Widget row(String label, String value, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: colors.onBrandMuted)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color ?? colors.onBrand,
              ),
            ),
          ),
        ],
      ),
    );
    // Cartão principal com a cor da marca: é a identidade visual do Início.
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.brand, colors.brandDeep],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Saldo previsto do mês',
                    style: TextStyle(color: colors.onBrandMuted),
                  ),
                ),
                IconButton(
                  color: colors.onBrand,
                  tooltip: 'Como calculamos o saldo',
                  icon: const Icon(Icons.info_outline, size: 20),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Como calculamos o saldo'),
                      content: const Text(
                        'Previsto: todas as rendas menos todas as contas do mês.\n\n'
                        'Confirmado: o que já foi recebido menos o que já foi pago.\n\n'
                        'Os valores consideram somente os lançamentos do mês, sem saldo de conta bancária.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Entendi'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Text(
              money(summary.predictedBalance),
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.brandBalance(summary.predictedBalance),
              ),
            ),
            Divider(
              height: 28,
              color: colors.onBrandMuted.withValues(alpha: 0.35),
            ),
            row(
              'Rendas',
              '${money(summary.receivedIncome)} de ${money(summary.income)}',
            ),
            row(
              'Contas pagas',
              '${money(summary.paidExpenses)} de ${money(summary.expenses)}',
            ),
            row(
              'Ainda a pagar',
              money(summary.expenses - summary.paidExpenses),
              color: summary.expenses > summary.paidExpenses
                  ? colors.brandWarning
                  : null,
            ),
            row(
              'Saldo confirmado',
              money(summary.availableBalance),
              color: colors.brandBalance(summary.availableBalance),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoriesCard extends StatelessWidget {
  const _CategoriesCard({required this.summary});
  final FinanceSummary summary;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Para onde vai o seu dinheiro',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          if (summary.expensesByCategory.isEmpty)
            const Text('Ainda não existem despesas neste mês.'),
          for (final category in summary.expensesByCategory.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(category.key)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${AppFormatters.currency.format(category.value)} · '
                          '${(category.value / summary.expenses * 100).round()}%',
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: (category.value / summary.expenses).clamp(
                        0.0,
                        1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
