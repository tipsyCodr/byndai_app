// import 'package:camera/camera.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
// import 'package:gridcard/features/scanner/preview.dart' as mypreview;
// import 'package:image_picker/image_picker.dart';

// class CameraScreen extends StatefulWidget {
//   const CameraScreen({super.key});

//   @override
//   CameraScreenState createState() => CameraScreenState();
// }

// class CameraScreenState extends State<CameraScreen> {
//   CameraController? _controller;
//   Future<void>? _initializeControllerFuture;
//   FlashMode _flashMode = FlashMode.off;
//   bool _isProcessing = false;

//   @override
//   void initState() {
//     super.initState();
//     _initializeControllerFuture = _initializeCamera();
//   }

//   Future<void> _initializeCamera() async {
//     final cameras = await availableCameras();
//     if (cameras.isEmpty) return;

//     _controller = CameraController(
//       cameras[0],
//       ResolutionPreset.max,
//       enableAudio: false,
//     );
//     await _controller!.initialize();
//     if (mounted) setState(() {});
//   }

//   @override
//   void dispose() {
//     _controller?.dispose();
//     super.dispose();
//   }

//   Future<void> _toggleFlash() async {
//     if (_controller == null) return;
//     final newMode =
//         _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
//     await _controller!.setFlashMode(newMode);
//     setState(() => _flashMode = newMode);
//   }

//   Future<void> _pickFromGallery() async {
//     final picker = ImagePicker();
//     final image = await picker.pickImage(source: ImageSource.gallery);
//     if (image != null) {
//       _processImage(image.path);
//     }
//   }

//   Future<void> _processImage(String path) async {
//     setState(() => _isProcessing = true);
//     try {
//       final inputImage = InputImage.fromFilePath(path);
//       final textRecognizer = TextRecognizer();
//       final RecognizedText recognizedText =
//           await textRecognizer.processImage(inputImage);
//       await textRecognizer.close();

