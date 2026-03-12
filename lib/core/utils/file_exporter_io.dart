import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> exportFileBytes({
  required Uint8List bytes,
  required String fileName,
  String? mimeType,
  String? shareText,
}) async {
  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);

  await Share.shareXFiles(
    [XFile(file.path, mimeType: mimeType, name: fileName)],
    text: shareText,
  );
}
