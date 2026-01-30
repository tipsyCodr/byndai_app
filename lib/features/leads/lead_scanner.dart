
// import 'dart:io';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';


// class LeadsScannerPage extends StatefulWidget {
//   const LeadsScannerPage({super.key});

//   @override
//   State<LeadsScannerPage> createState() => _LeadsScannerPageState();
// }

// class _LeadsScannerPageState extends State<LeadsScannerPage> {
//   List<XFile> _capturedImages = [];
//   bool _isLoading = false;
//   String _errorMessage = '';
//   String _ocrText = '';
//   Map<String, dynamic>? _formData;

//   final String apiUrl = "http://byndai_server-main.test/api/ocr-extract";

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Leads Scanner'),
//         backgroundColor: Colors.blue,
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             // Preview Images
//             if (_capturedImages.isNotEmpty)
//               SizedBox(
//                 height: 120,
//                 child: ListView.builder(
//                   scrollDirection: Axis.horizontal,
//                   itemCount: _capturedImages.length,
//                   itemBuilder: (context, index) {
//                     return Padding(
//                       padding: const EdgeInsets.only(right: 8),
//                       child: Stack(
//                         children: [
//                           Container(
//                             width: 100,
//                             height: 100,
//                             decoration: BoxDecoration(
//                               border: Border.all(color: Colors.blue, width: 2),
//                               borderRadius: BorderRadius.circular(10),
//                             ),
//                             child: kIsWeb
//                                 ? Image.network(_capturedImages[index].path,
//                                     fit: BoxFit.cover)
//                                 : Image.file(File(_capturedImages[index].path),
//                                     fit: BoxFit.cover),
//                           ),
//                           Positioned(
//                             top: 0,
//                             right: 0,
//                             child: GestureDetector(
//                               onTap: () => _removeImage(index),
//                               child: const CircleAvatar(
//                                 radius: 12,
//                                 backgroundColor: Colors.red,
//                                 child: Icon(Icons.close,
//                                     size: 14, color: Colors.white),
//                               ),
//                             ),
//                           )
//                         ],
//                       ),
//                     );
//                   },
//                 ),
//               )
//             else
//               Container(
//                 height: 200,
//                 width: 200,
//                 alignment: Alignment.center,
//                 decoration: BoxDecoration(
//                   border: Border.all(color: Colors.grey),
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 child: const Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(Icons.camera_alt, size: 40, color: Colors.grey),
//                     SizedBox(height: 10),
//                     Text("No image captured"),
//                   ],
//                 ),
//               ),

//             const SizedBox(height: 20),

//             ElevatedButton.icon(
//               onPressed: _captureImage,
//               icon: const Icon(Icons.camera_alt),
//               label: const Text("Capture Image"),
//             ),

//             const SizedBox(height: 10),

//             if (_capturedImages.isNotEmpty)
//               ElevatedButton.icon(
//                 onPressed: _isLoading ? null : _submitImages,
//                 icon: const Icon(Icons.cloud_upload),
//                 label: const Text("Submit For OCR"),
//                 style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
//               ),

//             if (_isLoading)
//               const Padding(
//                 padding: EdgeInsets.all(16),
//                 child: CircularProgressIndicator(),
//               ),

//             if (_errorMessage.isNotEmpty)
//               Padding(
//                 padding: const EdgeInsets.all(8),
//                 child: Text(_errorMessage,
//                     style: const TextStyle(color: Colors.red)),
//               ),

//             const SizedBox(height: 20),

