import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

enum AddChoice { expense, income, spreadsheet }

/// Botões de cadastro do Início e do Extrato: despesa e renda separadas, cada
/// uma abrindo o próprio formulário, sem menu intermediário.
class AddEntryButtons extends StatelessWidget {
  const AddEntryButtons({super.key, required this.onAdd});
  final ValueChanged<AddChoice> onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.extended(
          heroTag: null,
          tooltip: 'Adicionar despesa',
          backgroundColor: colors.expense,
          foregroundColor: colors.onExpense,
          onPressed: () => onAdd(AddChoice.expense),
          icon: const Icon(Icons.remove_circle_outline),
          label: const Text('Despesa'),
        ),
        const SizedBox(width: 12),
        FloatingActionButton.extended(
          heroTag: null,
          tooltip: 'Adicionar renda',
          backgroundColor: colors.income,
          foregroundColor: colors.onIncome,
          onPressed: () => onAdd(AddChoice.income),
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Renda'),
        ),
      ],
    );
  }
}
