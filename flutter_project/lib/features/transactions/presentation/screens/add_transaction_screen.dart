import 'package:flutter/material.dart';

import '../../../../core/errors/app_log.dart';
import '../../../../core/errors/failure_message.dart';
import '../../../../core/utils/finance_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/month_picker.dart';
import '../../data/finance_repository.dart';
import '../../domain/finance_models.dart';
import '../widgets/category_field.dart';

enum _Frequency { once, monthly, installments }

/// Textos de cada formulário. Conta e renda têm telas separadas, cada uma
/// com os próprios campos, exemplos e opções.
class _FormText {
  const _FormText({
    required this.title,
    required this.amount,
    required this.monthlyAmount,
    required this.installmentAmount,
    required this.installmentHelp,
    required this.name,
    required this.nameHint,
    required this.nameError,
    required this.date,
    required this.firstDate,
    required this.monthlyDay,
    required this.frequencies,
    required this.installmentsCount,
    required this.installmentsHelp,
    required this.alreadyConfirmed,
    required this.alreadyConfirmedHelp,
    required this.notesHint,
    required this.save,
    required this.saveMonthly,
  });

  final String title;
  final String amount;
  final String monthlyAmount;
  final String installmentAmount;
  final String installmentHelp;
  final String name;
  final String nameHint;
  final String nameError;
  final String date;
  final String firstDate;
  final String monthlyDay;
  final Map<_Frequency, String> frequencies;
  final String installmentsCount;
  final String installmentsHelp;
  final String alreadyConfirmed;
  final String? alreadyConfirmedHelp;
  final String notesHint;
  final String save;
  final String saveMonthly;

  static const expense = _FormText(
    title: 'Nova conta',
    amount: 'Valor da conta',
    monthlyAmount: 'Valor mensal',
    installmentAmount: 'Valor da parcela',
    installmentHelp: 'Informe o valor de cada parcela.',
    name: 'Nome da conta',
    nameHint: 'Ex.: aluguel, luz, internet, cartão',
    nameError: 'Informe um nome para reconhecer esta conta.',
    date: 'Vencimento',
    firstDate: 'Primeiro vencimento',
    monthlyDay: 'Dia de vencimento mensal',
    frequencies: {
      _Frequency.once: 'Uma vez',
      _Frequency.monthly: 'Todo mês',
      _Frequency.installments: 'Parcelado',
    },
    installmentsCount: 'Quantidade de parcelas restantes',
    installmentsHelp: 'Se a compra já começou, informe as parcelas que ainda faltam e o próximo vencimento.',
    alreadyConfirmed: 'Já paguei esta conta',
    alreadyConfirmedHelp:
        'Contas pagas não podem ser alteradas nem excluídas depois.',
    notesHint: 'Ex.: débito automático, pagar pelo app do banco',
    save: 'Salvar conta',
    saveMonthly: 'Salvar conta mensal',
  );

  static const income = _FormText(
    title: 'Nova renda',
    amount: 'Valor recebido',
    monthlyAmount: 'Valor mensal',
    installmentAmount: 'Valor por mês',
    installmentHelp: 'Informe quanto entra em cada mês.',
    name: 'Nome da renda',
    nameHint: 'Ex.: salário, freela, aluguel recebido, pensão',
    nameError: 'Informe um nome para reconhecer esta renda.',
    date: 'Data do recebimento',
    firstDate: 'Primeiro recebimento',
    monthlyDay: 'Dia do recebimento mensal',
    frequencies: {
      _Frequency.once: 'Uma vez',
      _Frequency.monthly: 'Todo mês',
      _Frequency.installments: 'Por alguns meses',
    },
    installmentsCount: 'Quantidade de meses',
    installmentsHelp: 'Ex.: contrato temporário ou bolsa com prazo definido.',
    alreadyConfirmed: 'Já recebi este valor',
    alreadyConfirmedHelp: null,
    notesHint: 'Ex.: descontos do mês, adiantamento',
    save: 'Salvar renda',
    saveMonthly: 'Salvar renda mensal',
  );
}

