// ignore: deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

Future<Uint8List?> readSelectedPath(String? path) async => null;
Future<void> writeTemplatePath(String path, Uint8List bytes) async =>
    throw UnsupportedError('O navegador nao expoe caminhos locais.');

Future<bool> downloadTemplate(Uint8List bytes) async {
  final blob = html.Blob([bytes],
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = 'modelo_financafacil.xlsx'
    ..style.display = 'none';
  html.document.body!.append(anchor);
  try {
    anchor.click();
    await Future<void>.delayed(const Duration(seconds: 1));
    return true;
  } finally {
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }
}
