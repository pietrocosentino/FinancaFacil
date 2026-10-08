import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'xlsx_import_reader.dart';

class ImportFile {
  const ImportFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

abstract class ImportFileGateway {
  Future<ImportFile?> pick();
  Future<bool> saveTemplate();
}

class NativeImportFileGateway implements ImportFileGateway {
  @override
  Future<ImportFile?> pick() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        allowMultiple: false,
        withData: false);
    if (result == null) return null;
    final selected = result.files.single;
    if (selected.size > XlsxImportReader.maxBytes ||
        !selected.name.toLowerCase().endsWith('.xlsx')) {
      throw const FormatException('Escolha um Excel .xlsx de até 5 MB.');
    }
    final bytes = selected.bytes ??
        (selected.path == null
            ? null
            : await File(selected.path!).readAsBytes());
    if (bytes == null) {
      throw const FormatException(
          'Não foi possível abrir o arquivo escolhido.');
    }
    return ImportFile(selected.name, bytes);
  }

  @override
  Future<bool> saveTemplate() async {
    final asset =
        await rootBundle.load('assets/import/modelo_financafacil.xlsx');
    final bytes =
        asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes);
    final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Salvar modelo FinançaFácil',
        fileName: 'modelo_financafacil.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: bytes);
    if (path == null) return false;
    // No mobile o plugin grava pelo seletor nativo; no desktop grava-se o caminho.
    if (!Platform.isAndroid && !Platform.isIOS) {
      await File(path).writeAsBytes(bytes, flush: true);
    }
    return true;
  }
}
