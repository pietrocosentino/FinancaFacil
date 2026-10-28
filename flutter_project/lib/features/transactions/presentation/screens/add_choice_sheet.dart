import 'package:flutter/material.dart';

enum AddChoice { expense, income, spreadsheet }

/// Ação compacta do Início que mantém os tipos de lançamento agrupados.
class QuickAddBar extends StatelessWidget {
  const QuickAddBar({super.key, required this.onAdd});
  final ValueChanged<AddChoice> onAdd;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton.icon(
              onPressed: () => onAdd(AddChoice.spreadsheet),
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Importar planilha'),
            ),
            OutlinedButton.icon(
              onPressed: () => _showChoices(context),
              icon: const Icon(Icons.add),
              label: const Text('Adicionar lançamento'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showChoices(BuildContext context) async {
    final choice = await showModalBottomSheet<AddChoice>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: Text(
                'Novo lançamento',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.remove_circle_outline),
              title: const Text('Despesa ou conta'),
              onTap: () => Navigator.pop(context, AddChoice.expense),
            ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Renda'),
              onTap: () => Navigator.pop(context, AddChoice.income),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (choice != null) onAdd(choice);
  }
}
