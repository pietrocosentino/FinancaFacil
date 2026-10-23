import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../domain/import_models.dart';

/// Leitor limitado ao modelo de importação. Nunca executa fórmulas ou macros.
class XlsxImportReader {
  static const maxBytes = 5 * 1024 * 1024;
  static const maxRows = 500;
  static const _maxExpandedBytes = 20 * 1024 * 1024;
  static const headers = {
    'descricao': 'description',
    'tipo': 'type',
    'valor mensal': 'amount',
    'primeiro vencimento': 'due_date',
    'recorrente': 'recurring',
    'quantidade de meses': 'months',
    'categoria': 'category',
    'observacoes': 'notes',
    'dia de vencimento': 'due_day',
  };

  List<ImportLine> read(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException('Escolha um Excel .xlsx de até 5 MB.');
    }
    try {
      _checkZipDirectory(bytes);
      final archive = ZipDecoder().decodeBytes(bytes);
      final files = {for (final file in archive) file.name: file};
      XmlDocument xml(String path) {
        final file = files[path];
        if (file == null || !file.isFile) {
          throw const FormatException('Arquivo Excel incompleto.');
        }
        final content = utf8.decode(file.content as List<int>);
        if (content.contains('<!DOCTYPE') || content.contains('<!ENTITY')) {
          throw const FormatException('Estrutura XML não permitida.');
        }
        return XmlDocument.parse(content);
      }

      final workbook = xml('xl/workbook.xml');
      final sheets = workbook
          .named('sheet')
          .where(
            (sheet) =>
                normalizeImportText(sheet.getAttribute('name') ?? '') ==
                'lancamentos',
          );
      if (sheets.length != 1) {
        throw const FormatException('Use o modelo com a aba Lançamentos.');
      }
      final relationship = sheets.single.getAttribute(
        'id',
        namespace: 'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
      );
      final links = xml('xl/_rels/workbook.xml.rels').named('Relationship');
      final matches = links.where(
        (link) => link.getAttribute('Id') == relationship,
      );
      if (matches.length != 1 ||
          matches.single.getAttribute('TargetMode') == 'External') {
        throw const FormatException('Aba de lançamentos inválida.');
      }
      final target = matches.single.getAttribute('Target') ?? '';
      if (target.contains('..') || target.contains('\\')) {
        throw const FormatException('Caminho da aba inválido.');
      }
      final path = target.startsWith('/') ? target.substring(1) : 'xl/$target';
      final shared = files.containsKey('xl/sharedStrings.xml')
          ? xml('xl/sharedStrings.xml')
                .named('si')
                .map((si) => si.named('t').map((t) => t.innerText).join())
                .toList()
          : <String>[];
      final date1904 = workbook
          .named('workbookPr')
          .any((p) => ['1', 'true'].contains(p.getAttribute('date1904')));
      final rows = xml(path).named('row').toList();
      final mapping = <int, String>{};
      final result = <ImportLine>[];
      var foundHeader = false;
      var previousLine = 0;
      for (final row in rows) {
        final line =
            int.tryParse(row.getAttribute('r') ?? '') ?? previousLine + 1;
        if (line <= previousLine || line > 10000) {
          throw const FormatException('Numeração de linhas inválida.');
        }
        previousLine = line;
        final cells = <int, Object?>{};
        var hasFormula = false;
        for (final cell in row.childrenNamed('c')) {
          final reference = cell.getAttribute('r') ?? '';
          final address = RegExp(r'^([A-Z]+)(\d+)$').firstMatch(reference);
          if (address == null || int.parse(address.group(2)!) != line) {
            throw const FormatException('Endereço de célula inválido.');
          }
          var column = 0;
          for (final unit in address.group(1)!.codeUnits) {
            column = column * 26 + unit - 64;
          }
          if (column > 100 || cells.containsKey(column)) {
            throw const FormatException(
              'Use uma planilha com até 100 colunas.',
            );
          }
          final formula = cell.childrenNamed('f').isNotEmpty;
          if (formula) hasFormula = true;
          final value = cell.firstChildNamed('v')?.innerText ?? '';
          Object? decoded;
          switch (cell.getAttribute('t')) {
            case 's':
              final index = int.tryParse(value);
              if (index == null || index < 0 || index >= shared.length) {
                throw const FormatException('Texto do Excel inválido.');
              }
              decoded = shared[index];
              break;
            case 'inlineStr':
              decoded = cell.named('t').map((t) => t.innerText).join();
              break;
            case 'e':
              hasFormula = true;
              decoded = value;
              break;
            case 'str':
              decoded = value;
              break;
            case 'd':
              decoded = parseImportDate(value.split('T').first) ?? value;
              break;
            default:
              decoded = num.tryParse(value) ?? value;
          }
          if (decoded.toString().length > 2000) {
            throw FormatException('Texto muito longo na linha $line.');
          }
          cells[column] = decoded;
        }
        if (cells.values.every(
              (v) => v == null || v.toString().trim().isEmpty,
            ) &&
            !hasFormula) {
          continue;
        }
        if (!foundHeader) {
          if (hasFormula) {
            throw const FormatException(
              'Cabeçalhos não podem conter fórmulas.',
            );
          }
          for (final entry in cells.entries) {
            final field =
                headers[normalizeImportText(entry.value?.toString() ?? '')];
            if (field == null) continue;
            if (mapping.containsValue(field)) {
              throw const FormatException('Cabeçalhos repetidos.');
            }
            mapping[entry.key] = field;
          }
          if (!headers.values.take(7).every(mapping.containsValue)) {
            throw const FormatException(
              'Cabeçalhos diferentes do modelo. Baixe o modelo de importação.',
            );
          }
          foundHeader = true;
          continue;
        }
        final values = {
          for (final entry in mapping.entries) entry.value: cells[entry.key],
        };
        final serial = values['due_date'];
        if (serial is num &&
            serial.isFinite &&
            serial >= 1 &&
            serial <= 73416 &&
            (date1904 || serial.floor() != 60)) {
          values['due_date'] = DateTime.utc(
            date1904 ? 1904 : 1899,
            date1904 ? 1 : 12,
            date1904 ? 1 : 30,
          ).add(Duration(days: serial.floor()));
        }
        final parsed = ImportLine(line, values);
        if (hasFormula) {
          parsed.sourceError = 'Fórmula ou erro de Excel: substitua por valores na planilha e selecione o arquivo novamente.';
          parsed.selected = false;
        }
        result.add(parsed);
        if (result.length > maxRows) {
          throw const FormatException(
            'Importe até 500 lançamentos por arquivo.',
          );
        }
      }
      if (result.isEmpty) {
        throw const FormatException('A aba Lançamentos está vazia.');
      }
      return result;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'Não foi possível ler este Excel. Use um arquivo .xlsx sem senha.',
      );
    }
  }

  /// Limita o tamanho descompactado antes de o decoder acessar qualquer conteúdo.
  void _checkZipDirectory(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    int? end;
    for (var i = bytes.length - 22; i >= 0 && i >= bytes.length - 65557; i--) {
      if (data.getUint32(i, Endian.little) == 0x06054b50 &&
          i + 22 + data.getUint16(i + 20, Endian.little) == bytes.length) {
        end = i;
        break;
      }
    }
    if (end == null ||
        data.getUint16(end + 4, Endian.little) != 0 ||
        data.getUint16(end + 6, Endian.little) != 0) {
      throw const FormatException('Excel inválido ou protegido.');
    }
    final count = data.getUint16(end + 10, Endian.little);
    var position = data.getUint32(end + 16, Endian.little);
    var total = 0;
    if (count > 200 || count == 0) {
      throw const FormatException('Arquivo Excel muito complexo.');
    }
    for (var i = 0; i < count; i++) {
      if (position + 46 > end ||
          data.getUint32(position, Endian.little) != 0x02014b50) {
        throw const FormatException('Arquivo Excel inválido.');
      }
      final size = data.getUint32(position + 24, Endian.little);
      total += size;
      if (total > _maxExpandedBytes ||
          (data.getUint16(position + 8, Endian.little) & 1) != 0) {
        throw const FormatException(
          'Excel muito grande ou protegido por senha.',
        );
      }
      position +=
          46 +
          data.getUint16(position + 28, Endian.little) +
          data.getUint16(position + 30, Endian.little) +
          data.getUint16(position + 32, Endian.little);
    }
  }
}

// O Excel e outros editores podem usar prefixos XML diferentes (x:, r:).
extension _XlsxElements on XmlNode {
  Iterable<XmlElement> named(String name) =>
      descendants.whereType<XmlElement>().where((e) => e.name.local == name);
  Iterable<XmlElement> childrenNamed(String name) =>
      children.whereType<XmlElement>().where((e) => e.name.local == name);
  XmlElement? firstChildNamed(String name) {
    final matches = childrenNamed(name);
    return matches.isEmpty ? null : matches.first;
  }
}
