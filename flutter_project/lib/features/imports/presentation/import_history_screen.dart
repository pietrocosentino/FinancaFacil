import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';
import '../data/import_repository.dart';
import '../domain/import_models.dart';
import 'import_error_message.dart';

class ImportHistoryScreen extends StatefulWidget {
  const ImportHistoryScreen({super.key, required this.repository});
  final ImportRepository repository;
  @override
  State<ImportHistoryScreen> createState() => _ImportHistoryScreenState();
}

class _ImportHistoryScreenState extends State<ImportHistoryScreen> {
  late Future<List<ImportBatch>> _future;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _future = widget.repository.history();
  }

  void _reload() => setState(() => _future = widget.repository.history());

  Future<void> _undo(ImportBatch batch) async {
    final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Desfazer importação?'),
                content: const Text(
                    'O lote será removido somente se nenhum registro foi alterado e nenhuma recorrência possui confirmações. Se houver mudanças, o lote inteiro será preservado.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Desfazer lote'))
                ]));
    if (accepted != true || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      final count = await widget.repository.undo(batch.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$count registros removidos.')));
        _reload();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(importFailure(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_busy,
      child: Scaffold(
          appBar: AppBar(title: const Text('Importações')),
          body: FutureBuilder<List<ImportBatch>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(importFailure(snapshot.error!)),
                            TextButton(
                                onPressed: _reload,
                                child: const Text('Tentar novamente'))
                          ])));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final batches = snapshot.data!;
                if (batches.isEmpty) {
                  return const Center(
                      child: Text('Você ainda não importou planilhas.'));
                }
                return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: batches.length,
                    itemBuilder: (context, index) {
                      final batch = batches[index];
                      return Card(
                          child: ListTile(
                              title: Text(batch.name),
                              subtitle: Text(
                                  '${batch.count} registros • ${AppFormatters.date.format(batch.createdAt.toLocal())}\n'
                                  '${batch.active ? 'Importado' : 'Desfeito'}'),
                              trailing: batch.active
                                  ? IconButton(
                                      tooltip: 'Desfazer lote',
                                      onPressed:
                                          _busy ? null : () => _undo(batch),
                                      icon: const Icon(Icons.undo))
                                  : null));
                    });
              })));
}
