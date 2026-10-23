import 'package:flutter/material.dart';

import '../../../../core/utils/finance_updates.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/async_panel.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/month_picker.dart';
import '../../data/finance_repository.dart';
import '../../domain/amount_edit_scope.dart';
import '../../domain/finance_models.dart';
import '../../domain/statement.dart';
import 'edit_amount_dialog.dart';
import 'finance_entry_card.dart';
import 'recurrence_rules_screen.dart';

/// Extrato mensal: consulta, filtros, confirmação, edição e exclusão.
/// O cadastro de novos lançamentos fica na aba Finanças.
class TransactionsListScreen extends StatefulWidget {
  const TransactionsListScreen({super.key, required this.repository});
  final FinanceRepository repository;
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
    } catch (_) {
      if (mounted) _message(failure);
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
    } catch (_) {
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
      confirmLabel: 'Confirmar',
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

  Future<void> _undo(FinanceEntry entry) async {
    if (_processing || _reviewing) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Voltar para pendente?',
      message:
          '${entry.description} voltará a exigir confirmação. Os lembretes de despesas serão recalculados.',
      confirmLabel: 'Voltar para pendente',
    );
    if (!confirmed || !mounted) return;
    await _mutate(
      () => _repository.markPending({entry.id}),
      success: 'Registro voltou para pendente.',
      failure: 'Não foi possível corrigir. Tente novamente.',
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
            child: Text(AppFormatters.monthYear.format(_month)),
          ),
        ),
        IconButton(
          tooltip: 'Próximo mês',
          icon: const Icon(Icons.chevron_right),
          onPressed: reachable(1) ? () => _changeMonth(1) : null,
        ),
      ],
    );
  }

  Widget _filtersPanel() => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_searchOpen)
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Buscar pelo nome da conta',
                ),
                onChanged: (value) => _updateFilter(
                  StatementFilter(
                    confirmation: _filter.confirmation,
                    kind: _filter.kind,
                    query: value,
                  ),
                ),
              ),
            ),
          if (_filter.kind != null)
            Text(
              _filter.kind == TransactionKind.expense
                  ? 'Somente despesas'
                  : 'Somente receitas',
            ),
          _monthNavigation(),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _processing ? null : () => _setMonth(DateTime.now()),
              child: const Text('Mês atual'),
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final confirmation in ConfirmationFilter.values)
                ChoiceChip(
                  label: Text(confirmation.label),
                  selected: _filter.confirmation == confirmation,
                  onSelected: _processing
                      ? null
                      : (_) => _updateFilter(
                          StatementFilter(
                            confirmation: confirmation,
                            kind: _filter.kind,
                            query: _filter.query,
                          ),
                        ),
                ),
            ],
          ),
          TextButton.icon(
            onPressed: _processing
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          RecurrenceRulesScreen(repository: _repository),
                    ),
                  ),
            icon: const Icon(Icons.repeat),
            label: const Text('Contas recorrentes e parcelas'),
          ),
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
        child: Align(
          heightFactor: 1,
          alignment: Alignment.center,
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
      ),
    );
  }

  Widget _entryCard(FinanceEntry entry) => FinanceEntryCard(
    entry: entry,
    selected: _selectedIds.contains(entry.id),
    onUndo: entry.isPaid && !entry.isAutomaticIncome && !_processing
        ? () => _undo(entry)
        : null,
    onDelete: _processing ? null : () => _delete(entry),
    onStop: _processing || RecurrenceReference.fromEntryId(entry.id) == null
        ? null
        : () => _stop(entry),
    onTap: _processing ? null : () => _editAmount(entry),
    onSelected: entry.isPaid || entry.isAutomaticIncome || _processing
        ? null
        : (value) => _toggleSelection(entry, value),
  );

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
                    ? 'Nenhum lançamento neste mês. Cadastre uma conta ou consulte outro mês.'
                    : 'Nenhum registro neste filtro. Consulte Todas para ver o mês.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      sliver: SliverList.builder(
        itemCount: entries.length,
        itemBuilder: (_, index) => _entryCard(entries[index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Extrato'),
      actions: [
        IconButton(
          tooltip: 'Buscar contas',
          icon: const Icon(Icons.search),
          onPressed: _processing
              ? null
              : () {
                  _searchOpen = !_searchOpen;
                  _updateFilter(
                    StatementFilter(
                      confirmation: _filter.confirmation,
                      kind: _filter.kind,
                    ),
                  );
                },
        ),
        PopupMenuButton<int>(
          tooltip: 'Filtrar receitas e despesas',
          enabled: !_processing,
          icon: const Icon(Icons.filter_list),
          onSelected: (kind) => _updateFilter(
            StatementFilter(
              confirmation: _filter.confirmation,
              kind: kind == 0 ? null : TransactionKind.values[kind - 1],
              query: _filter.query,
            ),
          ),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 0, child: Text('Receitas e despesas')),
            PopupMenuItem(value: 1, child: Text('Somente despesas')),
            PopupMenuItem(value: 2, child: Text('Somente receitas')),
          ],
        ),
      ],
    ),
    bottomNavigationBar: _confirmationBar(context),
    body: SafeArea(
      top: false,
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
  );
}
