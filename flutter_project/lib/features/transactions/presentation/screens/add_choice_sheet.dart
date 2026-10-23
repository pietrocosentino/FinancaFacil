import 'package:flutter/material.dart';

enum AddChoice { expense, income, spreadsheet }

/// Escolha do que cadastrar, aberta pelo botão "Adicionar".
Future<AddChoice?> showAddChoiceSheet(BuildContext context) =>
    showModalBottomSheet<AddChoice>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        Widget option(
          AddChoice choice,
          IconData icon,
          String title,
          String subtitle,
        ) => ListTile(
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(title),
          subtitle: Text(subtitle),
          onTap: () => Navigator.pop(context, choice),
        );
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text(
                    'O que você quer adicionar?',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                option(
                  AddChoice.expense,
                  Icons.receipt_outlined,
                  'Conta ou despesa',
                  'Contas fixas, compras e parcelamentos',
                ),
                option(
                  AddChoice.income,
                  Icons.savings_outlined,
                  'Renda',
                  'Salário e outros valores recebidos',
                ),
                option(
                  AddChoice.spreadsheet,
                  Icons.upload_file_outlined,
                  'Importar planilha',
                  'Vários lançamentos de uma vez, pelo modelo Excel',
                ),
              ],
            ),
          ),
        );
      },
    );

/// Botão principal de cadastro, presente no Início e no Extrato.
class AddEntryButton extends StatelessWidget {
  const AddEntryButton({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FloatingActionButton.extended(
    heroTag: null,
    onPressed: onPressed,
    icon: const Icon(Icons.add),
    label: const Text('Adicionar'),
    tooltip: 'Adicionar conta, renda ou planilha',
  );
}
