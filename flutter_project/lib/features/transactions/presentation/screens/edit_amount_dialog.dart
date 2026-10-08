import 'package:flutter/material.dart';

import '../../../../core/utils/finance_utils.dart';
import '../../domain/finance_models.dart';

class EditAmountDialog extends StatefulWidget {
  const EditAmountDialog(
      {super.key,
      required this.entry,
      required this.onSave,
      this.onSaveFuture});
  final FinanceEntry entry;
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
      await (_future
          ? widget.onSaveFuture!
          : widget.onSave)(parseMoney(_amount.text)!);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Não foi possível atualizar o valor. Tente novamente.';
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
                if (widget.entry.installment != null)
                  Text(_future
                      ? 'Afeta este mês e os próximos. Valores já confirmados serão preservados.'
                      : 'Esta alteração afeta somente o mês selecionado.'),
                if (widget.onSaveFuture != null)
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Aplicar também aos próximos meses'),
                      value: _future,
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _future = value)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amount,
                  enabled: !_saving,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Valor', prefixText: 'R\$ '),
                  validator: (value) => parseMoney(value ?? '') == null
                      ? 'Informe um valor maior que zero.'
                      : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  _saving ? null : () => Navigator.of(context).pop(false),
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
