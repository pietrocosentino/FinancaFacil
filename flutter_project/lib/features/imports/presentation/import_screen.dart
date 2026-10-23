import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/services/app_services.dart';
import '../../../core/utils/formatters.dart';
import '../../transactions/data/finance_repository.dart';
import '../../transactions/domain/finance_models.dart';
import '../data/import_file_gateway.dart';
import '../data/import_repository.dart';
import '../data/xlsx_import_reader.dart';
import '../domain/import_models.dart';
import 'import_error_message.dart';
import 'import_history_screen.dart';
import 'import_line_dialog.dart';

List<ImportLine> _readSheet(Uint8List bytes) => XlsxImportReader().read(bytes);

class ImportScreen extends StatefulWidget {
  const ImportScreen({
    super.key,
    this.finance,
    this.repository,
    this.files,
    this.reader,
  });
  final FinanceRepository? finance;
  final ImportRepository? repository;
  final ImportFileGateway? files;
  final Future<List<ImportLine>> Function(Uint8List)? reader;
  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  late final FinanceRepository _finance;
  late final ImportRepository _repository;
  late final ImportFileGateway _files;
  Map<TransactionKind, List<FinanceCategory>> _categories = {};
  List<ImportLine> _lines = [];
  String _name = '';
  String _hash = '';
  String? _error;
  bool _busy = false;
  bool _checked = false;
  TransactionKind? _filter;

  @override
  void initState() {
    super.initState();
    _finance = widget.finance ?? AppServices.finance;
    _repository = widget.repository ?? AppServices.imports;
    _files = widget.files ?? NativeImportFileGateway();
  }

  List<String> _errors(ImportLine line) =>
      line.errors(_categories[line.kind] ?? []);
  List<ImportLine> get _selected =>
      _lines.where((line) => line.selected).toList();
  bool get _canImport =>
      !_busy &&
      _checked &&
      _selected.isNotEmpty &&
      _selected.every((line) => _errors(line).isEmpty);

