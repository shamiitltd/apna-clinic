// Apna Clinic - Non-Web File Download Stub (Copies to Clipboard)
import 'package:flutter/services.dart';

class FileDownloadHelper {
  static Future<void> downloadFile({
    required String fileName,
    required String content,
    String mimeType = 'text/csv;charset=utf-8',
  }) async {
    await Clipboard.setData(ClipboardData(text: content));
  }
}
