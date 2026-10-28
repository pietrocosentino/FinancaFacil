import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../transactions/domain/finance_models.dart';
import 'xlsx_columns.dart';

/// Gera planilhas com o mesmo esquema aceito pelo importador, sem fórmulas.
class XlsxExportWriter {
  static const mimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  Uint8List write(
    List<FinanceEntry> entries, {
  }) {
    final sorted = [...entries]
      ..sort(
        (a, b) =>
            (a.dueDate ?? DateTime(0)).compareTo(b.dueDate ?? DateTime(0)),
      );
    final rows = <String>[
      _row(1, [for (final header in XlsxColumns.fields.keys) _text(header, style: 1)]),
    ];
    var line = 2;
    for (final entry in sorted) {
      final dueDate = entry.dueDate;
      rows.add(
        _row(line++, [
          _text(entry.description),
          _text(entry.kind.label),
          _money(entry.amount),
          dueDate == null ? _text('') : _date(dueDate),
          _text('Não'),
          _text(''),
          _text(entry.categoryName),
          _text(entry.notes),
          dueDate == null ? _text('') : _number(dueDate.day),
        ]),
      );
    }

    final sheet =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<cols><col min="1" max="1" width="36" customWidth="1"/>'
        '<col min="2" max="2" width="16" customWidth="1"/>'
        '<col min="3" max="3" width="16" customWidth="1"/>'
        '<col min="4" max="4" width="20" customWidth="1"/>'
        '<col min="5" max="6" width="20" customWidth="1"/>'
        '<col min="7" max="7" width="24" customWidth="1"/>'
        '<col min="8" max="8" width="40" customWidth="1"/>'
        '<col min="9" max="9" width="18" customWidth="1"/></cols>'
        '<sheetData>${rows.join()}</sheetData></worksheet>';

    final archive = Archive();
    void add(String path, String content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    add('[Content_Types].xml', _contentTypes);
    add('_rels/.rels', _rootRels);
    add('xl/workbook.xml', _workbook);
    add('xl/_rels/workbook.xml.rels', _workbookRels);
    add('xl/styles.xml', _styles);
    add('xl/worksheets/sheet1.xml', sheet);
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  /// Nome sugerido: financafacil_2026-01_a_2026-12.xlsx
  static String fileName(DateTime from, DateTime to) {
    String key(DateTime date) =>
        '${date.year}-${date.month.toString().padLeft(2, '0')}';
    return 'financafacil_${key(from)}_a_${key(to)}.xlsx';
  }

  static String _column(int index) => String.fromCharCode(65 + index);

  String _row(int number, List<String Function(String ref)> cells) =>
      '<row r="$number">'
      '${[for (var i = 0; i < cells.length; i++) cells[i]('${_column(i)}$number')].join()}'
      '</row>';

  String Function(String) _text(String value, {int style = 0}) =>
      (ref) =>
          '<c r="$ref" t="inlineStr"${style == 0 ? '' : ' s="$style"'}>'
          '<is><t xml:space="preserve">${_escape(value)}</t></is></c>';

  String Function(String) _date(DateTime date) {
    final serial = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime.utc(1899, 12, 30)).inDays;
    return (ref) => '<c r="$ref" s="2"><v>$serial</v></c>';
  }

  String Function(String) _money(double value, {bool bold = false}) =>
      (ref) =>
          '<c r="$ref" s="${bold ? 4 : 3}"><v>${value.toStringAsFixed(2)}</v></c>';

  String Function(String) _number(int value) =>
      (ref) => '<c r="$ref"><v>$value</v></c>';

  static String _escape(String value) => value
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  static const _contentTypes =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
      '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
      '</Types>';

  static const _rootRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
      '</Relationships>';

  static const _workbook =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<sheets><sheet name="Lançamentos" sheetId="1" r:id="rId1"/></sheets></workbook>';

  static const _workbookRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
      '</Relationships>';

  // Estilos: 0 padrão, 1 negrito, 2 data, 3 moeda, 4 moeda em negrito.
  static const _styles =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<numFmts count="2"><numFmt numFmtId="164" formatCode="dd/mm/yyyy"/>'
      '<numFmt numFmtId="165" formatCode="&quot;R\$&quot; #,##0.00;[Red]-&quot;R\$&quot; #,##0.00"/></numFmts>'
      '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font>'
      '<font><b/><sz val="11"/><name val="Calibri"/></font></fonts>'
      '<fills count="2"><fill><patternFill patternType="none"/></fill>'
      '<fill><patternFill patternType="gray125"/></fill></fills>'
      '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="5">'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
      '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
      '<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
      '<xf numFmtId="165" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
      '<xf numFmtId="165" fontId="1" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyFont="1"/>'
      '</cellXfs></styleSheet>';
}
