// import 'dart:io';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:image_picker/image_picker.dart';

// // Web के लिए
// import 'package:camera_web/camera_web.dart';

// class LeadsScannerPage extends StatefulWidget {
//   const LeadsScannerPage({super.key});

//   @override
//   State<LeadsScannerPage> createState() => _LeadsScannerPageState();
// }

// class _LeadsScannerPageState extends State<LeadsScannerPage> {
//   XFile? _capturedImage;
//   bool _isLoading = false;
//   String _errorMessage = '';

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Leads Scanner'),
//         backgroundColor: Colors.blue,
//       ),
//       body: Center(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(20),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               // Captured Image Preview
//               if (_capturedImage != null)
//                 Container(
//                   margin: const EdgeInsets.only(bottom: 20),
//                   decoration: BoxDecoration(
//                     border: Border.all(color: Colors.blue, width: 2),
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   child: kIsWeb
//                       ? Image.network(
//                           _capturedImage!.path,
//                           height: 250,
//                           width: 250,
//                           fit: BoxFit.cover,
//                         )
//                       : Image.file(
//                           File(_capturedImage!.path),
//                           height: 250,
//                           width: 250,
//                           fit: BoxFit.cover,
//                         ),
//                 )
//               else
//                 Container(
//                   height: 250,
//                   width: 250,
//                   decoration: BoxDecoration(
//                     border: Border.all(color: Colors.grey, width: 2),
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   child: const Icon(
//                     Icons.camera_alt,
//                     size: 50,
//                     color: Colors.grey,
//                   ),
//                 ),

//               const SizedBox(height: 30),

//               // Capture Button
//               ElevatedButton.icon(
//                 onPressed: _isLoading ? null : _captureImage,
//                 icon: const Icon(Icons.camera),
//                 label: const Text('Capture from Back Camera'),
//                 style: ElevatedButton.styleFrom(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 30,
//                     vertical: 15,
//                   ),
//                   backgroundColor: Colors.blue,
//                 ),
//               ),

//               const SizedBox(height: 15),

//               // Reset Button
//               if (_capturedImage != null)
//                 ElevatedButton.icon(
//                   onPressed: _resetImage,
//                   icon: const Icon(Icons.refresh),
//                   label: const Text('Reset'),
//                   style: ElevatedButton.styleFrom(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 30,
//                       vertical: 15,
//                     ),
//                     backgroundColor: Colors.grey,
//                   ),
//                 ),

//               // Loading Indicator
//               if (_isLoading)
//                 const Padding(
//                   padding: EdgeInsets.only(top: 20),
//                   child: CircularProgressIndicator(),
//                 ),

//               // Error Message
//               if (_errorMessage.isNotEmpty)
//                 Padding(
//                   padding: const EdgeInsets.only(top: 20),
//                   child: Text(
//                     _errorMessage,
//                     style: const TextStyle(
//                       color: Colors.red,
//                       fontWeight: FontWeight.bold,
//                     ),
//                     textAlign: TextAlign.center,
//                   ),
//                 ),

//               const SizedBox(height: 20),

//               // Instructions
//               const Text(
//                 'Instructions:',
//                 style: TextStyle(
//                   fontWeight: FontWeight.bold,
//                   fontSize: 16,
//                 ),
//               ),
//               const SizedBox(height: 10),
//               const Text(
//                 '1. Click "Capture from Back Camera" button\n'
//                 '2. Allow camera permissions if prompted\n'
//                 '3. Use back camera to capture image\n'
//                 '4. Click reset to capture again',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(color: Colors.grey),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Future<void> _captureImage() async {
//     try {
//       setState(() {
//         _isLoading = true;
//         _errorMessage = '';
//       });

//       // Check and request permissions
//       if (!kIsWeb) {
//         // For Mobile (Android/iOS)
//         var status = await Permission.camera.status;
//         if (!status.isGranted) {
//           status = await Permission.camera.request();
//           if (!status.isGranted) {
//             throw Exception('Camera permission denied');
//           }
//         }
//       }

//       final picker = ImagePicker();

//       if (kIsWeb) {
//         // For Web - using back camera
//         final XFile? image = await picker.pickImage(
//           source: ImageSource.camera,
//           preferredCameraDevice: CameraDevice.rear,
//         );

//         if (image != null) {
//           setState(() {
//             _capturedImage = image;
//           });
//         }
//       } else {
//         // For Mobile
//         final XFile? image = await picker.pickImage(
//           source: ImageSource.camera,
//           preferredCameraDevice: CameraDevice.rear,
//         );

//         if (image != null) {
//           setState(() {
//             _capturedImage = image;
//           });
//         }
//       }
//     } catch (e) {
//       setState(() {
//         _errorMessage = 'Error: ${e.toString()}';
//       });
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }

