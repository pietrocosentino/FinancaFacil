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
      this.onDelete,
      this.onStop,
      this.onUndo,
      this.notice,
      this.actions});
  final FinanceEntry entry;
  final bool selected;
  final ValueChanged<bool?>? onSelected;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onStop;
  final VoidCallback? onUndo;
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
        ? entry.isAutomaticIncome
            ? 'Recebido · automático'
            : entry.isIncome
                ? 'Recebido'
                : 'Pago'
        : !entry.isIncome && days != null && days < 0
            ? 'Atrasada'
            : !entry.isIncome && days == 0
                ? 'Vence hoje'
                : entry.isAutomaticIncome
                    ? 'Recebimento previsto'
                    : '${entry.kind.label} pendente';
    final dateLabel = entry.isIncome ? 'Recebimento' : 'Vencimento';
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(entry.description,
                            style: Theme.of(context).textTheme.titleMedium)),
                    if (onTap != null ||
                        onDelete != null ||
                        onStop != null ||
                        onUndo != null)
                      PopupMenuButton<String>(
                          tooltip: 'Mais opções de ${entry.description}',
                          onSelected: (action) {
                            switch (action) {
                              case 'edit':
                                onTap?.call();
                              case 'delete':
                                onDelete?.call();
                              case 'stop':
                                onStop?.call();
                              case 'undo':
                                onUndo?.call();
                            }
                          },
                          itemBuilder: (_) => [
                                if (onTap != null)
                                  const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Editar valor')),
                                if (onUndo != null)
                                  const PopupMenuItem(
                                      value: 'undo',
                                      child: Text('Corrigir confirmação')),
                                if (onDelete != null)
                                  PopupMenuItem(
                                      value: 'delete',
                                      child: Text(
                                          entry.isRecurring
                                              ? 'Excluir somente este mês'
                                              : 'Excluir lançamento',
                                          style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error))),
                                if (onStop != null)
                                  const PopupMenuItem(
                                      value: 'stop',
                                      child: Text('Encerrar próximos meses')),
                              ]),
                  ]),
                  Text(
                      '${entry.isIncome ? '+' : '-'} ${AppFormatters.currency.format(entry.amount)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 20, fontWeight: FontWeight.w700)),
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
                              size: 18),
                        Text(status, style: TextStyle(color: color)),
                      ]),
                  Text(
                      '$dateLabel: ${entry.dueDate == null ? 'Não informado' : AppFormatters.date.format(entry.dueDate!)}',
                      style: Theme.of(context).textTheme.bodySmall),
                  if (notice != null)
                    Text(notice!,
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.w600)),
                  ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 8),
                      title: const Text('Detalhes',
                          style: TextStyle(fontSize: 14)),
                      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(entry.categoryName),
                        if (entry.recurrenceDescription.isNotEmpty)
                          Text(entry.recurrenceDescription),
                        if (entry.lastDue != null)
                          Text(
                              'Última parcela: ${AppFormatters.date.format(entry.lastDue!)}'),
                        if (entry.notes.isNotEmpty && actions == null)
                          Text(entry.notes),
                        if (entry.isAutomaticIncome)
                          const Text(
                              'O app considera a renda recebida na data cadastrada, sem consultar sua conta bancária.'),
                      ]),
                  if (actions != null && entry.notes.isNotEmpty)
                    Text(entry.notes),
                  if (actions != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: actions!),
                ])));
  }
}
