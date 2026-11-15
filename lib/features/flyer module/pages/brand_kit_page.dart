import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gridcard/core/services/ai_flyer_service.dart';

class BrandKitPage extends StatefulWidget {
  const BrandKitPage({super.key});

  @override
  State<BrandKitPage> createState() => _BrandKitPageState();
}

class _BrandKitPageState extends State<BrandKitPage> {
  bool _isLoading = true;
  bool _isSaving = false;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _taglineController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _addressController = TextEditingController();

  Color _primaryColor = const Color(0xFF6366F1);
  Color _secondaryColor = const Color(0xFF10B981);
  String? _existingLogoUrl;
  File? _newLogoFile;

  @override
  void initState() {
    super.initState();
    _loadBrandKit();
  }

  Future<void> _loadBrandKit() async {
    setState(() => _isLoading = true);
    try {
      final kit = await AiFlyerService.getBrandKit();
      if (kit.isNotEmpty) {
        _nameController.text = kit['business_name'] ?? '';
        _taglineController.text = kit['tagline'] ?? '';
        _phoneController.text = kit['phone'] ?? '';
        _whatsappController.text = kit['whatsapp'] ?? '';
        _emailController.text = kit['email'] ?? '';
        _websiteController.text = kit['website'] ?? '';
        _addressController.text = kit['address'] ?? '';
        _existingLogoUrl = kit['logo_url'];

        if (kit['primary_color'] != null && kit['primary_color'].toString().isNotEmpty) {
          _primaryColor = _hexToColor(kit['primary_color']);
        }
        if (kit['secondary_color'] != null && kit['secondary_color'].toString().isNotEmpty) {
          _secondaryColor = _hexToColor(kit['secondary_color']);
        }
      }
    } catch (e) {
      debugPrint('Error loading brand kit: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.tryParse(hex, radix: 16) ?? 0xFF6366F1);
  }

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() => _newLogoFile = File(picked.path));
    }
  }

  void _showColorPicker({required bool isPrimary}) {
    Color currentColor = isPrimary ? _primaryColor : _secondaryColor;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isPrimary ? 'Pick Primary Color' : 'Pick Secondary Color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: currentColor,
            onColorChanged: (c) => currentColor = c,
            paletteType: PaletteType.hsvWithHue,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              setState(() {
                if (isPrimary) {
                  _primaryColor = currentColor;
                } else {
                  _secondaryColor = currentColor;
                }
              });
              Navigator.pop(ctx);
            },
            child: const Text('Select'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveBrandKit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final fields = {
        'business_name': _nameController.text.trim(),
        'tagline': _taglineController.text.trim(),
        'phone': _phoneController.text.trim(),
        'whatsapp': _whatsappController.text.trim(),
        'email': _emailController.text.trim(),
        'website': _websiteController.text.trim(),
        'address': _addressController.text.trim(),
        'primary_color': _colorToHex(_primaryColor),
        'secondary_color': _colorToHex(_secondaryColor),
      };

      await AiFlyerService.updateBrandKit(fields: fields, logoFile: _newLogoFile);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Brand Kit saved successfully!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving Brand Kit: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Brand Kit & Identity', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Save once! Your brand details, logo, and brand colors will automatically be applied to every AI-generated flyer.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Logo Uploader
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.cardTheme.color,
                              border: Border.all(color: theme.colorScheme.outlineVariant, width: 2),
                              image: _newLogoFile != null
                                  ? DecorationImage(image: FileImage(_newLogoFile!), fit: BoxFit.cover)
                                  : (_existingLogoUrl != null && _existingLogoUrl!.isNotEmpty)
                                      ? DecorationImage(image: NetworkImage(_existingLogoUrl!), fit: BoxFit.cover)
                                      : null,
                            ),
                            child: (_newLogoFile == null && (_existingLogoUrl == null || _existingLogoUrl!.isEmpty))
                                ? Icon(Icons.business_outlined, size: 48, color: theme.disabledColor)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: InkWell(
                              onTap: _pickLogo,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Business Logo',
                        style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Brand Colors
                    Text('Brand Colors', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _showColorPicker(isPrimary: true),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.cardTheme.color,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: theme.colorScheme.outlineVariant),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: _primaryColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Primary', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                      Text(_colorToHex(_primaryColor), style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _showColorPicker(isPrimary: false),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.cardTheme.color,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: theme.colorScheme.outlineVariant),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: _secondaryColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Secondary', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                      Text(_colorToHex(_secondaryColor), style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Business Info Fields
                    Text('Business Information', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Business Name *',
                        prefixIcon: const Icon(Icons.storefront_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter business name' : null,
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _taglineController,
                      decoration: InputDecoration(
                        labelText: 'Tagline / Category',
                        hintText: 'e.g. Premium Real Estate & Interiors',
                        prefixIcon: const Icon(Icons.short_text),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Call Phone',
                              prefixIcon: const Icon(Icons.call_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _whatsappController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'WhatsApp',
                              prefixIcon: const Icon(Icons.chat_bubble_outline),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: const Icon(Icons.mail_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _websiteController,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        labelText: 'Website URL',
                        hintText: 'e.g. www.mybrand.in',
                        prefixIcon: const Icon(Icons.language_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Business Address',
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _isSaving ? null : _saveBrandKit,
                        icon: _isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_rounded),
                        label: Text(_isSaving ? 'Saving...' : 'Save Brand Kit', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}