//   void _resetImage() {
//     setState(() {
//       _capturedImage = null;
//       _errorMessage = '';
//     });
//   }
// }

//=========================================================================================

// import 'dart:io';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:image_picker/image_picker.dart';

// // Web के लिए
// import 'package:camera_web/camera_web.dart';

// class LeadsScannerPage extends StatefulWidget {
//   const LeadsScannerPage({super.key});

//   @override
//   State<LeadsScannerPage> createState() => _LeadsScannerPageState();
// }

// class _LeadsScannerPageState extends State<LeadsScannerPage> {
//   List<XFile> _capturedImages = []; // Multiple images के लिए list
//   bool _isLoading = false;
//   String _errorMessage = '';

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Leads Scanner'),
//         backgroundColor: Colors.blue,
//       ),
//       body: Center(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(20),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               // Captured Images Preview - Horizontal List
//               if (_capturedImages.isNotEmpty)
//                 Column(
//                   children: [
//                     Container(
//                       height: 120,
//                       margin: const EdgeInsets.only(bottom: 20),
//                       child: ListView.builder(
//                         scrollDirection: Axis.horizontal,
//                         itemCount: _capturedImages.length,
//                         itemBuilder: (context, index) {
//                           return Padding(
//                             padding: const EdgeInsets.only(right: 10),
//                             child: Stack(
//                               children: [
//                                 Container(
//                                   width: 100,
//                                   height: 100,
//                                   decoration: BoxDecoration(
//                                     border: Border.all(color: Colors.blue, width: 2),
//                                     borderRadius: BorderRadius.circular(10),
//                                   ),
//                                   child: kIsWeb
//                                       ? Image.network(
//                                           _capturedImages[index].path,
//                                           width: 100,
//                                           height: 100,
//                                           fit: BoxFit.cover,
//                                         )
//                                       : Image.file(
//                                           File(_capturedImages[index].path),
//                                           width: 100,
//                                           height: 100,
//                                           fit: BoxFit.cover,
//                                         ),
//                                 ),
//                                 // Image Number Badge
//                                 Positioned(
//                                   top: 5,
//                                   left: 5,
//                                   child: Container(
//                                     padding: const EdgeInsets.all(4),
//                                     decoration: BoxDecoration(
//                                       color: Colors.blue,
//                                       borderRadius: BorderRadius.circular(12),
//                                     ),
//                                     child: Text(
//                                       '${index + 1}',
//                                       style: const TextStyle(
//                                         color: Colors.white,
//                                         fontSize: 12,
//                                         fontWeight: FontWeight.bold,
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                                 // Delete Button
//                                 Positioned(
//                                   top: 0,
//                                   right: 0,
//                                   child: GestureDetector(
//                                     onTap: () => _removeImage(index),
//                                     child: Container(
//                                       padding: const EdgeInsets.all(2),
//                                       decoration: const BoxDecoration(
//                                         color: Colors.red,
//                                         shape: BoxShape.circle,
//                                       ),
//                                       child: const Icon(
//                                         Icons.close,
//                                         size: 16,
//                                         color: Colors.white,
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           );
//                         },
//                       ),
//                     ),
//                     Text(
//                       'Total Images: ${_capturedImages.length}',
//                       style: const TextStyle(
//                         fontWeight: FontWeight.bold,
//                         color: Colors.blue,
//                       ),
//                     ),
//                     const SizedBox(height: 10),
//                   ],
//                 )
//               else
//                 Container(
//                   height: 250,
//                   width: 250,
//                   decoration: BoxDecoration(
//                     border: Border.all(color: Colors.grey, width: 2),
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   child: const Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Icon(
//                         Icons.camera_alt,
//                         size: 50,
//                         color: Colors.grey,
//                       ),
//                       SizedBox(height: 10),
//                       Text(
//                         'No images captured',
//                         style: TextStyle(color: Colors.grey),
//                       ),
//                     ],
//                   ),
//                 ),

//               const SizedBox(height: 30),

//               // Capture More Button
//               ElevatedButton.icon(
//                 onPressed: _isLoading ? null : _captureImage,
//                 icon: const Icon(Icons.add_a_photo),
//                 label: Text(_capturedImages.isEmpty
//                     ? 'Capture First Image'
//                     : 'Capture Another Image'),
//                 style: ElevatedButton.styleFrom(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 30,
//                     vertical: 15,
//                   ),
//                   backgroundColor: Colors.blue,
//                 ),
//               ),

//               const SizedBox(height: 15),

//               // Reset All Button
//               if (_capturedImages.isNotEmpty)
//                 ElevatedButton.icon(
//                   onPressed: _resetAllImages,
//                   icon: const Icon(Icons.delete_forever),
//                   label: const Text('Reset All Images'),
//                   style: ElevatedButton.styleFrom(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 30,
//                       vertical: 15,
//                     ),
//                     backgroundColor: Colors.red,
//                   ),
//                 ),

//               // Loading Indicator
//               if (_isLoading)
//                 const Padding(
//                   padding: EdgeInsets.only(top: 20),
//                   child: CircularProgressIndicator(),
//                 ),

//               // Error Message
//               if (_errorMessage.isNotEmpty)
//                 Padding(
//                   padding: const EdgeInsets.only(top: 20),
//                   child: Text(
//                     _errorMessage,
//                     style: const TextStyle(
//                       color: Colors.red,
//                       fontWeight: FontWeight.bold,
//                     ),
//                     textAlign: TextAlign.center,
//                   ),
//                 ),

//               const SizedBox(height: 20),

//               // Instructions
//               Container(
//                 padding: const EdgeInsets.all(15),
//                 decoration: BoxDecoration(
//                   color: Colors.blue[50],
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 child: Column(
//                   children: [
//                     const Text(
//                       'Instructions:',
//                       style: TextStyle(
//                         fontWeight: FontWeight.bold,
//                         fontSize: 16,
//                       ),
//                     ),
//                     const SizedBox(height: 10),
//                     const Text(
//                       '1. Click "Capture First Image" button\n'
//                       '2. Allow camera permissions if prompted\n'
//                       '3. Use back camera to capture image\n'
//                       '4. Click "Capture Another Image" to add more\n'
//                       '5. Tap on cross icon to remove specific image\n'
//                       '6. Click "Reset All Images" to start over',
//                       textAlign: TextAlign.left,
//                       style: TextStyle(color: Colors.grey),
//                     ),
//                     const SizedBox(height: 10),
//                     if (_capturedImages.isNotEmpty)
//                       Text(
//                         'You have captured ${_capturedImages.length} image(s)',
//                         style: const TextStyle(
//                           color: Colors.green,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Future<void> _captureImage() async {
//     try {
//       setState(() {
//         _isLoading = true;
//         _errorMessage = '';
//       });

//       // Check and request permissions
//       if (!kIsWeb) {
//         // For Mobile (Android/iOS)
//         var status = await Permission.camera.status;
//         if (!status.isGranted) {
//           status = await Permission.camera.request();
//           if (!status.isGranted) {
//             throw Exception('Camera permission denied');
//           }
//         }
//       }

//       final picker = ImagePicker();

//       if (kIsWeb) {
//         // For Web - using back camera
//         final XFile? image = await picker.pickImage(
//           source: ImageSource.camera,
//           preferredCameraDevice: CameraDevice.rear,
//         );

//         if (image != null) {
//           setState(() {
//             _capturedImages.add(image);
//           });
//         }
//       } else {
//         // For Mobile
//         final XFile? image = await picker.pickImage(
//           source: ImageSource.camera,
//           preferredCameraDevice: CameraDevice.rear,
//         );

//         if (image != null) {
//           setState(() {
//             _capturedImages.add(image);
//           });
//         }
//       }
//     } catch (e) {
//       setState(() {
//         _errorMessage = 'Error: ${e.toString()}';
//       });
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }

//   void _removeImage(int index) {
//     setState(() {
//       _capturedImages.removeAt(index);
//     });
//   }

//   void _resetAllImages() {
//     setState(() {
//       _capturedImages.clear();
//       _errorMessage = '';
//     });
//   }
// }

//==========================================================================
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LeadsScannerPage extends StatefulWidget {
  const LeadsScannerPage({super.key});

  @override
  State<LeadsScannerPage> createState() => _LeadsScannerPageState();
}

class _LeadsScannerPageState extends State<LeadsScannerPage> {
  List<XFile> _capturedImages = [];
  bool _isLoading = false;
  String _errorMessage = '';
  String _ocrText = '';

  final String apiUrl = "http://byndai_server-main.test/api/ocr-extract";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leads Scanner'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Preview Images
            if (_capturedImages.isNotEmpty)
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _capturedImages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.blue, width: 2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: kIsWeb
                                ? Image.network(_capturedImages[index].path,
                                    fit: BoxFit.cover)
                                : Image.file(File(_capturedImages[index].path),
                                    fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: const CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.red,
                                child: Icon(Icons.close,
                                    size: 14, color: Colors.white),
                              ),
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                height: 200,
                width: 200,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                    SizedBox(height: 10),
                    Text("No image captured"),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: _captureImage,
              icon: const Icon(Icons.camera_alt),
              label: const Text("Capture Image"),
            ),

            const SizedBox(height: 10),

            if (_capturedImages.isNotEmpty)
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _submitImages,
                icon: const Icon(Icons.cloud_upload),
                label: const Text("Submit For OCR"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),

            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(_errorMessage,
                    style: const TextStyle(color: Colors.red)),
              ),

            const SizedBox(height: 20),

            // OCR Result Box
            if (_ocrText.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Extracted Text (OCR Result):",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: SelectableText(_ocrText),
                  )
                ],
              )
          ],
        ),
      ),
    );
  }

  Future<void> _captureImage() async {
    try {
      if (!kIsWeb) {
        var status = await Permission.camera.request();
        if (!status.isGranted) throw Exception("Camera permission denied");
      }

      final picker = ImagePicker();
      final image =
          await picker.pickImage(source: ImageSource.camera, imageQuality: 80);

      if (image != null) {
        setState(() => _capturedImages.add(image));
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  void _removeImage(int index) {
    setState(() => _capturedImages.removeAt(index));
  }



  Future<void> _submitImages() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
        _ocrText = '';
      });

      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

      for (int i = 0; i < _capturedImages.length && i < 2; i++) {
        final file = _capturedImages[i];

        final bytes = await file.readAsBytes();

        request.files.add(
          http.MultipartFile.fromBytes(
            'images[]', // Laravel expects images[]
            bytes,
            filename: file.name,
          ),
        );
      }

      var response = await request.send();
      final resStr = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final json = jsonDecode(resStr);

        setState(() {
          _ocrText = json['text'] ?? '';
        });
      } else {
        throw Exception("OCR Failed: $resStr");
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
