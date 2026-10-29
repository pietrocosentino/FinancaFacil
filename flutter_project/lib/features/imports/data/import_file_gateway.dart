import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../../core/files/cloud_files.dart';
import '../../../core/files/selected_file_reader.dart';
import '../../../core/services/device_preferences.dart';
import 'xlsx_export_writer.dart';
import 'xlsx_import_reader.dart';

class ImportFile {
  const ImportFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

abstract class ImportFileGateway {
  /// Planilha escolhida no celular ou no Google Drive; `null` se cancelada.
  Future<ImportFile?> pick(FileLocation from);

  /// Grava o modelo em branco. `false` quando o usuário cancela.
  Future<bool> saveTemplate(FileLocation to);

  /// Grava um Excel gerado pelo app (exportação dos lançamentos).
  Future<bool> saveFile(String name, Uint8List bytes, FileLocation to);
}

/// No celular usa o seletor de documentos do sistema. Para o Drive, o seletor
/// padrão mantém o acesso ao provedor e permite converter planilhas Google em
/// Excel antes de entregar o arquivo ao leitor.
class NativeImportFileGateway implements ImportFileGateway {
  NativeImportFileGateway({CloudFiles? cloud})
    : _cloud = cloud ?? const CloudFiles();
  final CloudFiles _cloud;

  @override
  Future<ImportFile?> pick(FileLocation from) =>
      DevicePreferences.duringExternalFlow(() async {
        if (from == FileLocation.drive) {
          try {
            final file = await _cloud.pick(
              CloudApp.drive,
              mimeTypes: [
                XlsxExportWriter.mimeType,
                'application/vnd.google-apps.spreadsheet',
              ],
              maxBytes: XlsxImportReader.maxBytes,
            );
            if (file == null) return null;
            return ImportFile(_withExtension(file.name), file.bytes);
          } on CloudAppUnavailable {
            // Segue para o seletor do sistema.
          }
        }
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
          allowMultiple: false,
          withData: false,
          withReadStream: true,
        );
        if (result == null) return null;
        final selected = result.files.single;
        if (selected.size > XlsxImportReader.maxBytes ||
            !selected.name.toLowerCase().endsWith('.xlsx')) {
          throw const FormatException('Escolha um Excel .xlsx de até 5 MB.');
        }
        final bytes = await readSelectedFile(
          selected,
          XlsxImportReader.maxBytes,
        );
        return ImportFile(selected.name, bytes);
      });

  /// O Drive pode devolver o nome de uma planilha Google sem extensão.
  static String _withExtension(String name) =>
      name.toLowerCase().endsWith('.xlsx') ? name : '$name.xlsx';

  @override
  Future<bool> saveTemplate(FileLocation to) async {
    final bytes = XlsxExportWriter().write(const []);
    return saveFile('modelo_financafacil.xlsx', bytes, to);
  }

  @override
  Future<bool> saveFile(String name, Uint8List bytes, FileLocation to) =>
      DevicePreferences.duringExternalFlow(() async {
        if (to == FileLocation.drive) {
          try {
            await _cloud.send(
              CloudApp.drive,
              name: name,
              bytes: bytes,
              mimeType: XlsxExportWriter.mimeType,
            );
            return true;
          } on CloudAppUnavailable {
            // Segue para o seletor do sistema.
          }
        }
        final path = await FilePicker.platform.saveFile(
          dialogTitle: 'Salvar planilha FinançaFácil',
          fileName: name,
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
          bytes: bytes,
        );
        if (path == null) return false;
        // No mobile o plugin grava pelo seletor nativo; no desktop grava-se o caminho.
        if (!Platform.isAndroid && !Platform.isIOS) {
          await File(path).writeAsBytes(bytes, flush: true);
        }
        return true;
      });
}
