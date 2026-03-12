// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:crop_your_image/crop_your_image.dart';
// import 'package:image_picker/image_picker.dart';

// class CropScreen extends StatefulWidget {
//   final XFile imageFile;
//   final Function(Uint8List) onCropped;

//   const CropScreen({
//     super.key,
//     required this.imageFile,
//     required this.onCropped,
//   });

//   @override
//   State<CropScreen> createState() => _CropScreenState();
// }

// class _CropScreenState extends State<CropScreen> {
//   final CropController _controller = CropController();
//   Uint8List? _imageBytes;

//   @override
//   void initState() {
//     super.initState();
//     _loadImage();
//   }

//   Future<void> _loadImage() async {
//     final bytes = await widget.imageFile.readAsBytes();
//     setState(() {
//       _imageBytes = bytes;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_imageBytes == null) {
//       return const Scaffold(
//         body: Center(child: CircularProgressIndicator()),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Crop Image"),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.check),
//             onPressed: () {
//               _controller.crop();
//             },
//           )
//         ],
//       ),
//       body: Crop(
//         controller: _controller,
//         image: _imageBytes!,
//         aspectRatio: 1, // Keep square crop
//         initialSize: 0.95, // 👈 Make crop area nearly full image
//         // Optional: Set a fixed initial area if needed
//         // initialArea: Rect.fromLTWH(0, 0, _imageBytes!.width, _imageBytes!.height),
//         onCropped: (Uint8List croppedData) {
//           widget.onCropped(croppedData);
//           Navigator.pop(context);
//         },
//       ),
//     );
//   }
// }


import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:image_picker/image_picker.dart';

class CropScreen extends StatefulWidget {
  final XFile imageFile;
  final Function(Uint8List) onCropped;

  const CropScreen({
    super.key,
    required this.imageFile,
    required this.onCropped,
  });

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  final CropController _controller = CropController();
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final bytes = await widget.imageFile.readAsBytes();
    setState(() {
      _imageBytes = bytes;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_imageBytes == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Crop Image"),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              _controller.crop();
            },
          )
        ],
      ),
      body: Crop(
        controller: _controller,
        image: _imageBytes!,
        aspectRatio: 1, // Keep square crop
        initialSize: 0.95, // 👈 Make crop area nearly full image
        onCropped: (Uint8List croppedData) {
          widget.onCropped(croppedData);
          Navigator.pop(context);
        },
      ),
    );
  }
}