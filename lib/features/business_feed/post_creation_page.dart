// import 'dart:io';
// import 'dart:convert';
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:gridcard/config/app_config.dart';
// import 'package:gridcard/core/services/user_storage_service.dart';
// import 'package:http/http.dart' as http;
// import 'package:image_picker/image_picker.dart';
// import 'package:gridcard/widgets/top_alert.dart';

// class PostCreationPage extends StatefulWidget {
//   const PostCreationPage({super.key});

//   @override
//   State<PostCreationPage> createState() => _PostCreationPageState();
// }

// class _PostCreationPageState extends State<PostCreationPage> {
//   final TextEditingController _titleController = TextEditingController();
//   final TextEditingController _descriptionController = TextEditingController();

//   final List<XFile?> _images = [];
//   final ImagePicker _picker = ImagePicker();

//   bool _isLoading = false;

//   // ===========================
//   // ✅ INDUSTRY OPTIONS (API)
//   // ===========================
//   List<Map<String, dynamic>> _industryOptions = [];
//   bool _isIndustryLoading = false;

//   int? _selectedIndustryId;
//   String? _selectedIndustryName;

//   // ================= HEADERS =================
//   Future<Map<String, String>> _getHeaders() async {
//     final token = await UserStorageService().getToken();
//     return {
//       'Content-Type': 'application/json',
//       'Accept': 'application/json',
//       if (token != null) 'Authorization': 'Bearer $token',
//     };
//   }

//   Future<Map<String, String>> _getHeadersMultipart() async {
//     final token = await UserStorageService().getToken();

//     return {
//       'Accept': 'application/json',
//       if (token != null) 'Authorization': 'Bearer $token',
//     };
//   }

//   // ===========================
//   // ✅ FETCH INDUSTRIES API
//   // ===========================
//   Future<void> _fetchIndustries() async {
//     setState(() => _isIndustryLoading = true);

//     try {
//       final headers = await _getHeaders();
//       final uri = Uri.parse("${AppConfig.apiBaseUrl}/industries");

//       final response = await http.get(uri, headers: headers);

//       debugPrint("Industries Status: ${response.statusCode}");
//       debugPrint("Industries Body: ${response.body}");

//       if (response.statusCode == 200) {
//         final jsonData = jsonDecode(response.body);

//         if (jsonData["status"] == true) {
//           final List data = jsonData["data"];

//           setState(() {
//             _industryOptions = data.map((item) {
//               return {
//                 "id": item["id"],
//                 "name": item["title"], // 👈 backend title -> dropdown name
//                 "icons": item["icons"],
//               };
//             }).toList();
//           });
//         } else {
//           TopAlert.show(
//               context, jsonData["message"] ?? "Failed to load industries",
//               isError: true);
//         }
//       } else {
//         TopAlert.show(context, "Failed to load industries", isError: true);
//       }
//     } catch (e) {
//       debugPrint("Fetch industries error: $e");
//       TopAlert.show(context, "Network error while loading industries",
//           isError: true);
//     } finally {
//       if (mounted) setState(() => _isIndustryLoading = false);
//     }
//   }

//   // ================= INIT =================
//   @override
//   void initState() {
//     super.initState();
//     _fetchIndustries(); // ✅ page open होते ही call
//   }

//   // ================= IMAGE PICKING =================
//   Future<void> _pickImage(int index) async {
//     final XFile? selected =
//         await _picker.pickImage(source: ImageSource.gallery);
//     if (selected != null) {
//       setState(() {
//         if (_images.length > index) {
//           _images[index] = selected;
//         } else {
//           _images.add(selected);
//         }
//       });
//     }
//   }

//   // ================= ADD IMAGE FIELD =================
//   void _addImageField() {
//     if (_images.length < 5) {
//       setState(() {
//         _images.add(null);
//       });
//     } else {
//       TopAlert.show(context, 'Maximum 5 images allowed', isError: true);
//     }
//   }

//   // ================= REMOVE IMAGE FIELD =================
//   void _removeImageField(int index) {
//     setState(() {
//       _images.removeAt(index);
//     });
//   }

