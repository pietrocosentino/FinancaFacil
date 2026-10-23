import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entry_status.dart';
import '../../domain/finance_models.dart';

enum _EntryAction { edit, confirm, undo, notReceived, delete, stop }

/// Cartão de um lançamento. Tocar no cartão ou em "⋮" abre as ações
/// disponíveis; somente as ações com callback aparecem.
class FinanceEntryCard extends StatefulWidget {
  const FinanceEntryCard({
    super.key,
    required this.entry,
    this.selected = false,
    this.onSelected,
    this.onTap,
    this.onConfirm,
    this.onDelete,
    this.onStop,
    this.onUndo,
    this.onNotReceived,
    this.notice,
    this.actions,
  });
  final FinanceEntry entry;
  final bool selected;
  final ValueChanged<bool?>? onSelected;

  /// Editar valor.
  final VoidCallback? onTap;
  final VoidCallback? onConfirm;
  final VoidCallback? onDelete;
  final VoidCallback? onStop;
  final VoidCallback? onUndo;
  final VoidCallback? onNotReceived;
  final String? notice;
  final Widget? actions;

  @override
  State<FinanceEntryCard> createState() => _FinanceEntryCardState();
}

class _FinanceEntryCardState extends State<FinanceEntryCard> {
  final _menu = GlobalKey<PopupMenuButtonState<String>>();

  FinanceEntry get entry => widget.entry;

  Map<_EntryAction, VoidCallback?> get _callbacks => {
    _EntryAction.edit: widget.onTap,
    _EntryAction.confirm: widget.onConfirm,
    _EntryAction.undo: widget.onUndo,
    _EntryAction.notReceived: widget.onNotReceived,
    _EntryAction.delete: widget.onDelete,
    _EntryAction.stop: widget.onStop,
  };

  bool get _hasActions => _callbacks.values.any((action) => action != null);

  String _label(_EntryAction action) => switch (action) {
    _EntryAction.edit => 'Editar valor',
    _EntryAction.confirm =>
      entry.isIncome ? 'Confirmar recebimento' : 'Confirmar pagamento',
    _EntryAction.undo => 'Corrigir confirmação',
    _EntryAction.notReceived => 'Não recebi',
    _EntryAction.delete =>
      entry.isRecurring ? 'Excluir somente este mês' : 'Excluir lançamento',
    _EntryAction.stop => 'Encerrar próximos meses',
  };

  IconData _icon(_EntryAction action) => switch (action) {
    _EntryAction.edit => Icons.edit_outlined,
    _EntryAction.confirm => Icons.check_circle_outline,
    _EntryAction.undo => Icons.undo,
    _EntryAction.notReceived => Icons.money_off_outlined,
    _EntryAction.delete => Icons.delete_outline,
    _EntryAction.stop => Icons.stop_circle_outlined,
  };

  static Color _urgencyColor(AppColors colors, EntryUrgency urgency) =>
      switch (urgency) {
        EntryUrgency.settled => colors.positive,
        EntryUrgency.overdue => colors.danger,
        EntryUrgency.dueSoon => colors.warning,
        EntryUrgency.normal => colors.muted,
      };

  String get _details => [
    entry.categoryName,
    if (entry.recurrenceDescription.isNotEmpty) entry.recurrenceDescription,
  ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = EntryStatus.of(entry, DateTime.now());
    final color = _urgencyColor(AppColors.of(context), status.urgency);
    final dateLabel = entry.isIncome ? 'Recebimento' : 'Vencimento';
    final date = entry.dueDate == null
        ? 'não informado'
        : AppFormatters.date.format(entry.dueDate!);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _hasActions ? () => _menu.currentState?.showButtonMenu() : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (!entry.isPaid && widget.onSelected != null)
                    Semantics(
                      label: 'Selecionar ${entry.description}',
                      child: Checkbox(
                        value: widget.selected,
                        onChanged: widget.onSelected,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      entry.description,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (_hasActions)
                    PopupMenuButton<String>(
                      key: _menu,
                      tooltip: 'Mais opções de ${entry.description}',
                      onSelected: (name) =>
                          _callbacks[_EntryAction.values.byName(name)]?.call(),
                      itemBuilder: (_) => [
                        for (final action in _EntryAction.values)
                          if (_callbacks[action] != null)
                            PopupMenuItem(
                              value: action.name,
                              child: Row(
                                children: [
                                  Icon(
                                    _icon(action),
                                    size: 20,
                                    color: action == _EntryAction.delete
                                        ? theme.colorScheme.error
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Flexible(
                                    child: Text(
                                      _label(action),
                                      style: action == _EntryAction.delete
                                          ? TextStyle(
                                              color: theme.colorScheme.error,
                                            )
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                      ],
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${entry.isIncome ? '+' : '-'} ${AppFormatters.currency.format(entry.amount)}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Icon(
                          entry.isPaid
                              ? Icons.check_circle_outline
                              : Icons.schedule,
                          color: color,
                          size: 18,
                        ),
                        Text(status.label, style: TextStyle(color: color)),
                        Text(
                          '· $dateLabel $date',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    if (widget.notice != null)
                      Text(
                        widget.notice!,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    Text(_details, style: theme.textTheme.bodySmall),
                    if (entry.notes.isNotEmpty)
                      Text(
                        entry.notes,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    if (widget.actions != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: widget.actions!,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
