import 'package:flutter/material.dart';

import '../../../../core/errors/app_log.dart';
import '../../../../core/errors/failure_message.dart';
import '../../../../core/utils/finance_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/month_picker.dart';
import '../../data/finance_repository.dart';
import '../../domain/finance_models.dart';

/// O que a tela altera: um lançamento avulso pendente ou a renda mensal.
enum EditEntryMode { pendingEntry, incomeRule }

/// Edita os dados de um lançamento. Lançamentos confirmados não chegam aqui:
/// depois de confirmados só podem ser inativados.
class EditEntryScreen extends StatefulWidget {
  const EditEntryScreen({
    super.key,
    required this.entry,
    required this.repository,
    required this.mode,
  });
  final FinanceEntry entry;
  final FinanceRepository repository;
  final EditEntryMode mode;

  @override
  State<EditEntryScreen> createState() => _EditEntryScreenState();
}

class _EditEntryScreenState extends State<EditEntryScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _description;
  late final TextEditingController _amount;
  late final TextEditingController _notes;
  late DateTime _dueDate;
  late int _dueDay;
  String? _categoryId;
  List<FinanceCategory> _categories = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  FinanceEntry get _entry => widget.entry;
  bool get _isIncomeRule => widget.mode == EditEntryMode.incomeRule;

  @override
  void initState() {
    super.initState();
    _description = TextEditingController(text: _entry.description);
    _amount = TextEditingController(
      text: _entry.amount.toStringAsFixed(2).replaceAll('.', ','),
    );
    _notes = TextEditingController(text: _entry.notes);
    _dueDate = _entry.dueDate ?? DateTime.now();
    _dueDay = _dueDate.day;
    _loadCategories();
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final categories = await widget.repository.categories(_entry.kind);
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _categoryId =
            categories.any((category) => category.id == _entry.categoryId)
            ? _entry.categoryId
            : categories
                  .where((category) => category.name == _entry.categoryName)
                  .firstOrNull
                  ?.id;
      });
    } catch (error, stack) {
      AppLog.error(error, stack, 'carregar categorias da edição');
      if (mounted) {
        setState(() => _error = 'Não foi possível carregar as categorias.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(MonthRange.firstYear),
      lastDate: DateTime(MonthRange.lastYear, 12, 31),
    );
    if (selected != null && mounted) setState(() => _dueDate = selected);
  }

  Future<void> _save() async {
    if (_saving || _loading || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_isIncomeRule) {
        final ruleId = RecurrenceReference.fromEntryId(_entry.id)!.ruleId;
        await widget.repository.updateIncomeRule(
          ruleId,
          IncomeRuleDetails(
            description: _description.text,
            categoryId: _categoryId!,
            dueDay: _dueDay,
          ),
        );
      } else {
        await widget.repository.updateDetails(
          _entry.id,
          EntryDetails(
            description: _description.text,
            amount: parseMoney(_amount.text)!,
            dueDate: _dueDate,
            categoryId: _categoryId!,
            notes: _notes.text,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error, stack) {
      AppLog.error(error, stack, 'editar lançamento');
      if (mounted) {
        setState(() {
          _saving = false;
          _error = failureMessage(
            error,
            fallback: 'Não foi possível salvar. Tente novamente.',
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          _isIncomeRule ? 'Editar renda mensal' : 'Editar lançamento',
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _saving || _loading ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(_saving ? 'Salvando...' : 'Salvar alterações'),
          ),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              _isIncomeRule
                  ? 'Nome, categoria e dia valem para todos os meses desta renda. Para mudar o valor, use "Editar valor".'
                  : 'Você pode alterar este lançamento enquanto ele estiver pendente. Depois de confirmar o pagamento, não será mais possível alterar nem excluir.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              enabled: !_saving,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Nome'),
              validator: (value) =>
                  (value?.trim().isEmpty ?? true) ? 'Informe um nome.' : null,
            ),
            if (!_isIncomeRule) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _amount,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Valor',
                  prefixText: 'R\$ ',
                ),
                validator: (value) => parseMoney(value ?? '') == null
                    ? 'Informe um valor maior que zero.'
                    : null,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(
                  '${_entry.isIncome ? 'Recebimento' : 'Vencimento'}: ${AppFormatters.date.format(_dueDate)}',
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _dueDay,
                decoration: const InputDecoration(
                  labelText: 'Dia do recebimento mensal',
                ),
                items: [
                  for (var day = 1; day <= 31; day++)
                    DropdownMenuItem(value: day, child: Text('Dia $day')),
                ],
                onChanged: _saving
                    ? null
                    : (day) => setState(() => _dueDay = day ?? _dueDay),
              ),
            ],
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_categories.isEmpty)
              TextButton.icon(
                onPressed: _saving ? null : _loadCategories,
                icon: const Icon(Icons.refresh),
                label: const Text('Recarregar categorias'),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Categoria'),
                validator: (value) =>
                    value == null ? 'Escolha uma categoria.' : null,
                items: [
                  for (final category in _categories)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(
                        category.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _categoryId = value),
              ),
            if (!_isIncomeRule) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _notes,
                enabled: !_saving,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Observação (opcional)',
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
