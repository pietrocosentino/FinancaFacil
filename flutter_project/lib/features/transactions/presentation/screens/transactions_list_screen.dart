import 'package:flutter/material.dart';
import '../../../../core/services/app_services.dart';
import '../../../../core/utils/finance_updates.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/async_panel.dart';
import '../../../../shared/widgets/month_picker.dart';
import '../../../imports/presentation/import_screen.dart';
import '../../data/finance_repository.dart';
import '../../domain/amount_edit_scope.dart';
import '../../domain/finance_models.dart';
import 'add_transaction_screen.dart';
import 'edit_amount_dialog.dart';
import 'finance_entry_card.dart';
import 'recurrence_rules_screen.dart';

enum _EntryFilter {
  all('Todas'),
  pending('Pendentes'),
  confirmed('Confirmadas');

  const _EntryFilter(this.label);
  final String label;
}

class TransactionsListScreen extends StatefulWidget {
  const TransactionsListScreen(
      {super.key,
      this.repository,
      this.addKey,
      this.onEnableReminders,
      this.showRegistration = true});
  final bool showRegistration;
  final FinanceRepository? repository;
  final VoidCallback? onEnableReminders;
  final GlobalKey<AddTransactionScreenState>? addKey;
  @override
  State<TransactionsListScreen> createState() => _TransactionsListScreenState();
}

