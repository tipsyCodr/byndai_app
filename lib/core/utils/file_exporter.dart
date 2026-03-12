import 'dart:typed_data';

import 'file_exporter_io.dart'
    if (dart.library.html) 'file_exporter_web.dart' as exporter;

Future<void> exportFileBytes({
  required Uint8List bytes,
  required String fileName,
  String? mimeType,
  String? shareText,
}) {
  return exporter.exportFileBytes(
    bytes: bytes,
    fileName: fileName,
    mimeType: mimeType,
    shareText: shareText,
  );
}
