import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/core/services/social_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class PostCreationPage extends StatefulWidget {
  final String industryType;
  const PostCreationPage({super.key, required this.industryType});

  @override
  State<PostCreationPage> createState() => _PostCreationPageState();
}

class _PostCreationPageState extends State<PostCreationPage> {
  final TextEditingController _descriptionController = TextEditingController();
  File? _image;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? selected =
        await _picker.pickImage(source: ImageSource.gallery);
    if (selected != null) {
      setState(() {
        _image = File(selected.path);
      });
    }
  }

  Future<void> _submit() async {
    if (_descriptionController.text.isEmpty && _image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a description or an image')),
      );
      return;
    }

    final success = await context.read<SocialProvider>().createPost(
          _descriptionController.text,
          _image,
          widget.industryType,
        );

    if (success && mounted) {
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create post')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<SocialProvider>().isLoading;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Create Post', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: isLoading ? null : _submit,
            child: isLoading
                ? const CupertinoActivityIndicator(color: Colors.white)
                : const Text('Post',
                    style: TextStyle(
                        color: Colors.blueAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _descriptionController,
              maxLines: null,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "What's on your mind?",
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 20),
            if (_image != null)
              Stack(
                children: [
                  Image.file(_image!,
                      height: 300, width: double.infinity, fit: BoxFit.cover),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => setState(() => _image = null),
                      style:
                          IconButton.styleFrom(backgroundColor: Colors.black54),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.image, color: Colors.blueAccent),
              title: const Text('Add Photo',
                  style: TextStyle(color: Colors.white)),
              onTap: _pickImage,
              tileColor: Colors.grey[900],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ],
        ),
      ),
    );
  }
}