//       if (mounted) {
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (context) => mypreview.Preview(
//               imagePath: path,
//               recognizedText: recognizedText.text,
//             ),
//           ),
//         );
//       }
//     } catch (e) {
//       if (kDebugMode) debugPrint('Error processing image: $e');
//     } finally {
//       if (mounted) setState(() => _isProcessing = false);
//     }
//   }

//   Future<void> _takePicture() async {
//     if (_controller == null ||
//         !_controller!.value.isInitialized ||
//         _isProcessing) return;
//     try {
//       final image = await _controller!.takePicture();
//       _processImage(image.path);
//     } catch (e) {
//       if (kDebugMode) debugPrint('Error taking picture: $e');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final colors = Theme.of(context).colorScheme;

//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: Stack(
//         children: <Widget>[
//           // Camera Preview
//           Positioned.fill(
//             child: FutureBuilder<void>(
//               future: _initializeControllerFuture,
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.done &&
//                     _controller != null) {
//                   return Center(
//                     child: CameraPreview(_controller!),
//                   );
//                 } else {
//                   return const Center(
//                       child: CircularProgressIndicator(color: Colors.white));
//                 }
//               },
//             ),
//           ),

//           // Overlay Guide
//           Positioned.fill(
//             child: Container(
//               decoration: ShapeDecoration(
//                 shape: _ScannerOverlayShape(
//                   borderColor: colors.primary,
//                   borderWidth: 3.0,
//                   overlayColor: Colors.black.withOpacity(0.5),
//                 ),
//               ),
//             ),
//           ),

//           // Top Controls
//           Positioned(
//             top: MediaQuery.of(context).padding.top + 10,
//             left: 20,
//             right: 20,
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 IconButton(
//                   onPressed: () => Navigator.pop(context),
//                   icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
//                   style: IconButton.styleFrom(backgroundColor: Colors.black26),
//                 ),
//                 Text(
//                   "Scan Card",
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                     shadows: [Shadow(blurRadius: 10, color: Colors.black45)],
//                   ),
//                 ),
//                 IconButton(
//                   onPressed: _toggleFlash,
//                   icon: Icon(
//                     _flashMode == FlashMode.torch
//                         ? Icons.flash_on
//                         : Icons.flash_off,
//                     color: Colors.white,
//                   ),
//                   style: IconButton.styleFrom(backgroundColor: Colors.black26),
//                 ),
//               ],
//             ),
//           ),

//           // Bottom Controls
//           Positioned(
//             bottom: 40,
//             left: 0,
//             right: 0,
//             child: Column(
//               children: [
//                 if (_isProcessing)
//                   Padding(
//                     padding: const EdgeInsets.only(bottom: 20),
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 20, vertical: 10),
//                       decoration: BoxDecoration(
//                         color: Colors.black54,
//                         borderRadius: BorderRadius.circular(20),
//                       ),
//                       child: Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: const [
//                           SizedBox(
//                             width: 15,
//                             height: 15,
//                             child: CircularProgressIndicator(
//                                 strokeWidth: 2, color: Colors.white),
//                           ),
//                           SizedBox(width: 12),
//                           Text("Processing Card...",
//                               style: TextStyle(color: Colors.white)),
//                         ],
//                       ),
//                     ),
//                   ),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                   children: [
//                     IconButton(
//                       onPressed: _pickFromGallery,
//                       icon: const Icon(Icons.photo_library,
//                           color: Colors.white, size: 28),
//                       style: IconButton.styleFrom(
//                         padding: const EdgeInsets.all(16),
//                         backgroundColor: Colors.white24,
//                       ),
//                     ),
//                     GestureDetector(
//                       onTap: _takePicture,
//                       child: Container(
//                         height: 80,
//                         width: 80,
//                         decoration: BoxDecoration(
//                           shape: BoxShape.circle,
//                           border: Border.all(color: Colors.white, width: 4),
//                         ),
//                         child: Center(
//                           child: Container(
//                             height: 60,
//                             width: 60,
//                             decoration: const BoxDecoration(
//                               color: Colors.white,
//                               shape: BoxShape.circle,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                     IconButton(
//                       onPressed: () async {
//                         final cameras = await availableCameras();
//                         if (cameras.length < 2) return;
//                         setState(() {
//                           _controller = CameraController(
//                             _controller!.description.lensDirection ==
//                                     CameraLensDirection.front
//                                 ? cameras[0]
//                                 : cameras[1],
//                             ResolutionPreset.max,
//                             enableAudio: false,
//                           );
//                           _initializeControllerFuture =
//                               _controller!.initialize();
//                         });
//                       },
//                       icon: const Icon(Icons.flip_camera_ios,
//                           color: Colors.white, size: 28),
//                       style: IconButton.styleFrom(
//                         padding: const EdgeInsets.all(16),
//                         backgroundColor: Colors.white24,
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _ScannerOverlayShape extends ShapeBorder {
//   final Color borderColor;
//   final double borderWidth;
//   final Color overlayColor;

//   const _ScannerOverlayShape({
//     this.borderColor = Colors.white,
//     this.borderWidth = 3.0,
//     this.overlayColor = const Color(0x88000000),
//   });

//   @override
//   EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

//   @override
//   Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path();

//   @override
//   Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
//     return Path()..addRect(rect);
//   }

//   @override
//   void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
//     final width = rect.width;
//     final height = rect.height;

//     // Business card aspect ratio is roughly 1.75:1
//     final cardWidth = width * 0.85;
//     final cardHeight = cardWidth / 1.75;

//     final cardRect = Rect.fromCenter(
//       center: Offset(width / 2, height / 2 - 20),
//       width: cardWidth,
//       height: cardHeight,
//     );

//     final backgroundPaint = Paint()..color = overlayColor;
//     final borderPaint = Paint()
//       ..color = borderColor
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = borderWidth;

//     // Draw background with hole
//     final path = Path()
//       ..addRect(rect)
//       ..addRRect(RRect.fromRectAndRadius(cardRect, const Radius.circular(12)))
//       ..fillType = PathFillType.evenOdd;
//     canvas.drawPath(path, backgroundPaint);

//     // Draw corners
//     final rrect = RRect.fromRectAndRadius(cardRect, const Radius.circular(12));
//     canvas.drawRRect(rrect, borderPaint);

//     // Add some corner markers for better visual
//     final markerLength = 30.0;
//     final markerPaint = Paint()
//       ..color = borderColor
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = borderWidth + 2
//       ..strokeCap = StrokeCap.round;

//     // Top Left
//     canvas.drawLine(Offset(cardRect.left, cardRect.top + markerLength),
//         Offset(cardRect.left, cardRect.top), markerPaint);
//     canvas.drawLine(Offset(cardRect.left, cardRect.top),
//         Offset(cardRect.left + markerLength, cardRect.top), markerPaint);

//     // Top Right
//     canvas.drawLine(Offset(cardRect.right - markerLength, cardRect.top),
//         Offset(cardRect.right, cardRect.top), markerPaint);
//     canvas.drawLine(Offset(cardRect.right, cardRect.top),
//         Offset(cardRect.right, cardRect.top + markerLength), markerPaint);

//     // Bottom Left
//     canvas.drawLine(Offset(cardRect.left, cardRect.bottom - markerLength),
//         Offset(cardRect.left, cardRect.bottom), markerPaint);
//     canvas.drawLine(Offset(cardRect.left, cardRect.bottom),
//         Offset(cardRect.left + markerLength, cardRect.bottom), markerPaint);

//     // Bottom Right
//     canvas.drawLine(Offset(cardRect.right - markerLength, cardRect.bottom),
//         Offset(cardRect.right, cardRect.bottom), markerPaint);
//     canvas.drawLine(Offset(cardRect.right, cardRect.bottom),
//         Offset(cardRect.right, cardRect.bottom - markerLength), markerPaint);
//   }

//   @override
//   ShapeBorder scale(double t) => this;
// }
