import 'package:flutter/material.dart';

import '../../../../core/services/app_services.dart';
import '../../../../core/utils/finance_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/month_picker.dart';
import '../../data/finance_repository.dart';
import '../../domain/finance_models.dart';

enum _Frequency {
  once('Uma vez'),
  monthly('Todo mês'),
  installments('Parcelado');

  const _Frequency(this.label);
  final String label;
}

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({
    super.key,
    this.repository,
    this.onEnableReminders,
    this.initialKind = TransactionKind.expense,
  });
  final TransactionKind initialKind;
  final FinanceRepository? repository;
  final VoidCallback? onEnableReminders;
  @override
  State<AddTransactionScreen> createState() => AddTransactionScreenState();
}

class AddTransactionScreenState extends State<AddTransactionScreen> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  final _notes = TextEditingController();
  final _installments = TextEditingController();
  late final FinanceRepository _repository;
  TransactionKind _kind = TransactionKind.expense;
  TransactionKind _initialKind = TransactionKind.expense;
  DateTime _dueDate = DateTime.now();
  int _dueDay = DateTime.now().day;
  bool _alreadyConfirmed = false;
  String? _categoryId;
  List<FinanceCategory> _categories = [];
  _Frequency _frequency = _Frequency.once;
  bool get _recurring => _frequency != _Frequency.once;
  bool get _hasInstallments => _frequency == _Frequency.installments;
  bool _saving = false;
  bool _allowExit = false;
  bool _askingToLeave = false;
  bool _detailsChanged = false;
  bool get _dirty =>
      _amount.text.isNotEmpty ||
      _description.text.isNotEmpty ||
      _notes.text.isNotEmpty ||
      _installments.text.isNotEmpty ||
      _kind != _initialKind ||
      _detailsChanged ||
      _recurring ||
      _alreadyConfirmed;

  Future<bool> requestLeave() async {
    if (_saving || _askingToLeave) return false;
    if (!_dirty) return true;
    _askingToLeave = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descartar cadastro?'),
        content: const Text('Você tem dados ainda não salvos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuar preenchendo'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    _askingToLeave = false;
    if (discard == true && mounted) setState(() => _allowExit = true);
    return discard == true;
  }

  bool _loadingCategories = false;
  String? _categoryError;
  int _categoryRequest = 0;

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind;
    _initialKind = widget.initialKind;
    _repository = widget.repository ?? AppServices.finance;
    _loadCategories();
  }

  @override
  void dispose() {
    _categoryRequest++;
    for (final controller in [_amount, _description, _notes, _installments]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final request = ++_categoryRequest;
    setState(() {
      _loadingCategories = true;
      _categoryError = null;
      _categoryId = null;
    });
    try {
      final categories = await _repository.categories(_kind);
      if (!mounted || request != _categoryRequest) return;
      setState(() {
        _categories = categories;
        _categoryId = categories.length == 1 ? categories.first.id : null;
      });
    } catch (_) {
      if (mounted && request == _categoryRequest) {
        setState(() {
          _categories = [];
          _categoryError = 'Não foi possível carregar as categorias.';
        });
      }
    } finally {
      if (mounted && request == _categoryRequest) {
        setState(() => _loadingCategories = false);
      }
    }
  }

  void _changeKind(TransactionKind kind) {
    if (_saving || kind == _kind) return;
    setState(() => _kind = kind);
    _loadCategories();
  }

  Future<void> _pickDate() async {
    final picker = _recurring
        ? showMonthPicker(context: context, initialMonth: _dueDate)
        : showDatePicker(
            context: context,
            initialDate: _dueDate,
            firstDate: DateTime(MonthRange.firstYear),
            lastDate: DateTime(MonthRange.lastYear, 12, 31),
          );
    final selected = await picker;
    if (selected != null && mounted) {
      setState(() {
        _detailsChanged = true;
        // O mês inicial muda, mas o dia mensal escolhido continua sendo respeitado.
        _dueDate = _recurring
            ? monthlyDueDate(selected, 0, day: _dueDay)
            : selected;
        if (!_recurring) _dueDay = selected.day;
      });
    }
  }

  Future<void> _save() async {
    if (_saving || _loadingCategories || !_form.currentState!.validate()) {
      return;
    }
    if (_categoryId == null) return;
    setState(() => _saving = true);
    FocusScope.of(context).unfocus();
    try {
      await _repository.save(
        TransactionDraft(
          kind: _kind,
          amount: parseMoney(_amount.text)!,
          description: _description.text,
          notes: _notes.text,
          dueDay: _dueDay,
          alreadyConfirmed: !_recurring && _alreadyConfirmed,
          dueDate: _dueDate,
          categoryId: _categoryId!,
          isRecurring: _recurring,
          totalInstallments: _recurring && _hasInstallments
              ? int.parse(_installments.text)
              : null,
        ),
      );
      if (!mounted) return;
      _message(
        _recurring
            ? 'Conta mensal salva. Consulte em Finanças.'
            : 'Lançamento salvo.',
      );
      final action = await showDialog<String>(
        barrierDismissible: false,
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cadastro salvo'),
          content: Text(
            '${_description.text}\n${AppFormatters.currency.format(parseMoney(_amount.text))}\nPrimeiro vencimento: ${AppFormatters.date.format(_dueDate)}\n\n${_kind == TransactionKind.income && _recurring
                ? 'A renda será considerada recebida automaticamente na data de cada mês. Você pode editar o valor em Finanças.'
                : _kind == TransactionKind.income
                ? 'Consulte sua renda em Finanças.'
                : 'Confirme cada pagamento em Finanças. Ative os lembretes em Notificações para receber avisos.'}',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context, 'exit'),
              child: const Text('Sair'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'another'),
              child: const Text('Cadastrar outra'),
            ),
            if (widget.onEnableReminders != null &&
                _kind == TransactionKind.expense)
              ElevatedButton(
                onPressed: () => Navigator.pop(context, 'reminders'),
                child: const Text('Configurar lembretes'),
              ),
          ],
        ),
      );
      if (!mounted) return;
      _form.currentState?.reset();
      _amount.clear();
      _description.clear();
      _notes.clear();
      _installments.clear();
      setState(() {
        _dueDate = DateTime.now();
        _dueDay = _dueDate.day;
        _alreadyConfirmed = false;
        _frequency = _Frequency.once;
        _initialKind = _kind;
        _detailsChanged = false;
        _allowExit = false;
        _categoryId = _categories.length == 1 ? _categories.first.id : null;
      });
      if (action == 'exit') {
        setState(() => _allowExit = true);
        Navigator.of(context).pop();
      } else if (action == 'reminders') {
        widget.onEnableReminders?.call();
      }
    } catch (_) {
      if (mounted) {
        _message(
          'Não foi possível salvar. Verifique sua conexão e tente novamente.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _message(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowExit || (!_dirty && !_saving),
    onPopInvokedWithResult: (didPop, result) async {
      if (!didPop && await requestLeave() && mounted && context.mounted) {
        await Future<void>.delayed(Duration.zero);
        if (context.mounted) Navigator.of(context).pop();
      }
    },
    child: Scaffold(
      appBar: AppBar(title: const Text('Novo lançamento')),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: ElevatedButton(
            onPressed: _saving || _loadingCategories || _categories.isEmpty
                ? null
                : _save,
            child: Text(
              _saving
                  ? 'Salvando...'
                  : _recurring
                  ? 'Salvar conta mensal'
                  : 'Salvar lançamento',
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _form,
            onChanged: () => setState(() {}),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    for (final kind in TransactionKind.values)
                      ChoiceChip(
                        label: Text(kind.label),
                        selected: _kind == kind,
                        onSelected: _saving ? null : (_) => _changeKind(kind),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _amount,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    helperText: _hasInstallments
                        ? 'Informe o valor de cada parcela.'
                        : null,
                    labelText: _hasInstallments ? 'Valor da parcela' : 'Valor',
                    prefixText: 'R\$ ',
                    hintText: '0,00',
                  ),
                  validator: (value) => parseMoney(value ?? '') == null
                      ? 'Informe um valor válido maior que zero.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _description,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Nome da conta ou renda',
                    hintText: 'Aluguel, conta de luz, salário...',
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'Informe um nome para reconhecer esta conta.'
                      : null,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _pickDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(
                    '${_recurring ? 'Primeiro vencimento' : 'Vencimento'}: ${AppFormatters.date.format(_dueDate)}',
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Frequência'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final frequency in _Frequency.values)
                      ChoiceChip(
                        label: Text(frequency.label),
                        selected: _frequency == frequency,
                        onSelected: _saving
                            ? null
                            : (_) => setState(() {
                                _frequency = frequency;
                              }),
                      ),
                  ],
                ),
                if (!_recurring)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _kind == TransactionKind.income
                          ? 'Já recebi esta renda'
                          : 'Já paguei esta conta',
                    ),
                    value: _alreadyConfirmed,
                    onChanged: _saving
                        ? null
                        : (value) => setState(
                            () => _alreadyConfirmed = value ?? false,
                          ),
                  ),
                if (_recurring) ...[
                  DropdownButtonFormField<int>(
                    initialValue: _dueDay,
                    decoration: const InputDecoration(
                      labelText: 'Dia de vencimento mensal',
                    ),
                    items: [
                      for (var day = 1; day <= 31; day++)
                        DropdownMenuItem(value: day, child: Text('Dia $day')),
                    ],
                    onChanged: _saving
                        ? null
                        : (day) {
                            if (day == null) return;
                            setState(() {
                              _detailsChanged = true;
                              _dueDay = day;
                              _dueDate = monthlyDueDate(_dueDate, 0, day: day);
                            });
                          },
                  ),
                  if (_hasInstallments)
                    TextFormField(
                      controller: _installments,
                      enabled: !_saving,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantidade de meses restantes',
                        helperText: 'Se a compra já começou, informe os meses que ainda faltam e o próximo vencimento.',
                      ),
                      validator: (value) {
                        final count = int.tryParse(value ?? '');
                        return count == null || count < 2 || count > 1200
                            ? 'Informe de 2 a 1200 parcelas.'
                            : null;
                      },
                    ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'As previsões aparecem no mês consultado. Cada mês tem seu próprio pagamento.',
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (_loadingCategories)
                  const Center(child: CircularProgressIndicator())
                else if (_categoryError != null || _categories.isEmpty)
                  Column(
                    children: [
                      Text(
                        _categoryError ??
                            'Nenhuma categoria disponível para este tipo.',
                      ),
                      TextButton.icon(
                        onPressed: _saving ? null : _loadCategories,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Recarregar categorias'),
                      ),
                    ],
                  )
                else
                  DropdownButtonFormField<String>(
                    key: ValueKey(_categoryId),
                    initialValue: _categoryId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Categoria',
                      hintText: 'Selecione uma categoria',
                    ),
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
                        : (value) => setState(() {
                            _categoryId = value;
                            _detailsChanged = true;
                          }),
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notes,
                  enabled: !_saving,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Observação (opcional)',
                    hintText: 'Ex.: transferir para meu pai até o dia 8',
                  ),
                ),
                const SizedBox(height: 24),
                if (_hasInstallments &&
                    (int.tryParse(_installments.text) ?? 0) >= 2 &&
                    (int.tryParse(_installments.text) ?? 0) <= 1200)
                  Text(
                    'Última parcela: ${AppFormatters.date.format(monthlyDueDate(_dueDate, int.parse(_installments.text) - 1, day: _dueDay))}',
                  ),
                if (parseMoney(_amount.text) != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '${AppFormatters.currency.format(parseMoney(_amount.text))} ${_recurring ? 'todo dia $_dueDay' : 'em ${AppFormatters.date.format(_dueDate)}'}${_hasInstallments
                            ? ' · ${_installments.text} meses'
                            : _recurring
                            ? ' · sem data final'
                            : ''}. ${_kind == TransactionKind.expense ? 'Lembretes começam 3 dias antes do vencimento, se ativados.' : 'Confirme o recebimento em Finanças.'}',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
