import 'dart:typed_data';

import 'package:financafacil/features/imports/data/xlsx_columns.dart';
import 'package:financafacil/features/imports/data/xlsx_import_reader.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/import_workbook_fixture.dart';

void main() {
  final reader = XlsxImportReader();
  test('normaliza nomes de colunas comuns', () {
    expect(XlsxColumns.fieldForHeader('Lançamento'), 'description');
    expect(XlsxColumns.fieldForHeader('Valor total'), 'amount');
    expect(XlsxColumns.fieldForHeader('Data de vencimento'), 'due_date');
    expect(XlsxColumns.fieldForHeader('Forma de pagamento'), 'payment_method');
    expect(XlsxColumns.fieldForHeader('O que são?'), 'category');
    expect(XlsxColumns.fieldForHeader(r'Valor (R$)'), 'amount');
  });
  test('aceita prefixos XML no workbook, células e textos', () {
    final rows = reader.read(workbook('$header${validRow(2)}', prefixed: true));
    expect(rows.single.amount, 90.6);
    expect(rows.single.text('description'), 'Ótica');
  });
  test('interpreta data ISO tipada como data no Excel', () {
    final row = validRow(2).replaceFirst(
      inline('D2', '08/11/2026'),
      '<c r="D2" t="d"><v>2026-11-08T00:00:00</v></c>',
    );
    expect(
      reader.read(workbook('$header$row')).single.due,
      DateTime(2026, 11, 8),
    );
  });
  test('lê texto inline e valor numérico sem multiplicar parcelas', () {
    final rows = reader.read(workbook(header + validRow(2)));
    expect(rows.single.amount, 90.60);
    expect(rows.single.months, 10);
    expect(rows.single.line, 2);
  });
  test('mapeia cabeçalhos financeiros comuns e preserva forma de pagamento', () {
    final customHeader =
        '<row r="1">${['Lançamento', 'Tipo', 'Valor total', 'Data de vencimento', 'O que são?', 'Forma de pagamento', 'Banco'].asMap().entries.map((entry) {
          final column = String.fromCharCode(65 + entry.key);
          return inline('${column}1', entry.value);
        }).join()}</row>';
    final row =
        '<row r="2">${inline('A2', 'Aluguel')}${inline('B2', 'Conta')}'
        '<c r="C2"><v>1250.50</v></c>${inline('D2', '5-11-2026')}'
        '${inline('E2', 'Moradia')}${inline('F2', 'Pix')}'
        '${inline('G2', 'Banco Central')}</row>';
    final parsed = reader
        .read(workbook('$customHeader$row', sheetName: 'Despesas'))
        .single;

    expect(parsed.text('description'), 'Aluguel');
    expect(parsed.kind?.databaseValue, 'despesa');
    expect(parsed.amount, 1250.5);
    expect(parsed.due, DateTime(2026, 11, 5));
    expect(parsed.recurring, false);
    expect(parsed.text('category'), 'Moradia');
    expect(parsed.text('notes'), contains('Forma de pagamento: Pix'));
    expect(parsed.text('notes'), contains('Banco: Banco Central'));
  });
  test('procura cabeçalho após título e trata valor negativo como despesa', () {
    final rows =
        '<row r="1">${inline('A1', 'Contas da casa')}</row>'
        '<row r="2">${inline('A2', 'Descrição')}${inline('B2', 'Valor')}'
        '${inline('C2', 'Vencimento')}${inline('D2', 'Categoria')}</row>'
        '<row r="3">${inline('A3', 'Internet')}<c r="B3"><v>-99.9</v></c>'
        '${inline('C3', '10/11/2026')}${inline('D3', 'Serviços')}</row>';
    final parsed = reader.read(workbook(rows)).single;

    expect(parsed.kind?.databaseValue, 'despesa');
    expect(parsed.amount, 99.9);
    expect(parsed.recurring, false);
  });
  test('interpreta valor em reais e recorrência indicada no tipo', () {
    final rows =
        '<row r="1">${inline('A1', 'Descrição')}${inline('B1', 'Tipo')}'
        '${inline('C1', 'Valor')}${inline('D1', 'Vencimento')}'
        '${inline('E1', 'Categoria')}</row>'
        '<row r="2">${inline('A2', 'Aluguel')}${inline('B2', 'Conta fixa')}'
        '${inline('C2', r'R$ -1.234,56')}${inline('D2', '05/11/2026')}'
        '${inline('E2', 'Moradia')}</row>';
    final parsed = reader.read(workbook(rows)).single;

    expect(parsed.kind?.databaseValue, 'despesa');
    expect(parsed.amount, 1234.56);
    expect(parsed.recurring, true);
  });
  test('lê sharedStrings inclusive texto rico', () {
    final row = validRow(2)
        .replaceFirst(inline('A2', 'Ótica'), '<c r="A2" t="s"><v>0</v></c>');
    final rows = reader.read(
      workbook(
        header + row,
        shared: '<sst><si><r><t>Ó</t></r><r><t>tica</t></r></si></sst>',
      ),
    );
    expect(rows.single.text('description'), 'Ótica');
  });
  test('interpreta data numérica Excel e época 1904', () {
    final row = validRow(2)
        .replaceFirst(inline('D2', '08/11/2026'), '<c r="D2"><v>46334</v></c>');
    expect(reader.read(workbook(header + row)).single.due!.year, 2026);
    expect(
      reader.read(workbook(header + row, date1904: true)).single.due!.year,
      2030,
    );
  });
  test('fórmula com resultado em cache nunca vira valor autorizado', () {
    final row = validRow(2, amount: '<f>SUM(90,0.6)</f><v>90.6</v>');
    final parsed = reader.read(workbook(header + row)).single;
    expect(parsed.sourceError, isNotNull);
    expect(parsed.selected, isFalse);
  });
  test('linha vazia é ignorada e linha sem valor continua na prévia', () {
    final rows = reader.read(
      workbook('$header<row r="2"/>${validRow(3, amount: '')}'),
    );
    expect(rows.single.line, 3);
    expect(rows.single.amount, isNull);
  });
  test('recusa cabeçalhos sem valor ou vencimento e títulos repetidos', () {
    expect(
      () => reader.read(
        workbook(header.replaceFirst('Valor mensal', 'Outro') + validRow(2)),
      ),
      throwsFormatException,
    );
    expect(
      () => reader.read(
        workbook(header.replaceFirst('Observações', 'Descrição') + validRow(2)),
      ),
      throwsFormatException,
    );
  });
  test('recusa arquivo corrompido, vazio e acima de 5 MB', () {
    expect(
      () => reader.read(Uint8List.fromList([1, 2, 3])),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('Selecione o Google Sheets pelo Drive'),
        ),
      ),
    );
    expect(() => reader.read(Uint8List(0)), throwsFormatException);
    expect(
      () => reader.read(Uint8List(XlsxImportReader.maxBytes + 1)),
      throwsFormatException,
    );
  });
  test('recusa mais de 500 linhas', () {
    final rows = [header, for (var i = 2; i <= 502; i++) validRow(i)].join();
    expect(() => reader.read(workbook(rows)), throwsFormatException);
  });
}
