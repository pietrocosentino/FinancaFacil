import 'package:flutter/material.dart';

import '../../../../core/errors/app_log.dart';
import '../../../../core/errors/failure_message.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/finance_updates.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/async_panel.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/month_picker.dart';
import '../../../imports/presentation/export_entries.dart';
import '../../data/finance_repository.dart';
import '../../domain/amount_edit_scope.dart';
import '../../domain/entry_status.dart';
import '../../domain/finance_models.dart';
import '../../domain/statement.dart';
import 'add_choice_sheet.dart';
import 'edit_amount_dialog.dart';
import 'edit_entry_screen.dart';
import 'finance_entry_card.dart';
import 'recurrence_rules_screen.dart';

/// Extrato mensal: consulta, filtros, confirmação, edição e exclusão.
class TransactionsListScreen extends StatefulWidget {
  const TransactionsListScreen({
    super.key,
    required this.repository,
    this.onAdd,
  });
  final FinanceRepository repository;

  /// Abre o cadastro de despesa, renda ou a importação de planilha; sem ele
  /// os botões de cadastro não aparecem.
  final ValueChanged<AddChoice>? onAdd;
  @override
  State<TransactionsListScreen> createState() => _TransactionsListScreenState();
}

class _TransactionsListScreenState extends State<TransactionsListScreen> {
  late Future<List<FinanceEntry>> _future;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  final _selectedIds = <String>{};
  bool _processing = false;
  bool _reviewing = false;
  bool _searchOpen = false;
  StatementFilter _filter = const StatementFilter();

  FinanceRepository get _repository => widget.repository;

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

  Future<List<FinanceEntry>> _load() async {
    final month = _month;
    return monthStatement(await _repository.transactions(month), month);
  }

  void _reload() {
    if (mounted) {
      setState(() {
        _selectedIds.clear();
        _future = _load();
      });
    }
  }

  Future<void> _refresh() async {
    notifyFinanceChanged();
    try {
      await _future;
    } catch (_) {
      /* AsyncPanel apresenta o erro. */
    }
  }

  void _changeMonth(int delta) =>
      _setMonth(DateTime(_month.year, _month.month + delta));

  void _setMonth(DateTime date) {
    if (!MonthRange.contains(date)) return;
    setState(() {
      _month = DateTime(date.year, date.month);
      _selectedIds.clear();
      _future = _load();
    });
  }

  void _updateFilter(StatementFilter filter) => setState(() {
    _filter = filter;
    _selectedIds.clear();
  });

  void _message(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  /// Executa uma alteração bloqueando novas ações e recarregando a lista ao
  /// final, com sucesso ou falha.
  Future<void> _mutate(
    Future<void> Function() action, {
    required String success,
    required String failure,
  }) async {
    setState(() => _processing = true);
    try {
      await action();
      if (mounted) _message(success);
    } catch (error, stack) {
      AppLog.error(error, stack, 'extrato');
      if (mounted) _message(failureMessage(error, fallback: failure));
    } finally {
      if (mounted) {
        setState(() => _processing = false);
        _reload();
      }
    }
  }

  Future<void> _paySelected() async {
    if (_processing || _reviewing || _selectedIds.isEmpty) return;
    _reviewing = true;
    final ids = Set<String>.from(_selectedIds);
    late final List<FinanceEntry> entries;
    try {
      entries = await _future;
    } catch (error, stack) {
      AppLog.error(error, stack, 'revisar confirmações');
      _reviewing = false;
      if (mounted) {
        _message(
          'Não foi possível revisar. Atualize a lista e tente novamente.',
        );
      }
      return;
    }
    if (!mounted) {
      _reviewing = false;
      return;
    }
    final selected = entries.where((entry) => ids.contains(entry.id)).toList();
    final totals = totalsInCents(selected);
    final confirmed = await showConfirmDialog(
      context,
      title: 'Revisar confirmações',
      message:
          '${selected.length} registros selecionados\n'
          'Pagamentos: ${AppFormatters.currency.format(totals.expenseCents / 100)}\n'
          'Recebimentos: ${AppFormatters.currency.format(totals.incomeCents / 100)}\n\n'
          '${selected.map((e) => e.description).join('\n')}\n\n'
          'Confirme somente os valores já pagos ou recebidos.',
      warning: selected.any((entry) => !entry.isIncome)
          ? lockedAfterConfirmWarning
          : null,
      confirmLabel: 'Tenho certeza, confirmar',
      prominent: true,
      scrollable: true,
    );
    _reviewing = false;
    if (!confirmed || !mounted) return;
    await _mutate(
      () => _repository.markPaid(ids),
      success: 'Pagamentos/recebimentos confirmados.',
      failure: 'Não foi possível confirmar todos os pagamentos. Recarregue a lista antes de tentar novamente.',
    );
  }

  Future<void> _editAmount(FinanceEntry entry) async {
    if (_processing || _reviewing) return;
    final future = futureAmountTarget(entry, DateTime.now());
    setState(() => _processing = true);
    try {
      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => EditAmountDialog(
          entry: entry,
          futureFromMonth: future?.month,
          futureIncludesSelected: future?.includesSelected ?? false,
          onSave: (amount) => _repository.updateAmount(entry.id, amount),
          onSaveFuture: future == null
              ? null
              : (amount) => _repository.updateFutureAmount(future.id, amount),
        ),
      );
      // O repositório já sinaliza a alteração para as demais telas.
      if (saved == true && mounted) _message('Valor atualizado.');
    } finally {
      if (mounted) {
        setState(() => _processing = false);
        _reload();
      }
    }
  }

