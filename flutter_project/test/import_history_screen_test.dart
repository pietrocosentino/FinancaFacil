import 'package:financafacil/features/imports/data/import_repository.dart';
import 'package:financafacil/features/imports/domain/import_models.dart';
import 'package:financafacil/features/imports/presentation/import_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _History implements ImportRepository {
  bool active = true;
  Object? undoError;
  Object? historyError;
  final undone = <String>[];
  int loads = 0;

  @override
  Future<List<ImportBatch>> history() async {
    loads++;
    if (historyError != null) throw historyError!;
    return [
      ImportBatch(
        id: 'batch-1',
        name: 'contas.xlsx',
        count: 3,
        createdAt: DateTime.utc(2026, 5, 10, 12),
        active: active,
      ),
    ];
  }

  @override
  Future<int> undo(String batchId) async {
    if (undoError != null) throw undoError!;
    undone.add(batchId);
    active = false;
    return 3;
  }

  @override
  Future<ImportReceipt> save(
    String name,
    String fileHash,
    List<Map<String, Object?>> rows, {
    required bool allowSimilar,
  }) => throw UnimplementedError();

  @override
  Future<Set<int>> similarLines(List<Map<String, Object?>> rows) =>
      throw UnimplementedError();
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  Future<void> show(WidgetTester tester, _History repository) async {
    await tester.pumpWidget(
      MaterialApp(home: ImportHistoryScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> undo(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Desfazer lote'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desfazer lote'));
    await tester.pumpAndSettle();
  }

  testWidgets('desfazer lote recarrega o histórico sem erro', (tester) async {
    final repository = _History();
    await show(tester, repository);
    expect(find.textContaining('Importado'), findsOneWidget);
    await undo(tester);
    expect(repository.undone, ['batch-1']);
    expect(repository.loads, 2);
    expect(find.text('3 registros removidos.'), findsOneWidget);
    expect(find.textContaining('Desfeito'), findsOneWidget);
    expect(find.byTooltip('Desfazer lote'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lote alterado é preservado e o motivo aparece', (tester) async {
    final repository = _History()
      ..undoError = const FormatException(
        'Lote preservado: um lançamento foi alterado.',
      );
    await show(tester, repository);
    await undo(tester);
    expect(repository.undone, isEmpty);
    expect(
      find.text('Lote preservado: um lançamento foi alterado.'),
      findsOneWidget,
    );
    expect(find.textContaining('Importado'), findsOneWidget);
  });

  testWidgets('falha ao consultar permite tentar novamente', (tester) async {
    final repository = _History()..historyError = StateError('sem rede');
    await show(tester, repository);
    expect(find.text('Tentar novamente'), findsOneWidget);
    repository.historyError = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('contas.xlsx'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