//   // ================= PRINT REQUEST DATA =================
//   void _printRequestData() {
//     print('================== POST REQUEST DATA ==================');
//     print('Title: ${_titleController.text}');
//     print('Description: ${_descriptionController.text}');
//     print('Industry ID: $_selectedIndustryId');
//     print('Industry Name: $_selectedIndustryName');
//     print('Number of Images: ${_images.length}');

//     for (int i = 0; i < _images.length; i++) {
//       if (_images[i] != null) {
//         print('Image $i: ${_images[i]!.path}');
//       } else {
//         print('Image $i: Not selected');
//       }
//     }

//     print('========================================================');
//   }

//   // ================= SUBMIT POST =================
//   Future<void> _submitPost() async {
//     // ✅ Industry validation
//     if (_selectedIndustryId == null) {
//       TopAlert.show(context, "Please select industry", isError: true);
//       return;
//     }

//     setState(() => _isLoading = true);

//     try {
//       final headers = await _getHeadersMultipart();

//       var request = http.MultipartRequest(
//         "POST",
//         Uri.parse("${AppConfig.apiBaseUrl}/posts/create"),
//       );

//       request.headers.addAll(headers);

//       request.fields["title"] = _titleController.text;
//       request.fields["description"] = _descriptionController.text;

//       // ✅ selected industry id
//       request.fields["industry_id"] = _selectedIndustryId.toString();

//       // ✅ Images
//       for (int i = 0; i < _images.length; i++) {
//         if (_images[i] != null) {
//           final bytes = await _images[i]!.readAsBytes();

//           request.files.add(
//             http.MultipartFile.fromBytes(
//               "images[]",
//               bytes,
//               filename: _images[i]!.name,
//             ),
//           );
//         }
//       }

//       // debug
//       _printRequestData();

//       final streamedResponse = await request.send();
//       final responseBody = await streamedResponse.stream.bytesToString();

//       print("Response Status Code: ${streamedResponse.statusCode}");
//       print("Response Body: $responseBody");
//     } catch (e) {
//       print("Exception: $e");
//     } finally {
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }

//   // ================= CHECK PLATFORM =================
//   Future<bool> _isMobilePlatform() async {
//     try {
//       await File('test').exists();
//       return true;
//     } catch (e) {
//       return false;
//     }
//   }

