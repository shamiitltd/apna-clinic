// Apna Clinic - Native & Desktop Image Picker Implementation
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

class PickedImageData {
  final String name;
  final String extension;
  final Uint8List bytes;

  const PickedImageData({
    required this.name,
    required this.extension,
    required this.bytes,
  });
}

class PlatformImagePicker {
  /// Picks an image file on desktop/mobile platforms via FilePicker
  static Future<PickedImageData?> pickLogoImage() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      );

      if (files.isEmpty) return null;

      final file = files.first;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;

      final ext = file.extension?.toLowerCase() ?? 'png';
      return PickedImageData(
        name: file.name,
        extension: ext,
        bytes: bytes,
      );
    } catch (_) {
      return null;
    }
  }
}
