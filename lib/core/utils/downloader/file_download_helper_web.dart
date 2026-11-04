// Apna Clinic - Web Native File Download Implementation
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;

class FileDownloadHelper {
  static Future<void> downloadFile({
    required String fileName,
    required String content,
    String mimeType = 'text/csv;charset=utf-8',
  }) async {
    final bytes = utf8.encode(content);
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..target = 'blank'
      ..download = fileName;
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }
}