//   // ================= BUILD IMAGE FIELD =================
//   Widget _buildImageField(int index) {
//     return Column(
//       children: [
//         const SizedBox(height: 12),
//         Container(
//           padding: const EdgeInsets.all(12),
//           decoration: BoxDecoration(
//             color: Colors.grey[900],
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: Colors.grey.shade700),
//           ),
//           child: Row(
//             children: [
//               Expanded(
//                 child: GestureDetector(
//                   onTap: () => _pickImage(index),
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(vertical: 16),
//                     decoration: BoxDecoration(
//                       border: Border.all(
//                         color: _images[index] != null
//                             ? Colors.green
//                             : Colors.blueAccent,
//                         width: 2,
//                       ),
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Icon(
//                           _images[index] != null
//                               ? Icons.check_circle
//                               : Icons.add_photo_alternate,
//                           color: _images[index] != null
//                               ? Colors.green
//                               : Colors.blueAccent,
//                           size: 30,
//                         ),
//                         const SizedBox(height: 8),
//                         Text(
//                           _images[index] != null
//                               ? 'Image Selected'
//                               : 'Choose Image',
//                           style: TextStyle(
//                             color: _images[index] != null
//                                 ? Colors.green
//                                 : Colors.blueAccent,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 12),
//               IconButton(
//                 onPressed: () => _removeImageField(index),
//                 icon: const Icon(Icons.delete, color: Colors.red),
//                 style: IconButton.styleFrom(
//                   backgroundColor: Colors.black54,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   // ================= BUILD =================
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         backgroundColor: Colors.black,
//         title: const Text('Create Post', style: TextStyle(color: Colors.white)),
//         leading: IconButton(
//           icon: const Icon(Icons.close, color: Colors.white),
//           onPressed: () => Navigator.pop(context),
//         ),
//       ),
//       body: SingleChildScrollView(
//         physics: const AlwaysScrollableScrollPhysics(),
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Container(
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: Colors.grey[900],
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Title Field
//                   Text(
//                     'Title',
//                     style: TextStyle(
//                       color: Colors.grey[300],
//                       fontSize: 14,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                   TextField(
//                     controller: _titleController,
//                     style: const TextStyle(color: Colors.white),
//                     decoration: InputDecoration(
//                       hintText: "Enter post title",
//                       hintStyle: const TextStyle(color: Colors.white38),
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(8),
//                         borderSide: const BorderSide(color: Colors.grey),
//                       ),
//                       focusedBorder: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(8),
//                         borderSide: const BorderSide(color: Colors.blueAccent),
//                       ),
//                       contentPadding: const EdgeInsets.symmetric(
//                         horizontal: 12,
//                         vertical: 14,
//                       ),
//                     ),
//                     maxLength: 150,
//                   ),
//                   const SizedBox(height: 16),

//                   // Description Field
//                   Text(
//                     'Description',
//                     style: TextStyle(
//                       color: Colors.grey[300],
//                       fontSize: 14,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                   TextField(
//                     controller: _descriptionController,
//                     maxLines: 4,
//                     style: const TextStyle(color: Colors.white),
//                     decoration: InputDecoration(
//                       hintText: "What's on your mind?",
//                       hintStyle: const TextStyle(color: Colors.white38),
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(8),
//                         borderSide: const BorderSide(color: Colors.grey),
//                       ),
//                       focusedBorder: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(8),
//                         borderSide: const BorderSide(color: Colors.blueAccent),
//                       ),
//                       contentPadding: const EdgeInsets.symmetric(
//                         horizontal: 12,
//                         vertical: 14,
//                       ),
//                     ),
//                     maxLength: 5000,
//                   ),
//                   const SizedBox(height: 16),

//                   // ===========================
//                   // ✅ Industry Dropdown (API)
//                   // ===========================
//                   Text(
//                     'Industry *',
//                     style: TextStyle(
//                       color: Colors.grey[300],
//                       fontSize: 14,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                   GestureDetector(
//                     onTap: _isIndustryLoading
//                         ? null
//                         : () {
//                             if (_industryOptions.isEmpty) {
//                               TopAlert.show(context, "No industries found",
//                                   isError: true);
//                               return;
//                             }

//                             showDialog(
//                               context: context,
//                               builder: (context) => AlertDialog(
//                                 backgroundColor: Colors.grey[900],
//                                 title: const Text(
//                                   'Select Industry',
//                                   style: TextStyle(color: Colors.white),
//                                 ),
//                                 content: SizedBox(
//                                   width: double.maxFinite,
//                                   child: ListView.builder(
//                                     shrinkWrap: true,
//                                     itemCount: _industryOptions.length,
//                                     itemBuilder: (context, index) {
//                                       final industry = _industryOptions[index];

//                                       return ListTile(
//                                         title: Text(
//                                           industry['name'],
//                                           style: const TextStyle(
//                                               color: Colors.white),
//                                         ),
//                                         trailing: _selectedIndustryId ==
//                                                 industry['id']
//                                             ? const Icon(Icons.check,
//                                                 color: Colors.blueAccent)
//                                             : null,
//                                         onTap: () {
//                                           setState(() {
//                                             _selectedIndustryId =
//                                                 industry['id'];
//                                             _selectedIndustryName =
//                                                 industry['name'];
//                                           });
//                                           Navigator.pop(context);
//                                         },
//                                       );
//                                     },
//                                   ),
//                                 ),
//                               ),
//                             );
//                           },
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 12,
//                         vertical: 14,
//                       ),
//                       decoration: BoxDecoration(
//                         border: Border.all(
//                           color: _selectedIndustryId != null
//                               ? Colors.blueAccent
//                               : Colors.grey,
//                           width: _selectedIndustryId != null ? 2 : 1,
//                         ),
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       child: Row(
//                         children: [
//                           Icon(
//                             Icons.category,
//                             color: _selectedIndustryId != null
//                                 ? Colors.blueAccent
//                                 : Colors.grey,
//                           ),
//                           const SizedBox(width: 12),
//                           Expanded(
//                             child: Text(
//                               _isIndustryLoading
//                                   ? "Loading industries..."
//                                   : (_selectedIndustryName ??
//                                       'Select Industry'),
//                               style: TextStyle(
//                                 color: _selectedIndustryId != null
//                                     ? Colors.white
//                                     : Colors.white38,
//                                 fontSize: 16,
//                               ),
//                             ),
//                           ),
//                           if (_isIndustryLoading)
//                             const SizedBox(
//                               width: 18,
//                               height: 18,
//                               child: CircularProgressIndicator(strokeWidth: 2),
//                             )
//                           else
//                             const Icon(
//                               Icons.arrow_drop_down,
//                               color: Colors.grey,
//                             ),
//                         ],
//                       ),
//                     ),
//                   ),

//                   // Images Section
//                   const SizedBox(height: 24),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text(
//                         'Images (Max: 5)',
//                         style: TextStyle(
//                           color: Colors.grey[300],
//                           fontSize: 16,
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                       if (_images.length < 5)
//                         IconButton(
//                           onPressed: _addImageField,
//                           icon: const Icon(
//                             Icons.add_circle,
//                             color: Colors.blueAccent,
//                             size: 30,
//                           ),
//                           tooltip: 'Add image field',
//                         ),
//                     ],
//                   ),

//                   // Image Fields
//                   if (_images.isEmpty)
//                     Column(
//                       children: [
//                         const SizedBox(height: 12),
//                         GestureDetector(
//                           onTap: _addImageField,
//                           child: Container(
//                             padding: const EdgeInsets.symmetric(vertical: 20),
//                             decoration: BoxDecoration(
//                               border: Border.all(
//                                 color: Colors.blueAccent,
//                                 width: 2,
//                               ),
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                             child: Column(
//                               children: [
//                                 Icon(
//                                   Icons.add_photo_alternate,
//                                   color: Colors.blueAccent,
//                                   size: 40,
//                                 ),
//                                 const SizedBox(height: 8),
//                                 Text(
//                                   'Add Image',
//                                   style: TextStyle(
//                                     color: Colors.blueAccent,
//                                     fontSize: 16,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ],
//                     )
//                   else
//                     Column(
//                       children: List.generate(
//                         _images.length,
//                         (index) => _buildImageField(index),
//                       ),
//                     ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 40),
//           ],
//         ),
//       ),
//       floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
//       floatingActionButton: Container(
//         margin: const EdgeInsets.only(bottom: 20, right: 20),
//         child: FloatingActionButton.extended(
//           onPressed: _isLoading ? null : _submitPost,
//           backgroundColor: Colors.blueAccent,
//           foregroundColor: Colors.white,
//           icon: _isLoading
//               ? const CupertinoActivityIndicator(color: Colors.white)
//               : const Icon(Icons.send),
//           label: _isLoading ? const Text('Posting...') : const Text('Post'),
//         ),
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _titleController.dispose();
//     _descriptionController.dispose();
//     super.dispose();
//   }
// }

//=====================================================================================

import 'dart:io';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:gridcard/widgets/top_alert.dart';

class PostCreationPage extends StatefulWidget {
  const PostCreationPage({super.key});

  @override
  State<PostCreationPage> createState() => _PostCreationPageState();
}

class _PostCreationPageState extends State<PostCreationPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  final List<XFile?> _images = [];
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;

  List<Map<String, dynamic>> _industryOptions = [];
  bool _isIndustryLoading = false;

  int? _selectedIndustryId;
  String? _selectedIndustryName;

  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, String>> _getHeadersMultipart() async {
    final token = await UserStorageService().getToken();

    return {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  void _openIndustrySelector() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _industryOptions.length,
          itemBuilder: (context, index) {
            final item = _industryOptions[index];

            return ListTile(
              leading: const Icon(Icons.business),
              title: Text(item["name"]),
              trailing: _selectedIndustryId == item["id"]
                  ? Icon(Icons.check, color: colorScheme.primary)
                  : null,
              onTap: () {
                setState(() {
                  _selectedIndustryId = item["id"];
                  _selectedIndustryName = item["name"];
                });

                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }

  Future<void> _fetchIndustries() async {
    setState(() => _isIndustryLoading = true);

    try {
      final headers = await _getHeaders();
      final uri = Uri.parse("${AppConfig.apiBaseUrl}/industries");

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        if (jsonData["status"] == true) {
          final List data = jsonData["data"];

          setState(() {
            _industryOptions = data.map((item) {
              return {
                "id": item["id"],
                "name": item["title"],
                "icons": item["icons"],
              };
            }).toList();
          });
        }
      }
    } catch (e) {
      TopAlert.show(context, "Network error while loading industries",
          isError: true);
    } finally {
      if (mounted) setState(() => _isIndustryLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchIndustries();
  }

  Future<void> _pickImage(int index) async {
    final XFile? selected =
        await _picker.pickImage(source: ImageSource.gallery);
    if (selected != null) {
      setState(() {
        if (_images.length > index) {
          _images[index] = selected;
        } else {
          _images.add(selected);
        }
      });
    }
  }

  void _addImageField() {
    if (_images.length < 5) {
      setState(() {
        _images.add(null);
      });
    } else {
      TopAlert.show(context, 'Maximum 5 images allowed', isError: true);
    }
  }

  void _removeImageField(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  // Future<void> _submitPost() async {
  //   if (_selectedIndustryId == null) {
  //     TopAlert.show(context, "Please select industry", isError: true);
  //     return;
  //   }

  //   setState(() => _isLoading = true);

  //   try {
  //     final headers = await _getHeadersMultipart();

  //     var request = http.MultipartRequest(
  //       "POST",
  //       Uri.parse("${AppConfig.apiBaseUrl}/posts/create"),
  //     );

  //     request.headers.addAll(headers);

  //     request.fields["title"] = _titleController.text;
  //     request.fields["description"] = _descriptionController.text;
  //     request.fields["industry_id"] = _selectedIndustryId.toString();

  //     for (int i = 0; i < _images.length; i++) {
  //       if (_images[i] != null) {
  //         final bytes = await _images[i]!.readAsBytes();

  //         request.files.add(
  //           http.MultipartFile.fromBytes(
  //             "images[]",
  //             bytes,
  //             filename: _images[i]!.name,
  //           ),
  //         );
  //       }
  //     }

  //     final streamedResponse = await request.send();
  //     await streamedResponse.stream.bytesToString();
  //   } catch (e) {
  //     print(e);
  //   } finally {
  //     if (mounted) setState(() => _isLoading = false);
  //   }
  // }

  Future<void> _submitPost() async {
    if (_selectedIndustryId == null) {
      TopAlert.show(context, "Please select industry", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final headers = await _getHeadersMultipart();

      var request = http.MultipartRequest(
        "POST",
        Uri.parse("${AppConfig.apiBaseUrl}/posts/create"),
      );

      request.headers.addAll(headers);

      request.fields["title"] = _titleController.text;
      request.fields["description"] = _descriptionController.text;
      request.fields["industry_id"] = _selectedIndustryId.toString();

      for (int i = 0; i < _images.length; i++) {
        if (_images[i] != null) {
          final bytes = await _images[i]!.readAsBytes();

          request.files.add(
            http.MultipartFile.fromBytes(
              "images[]",
              bytes,
              filename: _images[i]!.name,
            ),
          );
        }
      }

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      final json = jsonDecode(responseBody);

      if (!mounted) return;

      if (streamedResponse.statusCode == 200 && json["status"] == true) {
        /// ✅ SUCCESS MESSAGE
        TopAlert.show(
          context,
          json["message"] ?? "Post created successfully",
          isSuccess: true,
        );

        /// clear form
        _titleController.clear();
        _descriptionController.clear();

        setState(() {
          _images.clear();
          _selectedIndustryId = null;
          _selectedIndustryName = null;
        });

        /// ✅ CLOSE PAGE AFTER 800ms
        // Future.delayed(const Duration(milliseconds: 800), () {
        //   if (mounted) {
        //     Navigator.pop(context);
        //   }
        // });

        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            Navigator.pop(context, json["data"]["id"]);
          }
        });
      } else {
        /// ❌ ERROR MESSAGE
        TopAlert.show(
          context,
          json["message"] ?? "Failed to create post",
          isError: true,
        );
      }
    } catch (e) {
      TopAlert.show(
        context,
        "Something went wrong",
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildImageField(int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? colorScheme.surfaceContainerHighest : null,
            borderRadius: BorderRadius.circular(12),
            border:
                isDark ? null : Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickImage(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _images[index] != null
                            ? Colors.green
                            : colorScheme.primary,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _images[index] != null
                              ? Icons.check_circle
                              : Icons.add_photo_alternate,
                          color: _images[index] != null
                              ? Colors.green
                              : colorScheme.primary,
                          size: 30,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _images[index] != null
                              ? 'Image Selected'
                              : 'Choose Image',
                          style: TextStyle(
                            color: _images[index] != null
                                ? Colors.green
                                : colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => _removeImageField(index),
                icon: const Icon(Icons.delete, color: Colors.red),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title: Text(
          'Create Post',
          style: TextStyle(color: colorScheme.onSurface),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? colorScheme.surfaceContainerHighest : null,
                borderRadius: BorderRadius.circular(12),
                border: isDark
                    ? null
                    : Border.all(color: colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Title",
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // TextField(
                  //   controller: _titleController,
                  //   style: TextStyle(color: colorScheme.onSurface),
                  //   decoration: InputDecoration(
                  //     hintText: "Enter post title",
                  //     hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                  //     filled: true,
                  //     fillColor:
                  //         isDark ? colorScheme.surfaceContainerHighest : null,
                  //     border: OutlineInputBorder(
                  //       borderRadius: BorderRadius.circular(8),
                  //       borderSide:
                  //           isDark ? BorderSide.none : const BorderSide(),
                  //     ),
                  //     enabledBorder: OutlineInputBorder(
                  //       borderRadius: BorderRadius.circular(8),
                  //       borderSide: isDark
                  //           ? BorderSide.none
                  //           : BorderSide(color: colorScheme.outline),
                  //     ),
                  //   ),
                  // ),
                  TextField(
                    controller: _titleController,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: "Enter post title",
                      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                      filled: true,
                      fillColor:
                          isDark ? colorScheme.surfaceContainerHighest : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Description",
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // TextField(
                  //   controller: _descriptionController,
                  //   maxLines: 4,
                  //   style: TextStyle(color: colorScheme.onSurface),
                  //   decoration: InputDecoration(
                  //     hintText: "What's on your mind?",
                  //     hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                  //     filled: true,
                  //     fillColor:
                  //         isDark ? colorScheme.surfaceContainerHighest : null,
                  //     border: OutlineInputBorder(
                  //       borderRadius: BorderRadius.circular(8),
                  //       borderSide:
                  //           isDark ? BorderSide.none : const BorderSide(),
                  //     ),
                  //     enabledBorder: OutlineInputBorder(
                  //       borderRadius: BorderRadius.circular(8),
                  //       borderSide: isDark
                  //           ? BorderSide.none
                  //           : BorderSide(color: colorScheme.outline),
                  //     ),
                  //   ),
                  // ),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 4,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: "What's on your mind?",
                      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                      filled: true,
                      fillColor:
                          isDark ? colorScheme.surfaceContainerHighest : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Industry",
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _isIndustryLoading ? null : _openIndustrySelector,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        color:
                            isDark ? colorScheme.surfaceContainerHighest : null,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedIndustryId != null
                              ? colorScheme.primary
                              : colorScheme.outline,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.category,
                            color: _selectedIndustryId != null
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _selectedIndustryName ?? "Select Industry",
                              style: TextStyle(
                                color: _selectedIndustryId != null
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Images (Max:5)',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_images.length < 5)
                        IconButton(
                          onPressed: _addImageField,
                          icon: Icon(Icons.add_circle,
                              color: colorScheme.primary),
                        ),
                    ],
                  ),
                  if (_images.isEmpty)
                    GestureDetector(
                      onTap: _addImageField,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: colorScheme.primary,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.add_photo_alternate,
                                color: colorScheme.primary, size: 40),
                            const SizedBox(height: 8),
                            Text(
                              'Add Image',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Column(
                      children: List.generate(
                        _images.length,
                        (index) => _buildImageField(index),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _submitPost,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        icon: _isLoading
            ? const CupertinoActivityIndicator(color: Colors.white)
            : const Icon(Icons.send),
        label: _isLoading ? const Text('Posting...') : const Text('Post'),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
