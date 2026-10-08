import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

Uint8List workbook(String rows,
    {bool date1904 = false, String shared = '', bool prefixed = false}) {
  final archive = Archive();
  void xml(String path, String content) {
    if (prefixed) {
      content = content.replaceAllMapped(RegExp(r'<(/?)([A-Za-z][A-Za-z0-9]*)'),
          (match) => '<${match.group(1)}x:${match.group(2)}');
      content = content.replaceFirst('>',
          ' xmlns:x="http://schemas.openxmlformats.org/spreadsheetml/2006/main">');
    }
    final data = utf8.encode(content);
    archive.addFile(ArchiveFile(path, data.length, data));
  }

  xml('xl/workbook.xml',
      '<workbook xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><workbookPr date1904="${date1904 ? 1 : 0}"/><sheets><sheet name="Lançamentos" r:id="r1"/></sheets></workbook>');
  xml('xl/_rels/workbook.xml.rels',
      '<Relationships><Relationship Id="r1" Target="worksheets/sheet1.xml"/></Relationships>');
  xml('xl/worksheets/sheet1.xml',
      '<worksheet><sheetData>$rows</sheetData></worksheet>');
  if (shared.isNotEmpty) xml('xl/sharedStrings.xml', shared);
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

String inline(String address, String value) =>
    '<c r="$address" t="inlineStr"><is><t>$value</t></is></c>';
String get header => '<row r="1">${[
      'Descrição',
      'Tipo',
      'Valor mensal',
      'Primeiro vencimento',
      'Recorrente',
      'Quantidade de meses',
      'Categoria',
      'Observações',
      'Dia de vencimento'
    ].asMap().entries.map((entry) => inline('${String.fromCharCode(65 + entry.key)}1', entry.value)).join()}</row>';
String validRow(int line,
        {String amount = '<v>90.6</v>', String date = '08/11/2026'}) =>
    '<row r="$line">${inline('A$line', 'Ótica')}${inline('B$line', 'Despesa')}<c r="C$line">$amount</c>${inline('D$line', date)}${inline('E$line', 'Sim')}<c r="F$line"><v>10</v></c>${inline('G$line', 'Saúde')}</row>';