//             // OCR Result Box
//             if (_ocrText.isNotEmpty)
//               Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text(
//                     "Extracted Text (OCR Result):",
//                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                   ),
//                   const SizedBox(height: 8),
//                   Container(
//                     width: double.infinity,
//                     padding: const EdgeInsets.all(12),
//                     decoration: BoxDecoration(
//                       color: Colors.grey.shade100,
//                       borderRadius: BorderRadius.circular(8),
//                       border: Border.all(color: Colors.grey.shade400),
//                     ),
//                     child: SelectableText(_ocrText),
//                   )
//                 ],
//               )
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _captureImage() async {
//     try {
//       if (!kIsWeb) {
//         var status = await Permission.camera.request();
//         if (!status.isGranted) throw Exception("Camera permission denied");
//       }

//       final picker = ImagePicker();
//       final image =
//           await picker.pickImage(source: ImageSource.camera, imageQuality: 80);

//       if (image != null) {
//         setState(() => _capturedImages.add(image));
//       }
//     } catch (e) {
//       setState(() => _errorMessage = e.toString());
//     }
//   }

//   void _removeImage(int index) {
//     setState(() => _capturedImages.removeAt(index));
//   }



//   Future<void> _submitImages() async {
//     try {
//       setState(() {
//         _isLoading = true;
//         _errorMessage = '';
//         _ocrText = '';
//       });

//       var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

//       for (int i = 0; i < _capturedImages.length && i < 2; i++) {
//         final file = _capturedImages[i];

//         final bytes = await file.readAsBytes();

//         request.files.add(
//           http.MultipartFile.fromBytes(
//             'images[]', // Laravel expects images[]
//             bytes,
//             filename: file.name,
//           ),
//         );
//       }

//       var response = await request.send();
//       final resStr = await response.stream.bytesToString();

//       if (response.statusCode == 200) {
//         final json = jsonDecode(resStr);
//         print("OCR API Response: $json"); // 🔥 CONSOLE LOG
//         setState(() {
//           _ocrText = json['text'] ?? '';
//         });
//       } else {
//         throw Exception("OCR Failed: $resStr");
//       }
//     } catch (e) {
//       setState(() => _errorMessage = e.toString());
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }
// }


//========================================================================================



import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LeadsScannerPage extends StatefulWidget {
  final Function(Map<String, dynamic>)? onDataExtracted;
  
  const LeadsScannerPage({super.key, this.onDataExtracted});

  @override
  State<LeadsScannerPage> createState() => _LeadsScannerPageState();
}

class _LeadsScannerPageState extends State<LeadsScannerPage> {
  List<XFile> _capturedImages = [];
  bool _isLoading = false;
  String _errorMessage = '';
  String _ocrText = '';
  Map<String, dynamic>? _formData;

  // final String apiUrl = "http://byndai_server-main.test/api/ocr-extract";

  final String apiUrl = "https://powderblue-jellyfish-554082.hostingersite.com/api/ocr-extract";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leads Scanner'),
        backgroundColor: Colors.blue,
        actions: [
          if (_formData != null)
            IconButton(
              onPressed: () {
                if (widget.onDataExtracted != null && _formData != null) {
                  widget.onDataExtracted!(_formData!);
                }
                Navigator.pop(context);
              },
              icon: const Icon(Icons.check),
              tooltip: 'Use Extracted Data',
            ),
        ],
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
                  ),
                ],
              ),

            // Extracted Form Data Preview
            if (_formData != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    "Extracted Form Data:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _formData!.entries.map((entry) {
                        if (entry.value != null && entry.value.toString().isNotEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              "${entry.key}: ${entry.value}",
                              style: const TextStyle(fontSize: 14),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (widget.onDataExtracted != null && _formData != null) {
                        widget.onDataExtracted!(_formData!);
                        Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.check_circle),
                    label: const Text("Use This Data in Form"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  ),
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
        _formData = null;
      });

      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

      for (int i = 0; i < _capturedImages.length && i < 2; i++) {
        final file = _capturedImages[i];
        final bytes = await file.readAsBytes();

        request.files.add(
          http.MultipartFile.fromBytes(
            'images[]',
            bytes,
            filename: file.name,
          ),
        );
      }

      var response = await request.send();
      final resStr = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final json = jsonDecode(resStr);
        print("OCR API Response: $json");
        
        setState(() {
          _ocrText = json['text'] ?? '';
          
          // Extract formdata from response
          if (json['formdata'] != null) {
            _formData = Map<String, dynamic>.from(json['formdata']);
          } else {
            // If formdata is not directly in response, try to parse from text
            _formData = _parseFormDataFromText(_ocrText);
          }
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

  Map<String, dynamic> _parseFormDataFromText(String text) {
    // Simple parsing logic if formdata not in API response
    final Map<String, dynamic> data = {};
    
    // Extract email patterns
    final emailRegex = RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b');
    final emails = emailRegex.allMatches(text).map((m) => m.group(0)).toList();
    if (emails.isNotEmpty) data['email1'] = emails[0];
    if (emails.length > 1) data['email2'] = emails[1];
    
    // Extract phone numbers
    final phoneRegex = RegExp(r'\b\d{10}\b');
    final phones = phoneRegex.allMatches(text).map((m) => m.group(0)).toList();
    for (int i = 0; i < phones.length && i < 3; i++) {
      data['mobile${i+1}'] = phones[i];
    }
    
    return data;
  }
}