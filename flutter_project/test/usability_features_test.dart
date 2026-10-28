import 'dart:typed_data';

import 'package:financafacil/core/files/cloud_files.dart';
import 'package:financafacil/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:financafacil/features/imports/data/import_file_gateway.dart';
import 'package:financafacil/features/imports/data/import_repository.dart';
import 'package:financafacil/features/imports/data/xlsx_import_reader.dart';
import 'package:financafacil/features/imports/domain/import_models.dart';
import 'package:financafacil/features/imports/presentation/import_screen.dart';
import 'package:financafacil/features/transactions/domain/finance_models.dart';
import 'package:financafacil/features/transactions/presentation/screens/add_choice_sheet.dart';
import 'package:financafacil/features/transactions/presentation/screens/add_transaction_screen.dart';
import 'package:financafacil/features/transactions/presentation/screens/transactions_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/fake_repositories.dart';
import 'support/import_workbook_fixture.dart';

DateTime _thisMonth(int day) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, day);
}

FinanceEntry _entry(
  String id, {
  TransactionKind kind = TransactionKind.expense,
  double amount = 100,
  DateTime? due,
  bool paid = false,
  bool recurring = false,
  String description = 'Conta',
}) => FinanceEntry(
  id: id,
  kind: kind,
  amount: amount,
  description: description,
  dueDate: due ?? _thisMonth(15),
  categoryName: 'Moradia',
  isPaid: paid,
  isRecurring: recurring,
);

class _Files implements ImportFileGateway {
  @override
  Future<ImportFile?> pick(FileLocation from) async =>
      ImportFile('contas.xlsx', workbook(header + validRow(2)));
  @override
  Future<bool> saveTemplate(FileLocation to) async => true;
  @override
  Future<bool> saveFile(String name, Uint8List bytes, FileLocation to) async =>
      true;
}

class _Imports implements ImportRepository {
  List<Map<String, Object?>>? saved;
  @override
  Future<Set<int>> similarLines(List<Map<String, Object?>> rows) async => {};
  @override
  Future<ImportReceipt> save(
    String name,
    String fileHash,
    List<Map<String, Object?>> rows, {
    required bool allowSimilar,
  }) async {
    saved = rows;
    return ImportReceipt('batch', rows.length, false);
  }

