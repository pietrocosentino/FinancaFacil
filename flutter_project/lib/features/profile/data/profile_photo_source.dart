import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/files/cloud_files.dart';
import '../../../core/files/selected_file_reader.dart';
import 'profile_image_decoder.dart';

/// Origem da foto de perfil. Retorna a imagem já reduzida para avatar ou
/// `null` quando o usuário cancela a escolha.
abstract class ProfilePhotoSource {
  Future<Uint8List?> fromGallery();
  Future<Uint8List?> fromGooglePhotos();
  Future<Uint8List?> fromDrive();
  Future<Uint8List?> fromFiles();
}

/// Seletores nativos: galeria, Google Fotos, Google Drive e arquivos. Sem o
/// aplicativo Google instalado, abre o seletor equivalente do sistema.
class DeviceProfilePhotoSource implements ProfilePhotoSource {
  DeviceProfilePhotoSource({ImagePicker? imagePicker, CloudFiles? cloud})
    : _imagePicker = imagePicker ?? ImagePicker(),
      _cloud = cloud ?? const CloudFiles();

  static const maxInputBytes = 5 * 1024 * 1024;
  static const _imageTypes = ['image/jpeg', 'image/png', 'image/webp'];
  final ImagePicker _imagePicker;
  final CloudFiles _cloud;

  @override
  Future<Uint8List?> fromGallery() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 70,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    return prepareProfileImage(await file.readAsBytes());
  }

  @override
  Future<Uint8List?> fromGooglePhotos() =>
      _fromApp(CloudApp.photos, fallback: fromGallery);

  @override
  Future<Uint8List?> fromDrive() =>
      _fromApp(CloudApp.drive, fallback: fromFiles);

  Future<Uint8List?> _fromApp(
    CloudApp app, {
    required Future<Uint8List?> Function() fallback,
  }) async {
    try {
      final file = await _cloud.pick(
        app,
        mimeTypes: _imageTypes,
        maxBytes: maxInputBytes,
      );
      return file == null ? null : await prepareProfileImage(file.bytes);
    } on CloudAppUnavailable {
      return fallback();
    }
  }

  @override
  Future<Uint8List?> fromFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      allowMultiple: false,
      withData: false,
      withReadStream: true,
    );
    if (result == null) return null;
    final input = await readSelectedFile(result.files.single, maxInputBytes);
    return prepareProfileImage(input);
  }
}
