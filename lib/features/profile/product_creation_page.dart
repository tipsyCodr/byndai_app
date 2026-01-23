import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/core/services/product_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class ProductCreationPage extends StatefulWidget {
  const ProductCreationPage({super.key});

  @override
  State<ProductCreationPage> createState() => _ProductCreationPageState();
}

class _ProductCreationPageState extends State<ProductCreationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<TextEditingController> _linkControllers = [
    TextEditingController()
  ];
  final List<File> _images = [];
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImages() async {
    final List<XFile> selected = await _picker.pickMultiImage();
    if (selected.isNotEmpty) {
      setState(() {
        _images.addAll(selected.map((e) => File(e.path)));
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  void _addLinkField() {
    setState(() {
      _linkControllers.add(TextEditingController());
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ProductProvider>();
    final links = _linkControllers
        .map((c) => c.text)
        .where((text) => text.isNotEmpty)
        .toList();

    final success = await provider.createProduct(
      name: _nameController.text,
      price: double.tryParse(_priceController.text) ?? 0.0,
      description: _descriptionController.text,
      files: _images,
      links: links,
    );

    if (mounted && success) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<ProductProvider>().isLoading;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.primary),
        title:
            Text('Add Product', style: TextStyle(color: colorScheme.primary)),
        actions: [
          TextButton(
            onPressed: isLoading ? null : _submit,
            child: isLoading
                ? CupertinoActivityIndicator(color: colorScheme.primary)
                : Text('Save',
                    style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel(context, 'Product Images'),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    GestureDetector(
                      onTap: _pickImages,
                      child: Container(
                        width: 100,
                        decoration: BoxDecoration(
                          color: isDark
                              ? colorScheme.surfaceContainerHighest
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: colorScheme.onSurface.withOpacity(0.05)),
                        ),
                        child:
                            Icon(Icons.add_a_photo, color: colorScheme.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ..._images.asMap().entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(entry.value,
                                  width: 100, height: 100, fit: BoxFit.cover),
                            ),
                            Positioned(
                              right: 4,
                              top: 4,
                              child: GestureDetector(
                                onTap: () => _removeImage(entry.key),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildTextField(context, _nameController, 'Product Name',
                  'Enter product name'),
              const SizedBox(height: 16),
              _buildTextField(context, _priceController, 'Price', 'Enter price',
                  keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              _buildTextField(context, _descriptionController, 'Description',
                  'Enter product description',
                  maxLines: 3),
              const SizedBox(height: 24),
              _buildLabel(context, 'Product Links'),
              const SizedBox(height: 8),
              ..._linkControllers.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: TextField(
                    controller: entry.value,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Link URL',
                      hintStyle: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.2)),
                      filled: true,
                      fillColor: isDark
                          ? colorScheme.surfaceContainerHighest
                          : Colors.grey[100],
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                  ),
                );
              }),
              TextButton.icon(
                onPressed: _addLinkField,
                icon: Icon(Icons.add, size: 20, color: colorScheme.primary),
                label: Text('Add Another Link',
                    style: TextStyle(color: colorScheme.primary)),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(BuildContext context, String text) {
    return Text(text,
        style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            fontSize: 14,
            fontWeight: FontWeight.bold));
  }

  Widget _buildTextField(BuildContext context, TextEditingController controller,
      String label, String hint,
      {TextInputType? keyboardType, int maxLines = 1}) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(context, label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: TextStyle(color: colorScheme.onSurface),
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: (value) =>
              value == null || value.isEmpty ? 'This field is required' : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.2)),
            filled: true,
            fillColor:
                isDark ? colorScheme.surfaceContainerHighest : Colors.grey[100],
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}