  Future<void> _choose() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await _files.pick();
      if (file == null) return;
      final lines =
          await (widget.reader?.call(file.bytes) ??
              compute(_readSheet, file.bytes));
      final categories = {
        for (final kind in TransactionKind.values)
          kind: await _finance.categories(kind),
      };
      if (!mounted) return;
      for (final line in lines) {
        line.matchCategory(categories[line.kind] ?? []);
        if (line.errors(categories[line.kind] ?? []).isNotEmpty) {
          line.selected = false;
        }
      }
      setState(() {
        _lines = lines;
        _categories = categories;
        _name = file.name;
        _hash = sha256.convert(file.bytes).toString();
        _checked = false;
      });
      await _checkSimilar();
    } catch (error) {
      if (mounted) setState(() => _error = importFailure(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkSimilar() async {
    final valid = _lines.where((line) => _errors(line).isEmpty).toList();
    final existing = await _repository.similarLines(
      valid.map((line) => line.payload).toList(),
    );
    if (!mounted) return;
    final seen = <String>{};
    setState(() {
      for (final line in _lines) {
        line.similar =
            _errors(line).isEmpty &&
            (existing.contains(line.line) || !seen.add(line.signature));
        if (line.similar) line.selected = false;
      }
      _checked = true;
    });
  }

  Future<void> _reviewAgain() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _checkSimilar();
    } catch (error) {
      if (mounted) setState(() => _error = importFailure(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(ImportLine line) async {
    if (_busy || line.sourceError != null) return;
    final corrected = await showDialog<ImportLine>(
      context: context,
      builder: (_) => ImportLineDialog(line: line, categories: _categories),
    );
    if (corrected == null || !mounted) return;
    setState(() {
      _lines[_lines.indexOf(line)] = corrected;
      _checked = false;
    });
    await _reviewAgain();
  }

  Future<void> _template() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (await _files.saveTemplate() && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Modelo salvo. Preencha a aba Lançamentos.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Não foi possível salvar o modelo. Escolha uma pasta acessível no aparelho.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!_canImport) return;
    final rows = _selected;
    final similar = rows.where((line) => line.similar).length;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar importação?'),
        scrollable: true,
        content: Text(
          '${rows.length} lançamentos serão cadastrados.\n'
          '${_lines.length - rows.length} linhas não serão importadas.\n\n'
          'Recorrências serão cadastradas uma única vez. Despesas exigem confirmação de pagamento; rendas recorrentes entram automaticamente no saldo na data mensal.'
          '${similar > 0 ? '\n\nVocê incluiu $similar possíveis duplicatas. Confirme somente se são lançamentos diferentes.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar à prévia'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Importar agora'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final receipt = await _repository.save(
        _name,
        _hash,
        rows.map((line) => line.payload).toList(),
        allowSimilar: similar > 0,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            receipt.alreadyImported
                ? 'Arquivo já importado'
                : 'Importação concluída',
          ),
          content: Text(
            receipt.alreadyImported
                ? 'Este arquivo já possui uma importação ativa. Nenhum registro foi duplicado. Consulte o histórico.'
                : '${receipt.count} lançamentos cadastrados. Consulte o mês do primeiro vencimento na aba Finanças.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
      if (mounted) {
        setState(() {
          _lines = [];
          _checked = false;
          _name = '';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = importFailure(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _summary() {
    String total(TransactionKind kind) => AppFormatters.currency.format(
      _selected
              .where((line) => line.kind == kind)
              .fold<int>(
                0,
                (sum, line) => sum + ((line.amount ?? 0) * 100).round(),
              ) /
          100,
    );
    final invalid = _lines.where((line) => _errors(line).isNotEmpty).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('${_selected.length} de ${_lines.length} linhas selecionadas'),
            Text('Receitas selecionadas: ${total(TransactionKind.income)}'),
            Text('Despesas selecionadas: ${total(TransactionKind.expense)}'),
            const Text(
              'Soma dos valores por linha. Recorrências contam uma vez; os vencimentos podem ser de meses diferentes.',
            ),
            if (invalid > 0)
              Text(
                '$invalid linhas precisam de correção e estão fora da importação.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_lines.any((line) => line.similar))
              const Text(
                'Possíveis duplicatas foram desmarcadas. Selecione somente se forem lançamentos diferentes.',
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(ImportLine line) {
    final errors = _errors(line);
    final category = (_categories[line.kind] ?? [])
        .where((category) => category.id == line.categoryId)
        .map((category) => category.name)
        .join();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              value: line.selected,
              onChanged: _busy || errors.isNotEmpty
                  ? null
                  : (value) => setState(() => line.selected = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                line.text('description').isEmpty
                    ? 'Linha ${line.line}'
                    : line.text('description'),
              ),
              subtitle: Text(
                'Linha ${line.line} • ${line.kind?.label ?? 'Tipo inválido'}\n'
                '${line.amount == null ? 'Valor inválido' : AppFormatters.currency.format(line.amount)} • ${line.text('due_date')}\n'
                '${line.recurring == true
                    ? line.months == null
                          ? 'Mensal, sem data final'
                          : '${line.months} meses'
                    : 'Avulso'}\n'
                'Categoria: ${category.isEmpty ? 'Escolha na correção' : category}',
              ),
            ),
            if (line.similar)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Possível duplicata'),
              ),
            for (final error in errors)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 2,
                ),
                child: Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (line.sourceError == null)
              TextButton.icon(
                onPressed: _busy ? null : () => _edit(line),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Corrigir dados ou categoria'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Importar planilha'),
        actions: [
          IconButton(
            tooltip: 'Histórico de importações',
            onPressed: _busy
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ImportHistoryScreen(repository: _repository),
                    ),
                  ),
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      bottomNavigationBar: _lines.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: _canImport ? _submit : null,
                  icon: const Icon(Icons.check),
                  label: Text(
                    _busy
                        ? 'Aguarde...'
                        : 'Importar ${_selected.length} lançamentos',
                  ),
                ),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Suas contas, sem digitar uma por uma',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Preencha o modelo e confira cada linha antes de cadastrar. Excel .xlsx, até 5 MB e 500 linhas.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _template,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Baixar modelo Excel'),
          ),
          FilledButton.icon(
            onPressed: _busy ? null : _choose,
            icon: const Icon(Icons.upload_file),
            label: Text(
              _lines.isEmpty ? 'Escolher planilha' : 'Escolher outra planilha',
            ),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_lines.isNotEmpty) ...[
            _summary(),
            if (!_checked && !_busy)
              OutlinedButton(
                onPressed: _reviewAgain,
                child: const Text('Verificar duplicatas novamente'),
              ),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Todas'),
                  selected: _filter == null,
                  onSelected: (_) => setState(() => _filter = null),
                ),
                for (final kind in TransactionKind.values)
                  ChoiceChip(
                    label: Text('${kind.label}s'),
                    selected: _filter == kind,
                    onSelected: (_) => setState(() => _filter = kind),
                  ),
              ],
            ),
            for (final line in _lines.where(
              (line) => _filter == null || line.kind == _filter,
            ))
              _row(line),
          ],
        ],
      ),
    ),
  );
}
