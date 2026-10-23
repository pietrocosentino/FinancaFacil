import 'package:flutter/material.dart';

import '../../transactions/domain/finance_models.dart';
import '../domain/import_models.dart';

class ImportLineDialog extends StatefulWidget {
  const ImportLineDialog({
    super.key,
    required this.line,
    required this.categories,
  });
  final ImportLine line;
  final Map<TransactionKind, List<FinanceCategory>> categories;
  @override
  State<ImportLineDialog> createState() => _ImportLineDialogState();
}

class _ImportLineDialogState extends State<ImportLineDialog> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  late TransactionKind? _kind;
  late bool? _recurring;
  String? _category;
  @override
  void initState() {
    super.initState();
    _fields = {
      for (final key in [
        'description',
        'amount',
        'due_date',
        'months',
        'notes',
        'due_day',
      ])
        key: TextEditingController(text: widget.line.text(key)),
    };
    _kind = widget.line.kind;
    _recurring = widget.line.recurring;
    _category = widget.line.categoryId;
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  ImportLine _draft() => ImportLine(widget.line.line, {
    for (final entry in _fields.entries) entry.key: entry.value.text,
    'type': _kind?.label ?? '',
    'recurring': _recurring == null
        ? ''
        : _recurring!
        ? 'Sim'
        : 'Não',
    'category': widget.line.text('category'),
  }, categoryId: _category);

  void _save() {
    final draft = _draft();
    final errors = draft.errors(widget.categories[_kind] ?? []);
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errors.join('\n'))));
      return;
    }
    Navigator.pop(context, draft);
  }

  Widget _input(
    String key,
    String label, {
    String? hint,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: _fields[key],
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label, helperText: hint),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final categories = widget.categories[_kind] ?? [];
    return AlertDialog(
      title: Text('Corrigir linha ${widget.line.line}'),
      scrollable: true,
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _input('description', 'Descrição'),
              DropdownButtonFormField<TransactionKind>(
                initialValue: _kind,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: [
                  for (final kind in TransactionKind.values)
                    DropdownMenuItem(value: kind, child: Text(kind.label)),
                ],
                onChanged: (value) => setState(() {
                  _kind = value;
                  _category = null;
                }),
              ),
              const SizedBox(height: 12),
              _input(
                'amount',
                'Valor mensal (R\$)',
                keyboard: const TextInputType.numberWithOptions(decimal: true),
              ),
              _input(
                'due_date',
                'Primeiro vencimento',
                hint: 'DD/MM/AAAA ou AAAA-MM-DD',
              ),
              DropdownButtonFormField<bool>(
                initialValue: _recurring,
                decoration: const InputDecoration(labelText: 'Recorrente'),
                items: const [
                  DropdownMenuItem(value: true, child: Text('Sim')),
                  DropdownMenuItem(value: false, child: Text('Não')),
                ],
                onChanged: (value) => setState(() {
                  _recurring = value;
                  if (value == false) {
                    _fields['months']!.clear();
                    _fields['due_day']!.clear();
                  }
                }),
              ),
              const SizedBox(height: 12),
              if (_recurring == true) ...[
                _input(
                  'months',
                  'Quantidade de meses',
                  hint: 'Deixe vazio para não ter data final.',
                  keyboard: TextInputType.number,
                ),
                _input(
                  'due_day',
                  'Dia de vencimento mensal',
                  hint: 'Opcional. Se vazio, usa o dia do primeiro vencimento.',
                  keyboard: TextInputType.number,
                ),
              ],
              DropdownButtonFormField<String>(
                key: ValueKey('${_kind?.name}:$_category'),
                initialValue: _category,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Categoria',
                  helperText: 'Na planilha: ${widget.line.text('category')}',
                ),
                items: [
                  for (final category in categories)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(
                        category.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _category = value),
              ),
              const SizedBox(height: 12),
              _input('notes', 'Observações'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Salvar correção')),
      ],
    );
  }
}
