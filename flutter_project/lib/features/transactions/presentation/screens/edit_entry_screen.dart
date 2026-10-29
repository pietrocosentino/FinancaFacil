import 'package:flutter/material.dart';

import '../../../../core/errors/app_log.dart';
import '../../../../core/errors/failure_message.dart';
import '../../../../core/utils/finance_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/month_picker.dart';
import '../../data/finance_repository.dart';
import '../../domain/finance_models.dart';
import '../widgets/category_field.dart';

/// O que a tela altera: um lançamento avulso ou a renda mensal.
enum EditEntryMode { pendingEntry, incomeRule }

/// Edita os dados de um lançamento. Contas pagas não chegam aqui: depois de
/// pagas só podem ser inativadas. Rendas podem ser editadas a qualquer hora.
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
  late final TextEditingController _category;
  late DateTime _dueDate;
  late int _dueDay;
  List<FinanceCategory> _categories = [];
  bool _saving = false;
  String? _error;
  String? _categoryError;

  FinanceEntry get _entry => widget.entry;
  bool get _isIncomeRule => widget.mode == EditEntryMode.incomeRule;
  bool get _isIncome => _entry.isIncome;

  @override
  void initState() {
    super.initState();
    _description = TextEditingController(text: _entry.description);
    _amount = TextEditingController(
      text: _entry.amount.toStringAsFixed(2).replaceAll('.', ','),
    );
    _notes = TextEditingController(text: _entry.notes);
    _category = TextEditingController(
      text: _entry.categoryName == 'Sem categoria' ? '' : _entry.categoryName,
    );
    _dueDate = _entry.dueDate ?? DateTime.now();
    _dueDay = _dueDate.day;
    _loadCategories();
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    _notes.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await widget.repository.categories(_entry.kind);
      if (mounted) setState(() => _categories = categories);
    } catch (error, stack) {
      AppLog.error(error, stack, 'carregar categorias da edição');
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
    FocusScope.of(context).unfocus();
    final categoryError = categoryNameError(_category.text);
    setState(() => _categoryError = categoryError);
    if (_saving || !_form.currentState!.validate() || categoryError != null) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final categoryId = await resolveCategoryId(
        widget.repository,
        _entry.kind,
        _categories,
        _category.text,
      );
      if (_isIncomeRule) {
        await widget.repository.updateIncomeFromMonth(
          _entry,
          IncomeChange(
            description: _description.text,
            amount: parseMoney(_amount.text)!,
            categoryId: categoryId,
            dueDay: _dueDay,
          ),
          _fromMonth,
        );
      } else {
        await widget.repository.updateDetails(
          _entry.id,
          EntryDetails(
            description: _description.text,
            amount: parseMoney(_amount.text)!,
            dueDate: _dueDate,
            categoryId: categoryId,
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

  /// Alteração definitiva começa no mês atual; meses passados não mudam.
  DateTime get _fromMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  String get _intro => _isIncomeRule
      ? 'A alteração vale de ${AppFormatters.monthYear.format(_fromMonth)} em diante, para todos os próximos meses. Os meses anteriores continuam como estão.\n\nPara um desconto só em um mês, use "Editar só este mês" no Extrato.'
      : _isIncome
      ? 'A renda pode ser alterada a qualquer momento, mesmo depois de recebida.'
      : 'Você pode alterar esta conta enquanto ela estiver pendente. Depois de confirmar o pagamento, não será mais possível alterar nem excluir.';

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          _isIncomeRule
              ? 'Alterar renda fixa'
              : _isIncome
              ? 'Editar renda'
              : 'Editar conta',
        ),
      ),
      // Botão no corpo para subir junto com o teclado.
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _formBody()),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.check),
                  label: Text(_saving ? 'Salvando...' : 'Salvar alterações'),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _formBody() => Form(
    key: _form,
    child: ListView(
      padding: const EdgeInsets.all(16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Text(_intro),
        const SizedBox(height: 16),
        TextFormField(
          controller: _description,
          enabled: !_saving,
          maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: _isIncome ? 'Nome da renda' : 'Nome da conta',
          ),
          validator: (value) =>
              (value?.trim().isEmpty ?? true) ? 'Informe um nome.' : null,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _amount,
          enabled: !_saving,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: _isIncomeRule
                ? 'Valor mensal'
                : _isIncome
                ? 'Valor recebido'
                : 'Valor',
            prefixText: 'R\$ ',
          ),
          validator: (value) => parseMoney(value ?? '') == null
              ? 'Informe um valor maior que zero.'
              : null,
        ),
        if (!_isIncomeRule) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _saving ? null : _pickDate,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(
              '${_isIncome ? 'Recebimento' : 'Vencimento'}: ${AppFormatters.date.format(_dueDate)}',
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
        CategoryField(
          kind: _entry.kind,
          categories: _categories,
          controller: _category,
          enabled: !_saving,
          errorText: _categoryError,
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
  );
}
