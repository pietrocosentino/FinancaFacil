import 'package:flutter/material.dart';

import '../../../core/errors/app_log.dart';
import '../../../core/files/cloud_files.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/file_location_sheet.dart';
import '../../../shared/widgets/month_picker.dart';
import '../../transactions/data/finance_repository.dart';
import '../data/import_file_gateway.dart';
import '../data/xlsx_export_writer.dart';

/// Pergunta o período e o destino e grava os lançamentos em Excel.
Future<void> exportEntries(
  BuildContext context,
  FinanceRepository finance, {
  ImportFileGateway? files,
}) async {
  final period = await showDialog<(DateTime, DateTime)>(
    context: context,
    builder: (_) => const _ExportPeriodDialog(),
  );
  if (period == null || !context.mounted) return;
  final to = await showSaveLocationSheet(
    context,
    title: 'Onde salvar a planilha?',
  );
  if (to == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  void message(String text) =>
      messenger.showSnackBar(SnackBar(content: Text(text)));
  final (from, until) = period;
  try {
    final end = DateTime(until.year, until.month + 1);
    final entries =
        (await finance.transactions(DateTime(until.year, until.month)))
            .where((entry) {
              final due = entry.dueDate;
              return due != null && !due.isBefore(from) && due.isBefore(end);
            })
            .toList();
    if (entries.isEmpty) {
      message('Nenhum lançamento nesse período.');
      return;
    }
    final bytes = XlsxExportWriter().write(entries);
    final saved = await (files ?? NativeImportFileGateway()).saveFile(
      XlsxExportWriter.fileName(from, until),
      bytes,
      to,
    );
    if (saved) {
      message(
        to == FileLocation.drive
            ? 'Confirme o envio no Google Drive.'
            : 'Planilha salva com ${entries.length} lançamentos.',
      );
    }
  } catch (error, stack) {
    AppLog.error(error, stack, 'exportar lançamentos');
    message('Não foi possível gerar a planilha. Tente novamente.');
  }
}

class _ExportPeriodDialog extends StatefulWidget {
  const _ExportPeriodDialog();
  @override
  State<_ExportPeriodDialog> createState() => _ExportPeriodDialogState();
}

class _ExportPeriodDialogState extends State<_ExportPeriodDialog> {
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year);
    _to = DateTime(now.year, now.month);
  }

  bool get _valid => !_from.isAfter(_to);

  Future<void> _pick(bool start) async {
    final picked = await showMonthPicker(
      context: context,
      initialMonth: start ? _from : _to,
    );
    if (picked == null || !mounted) return;
    setState(() {
      final month = DateTime(picked.year, picked.month);
      if (start) {
        _from = month;
      } else {
        _to = month;
      }
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Baixar lançamentos'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Escolha o período. A planilha traz data, nome, tipo, categoria, valor e situação de cada lançamento.',
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => _pick(true),
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text('De: ${AppFormatters.monthYear.format(_from)}'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _pick(false),
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text('Até: ${AppFormatters.monthYear.format(_to)}'),
        ),
        if (!_valid)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'O mês inicial deve ser anterior ao final.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      ElevatedButton(
        onPressed: _valid ? () => Navigator.pop(context, (_from, _to)) : null,
        child: const Text('Continuar'),
      ),
    ],
  );
}