  Future<void> _openEditor(FinanceEntry entry, EditEntryMode mode) async {
    if (_processing || _reviewing) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            EditEntryScreen(entry: entry, repository: _repository, mode: mode),
      ),
    );
    if (saved == true && mounted) {
      _message(
        mode == EditEntryMode.incomeRule
            ? 'Renda fixa atualizada deste mês em diante.'
            : 'Lançamento atualizado.',
      );
    }
  }

  Future<void> _setInactive(FinanceEntry entry, bool inactive) async {
    if (_processing || _reviewing) return;
    final amount = AppFormatters.currency.format(entry.amount);
    final confirmed = await showConfirmDialog(
      context,
      title: inactive ? 'Inativar lançamento?' : 'Reativar lançamento?',
      message: inactive
          ? '${entry.description}\n$amount\n\n'
                'Use quando a confirmação foi feita por engano. O lançamento continua no extrato, marcado como inativo, mas deixa de entrar na soma de receitas, despesas e saldo.'
          : '${entry.description}\n$amount\n\n'
                'O lançamento volta a entrar na soma de receitas, despesas e saldo, como confirmado.',
      confirmLabel: inactive ? 'Inativar' : 'Reativar',
      prominent: true,
    );
    if (!confirmed || !mounted) return;
    await _mutate(
      () => _repository.setInactive(entry.id, inactive),
      success: inactive
          ? 'Lançamento inativado. Ele não entra mais nos totais.'
          : 'Lançamento reativado.',
      failure: 'Não foi possível alterar. Confira a conexão e tente novamente.',
    );
  }

  Future<void> _delete(FinanceEntry entry) async {
    if (_processing || _reviewing) return;
    final month = entry.dueDate == null
        ? ''
        : AppFormatters.monthYear.format(entry.dueDate!);
    final confirmed = await showConfirmDialog(
      context,
      title: entry.isRecurring
          ? 'Excluir somente este mês?'
          : 'Excluir lançamento?',
      message:
          '${entry.description}\n${AppFormatters.currency.format(entry.amount)}\n$month\n\n'
          'O valor será retirado do saldo.'
          '${entry.isRecurring ? ' A recorrência continuará nos outros meses e este mês não reaparecerá.' : ''}',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _mutate(
      () => _repository.deleteEntry(entry.id),
      success: 'Lançamento excluído.',
      failure: 'Não foi possível excluir. Confira a conexão e a atualização do banco.',
    );
  }

  Future<void> _stop(FinanceEntry entry) async {
    if (_processing || _reviewing) return;
    final reference = RecurrenceReference.fromEntryId(entry.id);
    if (reference == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Encerrar próximos meses?',
      message:
          '${entry.description}\n\nA recorrência termina no fim do mês atual. Os registros anteriores e deste mês serão preservados.',
      confirmLabel: 'Encerrar',
    );
    if (!confirmed || !mounted) return;
    await _mutate(
      () => _repository.stopPlan(reference.ruleId),
      success: 'Recorrência encerrada após este mês.',
      failure: 'Não foi possível encerrar. Tente novamente.',
    );
  }

  Future<void> _pickMonth() async {
    final date = await showMonthPicker(context: context, initialMonth: _month);
    if (date != null && mounted) _setMonth(date);
  }

  void _toggleSelection(FinanceEntry entry, bool? selected) => setState(() {
    if (selected == true) {
      _selectedIds.add(entry.id);
    } else {
      _selectedIds.remove(entry.id);
    }
  });

  Future<void> _confirmOne(FinanceEntry entry) async {
    if (_processing || _reviewing) return;
    final confirmed = await showConfirmDialog(
      context,
      title: entry.isIncome ? 'Confirmar recebimento?' : 'Confirmar pagamento?',
      message:
          '${entry.description}\n${AppFormatters.currency.format(entry.amount)}\n\n'
          '${entry.isIncome ? 'Confirme somente depois de o valor entrar na sua conta.' : 'Confirme somente depois de pagar. O aplicativo não realiza pagamentos.'}',
      warning: entry.isIncome ? null : lockedAfterConfirmWarning,
      confirmLabel: entry.isIncome
          ? 'Tenho certeza, recebi'
          : 'Tenho certeza, paguei',
      cancelLabel: 'Ainda não',
      prominent: true,
    );
    if (!confirmed || !mounted) return;
    await _mutate(
      () => _repository.markPaid({entry.id}),
      success: entry.isIncome
          ? 'Recebimento confirmado.'
          : 'Pagamento confirmado.',
      failure: 'Não foi possível confirmar. Tente novamente.',
    );
  }

  Future<void> _notReceived(FinanceEntry entry) async {
    if (_processing || _reviewing) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Não recebeu esta renda?',
      message:
          '${entry.description}\n${AppFormatters.currency.format(entry.amount)}\n\n'
          'Este mês deixa de contar como recebido e fica pendente. Quando o valor entrar, confirme o recebimento. Os outros meses continuam automáticos.',
      confirmLabel: 'Marcar como não recebida',
    );
    if (!confirmed || !mounted) return;
    await _mutate(
      () => _repository.markNotReceived(entry.id),
      success: 'Renda marcada como pendente.',
      failure: 'Não foi possível alterar. Tente novamente.',
    );
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  Widget _monthNavigation() {
    bool reachable(int delta) =>
        !_processing &&
        MonthRange.contains(DateTime(_month.year, _month.month + delta));
    return Row(
      children: [
        IconButton(
          tooltip: 'Mês anterior',
          icon: const Icon(Icons.chevron_left),
          onPressed: reachable(-1) ? () => _changeMonth(-1) : null,
        ),
        Expanded(
          child: TextButton(
            onPressed: _processing ? null : _pickMonth,
            child: Text(
              AppFormatters.monthYear.format(_month),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        if (!_isCurrentMonth)
          IconButton(
            tooltip: 'Voltar ao mês atual',
            icon: const Icon(Icons.today_outlined),
            onPressed: _processing ? null : () => _setMonth(DateTime.now()),
          ),
        IconButton(
          tooltip: 'Próximo mês',
          icon: const Icon(Icons.chevron_right),
          onPressed: reachable(1) ? () => _changeMonth(1) : null,
        ),
      ],
    );
  }

  Widget _filterChips() {
    Widget kindChip(TransactionKind kind, String label) => FilterChip(
      visualDensity: VisualDensity.compact,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      label: Text(label),
      selected: _filter.kind == kind,
      onSelected: _processing
          ? null
          : (selected) => _updateFilter(
              _filter.copyWith(kind: () => selected ? kind : null),
            ),
    );
    // Duas linhas centralizadas: situação em cima, tipo embaixo.
    Widget row(List<Widget> chips) => Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: chips,
    );
    return Column(
      children: [
        row([
          for (final confirmation in ConfirmationFilter.values)
            ChoiceChip(
              visualDensity: VisualDensity.compact,
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              label: Text(confirmation.label),
              selected: _filter.confirmation == confirmation,
              onSelected: _processing
                  ? null
                  : (_) => _updateFilter(
                      _filter.copyWith(confirmation: confirmation),
                    ),
            ),
        ]),
        const SizedBox(height: 4),
        row([
          kindChip(TransactionKind.expense, 'Despesas'),
          kindChip(TransactionKind.income, 'Receitas'),
        ]),
      ],
    );
  }

  Widget _filtersPanel() => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_searchOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
              child: TextField(
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  labelText: 'Buscar pelo nome da conta',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) =>
                    _updateFilter(_filter.copyWith(query: value)),
              ),
            ),
          _monthNavigation(),
          _filterChips(),
        ],
      ),
    ),
  );

  Widget? _confirmationBar(BuildContext context) {
    if (_selectedIds.isEmpty || MediaQuery.of(context).viewInsets.bottom > 0) {
      return null;
    }
    return SafeArea(
      top: false,
      child: Container(
        color: Theme.of(context).colorScheme.surface,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Row(
          children: [
            TextButton(
              onPressed: _processing
                  ? null
                  : () => setState(_selectedIds.clear),
              child: const Text('Limpar'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: _processing ? null : _paySelected,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(
                  _processing
                      ? 'Confirmando...'
                      : 'Confirmar selecionados (${_selectedIds.length})',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Pendente: alterar, excluir e confirmar. Conta paga: somente inativar e
  /// encerrar a recorrência. Renda continua editável mesmo depois de recebida.
  Widget _entryCard(FinanceEntry entry) {
    VoidCallback? when(bool allowed, VoidCallback action) =>
        allowed && !_processing ? action : null;
    final monthly = RecurrenceReference.fromEntryId(entry.id) != null;
    final pendingManual = !entry.isPaid && !entry.isAutomaticIncome;
    final editable = !entry.isLocked;
    return FinanceEntryCard(
      entry: entry,
      selected: _selectedIds.contains(entry.id),
      onEdit: when(
        editable && !monthly,
        () => _openEditor(entry, EditEntryMode.pendingEntry),
      ),
      onTap: when(editable && monthly, () => _editAmount(entry)),
      onEditIncome: when(
        entry.isIncome && entry.isRecurring,
        () => _openEditor(entry, EditEntryMode.incomeRule),
      ),
      onConfirm: when(pendingManual, () => _confirmOne(entry)),
      onNotReceived: when(entry.isAutomaticIncome, () => _notReceived(entry)),
      onInactivate: when(
        entry.isLocked && !entry.isInactive,
        () => _setInactive(entry, true),
      ),
      onReactivate: when(entry.isInactive, () => _setInactive(entry, false)),
      onDelete: when(editable, () => _delete(entry)),
      onStop: when(monthly, () => _stop(entry)),
      onSelected: pendingManual && !_processing
          ? (value) => _toggleSelection(entry, value)
          : null,
    );
  }

  Widget _monthTotals(List<FinanceEntry> entries) {
    final totals = totalsInCents(entries);
    final colors = AppColors.of(context);
    final style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          Text(
            'Receitas ${AppFormatters.currency.format(totals.incomeCents / 100)}',
            style: style?.copyWith(color: colors.positive),
          ),
          Text(
            'Despesas ${AppFormatters.currency.format(totals.expenseCents / 100)}',
            style: style?.copyWith(color: colors.danger),
          ),
        ],
      ),
    );
  }

  Widget _entries(List<FinanceEntry> monthEntries) {
    final entries = _filter.apply(monthEntries);
    if (entries.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.receipt_long_outlined, size: 40),
              const SizedBox(height: 12),
              Text(
                monthEntries.isEmpty
                    ? 'Nenhum lançamento neste mês.'
                    : 'Nenhum lançamento com estes filtros.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (monthEntries.isNotEmpty)
                TextButton(
                  onPressed: () {
                    _searchOpen = false;
                    _updateFilter(const StatementFilter());
                  },
                  child: const Text('Limpar filtros'),
                )
              else
                // Cadastro fica só no Início; aqui apenas orientamos.
                const Text(
                  'Para cadastrar, use Despesa ou Renda no Início.',
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      );
    }
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(child: _monthTotals(entries)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
          sliver: SliverList.builder(
            itemCount: entries.length,
            itemBuilder: (_, index) => _entryCard(entries[index]),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Extrato'),
      actions: [
        IconButton(
          tooltip: 'Buscar contas',
          icon: Icon(_searchOpen ? Icons.search_off : Icons.search),
          onPressed: _processing
              ? null
              : () {
                  _searchOpen = !_searchOpen;
                  _updateFilter(_filter.copyWith(query: ''));
                },
        ),
        if (widget.onAdd != null)
          IconButton(
            tooltip: 'Importar planilha',
            icon: const Icon(Icons.upload_file_outlined),
            onPressed: _processing
                ? null
                : () => widget.onAdd!(AddChoice.spreadsheet),
          ),
        IconButton(
          tooltip: 'Baixar lançamentos em Excel',
          icon: const Icon(Icons.file_download_outlined),
          onPressed: _processing
              ? null
              : () => exportEntries(context, _repository),
        ),
        IconButton(
          tooltip: 'Contas recorrentes e parcelas',
          icon: const Icon(Icons.repeat),
          onPressed: _processing
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        RecurrenceRulesScreen(repository: _repository),
                  ),
                ),
        ),
      ],
    ),
    bottomNavigationBar: _confirmationBar(context),
    body: SafeArea(
      top: false,
      child: Column(
        children: [
          // Fixa no topo, acima dos totais: não rola com a lista.
          if (widget.onAdd != null && _selectedIds.isEmpty)
            QuickAddBar(onAdd: widget.onAdd!),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _filtersPanel(),
                  AsyncSliverPanel<List<FinanceEntry>>(
                    future: _future,
                    onRetry: _reload,
                    errorMessage: 'Não foi possível carregar as contas. Verifique sua conexão e tente novamente.',
                    builder: _entries,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