/// Cadastro de uma conta ([TransactionKind.expense]) ou de uma renda
/// ([TransactionKind.income]); o tipo vem da escolha em "Adicionar".
class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({
    super.key,
    required this.repository,
    this.onEnableReminders,
    this.initialKind = TransactionKind.expense,
  });
  final TransactionKind initialKind;
  final FinanceRepository repository;
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
  final _category = TextEditingController();
  late final TransactionKind _kind = widget.initialKind;
  DateTime _dueDate = DateTime.now();
  int _dueDay = DateTime.now().day;
  bool _alreadyConfirmed = false;
  List<FinanceCategory> _categories = [];
  _Frequency _frequency = _Frequency.once;
  bool get _recurring => _frequency != _Frequency.once;
  bool get _hasInstallments => _frequency == _Frequency.installments;
  bool get _isIncome => _kind == TransactionKind.income;
  _FormText get _text => _isIncome ? _FormText.income : _FormText.expense;
  bool _saving = false;
  bool _allowExit = false;
  bool _askingToLeave = false;
  bool _detailsChanged = false;
  String? _categoryError;
  FinanceRepository get _repository => widget.repository;
  double? get _amountValue => parseMoney(_amount.text);
  int? get _installmentCount {
    final count = int.tryParse(_installments.text);
    return count != null && count >= 2 && count <= 1200 ? count : null;
  }

  bool get _dirty =>
      _amount.text.isNotEmpty ||
      _description.text.isNotEmpty ||
      _notes.text.isNotEmpty ||
      _installments.text.isNotEmpty ||
      _category.text.isNotEmpty ||
      _detailsChanged ||
      _recurring ||
      _alreadyConfirmed;

  Future<bool> requestLeave() async {
    if (_saving || _askingToLeave) return false;
    if (!_dirty) return true;
    _askingToLeave = true;
    final discard = await showConfirmDialog(
      context,
      title: 'Descartar cadastro?',
      message: 'Você tem dados ainda não salvos.',
      cancelLabel: 'Continuar preenchendo',
      confirmLabel: 'Descartar',
    );
    _askingToLeave = false;
    if (discard && mounted) setState(() => _allowExit = true);
    return discard;
  }

  @override
  void initState() {
    super.initState();
    _category.addListener(_categoryChanged);
    _loadCategories();
  }

  @override
  void dispose() {
    for (final controller in [
      _amount,
      _description,
      _notes,
      _installments,
      _category,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _categoryChanged() {
    if (_categoryError != null) setState(() => _categoryError = null);
  }

  /// A lista é só uma sugestão: sem ela o usuário ainda digita a categoria
  /// ou deixa em branco.
  Future<void> _loadCategories() async {
    try {
      final categories = await _repository.categories(_kind);
      if (mounted) setState(() => _categories = categories);
    } catch (error, stack) {
      AppLog.error(error, stack, 'carregar categorias');
    }
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
    FocusScope.of(context).unfocus();
    final categoryError = categoryNameError(_category.text);
    setState(() => _categoryError = categoryError);
    if (_saving || !_form.currentState!.validate() || categoryError != null) {
      return;
    }
    setState(() => _saving = true);
    try {
      final categoryId = await resolveCategoryId(
        _repository,
        _kind,
        _categories,
        _category.text,
      );
      await _repository.save(
        TransactionDraft(
          kind: _kind,
          amount: _amountValue!,
          description: _description.text,
          notes: _notes.text,
          dueDay: _dueDay,
          // Renda avulsa é lançada no momento em que entra: já conta como recebida.
          alreadyConfirmed: !_recurring && (_isIncome || _alreadyConfirmed),
          dueDate: _dueDate,
          categoryId: categoryId,
          isRecurring: _recurring,
          totalInstallments: _recurring && _hasInstallments
              ? int.parse(_installments.text)
              : null,
        ),
      );
      if (!mounted) return;
      final action = await showDialog<String>(
        barrierDismissible: false,
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cadastro salvo'),
          content: Text(_savedSummary()),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context, 'exit'),
              child: const Text('Sair'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'another'),
              child: Text(
                _isIncome ? 'Cadastrar outra renda' : 'Cadastrar outra conta',
              ),
            ),
            if (widget.onEnableReminders != null && !_isIncome)
              ElevatedButton(
                onPressed: () => Navigator.pop(context, 'reminders'),
                child: const Text('Configurar lembretes'),
              ),
          ],
        ),
      );
      if (!mounted) return;
      _form.currentState?.reset();
      for (final controller in [
        _amount,
        _description,
        _notes,
        _installments,
        _category,
      ]) {
        controller.clear();
      }
      // Uma categoria criada agora passa a aparecer na lista.
      _loadCategories();
      setState(() {
        _dueDate = DateTime.now();
        _dueDay = _dueDate.day;
        _alreadyConfirmed = false;
        _frequency = _Frequency.once;
        _detailsChanged = false;
        _allowExit = false;
      });
      if (action == 'exit') {
        setState(() => _allowExit = true);
        Navigator.of(context).pop();
      } else if (action == 'reminders') {
        widget.onEnableReminders?.call();
      }
    } catch (error, stack) {
      AppLog.error(error, stack, 'salvar lançamento');
      if (mounted) {
        _message(
          failureMessage(
            error,
            fallback: 'Não foi possível salvar. Verifique sua conexão e tente novamente.',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  /// Resumo exibido depois de salvar, com o próximo passo esperado.
  String _savedSummary() {
    final guidance = _isIncome
        ? _recurring
              ? 'A renda será considerada recebida automaticamente na data de cada mês. Se houver descontos ou mudança no valor, edite pelo Extrato.'
              : 'A renda já entrou no saldo como recebida. Você pode alterá-la ou excluí-la no Extrato.'
        : 'Confirme cada pagamento no Extrato. Ative os lembretes em Notificações para receber avisos.';
    return '${_description.text}\n'
        '${AppFormatters.currency.format(_amountValue)}\n'
        '${_recurring ? _text.firstDate : _text.date}: ${AppFormatters.date.format(_dueDate)}\n\n'
        '$guidance';
  }

  /// Prévia do cadastro antes de salvar.
  String _previewText(double amount) {
    final when = _recurring
        ? 'todo dia $_dueDay'
        : 'em ${AppFormatters.date.format(_dueDate)}';
    final period = _hasInstallments
        ? ' · ${_installments.text} meses'
        : _recurring
        ? ' · sem data final'
        : '';
    final guidance = !_isIncome
        ? 'Lembretes começam 3 dias antes do vencimento, se ativados.'
        : _recurring
        ? 'A renda entra no saldo automaticamente na data de cada mês.'
        : 'Entra no saldo como recebida.';
    return '${AppFormatters.currency.format(amount)} $when$period. $guidance';
  }

  void _message(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  String get _amountLabel => _hasInstallments
      ? _text.installmentAmount
      : _recurring
      ? _text.monthlyAmount
      : _text.amount;

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
      appBar: AppBar(title: Text(_text.title)),
      // O botão fica no corpo, logo abaixo do formulário: com o teclado aberto
      // ele sobe junto e continua visível (a barra inferior ficaria atrás dele).
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _formBody()),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: Text(
                    _saving
                        ? 'Salvando...'
                        : _recurring
                        ? _text.saveMonthly
                        : _text.save,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _formBody() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    child: Form(
      key: _form,
      onChanged: () => setState(() {}),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _amount,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              helperText: _hasInstallments ? _text.installmentHelp : null,
              labelText: _amountLabel,
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
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: _text.name,
              hintText: _text.nameHint,
            ),
            textInputAction: TextInputAction.next,
            validator: (value) =>
                (value?.trim().isEmpty ?? true) ? _text.nameError : null,
          ),
          const SizedBox(height: 16),
          const Text('Frequência'),
          Wrap(
            spacing: 8,
            children: [
              for (final MapEntry(key: frequency, value: label)
                  in _text.frequencies.entries)
                ChoiceChip(
                  label: Text(label),
                  selected: _frequency == frequency,
                  onSelected: _saving
                      ? null
                      : (_) => setState(() => _frequency = frequency),
                ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _saving ? null : _pickDate,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(
              '${_recurring ? _text.firstDate : _text.date}: ${AppFormatters.date.format(_dueDate)}',
            ),
          ),
          // Conta pode já estar paga; renda avulsa sempre entra como recebida.
          if (!_recurring && !_isIncome)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_text.alreadyConfirmed),
              subtitle: _text.alreadyConfirmedHelp == null
                  ? null
                  : Text(_text.alreadyConfirmedHelp!),
              value: _alreadyConfirmed,
              onChanged: _saving
                  ? null
                  : (value) =>
                        setState(() => _alreadyConfirmed = value ?? false),
            ),
          if (_recurring) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _dueDay,
              decoration: InputDecoration(labelText: _text.monthlyDay),
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
            if (_hasInstallments) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _installments,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _text.installmentsCount,
                  helperText: _text.installmentsHelp,
                  helperMaxLines: 3,
                ),
                validator: (value) {
                  final count = int.tryParse(value ?? '');
                  return count == null || count < 2 || count > 1200
                      ? 'Informe de 2 a 1200 meses.'
                      : null;
                },
              ),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _isIncome
                    ? 'A renda aparece em cada mês e pode ser alterada a qualquer momento no Extrato.'
                    : 'As previsões aparecem no mês consultado. Cada mês tem seu próprio pagamento.',
              ),
            ),
          ],
          const SizedBox(height: 16),
          CategoryField(
            kind: _kind,
            categories: _categories,
            controller: _category,
            enabled: !_saving,
            errorText: _categoryError,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notes,
            enabled: !_saving,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Observação (opcional)',
              hintText: _text.notesHint,
            ),
          ),
          const SizedBox(height: 24),
          if (_hasInstallments && _installmentCount != null)
            Text(
              '${_isIncome ? 'Último recebimento' : 'Última parcela'}: ${AppFormatters.date.format(monthlyDueDate(_dueDate, _installmentCount! - 1, day: _dueDay))}',
            ),
          if (_amountValue != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_previewText(_amountValue!)),
              ),
            ),
        ],
      ),
    ),
  );
}
