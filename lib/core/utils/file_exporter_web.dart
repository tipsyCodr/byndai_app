import 'dart:typed_data';

import 'package:universal_html/html.dart' as html;

Future<void> exportFileBytes({
  required Uint8List bytes,
  required String fileName,
  String? mimeType,
  String? shareText,
}) async {
  final blob = html.Blob([bytes], mimeType ?? 'application/octet-stream');
  final url = html.Url.createObjectUrlFromBlob(blob);

  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();

  html.Url.revokeObjectUrl(url);
}
