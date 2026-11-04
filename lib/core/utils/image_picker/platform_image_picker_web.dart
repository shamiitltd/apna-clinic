// Apna Clinic - Web Image Picker Implementation
// Uses native HTML5 FileUploadInputElement with zero plugin channel dependencies.
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

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
  /// Opens browser native file selector using HTML5 FileUploadInputElement.
  /// Bypasses platform channel uninitialized errors completely.
  static Future<PickedImageData?> pickLogoImage() async {
    final completer = Completer<PickedImageData?>();
    final uploadInput = html.FileUploadInputElement()
      ..accept = 'image/png,image/jpeg,image/jpg,image/webp'
      ..multiple = false;

    html.EventListener? focusListener;

    focusListener = (event) {
      // If user dismisses native dialog without picking a file
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
        if (focusListener != null) {
          html.window.removeEventListener('focus', focusListener);
        }
      });
    };

    html.window.addEventListener('focus', focusListener);

    uploadInput.onChange.listen((e) {
      if (focusListener != null) {
        html.window.removeEventListener('focus', focusListener);
      }

      final files = uploadInput.files;
      if (files == null || files.isEmpty) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }

      final file = files[0];
      final reader = html.FileReader();

      reader.onLoadEnd.listen((e) {
        final result = reader.result;
        if (result == null) {
          if (!completer.isCompleted) completer.complete(null);
          return;
        }

        Uint8List bytes;
        if (result is Uint8List) {
          bytes = result;
        } else if (result is ByteBuffer) {
          bytes = Uint8List.view(result);
        } else if (result is List<int>) {
          bytes = Uint8List.fromList(result);
        } else {
          if (!completer.isCompleted) completer.complete(null);
          return;
        }

        final fileName = file.name;
        final ext = fileName.contains('.')
            ? fileName.split('.').last.toLowerCase()
            : 'png';

        if (!completer.isCompleted) {
          completer.complete(
            PickedImageData(
              name: fileName,
              extension: ext,
              bytes: bytes,
            ),
          );
        }
      });

      reader.onError.listen((e) {
        if (!completer.isCompleted) completer.complete(null);
      });

      reader.readAsArrayBuffer(file);
    });

    uploadInput.click();
    return completer.future;
  }
}
