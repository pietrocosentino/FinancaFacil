import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Limites de navegação da interface, compartilhados pelo formulário e pela lista.
class MonthRange {
  static const firstYear = 2020;
  static const lastYear = 2100;

  static bool contains(DateTime month) =>
      month.year >= firstYear && month.year <= lastYear;
}

Future<DateTime?> showMonthPicker({
  required BuildContext context,
  required DateTime initialMonth,
}) => showDialog<DateTime>(
  context: context,
  builder: (_) => _MonthPicker(initialMonth: initialMonth),
);

class _MonthPicker extends StatefulWidget {
  const _MonthPicker({required this.initialMonth});
  final DateTime initialMonth;

  @override
  State<_MonthPicker> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<_MonthPicker> {
  late int _year = widget.initialMonth.year.clamp(
    MonthRange.firstYear,
    MonthRange.lastYear,
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Escolha o mês'),
    scrollable: true,
    content: SizedBox(
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Ano anterior',
                onPressed: _year > MonthRange.firstYear
                    ? () => setState(() => _year--)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '$_year',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Próximo ano',
                onPressed: _year < MonthRange.lastYear
                    ? () => setState(() => _year++)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var month = 1; month <= 12; month++)
                ChoiceChip(
                  label: Text(
                    DateFormat.MMM('pt_BR').format(DateTime(_year, month)),
                  ),
                  selected:
                      _year == widget.initialMonth.year &&
                      month == widget.initialMonth.month,
                  onSelected: (_) =>
                      Navigator.pop(context, DateTime(_year, month)),
                ),
            ],
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
    ],
  );
}