  @override
  Future<List<ImportBatch>> history() async => [];
  @override
  Future<int> undo(String batchId) async => 0;
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('Início', () {
    testWidgets('resume o mês, compara com o anterior e troca de mês', (
      tester,
    ) async {
      // Tela alta: o ListView só monta o que cabe, e a comparação com o mês
      // anterior fica abaixo do resumo e das fontes de renda.
      tester.view.physicalSize = Size(
        800 * tester.view.devicePixelRatio,
        2000 * tester.view.devicePixelRatio,
      );
      addTearDown(tester.view.reset);
      final now = DateTime.now();
      final previous = DateTime(now.year, now.month - 1, 10);
      final repository = FakeFinanceRepository()
        ..entries = [
          _entry(
            'salary',
            kind: TransactionKind.income,
            amount: 3000,
            paid: true,
            due: _thisMonth(5),
          ),
          _entry('rent', amount: 1500, paid: true, due: _thisMonth(1)),
          _entry('light', amount: 300, due: DateTime(now.year, now.month, 28)),
          _entry('old', amount: 1000, paid: true, due: previous),
        ];
      await tester.pumpWidget(
        MaterialApp(home: DashboardScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      // O formato de moeda usa espaço não separável depois de "R\$".
      expect(find.textContaining('1.200,00'), findsOneWidget);
      expect(
        find.textContaining(RegExp(r'1\.500,00 de R\$\s1\.800,00')),
        findsOneWidget,
      );
      expect(
        find.text('Despesas 80% maiores que no mês anterior.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Mês anterior'));
      await tester.pumpAndSettle();
      expect(find.text('O que precisa de atenção'), findsNothing);
      expect(find.textContaining('1.000,00'), findsWidgets);
      expect(
        find.text('Sem despesas no mês anterior para comparar.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('primeiro acesso mostra como começar', (tester) async {
      final added = <AddChoice>[];
      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            repository: FakeFinanceRepository(),
            onAdd: added.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Comece por aqui'), findsOneWidget);
      await tester.tap(find.text('Adicionar lançamento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Renda'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adicionar lançamento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Despesa ou conta'));
      await tester.pumpAndSettle();
      expect(added, [AddChoice.income, AddChoice.expense]);
    });
  });

  group('Extrato', () {
    Future<FakeFinanceRepository> open(
      WidgetTester tester,
      List<FinanceEntry> entries,
    ) async {
      final repository = FakeFinanceRepository()..entries = entries;
      await tester.pumpWidget(
        MaterialApp(home: TransactionsListScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      return repository;
    }

    Future<void> action(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.byType(PopupMenuButton<String>).first);
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    testWidgets('"Não recebi" deixa a renda pendente para confirmar depois', (
      tester,
    ) async {
      final repository = await open(tester, [
        _entry(
          'r:salary:${_thisMonth(1).toIso8601String().substring(0, 10)}',
          kind: TransactionKind.income,
          amount: 3000,
          paid: true,
          recurring: true,
          due: _thisMonth(1),
          description: 'Salário',
        ),
      ]);
      expect(find.text('Recebido · automático'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
      await action(tester, 'Não recebi');
      await tester.tap(find.text('Marcar como não recebida'));
      await tester.pumpAndSettle();
      expect(repository.notReceivedIds, hasLength(1));
      expect(find.text('Receita pendente'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
      await action(tester, 'Confirmar recebimento');
      await tester.tap(find.text('Tenho certeza, recebi'));
      await tester.pumpAndSettle();
      expect(repository.paidIds, {repository.notReceivedIds.single});
      expect(find.text('Recebido'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tocar no cartão abre as ações do lançamento', (tester) async {
      await open(tester, [_entry('a', description: 'Aluguel')]);
      await tester.tap(find.text('Aluguel'));
      await tester.pumpAndSettle();
      expect(find.text('Confirmar pagamento'), findsOneWidget);
      expect(find.text('Editar lançamento'), findsOneWidget);
      expect(find.text('Excluir lançamento'), findsOneWidget);
    });

    testWidgets('filtros em checklist combinam tipo e situação', (
      tester,
    ) async {
      await open(tester, [
        _entry('a', description: 'Aluguel'),
        _entry('b', kind: TransactionKind.income, description: 'Freela'),
        _entry(
          'c',
          kind: TransactionKind.income,
          paid: true,
          description: 'Salário recebido',
        ),
      ]);
      await tester.tap(find.text('Filtro'));
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsNWidgets(4));
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Pendentes'));
      await tester.ensureVisible(
        find.widgetWithText(CheckboxListTile, 'Receitas'),
      );
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Receitas'));
      await tester.ensureVisible(find.text('Aplicar'));
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      expect(find.text('Freela'), findsOneWidget);
      expect(find.text('Aluguel'), findsNothing);
      expect(find.text('Salário recebido'), findsNothing);
      await tester.tap(find.text('Filtro (2)'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Confirmadas'));
      await tester.ensureVisible(find.text('Aplicar'));
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      expect(find.text('Freela'), findsOneWidget);
      expect(find.text('Salário recebido'), findsOneWidget);
      expect(find.text('Aluguel'), findsNothing);
      await tester.tap(find.text('Filtro (3)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Limpar'));
      await tester.ensureVisible(find.text('Aplicar'));
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      expect(find.text('Freela'), findsOneWidget);
      expect(find.text('Salário recebido'), findsOneWidget);
      expect(find.text('Aluguel'), findsOneWidget);
    });

    testWidgets('voltar ao mês atual aparece só fora do mês atual', (
      tester,
    ) async {
      await open(tester, [_entry('a', description: 'Aluguel')]);
      expect(find.byTooltip('Voltar ao mês atual'), findsNothing);
      await tester.tap(find.byTooltip('Próximo mês'));
      await tester.pumpAndSettle();
      expect(find.text('Aluguel'), findsNothing);
      await tester.tap(find.byTooltip('Voltar ao mês atual'));
      await tester.pumpAndSettle();
      expect(find.text('Aluguel'), findsOneWidget);
      expect(find.byTooltip('Voltar ao mês atual'), findsNothing);
    });

    testWidgets('limpar seleção esconde a confirmação em lote', (tester) async {
      await open(tester, [_entry('a', description: 'Aluguel')]);
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(find.text('Confirmar selecionados (1)'), findsOneWidget);
      await tester.tap(find.text('Limpar'));
      await tester.pumpAndSettle();
      expect(find.text('Confirmar selecionados (1)'), findsNothing);
    });
  });

  group('Categorias', () {
    testWidgets('categoria digitada que não existe é criada ao salvar', (
      tester,
    ) async {
      final repository = FakeFinanceRepository();
      await tester.pumpWidget(
        MaterialApp(home: AddTransactionScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      final category = find.descendant(
        of: find.byType(DropdownMenu<String>),
        matching: find.byType(TextField),
      );
      await tester.ensureVisible(category);
      await tester.enterText(category, 'P');
      await tester.ensureVisible(find.text('Salvar conta'));
      await tester.tap(find.text('Salvar conta'));
      await tester.pumpAndSettle();
      expect(find.text('Use de 2 a 40 caracteres.'), findsOneWidget);
      expect(repository.saved, isNull);
      await tester.enterText(category, 'Pet');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor da conta'),
        '80',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome da conta'),
        'Ração',
      );
      await tester.ensureVisible(find.text('Salvar conta'));
      await tester.tap(find.text('Salvar conta'));
      await tester.pumpAndSettle();
      expect(repository.createdCategories.single.name, 'Pet');
      expect(repository.saved?.categoryId, 'new-Pet');
    });

    testWidgets('importação cria a categoria da planilha e libera a linha', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final finance = FakeFinanceRepository();
      final imports = _Imports();
      await tester.pumpWidget(
        MaterialApp(
          home: ImportScreen(
            finance: finance,
            repository: imports,
            files: _Files(),
            reader: (bytes) async => XlsxImportReader().read(bytes),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Do celular'));
      await tester.pumpAndSettle();
      expect(find.text('Importar 0 lançamentos'), findsOneWidget);
      // A lista é preguiçosa: rola até a linha ser construída.
      await tester.scrollUntilVisible(
        find.text('Criar categoria “Saúde”'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Criar categoria “Saúde”'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Criar'));
      await tester.pumpAndSettle();
      expect(finance.createdCategories.single.name, 'Saúde');
      expect(find.text('Criar categoria “Saúde”'), findsNothing);
      await tester.tap(find.text('Importar 1 lançamentos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Importar agora'));
      // O indicador de progresso segue animado atrás do aviso de conclusão.
      await tester.pump(const Duration(milliseconds: 400));
      expect(imports.saved!.single['category_id'], 'new-Saúde');
      expect(find.text('Importação concluída'), findsOneWidget);
    });
  });
}
