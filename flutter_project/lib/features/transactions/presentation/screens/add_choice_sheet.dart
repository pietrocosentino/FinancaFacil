import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

enum AddChoice { expense, income, spreadsheet }

/// Barra discreta fixa no topo do Início e do Extrato: despesa e renda
/// separadas, cada uma abrindo o próprio formulário, sem menu intermediário.
class QuickAddBar extends StatelessWidget {
  const QuickAddBar({super.key, required this.onAdd});
  final ValueChanged<AddChoice> onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    Widget button(AddChoice choice, String label, IconData icon, Color color) =>
        Expanded(
          child: Tooltip(
            message: choice == AddChoice.income
                ? 'Adicionar renda'
                : 'Adicionar despesa',
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color.withValues(alpha: 0.45)),
                backgroundColor: color.withValues(alpha: 0.06),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onPressed: () => onAdd(choice),
              icon: Icon(icon, size: 20),
              label: Text(label),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          button(
            AddChoice.expense,
            'Despesa',
            Icons.remove_circle_outline,
            colors.expense,
          ),
          const SizedBox(width: 12),
          button(
            AddChoice.income,
            'Renda',
            Icons.add_circle_outline,
            colors.income,
          ),
        ],
      ),
    );
  }
}
