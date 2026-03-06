import 'dart:io';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:gridcard/widgets/top_alert.dart';

class EditPostPage extends StatefulWidget {
  final Map<String, dynamic> post;

  const EditPostPage({super.key, required this.post});

  @override
  State<EditPostPage> createState() => _EditPostPageState();
}

class _EditPostPageState extends State<EditPostPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  // Existing images from the post (with id and url)
  final List<Map<String, dynamic>> _existingImages = [];

  // New images picked by user
  final List<XFile?> _newImages = [];

  // Track removed existing image IDs (to send to backend)
  final List<int> _removedImageIds = [];

  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  bool _isIndustryLoading = false;

  // Industry options
  List<Map<String, dynamic>> _industryOptions = [];
  int? _selectedIndustryId;
  String? _selectedIndustryName;

  @override
  void initState() {
    super.initState();

    // Initialize controllers with existing data
    _titleController = TextEditingController(text: widget.post['title'] ?? '');
    _descriptionController =
        TextEditingController(text: widget.post['description'] ?? '');

    // Load existing images from post media
    final media = widget.post['media'] as List? ?? [];
    for (var item in media) {
      if (item['media_type'] == 'image') {
        _existingImages.add({
          'id': item['id'],
          'url': item['media_url'],
        });
      }
    }

    // Set selected industry
    _selectedIndustryId = widget.post['industry_id'];
    _selectedIndustryName = widget.post['industry_title'];

    // Fetch industries for dropdown
    _fetchIndustries();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ================= HEADERS =================
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

  // ===========================
  // ✅ FETCH INDUSTRIES API
  // ===========================
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
      debugPrint("Fetch industries error: $e");
    } finally {
      if (mounted) setState(() => _isIndustryLoading = false);
    }
  }

  // ================= IMAGE PICKING =================
  Future<void> _pickNewImage() async {
    final XFile? selected =
        await _picker.pickImage(source: ImageSource.gallery);
    if (selected != null) {
      setState(() {
        _newImages.add(selected);
      });
    }
  }

  // ================= REMOVE EXISTING IMAGE =================
  void _removeExistingImage(int index) {
    final imageId = _existingImages[index]['id'];
    setState(() {
      _removedImageIds.add(imageId);
      _existingImages.removeAt(index);
    });
  }

  // ================= REMOVE NEW IMAGE =================
  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
    });
  }

  // ================= SUBMIT UPDATE =================
  Future<void> _updatePost() async {
    // Validate industry
    if (_selectedIndustryId == null) {
      TopAlert.show(context, "Please select industry", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final headers = await _getHeadersMultipart();
      final postId = widget.post['id'];

      var request = http.MultipartRequest(
        "POST",
        Uri.parse("${AppConfig.apiBaseUrl}/posts/update/$postId"),
      );

      request.headers.addAll(headers);

      // Text fields
      request.fields["title"] = _titleController.text;
      request.fields["description"] = _descriptionController.text;
      request.fields["industry_id"] = _selectedIndustryId.toString();

      // Send IDs of existing images to keep (those not removed)
      final keepImageIds =
          _existingImages.map((img) => img['id'].toString()).toList();
      for (var id in keepImageIds) {
        request.fields["existing_images[]"] = id;
      }

      // Send new images as files
      for (var image in _newImages) {
        if (image != null) {
          final bytes = await image.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              "new_images[]",
              bytes,
              filename: image.name,
            ),
          );
        }
      }

      // Send removed image IDs (optional, if backend needs explicit removal)
      for (var id in _removedImageIds) {
        request.fields["removed_images[]"] = id.toString();
      }

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final jsonResponse = jsonDecode(responseBody);
        if (jsonResponse["status"] == true) {
          // Success - return updated post data
          final updatedPost = jsonResponse["data"] ?? widget.post;
          TopAlert.show(context, "Post updated successfully", isSuccess: true);
          Navigator.pop(context, updatedPost);
        } else {
          throw Exception(jsonResponse["message"] ?? "Update failed");
        }
      } else {
        throw Exception("Server error: ${streamedResponse.statusCode}");
      }
    } catch (e) {
      debugPrint("Update error: $e");
      TopAlert.show(context, "Failed to update: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Edit Post', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    onTap: _isIndustryLoading
                        ? null
                        : () {
                            if (_industryOptions.isEmpty) {
                              TopAlert.show(context, "No industries found",
                                  isError: true);
                              return;
                            }

                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: Colors.grey[900],
                                title: const Text(
                                  'Select Industry',
                                  style: TextStyle(color: Colors.white),
                                ),
                                content: SizedBox(
                                  width: double.maxFinite,
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _industryOptions.length,
                                    itemBuilder: (context, index) {
                                      final industry = _industryOptions[index];
                                      return ListTile(
                                        title: Text(
                                          industry['name'],
                                          style: const TextStyle(
                                              color: Colors.white),
                                        ),
                                        trailing: _selectedIndustryId ==
                                                industry['id']
                                            ? const Icon(Icons.check,
                                                color: Colors.blueAccent)
                                            : null,
                                        onTap: () {
                                          setState(() {
                                            _selectedIndustryId =
                                                industry['id'];
                                            _selectedIndustryName =
                                                industry['name'];
                                          });
                                          Navigator.pop(context);
                                        },
                                      );
                                    },
                                  ),
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
                              _isIndustryLoading
                                  ? "Loading industries..."
                                  : (_selectedIndustryName ??
                                      'Select Industry'),
                              style: TextStyle(
                                color: _selectedIndustryId != null
                                    ? Colors.white
                                    : Colors.white38,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (_isIndustryLoading)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            const Icon(
                              Icons.arrow_drop_down,
                              color: Colors.grey,
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Images Section
                  Text(
                    'Images',
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Existing images
                  if (_existingImages.isNotEmpty) ...[
                    const Text(
                      'Current Images',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    ..._existingImages.asMap().entries.map((entry) {
                      final index = entry.key;
                      final image = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[850],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _fullUrl(image['url']),
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, st) => Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[700],
                                  child: const Icon(Icons.broken_image),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Image ${index + 1}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeExistingImage(index),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  // New images
                  if (_newImages.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'New Images',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    ..._newImages.asMap().entries.map((entry) {
                      final index = entry.key;
                      final image = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[850],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              // child: Image.file(
                              //   File(image!.path),
                              //   width: 60,
                              //   height: 60,
                              //   fit: BoxFit.cover,
                              //   errorBuilder: (ctx, err, st) => Container(
                              //     width: 60,
                              //     height: 60,
                              //     color: Colors.grey[700],
                              //     child: const Icon(Icons.broken_image),
                              //   ),
                              // ),
                              child: FutureBuilder<Uint8List>(
                                future: image!.readAsBytes(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                          ConnectionState.done &&
                                      snapshot.hasData) {
                                    return Image.memory(
                                      snapshot.data!,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                    );
                                  } else {
                                    return Container(
                                      width: 60,
                                      height: 60,
                                      color: Colors.grey[700],
                                      child: const Center(
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2)),
                                    );
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'New Image ${index + 1}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeNewImage(index),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  // Add image button
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _pickNewImage,
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('Add Image'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 45),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 20, right: 20),
        child: FloatingActionButton.extended(
          onPressed: _isLoading ? null : _updatePost,
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          icon: _isLoading
              ? const CupertinoActivityIndicator(color: Colors.white)
              : const Icon(Icons.save),
          label: _isLoading ? const Text('Updating...') : const Text('Update'),
        ),
      ),
    );
  }

  // Helper to build full URL for existing images...
  String _fullUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    // Assuming base URL is same as used in PostCard
    // const base = "https://byndai.in/";
    const base = AppConfig.imageBaseUrl;

    if (path.startsWith('/')) {
      return base + path;
    } else {
      return '$base/$path';
    }
  }
}
