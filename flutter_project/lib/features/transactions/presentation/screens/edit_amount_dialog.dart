import 'package:flutter/material.dart';

import '../../../../core/errors/app_log.dart';
import '../../../../core/errors/failure_message.dart';
import '../../../../core/utils/finance_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/finance_models.dart';

class EditAmountDialog extends StatefulWidget {
  const EditAmountDialog({
    super.key,
    required this.entry,
    required this.onSave,
    this.onSaveFuture,
    this.futureFromMonth,
    this.futureIncludesSelected = true,
  });
  final FinanceEntry entry;
  final DateTime? futureFromMonth;
  final bool futureIncludesSelected;
  final Future<void> Function(double amount) onSave;
  final Future<void> Function(double amount)? onSaveFuture;

  @override
  State<EditAmountDialog> createState() => _EditAmountDialogState();
}

class _EditAmountDialogState extends State<EditAmountDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _amount;
  bool _saving = false;
  bool _future = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
      text: widget.entry.amount.toStringAsFixed(2).replaceAll('.', ','),
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await (_future ? widget.onSaveFuture! : widget.onSave)(
        parseMoney(_amount.text)!,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error, stack) {
      AppLog.error(error, stack, 'editar valor');
      if (mounted) {
        setState(() {
          _saving = false;
          _error = failureMessage(
            error,
            fallback: 'Não foi possível atualizar o valor. Tente novamente.',
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      scrollable: true,
      title: const Text('Editar valor'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.entry.description),
            const SizedBox(height: 8),
            Text(
              _future
                  ? 'Novo valor a partir de ${widget.futureFromMonth == null ? "este mês" : AppFormatters.monthYear.format(widget.futureFromMonth!)}. Outros valores já confirmados serão preservados.'
                  : 'Altera somente este lançamento. ${widget.entry.isPaid ? (widget.entry.isIncome ? "Continuará como recebido." : "Continuará como pago.") : "A confirmação permanece pendente."}',
            ),
            if (widget.onSaveFuture != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  widget.futureIncludesSelected
                      ? 'Aplicar também aos próximos meses'
                      : 'Alterar somente os próximos meses',
                ),
                subtitle: widget.futureIncludesSelected
                    ? null
                    : const Text(
                        'O lançamento selecionado mantém o valor atual.',
                      ),
                value: _future,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _future = value),
              ),
            const SizedBox(height: 16),
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
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Salvando...' : 'Salvar'),
        ),
      ],
    ),
  );
}
