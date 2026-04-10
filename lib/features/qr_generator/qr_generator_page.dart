import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:gridcard/widgets/top_alert.dart';
import 'package:gridcard/widgets/glass_box.dart';

// ignore: avoid_web_libraries_in_flutter
// import 'dart:html' as html;

import 'package:universal_html/html.dart' as html;

class QrGeneratorPage extends StatefulWidget {
  const QrGeneratorPage({super.key});

  @override
  State<QrGeneratorPage> createState() => _QrGeneratorPageState();
}

enum QrType { link, whatsapp, email, text, wifi }

class _QrGeneratorPageState extends State<QrGeneratorPage> {
  final GlobalKey _previewKey = GlobalKey();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();

  // New Controllers for varied types
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _wifiSsidController = TextEditingController();
  final TextEditingController _wifiPasswordController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  QrType _selectedType = QrType.link;
  Uint8List? _generatedImage;
  bool _isGenerating = false;
  bool _showPreview = false;
  String _currentTitle = "";
  String _currentData = "";

  late ImageProvider _logoImage;

  @override
  void initState() {
    super.initState();
    _logoImage = const AssetImage("assets/byndAi.png");
    _titleController.text = "My QR Code";
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(_logoImage, context);
  }

  void _handleBack() {
    if (_showPreview) {
      setState(() {
        _showPreview = false;
        _generatedImage = null;
      });
    } else {
      Navigator.pop(context);
    }
  }

  String _formatQrData() {
    switch (_selectedType) {
      case QrType.link:
        return _linkController.text.trim();
      case QrType.whatsapp:
        var phone = _phoneController.text.trim();
        if (phone.length == 10) {
          phone = "91$phone";
        }
        final msg = Uri.encodeComponent(_messageController.text.trim());
        return "https://wa.me/$phone?text=$msg";
      case QrType.email:
        final email = _emailController.text.trim();
        final sub = Uri.encodeComponent(_subjectController.text.trim());
        final body = Uri.encodeComponent(_bodyController.text.trim());
        return "mailto:$email?subject=$sub&body=$body";
      case QrType.wifi:
        final ssid = _wifiSsidController.text.trim();
        final pass = _wifiPasswordController.text.trim();
        return "WIFI:S:$ssid;T:WPA;P:$pass;;";
      case QrType.text:
        return _messageController.text.trim();
    }
  }

  Future<void> _generateQr() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isGenerating = true;
      _currentTitle = _titleController.text;
      _currentData = _formatQrData();
      _showPreview = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await Future.delayed(const Duration(milliseconds: 500));
        final bytes = await _captureQrImage();

        setState(() {
          _generatedImage = bytes;
          _isGenerating = false;
        });
      } catch (e) {
        debugPrint("Capture Error: $e");
        setState(() => _isGenerating = false);
        if (mounted) {
          TopAlert.show(context, "Preview rendering failed. Please try again.",
              isError: true);
        }
      }
    });
  }

  Future<Uint8List> _captureQrImage() async {
    // यहाँ Context चेक करना ज़रूरी है
    final boundary = _previewKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) throw Exception("RepaintBoundary not found yet");

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _downloadQr() async {
    if (_generatedImage == null) {
      TopAlert.show(context, "Processing image, please wait...");
      return;
    }

    final fileName = "qr_${DateTime.now().millisecondsSinceEpoch}.png";

    if (kIsWeb) {
      final blob = html.Blob([_generatedImage!]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(_generatedImage!);
      await Share.shareXFiles([XFile(file.path)],
          text: "QR Code: $_currentTitle");
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          title: Text(_showPreview ? "Preview" : "QR Generator"),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Center(
            child: Column(
              children: [
                if (!_showPreview) ...[
                  // Promotional Header
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.auto_awesome,
                            color: colorScheme.primary, size: 40),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Branded QR Magic",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          "Create stunning, professional QR codes for links, WhatsApp, WiFi and more in seconds.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GlassBox(
                          padding: const EdgeInsets.all(16),
                          border: Border.all(
                              color: Colors.transparent), // Removing border
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildTypeSelector(colorScheme),
                              const SizedBox(height: 30),

                              // Common Title Field
                              _buildTextField(
                                controller: _titleController,
                                label: "Card Title",
                                icon: Icons.title,
                                colorScheme: colorScheme,
                              ),
                              const SizedBox(height: 20),

                              // Dynamic Fields based on Type
                              ..._buildDynamicFields(colorScheme),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: _isGenerating ? null : _generateQr,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            elevation: 8,
                            shadowColor:
                                colorScheme.primary.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text(
                            "GENERATE SMART QR",
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_showPreview) ...[
                  RepaintBoundary(
                    key: _previewKey,
                    child: Container(
                      width: 350,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          )
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentTitle.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 18,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w900,
                              color: Colors
                                  .black, // Kept black for scanning contrast on white card
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: QrImageView(
                              data: _currentData,
                              size: 240,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "SCAN TO CONNECT",
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  Text(
                                    "ByndAI Smart QR",
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Image(
                                image: _logoImage,
                                width: 60,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.bolt, color: Colors.black),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  if (_isGenerating)
                    const CircularProgressIndicator()
                  else
                    Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _downloadQr,
                          icon: const Icon(Icons.share),
                          label: const Text("SHARE & DOWNLOAD"),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 55),
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: _handleBack,
                          icon: const Icon(Icons.edit_note),
                          label: const Text("Edit Details"),
                        ),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Select QR Type",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: QrType.values.map((type) {
              final isSelected = _selectedType == type;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(type.name.toUpperCase()),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) setState(() => _selectedType = type);
                  },
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  selectedColor: colorScheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildDynamicFields(ColorScheme colorScheme) {
    switch (_selectedType) {
      case QrType.link:
        return [
          _buildTextField(
            controller: _linkController,
            label: "Website URL",
            icon: Icons.link,
            colorScheme: colorScheme,
            hint: "https://example.com",
          ),
        ];
      case QrType.whatsapp:
        return [
          _buildTextField(
            controller: _phoneController,
            label: "WhatsApp Number",
            icon: Icons.phone,
            colorScheme: colorScheme,
            hint: "919876543210",
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _messageController,
            label: "Default Message",
            icon: Icons.message,
            colorScheme: colorScheme,
            maxLines: 2,
          ),
        ];
      case QrType.email:
        return [
          _buildTextField(
            controller: _emailController,
            label: "Recipient Email",
            icon: Icons.email,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _subjectController,
            label: "Subject",
            icon: Icons.subject,
            colorScheme: colorScheme,
          ),
        ];
      case QrType.wifi:
        return [
          _buildTextField(
            controller: _wifiSsidController,
            label: "Network SSID (Name)",
            icon: Icons.wifi,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _wifiPasswordController,
            label: "Password",
            icon: Icons.lock,
            colorScheme: colorScheme,
          ),
        ];
      case QrType.text:
        return [
          _buildTextField(
            controller: _messageController,
            label: "Plain Text",
            icon: Icons.text_fields,
            colorScheme: colorScheme,
            maxLines: 5,
          ),
        ];
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ColorScheme colorScheme,
    String? hint,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      validator: (value) => value == null || value.isEmpty ? "Required" : null,
    );
  }
}
