// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:pro_image_editor/pro_image_editor.dart';

// class EditorPage extends StatelessWidget {
//   final String imageUrl;

//   const EditorPage({super.key, required this.imageUrl});

//   @override
//   Widget build(BuildContext context) {
//     return ProImageEditor.network(
//       imageUrl,

//       callbacks: ProImageEditorCallbacks(
//         onImageEditingComplete: (Uint8List bytes) async {
//           debugPrint("DONE: ${bytes.length}");

//           Navigator.pop(context);
//         },
//       ),
//     );
//   }
// }

//=======================================================================================================================

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:gal/gal.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:universal_html/html.dart' as html; // cross-platform html

class EditorPage extends StatelessWidget {
  final String imageUrl;

  const EditorPage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ProImageEditor.network(
      imageUrl,


      
      callbacks: ProImageEditorCallbacks(
        onImageEditingComplete: (Uint8List bytes) async {
          /// 🔥 SAVE LOGIC
          await _saveImage(bytes, context);

          Navigator.pop(context);
        },
      ),
    );
  }

  /// ✅ SAVE METHOD (WEB + MOBILE)
  Future<void> _saveImage(Uint8List bytes, BuildContext context) async {
    try {
      if (kIsWeb) {
        /// 🌐 WEB DOWNLOAD
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);

        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", "flyer.png")
          ..click();

        html.Url.revokeObjectUrl(url);
      } else {
        /// 📱 MOBILE GALLERY SAVE
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/flyer_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(bytes);
        await Gal.putImage(file.path);
        debugPrint("Saved to gallery");
      }

      /// ✅ SUCCESS MESSAGE
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Image Saved Successfully")),
      );
    } catch (e) {
      debugPrint("Save Error: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to Save Image")),
      );
    }
  }
}


//=========================================================================================
