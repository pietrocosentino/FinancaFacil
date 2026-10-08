import 'dart:io';
import 'dart:typed_data';

import 'package:financafacil/features/imports/data/xlsx_import_reader.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/import_workbook_fixture.dart';

void main() {
  final reader = XlsxImportReader();
  test('aceita prefixos XML no workbook, células e textos', () {
    final rows = reader.read(workbook('$header${validRow(2)}', prefixed: true));
    expect(rows.single.amount, 90.6);
    expect(rows.single.text('description'), 'Ótica');
  });
  test('interpreta data ISO tipada como data no Excel', () {
    final row = validRow(2).replaceFirst(inline('D2', '08/11/2026'),
        '<c r="D2" t="d"><v>2026-11-08T00:00:00</v></c>');
    expect(
        reader.read(workbook('$header$row')).single.due, DateTime(2026, 11, 8));
  });
  test('lê texto inline e valor numérico sem multiplicar parcelas', () {
    final rows = reader.read(workbook(header + validRow(2)));
    expect(rows.single.amount, 90.60);
    expect(rows.single.months, 10);
    expect(rows.single.line, 2);
  });
  test('lê sharedStrings inclusive texto rico', () {
    final row = validRow(2)
        .replaceFirst(inline('A2', 'Ótica'), '<c r="A2" t="s"><v>0</v></c>');
    final rows = reader.read(workbook(header + row,
        shared: '<sst><si><r><t>Ó</t></r><r><t>tica</t></r></si></sst>'));
    expect(rows.single.text('description'), 'Ótica');
  });
  test('interpreta data numérica Excel e época 1904', () {
    final row = validRow(2)
        .replaceFirst(inline('D2', '08/11/2026'), '<c r="D2"><v>46334</v></c>');
    expect(reader.read(workbook(header + row)).single.due!.year, 2026);
    expect(reader.read(workbook(header + row, date1904: true)).single.due!.year,
        2030);
  });
  test('fórmula com resultado em cache nunca vira valor autorizado', () {
    final row = validRow(2, amount: '<f>SUM(90,0.6)</f><v>90.6</v>');
    final parsed = reader.read(workbook(header + row)).single;
    expect(parsed.sourceError, isNotNull);
    expect(parsed.selected, isFalse);
  });
  test('linha vazia é ignorada e linha sem valor continua na prévia', () {
    final rows = reader
        .read(workbook('$header<row r="2"/>${validRow(3, amount: '')}'));
    expect(rows.single.line, 3);
    expect(rows.single.amount, isNull);
  });
  test('recusa cabeçalhos incompletos e repetidos', () {
    expect(
        () => reader.read(
            workbook(header.replaceFirst('Categoria', 'Outro') + validRow(2))),
        throwsFormatException);
    expect(
        () => reader.read(workbook(
            header.replaceFirst('Observações', 'Descrição') + validRow(2))),
        throwsFormatException);
  });
  test('recusa arquivo corrompido, vazio e acima de 5 MB', () {
    expect(() => reader.read(Uint8List.fromList([1, 2, 3])),
        throwsFormatException);
    expect(() => reader.read(Uint8List(0)), throwsFormatException);
    expect(() => reader.read(Uint8List(XlsxImportReader.maxBytes + 1)),
        throwsFormatException);
  });
  test('recusa mais de 500 linhas', () {
    final rows = [header, for (var i = 2; i <= 502; i++) validRow(i)].join();
    expect(() => reader.read(workbook(rows)), throwsFormatException);
  });
  test('modelo entregue não importa exemplos da aba de instruções', () {
    final bytes =
        File('assets/import/modelo_financafacil.xlsx').readAsBytesSync();
    expect(
        () => reader.read(bytes),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('vazia'))));
  });
}
