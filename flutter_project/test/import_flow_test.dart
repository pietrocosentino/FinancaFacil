import 'dart:typed_data';

import 'package:financafacil/core/files/cloud_files.dart';
import 'package:financafacil/features/imports/data/import_file_gateway.dart';
import 'package:financafacil/features/imports/data/import_repository.dart';
import 'package:financafacil/features/imports/data/xlsx_export_writer.dart';
import 'package:financafacil/features/imports/data/xlsx_import_reader.dart';
import 'package:financafacil/features/imports/domain/import_models.dart';
import 'package:financafacil/features/imports/presentation/import_screen.dart';
import 'package:financafacil/features/transactions/domain/finance_models.dart';
import 'package:financafacil/shared/widgets/file_location_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_repositories.dart';
import 'support/import_workbook_fixture.dart';

class _Finance extends FakeFinanceRepository {
  @override
  Future<List<FinanceCategory>> categories(TransactionKind kind) async => [
    FinanceCategory(
      id: kind.name,
      name: kind == TransactionKind.expense ? 'Saúde' : 'Salário',
    ),
  ];
}

class _Files implements ImportFileGateway {
  ImportFile? file = ImportFile('contas.xlsx', workbook(header + validRow(2)));
  int downloads = 0;
  @override
  Future<ImportFile?> pick(FileLocation from) async => file;
  @override
  Future<bool> saveTemplate(FileLocation to) async {
    downloads++;
    return true;
  }

  @override
  Future<bool> saveFile(String name, Uint8List bytes, FileLocation to) async =>
      true;
}

class _Imports implements ImportRepository {
  int saves = 0;
  bool fail = false;
  bool allowSimilar = false;
  List<Map<String, Object?>>? saved;
  String? hash;
  Set<int> duplicates = {};
  @override
  Future<Set<int>> similarLines(List<Map<String, Object?>> rows) async =>
      duplicates;
  @override
  Future<ImportReceipt> save(
    String name,
    String fileHash,
    List<Map<String, Object?>> rows, {
    required bool allowSimilar,
  }) async {
    saves++;
    this.allowSimilar = allowSimilar;
    saved = rows;
    hash = fileHash;
    if (fail) throw const FormatException('Falha simulada.');
    return ImportReceipt('batch', rows.length, false);
  }
}

void main() {
  late _Files files;
  late _Imports imports;
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ImportScreen(
          finance: _Finance(),
          files: files,
          repository: imports,
          reader: (bytes) async => XlsxImportReader().read(bytes),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester) async {
    await tester.tap(find.text('Do celular'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    files = _Files();
    imports = _Imports();
  });

  testWidgets('cancelar escolha do arquivo não grava nem mostra prévia', (
    tester,
  ) async {
    files.file = null;
    await open(tester);
    await choose(tester);
    expect(imports.saves, 0);
    expect(find.text('contas.xlsx'), findsNothing);
  });
  testWidgets('modelo e exportação ficam fora da tela de importação', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Baixar modelo Excel'), findsNothing);
    expect(find.text('Baixar meus lançamentos em Excel'), findsNothing);
    expect(
      find.textContaining('planilhas do Google Sheets selecionadas pelo Drive'),
      findsOneWidget,
    );
    expect(imports.saves, 0);
  });

  testWidgets('opções de salvar cabem em tela baixa sem overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showSaveLocationSheet(
                  context,
                  title: 'Onde salvar o modelo?',
                ),
                child: const Text('Salvar'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Onde salvar o modelo?'), findsOneWidget);
    expect(find.text('No celular'), findsOneWidget);
    expect(find.text('No Google Drive'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('planilha exportada pelo app ativa a importação', (tester) async {
    files.file = ImportFile(
      'financafacil.xlsx',
      XlsxExportWriter().write([
        FinanceEntry(
          id: 'one',
          kind: TransactionKind.expense,
          amount: 90.6,
          description: 'Ótica',
          dueDate: DateTime(2026, 11, 8),
          categoryName: 'Saúde',
          isPaid: false,
        ),
      ]),
    );
    await open(tester);
    await choose(tester);
    expect(find.text('Baixar meus lançamentos em Excel'), findsNothing);
    final import = find.text('Importar 1 lançamentos');
    expect(import, findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: import,
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      ),
    );
    expect(button.onPressed, isNotNull);
    expect(find.byTooltip('Histórico de importações'), findsNothing);
  });
  testWidgets('prévia permite voltar da confirmação sem gravar', (
    tester,
  ) async {
    await open(tester);
    await choose(tester);
    expect(find.text('contas.xlsx'), findsOneWidget);
    await tester.tap(find.text('Importar 1 lançamentos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voltar à prévia'));
    await tester.pumpAndSettle();
    expect(imports.saves, 0);
  });
  testWidgets('confirmação envia uma regra com valor mensal e hash estável', (
    tester,
  ) async {
    await open(tester);
    await choose(tester);
    await tester.tap(find.text('Importar 1 lançamentos'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'rendas recorrentes entram automaticamente no saldo na data mensal',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Importar agora'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(imports.saves, 1);
    expect(imports.saved!.single['amount'], 90.6);
    expect(imports.saved!.single['months'], 10);
    expect(imports.saved!.single['recurring'], true);
    expect(imports.hash, hasLength(64));
    expect(find.text('Importação concluída'), findsOneWidget);
  });
  testWidgets('duplicata começa desmarcada e exige seleção explícita', (
    tester,
  ) async {
    imports.duplicates = {2};
    await open(tester);
    await choose(tester);
    await tester.scrollUntilVisible(find.byType(CheckboxListTile), 200);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      false,
    );
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Importar 0 lançamentos'),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
    Scrollable.ensureVisible(
      tester.element(find.byType(CheckboxListTile)),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importar 1 lançamentos'));
    await tester.pumpAndSettle();
    expect(find.textContaining('possíveis duplicatas'), findsOneWidget);
    await tester.tap(find.text('Importar agora'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(imports.allowSimilar, true);
  });
  testWidgets('falha preserva prévia e permite tentar com o mesmo hash', (
    tester,
  ) async {
    imports.fail = true;
    await open(tester);
    await choose(tester);
    await tester.tap(find.text('Importar 1 lançamentos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importar agora'));
    await tester.pumpAndSettle();
    final hash = imports.hash;
    expect(find.text('Falha simulada.'), findsOneWidget);
    expect(find.text('contas.xlsx'), findsOneWidget);
    imports.fail = false;
    await tester.tap(find.text('Importar 1 lançamentos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importar agora'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(imports.saves, 2);
    expect(imports.hash, hash);
  });
  testWidgets('categoria desconhecida bloqueia a linha até ser corrigida', (
    tester,
  ) async {
    files.file = ImportFile(
      'contas.xlsx',
      workbook((header + validRow(2)).replaceFirst('Saúde', 'Outra')),
    );
    await open(tester);
    await choose(tester);
    await tester.scrollUntilVisible(
      find.text('Corrigir dados ou categoria'),
      200,
    );
    expect(find.textContaining('Escolha uma categoria'), findsOneWidget);
    await tester.ensureVisible(find.text('Corrigir dados ou categoria'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Corrigir dados ou categoria'));
    await tester.pumpAndSettle();
    final category = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(category);
    await tester.pumpAndSettle();
    await tester.tap(category);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saúde').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar correção'));
    await tester.pumpAndSettle();
    expect(find.text('Importar 1 lançamentos'), findsOneWidget);
    expect(imports.saves, 0);
  });
}
