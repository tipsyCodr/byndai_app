import 'dart:io';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class PostCreationPage extends StatefulWidget {
  const PostCreationPage({super.key});

  @override
  State<PostCreationPage> createState() => _PostCreationPageState();
}

class _PostCreationPageState extends State<PostCreationPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // final List<File?> _images = [];
  // final List<File?> _videos = [];

  final List<XFile?> _images = [];
  final List<XFile?> _videos = [];

  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;

  // Industry options
  final List<Map<String, dynamic>> _industryOptions = [
    {'id': 1, 'name': 'Technology'},
    {'id': 2, 'name': 'Healthcare'},
    {'id': 3, 'name': 'Education'},
    // Add more industries as needed
  ];

  int? _selectedIndustryId;
  String? _selectedIndustryName;

  // ================= HEADERS =================
  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ================= IMAGE PICKING =================
 

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

  // ================= VIDEO PICKING =================
  

  Future<void> _pickVideo(int index) async {
    final XFile? selected =
        await _picker.pickVideo(source: ImageSource.gallery);
    if (selected != null) {
      setState(() {
        if (_videos.length > index) {
          _videos[index] = selected;
        } else {
          _videos.add(selected);
        }
      });
    }
  }

  // ================= ADD IMAGE FIELD =================
  void _addImageField() {
    if (_images.length < 5) {
      setState(() {
        _images.add(null);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 5 images allowed')),
      );
    }
  }

  // ================= REMOVE IMAGE FIELD =================
  void _removeImageField(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  // ================= ADD VIDEO FIELD =================
  void _addVideoField() {
    if (_videos.length < 2) {
      setState(() {
        _videos.add(null);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 2 videos allowed')),
      );
    }
  }

  // ================= REMOVE VIDEO FIELD =================
  void _removeVideoField(int index) {
    setState(() {
      _videos.removeAt(index);
    });
  }

  // ================= PRINT REQUEST DATA =================
  void _printRequestData() {
    print('================== POST REQUEST DATA ==================');
    print('Title: ${_titleController.text}');
    print('Description: ${_descriptionController.text}');
    print('Industry ID: $_selectedIndustryId');
    print('Industry Name: $_selectedIndustryName');
    print('Number of Images: ${_images.length}');

    for (int i = 0; i < _images.length; i++) {
      if (_images[i] != null) {
        print('Image $i: ${_images[i]!.path}');
      } else {
        print('Image $i: Not selected');
      }
    }

    print('Number of Videos: ${_videos.length}');
    for (int i = 0; i < _videos.length; i++) {
      if (_videos[i] != null) {
        print('Video $i: ${_videos[i]!.path}');
      } else {
        print('Video $i: Not selected');
      }
    }
    print('========================================================');
  }

  // ================= SUBMIT POST =================


  Future<Map<String, String>> _getHeadersMultipart() async {
    final token = await UserStorageService().getToken();

    return {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _submitPost() async {
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

      // ✅ Images
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

      // ✅ Videos
      for (int i = 0; i < _videos.length; i++) {
        if (_videos[i] != null) {
          final bytes = await _videos[i]!.readAsBytes();

          request.files.add(
            http.MultipartFile.fromBytes(
              "videos[]",
              bytes,
              filename: _videos[i]!.name,
            ),
          );
        }
      }

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      print("Response Status Code: ${streamedResponse.statusCode}");
      print("Response Body: $responseBody");
    } catch (e) {
      print("Exception: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ================= CHECK PLATFORM =================
  Future<bool> _isMobilePlatform() async {
    try {
      // Try to access platform-specific features
      await File('test').exists();
      return true; // Mobile platform
    } catch (e) {
      return false; // Web platform
    }
  }

  // ================= BUILD IMAGE FIELD =================
  Widget _buildImageField(int index) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade700),
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
                            : Colors.blueAccent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _images[index] != null
                              ? Icons.check_circle
                              : Icons.add_photo_alternate,
                          color: _images[index] != null
                              ? Colors.green
                              : Colors.blueAccent,
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
                                : Colors.blueAccent,
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
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ================= BUILD VIDEO FIELD =================
  Widget _buildVideoField(int index) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade700),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickVideo(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _videos[index] != null
                            ? Colors.green
                            : Colors.blueAccent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _videos[index] != null
                              ? Icons.check_circle
                              : Icons.video_library,
                          color: _videos[index] != null
                              ? Colors.green
                              : Colors.blueAccent,
                          size: 30,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _videos[index] != null
                              ? 'Video Selected'
                              : 'Choose Video',
                          style: TextStyle(
                            color: _videos[index] != null
                                ? Colors.green
                                : Colors.blueAccent,
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
                onPressed: () => _removeVideoField(index),
                icon: const Icon(Icons.delete, color: Colors.red),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Create Post', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Container with form fields
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Field
                  Text(
                    'Title',
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Enter post title",
                      hintStyle: const TextStyle(color: Colors.white38),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.blueAccent),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    maxLength: 150,
                  ),
                  const SizedBox(height: 16),

                  // Description Field
                  Text(
                    'Description',
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "What's on your mind?",
                      hintStyle: const TextStyle(color: Colors.white38),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.blueAccent),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    maxLength: 5000,
                  ),
                  const SizedBox(height: 16),

                  // Industry Dropdown
                  Text(
                    'Industry *',
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      // Show industry selection dialog
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: Colors.grey[900],
                          title: const Text(
                            'Select Industry',
                            style: TextStyle(color: Colors.white),
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: _industryOptions.map((industry) {
                              return ListTile(
                                title: Text(
                                  industry['name'],
                                  style: const TextStyle(color: Colors.white),
                                ),
                                trailing: _selectedIndustryId == industry['id']
                                    ? const Icon(Icons.check,
                                        color: Colors.blueAccent)
                                    : null,
                                onTap: () {
                                  setState(() {
                                    _selectedIndustryId = industry['id'];
                                    _selectedIndustryName = industry['name'];
                                  });
                                  Navigator.pop(context);
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _selectedIndustryId != null
                              ? Colors.blueAccent
                              : Colors.grey,
                          width: _selectedIndustryId != null ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.category,
                            color: _selectedIndustryId != null
                                ? Colors.blueAccent
                                : Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedIndustryName ?? 'Select Industry',
                              style: TextStyle(
                                color: _selectedIndustryId != null
                                    ? Colors.white
                                    : Colors.white38,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Images Section
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Images (Max: 5)',
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_images.length < 5)
                        IconButton(
                          onPressed: _addImageField,
                          icon: const Icon(
                            Icons.add_circle,
                            color: Colors.blueAccent,
                            size: 30,
                          ),
                          tooltip: 'Add image field',
                        ),
                    ],
                  ),

                  // Image Fields
                  if (_images.isEmpty)
                    Column(
                      children: [
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: _addImageField,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.blueAccent,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.add_photo_alternate,
                                  color: Colors.blueAccent,
                                  size: 40,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Add Image',
                                  style: TextStyle(
                                    color: Colors.blueAccent,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: List.generate(
                        _images.length,
                        (index) => _buildImageField(index),
                      ),
                    ),

                  // Videos Section
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Videos (Max: 2)',
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_videos.length < 2)
                        IconButton(
                          onPressed: _addVideoField,
                          icon: const Icon(
                            Icons.add_circle,
                            color: Colors.blueAccent,
                            size: 30,
                          ),
                          tooltip: 'Add video field',
                        ),
                    ],
                  ),

                  // Video Fields
                  if (_videos.isEmpty)
                    Column(
                      children: [
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: _addVideoField,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.blueAccent,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.video_library,
                                  color: Colors.blueAccent,
                                  size: 40,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Add Video',
                                  style: TextStyle(
                                    color: Colors.blueAccent,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: List.generate(
                        _videos.length,
                        (index) => _buildVideoField(index),
                      ),
                    ),
                ],
              ),
            ),

            // Spacing
            const SizedBox(height: 40),
          ],
        ),
      ),

      // Bottom Post Button
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 20, right: 20),
        child: FloatingActionButton.extended(
          onPressed: _isLoading ? null : _submitPost,
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          icon: _isLoading
              ? const CupertinoActivityIndicator(color: Colors.white)
              : const Icon(Icons.send),
          label: _isLoading ? const Text('Posting...') : const Text('Post'),
        ),
      ),
    );
  }
}
