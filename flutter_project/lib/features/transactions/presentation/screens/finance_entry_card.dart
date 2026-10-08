import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../dashboard/domain/finance_summary.dart';
import '../../domain/finance_models.dart';

class FinanceEntryCard extends StatelessWidget {
  const FinanceEntryCard(
      {super.key,
      required this.entry,
      this.selected = false,
      this.onSelected,
      this.onTap,
      this.notice,
      this.actions});
  final FinanceEntry entry;
  final bool selected;
  final ValueChanged<bool?>? onSelected;
  final VoidCallback? onTap;
  final String? notice;
  final Widget? actions;
  @override
  Widget build(BuildContext context) {
    final days = entry.dueDate == null
        ? null
        : daysUntil(entry.dueDate!, DateTime.now());
    final statusColor = entry.isPaid
        ? AppTheme.mintNeon
        : !entry.isIncome && days != null && days < 0
            ? Colors.redAccent
            : !entry.isIncome && days != null && days <= 3
                ? Colors.amber
                : AppTheme.textSecondary;
    final color = AppTheme.semanticColor(context, statusColor);
    final status = entry.isPaid
        ? (entry.isIncome ? 'Recebido' : 'Pago')
        : !entry.isIncome && days != null && days < 0
            ? 'Atrasada'
            : !entry.isIncome && days == 0
                ? 'Vence hoje'
                : '${entry.kind.label} pendente';
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(entry.description,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                      '${entry.isIncome ? '+' : '-'} ${AppFormatters.currency.format(entry.amount)}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: Theme.of(context).colorScheme.onSurface)),
                  Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (!entry.isPaid && onSelected != null)
                          Semantics(
                              label: 'Selecionar ${entry.description}',
                              child: Checkbox(
                                  value: selected, onChanged: onSelected))
                        else
                          Icon(
                              entry.isPaid
                                  ? Icons.check_circle_outline
                                  : Icons.schedule,
                              color: color,
                              size: 20),
                        Text(status, style: TextStyle(color: color)),
                        if (onTap != null)
                          TextButton.icon(
                              onPressed: onTap,
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Editar valor')),
                      ]),
                  Text(
                      'Vencimento: ${entry.dueDate == null ? 'Não informado' : AppFormatters.date.format(entry.dueDate!)}'),
                  Text(entry.categoryName,
                      style: Theme.of(context).textTheme.bodySmall),
                  if (notice != null)
                    Text(notice!,
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.w600)),
                  if (entry.recurrenceDescription.isNotEmpty)
                    Text(entry.recurrenceDescription),
                  if (entry.lastDue != null)
                    Text(
                        'Última parcela: ${AppFormatters.date.format(entry.lastDue!)}'),
                  if (entry.notes.isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(entry.notes)),
                  if (actions != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: actions!),
                ])));
  }
}