class _TransactionsListScreenState extends State<TransactionsListScreen> {
  late final FinanceRepository _repository;
  late Future<List<FinanceEntry>> _future;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  final _selectedIds = <String>{};
  bool _processing = false;
  bool _reviewing = false;
  bool _adding = false;
  _EntryFilter _filter = _EntryFilter.all;
  bool _searchOpen = false;
  String _query = '';
  TransactionKind? _kind;
  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? AppServices.finance;
    _future = _load();
    financeRevision.addListener(_reload);
  }

  Future<List<FinanceEntry>> _load() async {
    final month = _month;
    final entries = (await _repository.transactions(month))
        .where((entry) => entry.belongsToMonth(month))
        .toList();
    entries.sort((a, b) {
      if (a.isPaid != b.isPaid) return a.isPaid ? 1 : -1;
      return (a.dueDate ?? DateTime(2100))
          .compareTo(b.dueDate ?? DateTime(2100));
    });
    return entries;
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
    } catch (_) {/* AsyncPanel apresenta o erro. */}
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

  @override
  void dispose() {
    financeRevision.removeListener(_reload);
    super.dispose();
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
            'Não foi possível revisar. Atualize a lista e tente novamente.');
      }
      return;
    }
    if (!mounted) return;
    final selected = entries.where((entry) => ids.contains(entry.id)).toList();
    final expense = selected
            .where((e) => !e.isIncome)
            .fold<int>(0, (sum, e) => sum + e.amountInCents) /
        100;
    final income = selected
            .where((e) => e.isIncome)
            .fold<int>(0, (sum, e) => sum + e.amountInCents) /
        100;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Revisar confirmações'),
                scrollable: true,
                content: Text(
                    '${selected.length} registros selecionados\nPagamentos: ${AppFormatters.currency.format(expense)}\nRecebimentos: ${AppFormatters.currency.format(income)}\n\n${selected.map((e) => e.description).join('\n')}\n\nConfirme somente os valores já pagos ou recebidos.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar')),
                  ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Confirmar'))
                ]));
    _reviewing = false;
    if (confirmed != true || !mounted) return;
    setState(() => _processing = true);
    try {
      await _repository.markPaid(ids);
      if (mounted) {
        _message('Pagamentos/recebimentos confirmados.');
      }
    } catch (_) {
      if (mounted) {
        _message(
            'Não foi possível confirmar todos os pagamentos. Recarregue a lista antes de tentar novamente.');
      }
    } finally {
      if (mounted) {
        setState(() => _processing = false);
        _reload();
      }
    }
  }

  void _message(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

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
      if (saved == true && mounted) {
        notifyFinanceChanged();
        _message('Valor atualizado.');
      }
    } finally {
      if (mounted) {
        setState(() => _processing = false);
        _reload();
      }
    }
  }

  Future<void> _undo(FinanceEntry entry) async {
    if (_processing) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Voltar para pendente?'),
                content: Text(
                    '${entry.description} voltará a exigir confirmação. Os lembretes de despesas serão recalculados.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Voltar para pendente'))
                ]));
    if (confirmed != true || !mounted) return;
    setState(() => _processing = true);
    try {
      await _repository.markPending({entry.id});
      if (mounted) _message('Registro voltou para pendente.');
    } catch (_) {
      if (mounted) _message('Não foi possível corrigir. Tente novamente.');
    } finally {
      if (mounted) {
        setState(() => _processing = false);
        _reload();
      }
    }
  }

  Future<void> _delete(FinanceEntry entry) async {
    if (_processing || _reviewing) return;
    final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(entry.isRecurring
                    ? 'Excluir somente este mês?'
                    : 'Excluir lançamento?'),
                content: Text(
                    '${entry.description}\n${AppFormatters.currency.format(entry.amount)}\n${entry.dueDate == null ? '' : AppFormatters.monthYear.format(entry.dueDate!)}\n\nO valor será retirado do saldo.${entry.isRecurring ? ' A recorrência continuará nos outros meses e este mês não reaparecerá.' : ''}'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text('Excluir',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)))
                ]));
    if (accepted != true || !mounted) return;
    setState(() => _processing = true);
    try {
      await _repository.deleteEntry(entry.id);
      if (mounted) _message('Lançamento excluído.');
    } catch (_) {
      if (mounted) {
        _message(
            'Não foi possível excluir. Confira a conexão e a atualização do banco.');
      }
    } finally {
      if (mounted) {
        setState(() => _processing = false);
        _reload();
      }
    }
  }

  Future<void> _stop(FinanceEntry entry) async {
    if (_processing || _reviewing) return;
    final reference = RecurrenceReference.fromEntryId(entry.id);
    if (reference == null) return;
    final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Encerrar próximos meses?'),
                content: Text(
                    '${entry.description}\n\nA recorrência termina no fim do mês atual. Os registros anteriores e deste mês serão preservados.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Encerrar'))
                ]));
    if (accepted != true || !mounted) return;
    setState(() => _processing = true);
    try {
      await _repository.stopPlan(reference.ruleId);
      if (mounted) _message('Recorrência encerrada após este mês.');
    } catch (_) {
      if (mounted) _message('Não foi possível encerrar. Tente novamente.');
    } finally {
      if (mounted) {
        setState(() => _processing = false);
        _reload();
      }
    }
  }

  Future<void> _pickMonth() async {
    final date = await showMonthPicker(context: context, initialMonth: _month);
    if (date != null && mounted) {
      _setMonth(date);
    }
  }

  Widget _filtersPanel() => SliverToBoxAdapter(
      child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_searchOpen)
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                          labelText: 'Buscar pelo nome da conta'),
                      onChanged: (value) => setState(() {
                            _query = value.trim().toLowerCase();
                            _selectedIds.clear();
                          }))),
            if (_kind != null)
              Text(_kind == TransactionKind.expense
                  ? 'Somente despesas'
                  : 'Somente receitas'),
            Row(children: [
              IconButton(
                  tooltip: 'Mês anterior',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _processing ||
                          !MonthRange.contains(
                              DateTime(_month.year, _month.month - 1))
                      ? null
                      : () => _changeMonth(-1)),
              Expanded(
                  child: TextButton(
                      onPressed: _processing ? null : _pickMonth,
                      child: Text(AppFormatters.monthYear.format(_month)))),
              IconButton(
                  tooltip: 'Próximo mês',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _processing ||
                          !MonthRange.contains(
                              DateTime(_month.year, _month.month + 1))
                      ? null
                      : () => _changeMonth(1)),
            ]),
            Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                    onPressed: _processing
                        ? null
                        : () {
                            _setMonth(DateTime.now());
                          },
                    child: const Text('Mês atual'))),
            Wrap(spacing: 8, children: [
              for (final filter in _EntryFilter.values)
                ChoiceChip(
                    label: Text(filter.label),
                    selected: _filter == filter,
                    onSelected: _processing
                        ? null
                        : (_) => setState(() {
                              _filter = filter;
                              _selectedIds.clear();
                            }))
            ]),
            TextButton.icon(
                onPressed: _processing
                    ? null
                    : () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            RecurrenceRulesScreen(repository: _repository))),
                icon: const Icon(Icons.repeat),
                label: const Text('Contas recorrentes e parcelas')),
          ])));

  Future<void> _addEntry() async {
    if (_adding || _processing) return;
    _adding = true;
    try {
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AddTransactionScreen(
              key: widget.addKey,
              repository: _repository,
              onEnableReminders: widget.onEnableReminders)));
    } finally {
      _adding = false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Text(widget.showRegistration ? 'Finanças' : 'Extrato'),
          actions: [
            IconButton(
                tooltip: 'Buscar contas',
                icon: const Icon(Icons.search),
                onPressed: _processing
                    ? null
                    : () => setState(() {
                          _searchOpen = !_searchOpen;
                          _query = '';
                          _selectedIds.clear();
                        })),
            PopupMenuButton<int>(
                tooltip: 'Filtrar receitas e despesas',
                enabled: !_processing,
                icon: const Icon(Icons.filter_list),
                onSelected: (kind) => setState(() {
                      _kind =
                          kind == 0 ? null : TransactionKind.values[kind - 1];
                      _selectedIds.clear();
                    }),
                itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 0, child: Text('Receitas e despesas')),
                      PopupMenuItem(value: 1, child: Text('Somente despesas')),
                      PopupMenuItem(value: 2, child: Text('Somente receitas'))
                    ]),
          ]),
      bottomNavigationBar: (!widget.showRegistration && _selectedIds.isEmpty) ||
              MediaQuery.of(context).viewInsets.bottom > 0
          ? null
          : SafeArea(
              top: false,
              child: Container(
                  color: Theme.of(context).colorScheme.surface,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Align(
                      heightFactor: 1,
                      alignment: Alignment.center,
                      child: FilledButton.icon(
                          onPressed: _processing
                              ? null
                              : _selectedIds.isEmpty
                                  ? _addEntry
                                  : _paySelected,
                          icon: Icon(_selectedIds.isEmpty
                              ? Icons.add_circle_outline
                              : Icons.check_circle_outline),
                          label: Text(_selectedIds.isEmpty
                              ? 'Adicionar'
                              : _processing
                                  ? 'Confirmando...'
                                  : 'Confirmar selecionados (${_selectedIds.length})'))))),
      body: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (widget.showRegistration)
                    SliverToBoxAdapter(
                        child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                            child: Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton.icon(
                                    onPressed: _processing
                                        ? null
                                        : () => Navigator.of(context).push(
                                            MaterialPageRoute(
                                                builder: (_) => ImportScreen(
                                                    finance: _repository))),
                                    icon: const Icon(Icons.upload_file_outlined,
                                        size: 20),
                                    label: const Text('Importar planilha'))))),
                  _filtersPanel(),
                  AsyncSliverPanel<List<FinanceEntry>>(
                    future: _future,
                    onRetry: _reload,
                    errorMessage:
                        'Não foi possível carregar as contas. Verifique sua conexão e tente novamente.',
                    builder: (allEntries) {
                      final entries = allEntries
                          .where((e) =>
                              (_filter == _EntryFilter.all ||
                                  (_filter == _EntryFilter.pending
                                      ? !e.isPaid
                                      : e.isPaid)) &&
                              (_kind == null || e.kind == _kind) &&
                              e.description.toLowerCase().contains(_query))
                          .toList();
                      if (entries.isEmpty) {
                        return SliverToBoxAdapter(
                            child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(children: [
                                  const Icon(Icons.receipt_long_outlined,
                                      size: 40),
                                  const SizedBox(height: 12),
                                  Text(
                                      allEntries.isEmpty
                                          ? 'Nenhum lançamento neste mês. Cadastre uma conta ou consulte outro mês.'
                                          : 'Nenhum registro neste filtro. Consulte Todas para ver o mês.',
                                      textAlign: TextAlign.center),
                                ])));
                      }
                      return SliverPadding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                          sliver: SliverList.builder(
                              itemCount: entries.length,
                              itemBuilder: (_, index) {
                                final entry = entries[index];
                                return FinanceEntryCard(
                                    entry: entry,
                                    selected: _selectedIds.contains(entry.id),
                                    onUndo: entry.isPaid &&
                                            !entry.isAutomaticIncome &&
                                            !_processing
                                        ? () => _undo(entry)
                                        : null,
                                    onDelete: _processing
                                        ? null
                                        : () => _delete(entry),
                                    onStop: _processing ||
                                            RecurrenceReference.fromEntryId(
                                                    entry.id) ==
                                                null
                                        ? null
                                        : () => _stop(entry),
                                    onTap: _processing
                                        ? null
                                        : () => _editAmount(entry),
                                    onSelected: entry.isPaid ||
                                            entry.isAutomaticIncome ||
                                            _processing
                                        ? null
                                        : (value) => setState(() {
                                              if (value == true) {
                                                _selectedIds.add(entry.id);
                                              } else {
                                                _selectedIds.remove(entry.id);
                                              }
                                            }));
                              }));
                    },
                  ),
                ]),
          )));
}
