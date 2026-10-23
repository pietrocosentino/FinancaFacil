import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/files/selected_file_reader.dart';
import 'profile_image_decoder.dart';

/// Origem da foto de perfil. Retorna a imagem já reduzida para avatar ou
/// `null` quando o usuário cancela a escolha.
abstract class ProfilePhotoSource {
  Future<Uint8List?> fromGallery();
  Future<Uint8List?> fromFiles();
}

/// Seletores nativos: galeria do aparelho e provedores de arquivos (Drive etc.).
class DeviceProfilePhotoSource implements ProfilePhotoSource {
  DeviceProfilePhotoSource({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  static const maxInputBytes = 5 * 1024 * 1024;
  final ImagePicker _imagePicker;

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
