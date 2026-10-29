import 'package:flutter/material.dart';

import '../../../../core/errors/app_log.dart';
import '../../../../core/errors/failure_message.dart';
import '../../domain/finance_models.dart';

/// Pede o nome e cria uma categoria própria. Retorna a categoria criada (ou a
/// existente com o mesmo nome) ou `null` se o usuário cancelar.
Future<FinanceCategory?> showNewCategoryDialog(
  BuildContext context, {
  required TransactionKind kind,
  required Future<FinanceCategory> Function(String name) create,
  String initialName = '',
}) => showDialog<FinanceCategory>(
  context: context,
  builder: (_) =>
      _NewCategoryDialog(kind: kind, create: create, initialName: initialName),
);

class _NewCategoryDialog extends StatefulWidget {
  const _NewCategoryDialog({
    required this.kind,
    required this.create,
    required this.initialName,
  });
  final TransactionKind kind;
  final Future<FinanceCategory> Function(String name) create;
  final String initialName;

  @override
  State<_NewCategoryDialog> createState() => _NewCategoryDialogState();
}

class _NewCategoryDialogState extends State<_NewCategoryDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  static String? validate(String? value) {
    final length = value?.trim().length ?? 0;
    return length < 2 || length > 40
        ? 'Use um nome com 2 a 40 caracteres.'
        : null;
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final category = await widget.create(_name.text.trim());
      if (mounted) Navigator.of(context).pop(category);
    } catch (error, stack) {
      AppLog.error(error, stack, 'nova categoria');
      if (mounted) {
        setState(() {
          _saving = false;
          _error = failureMessage(
            error,
            fallback: 'Não foi possível criar a categoria. Tente novamente.',
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
      title: Text(
        widget.kind == TransactionKind.income
            ? 'Nova categoria de renda'
            : 'Nova categoria de despesa',
      ),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              enabled: !_saving,
              autofocus: true,
              maxLength: 40,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
              decoration: const InputDecoration(
                labelText: 'Nome da categoria',
                hintText: 'Ex.: Pet, Academia, Freelas',
              ),
              validator: validate,
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Criando...' : 'Criar'),
        ),
      ],
    ),
  );
}
