import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

// ignore: avoid_web_libraries_in_flutter
// import 'dart:html' as html;

import 'package:universal_html/html.dart' as html;

class QrGeneratorPage extends StatefulWidget {
  const QrGeneratorPage({super.key});

  @override
  State<QrGeneratorPage> createState() => _QrGeneratorPageState();
}

class _QrGeneratorPageState extends State<QrGeneratorPage> {
  final GlobalKey _previewKey = GlobalKey();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  Uint8List? _generatedImage;
  bool _isGenerating = false;
  bool _showPreview = false;
  String _currentTitle = "";
  String _currentLink = "";

  late ImageProvider _logoImage;

  @override
  void initState() {
    super.initState();
    _logoImage = const AssetImage("assets/byndAi.png");
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

  /// 🔹 इमेज कैप्चर करने का लॉजिक (अब सुरक्षित है)
  Future<void> _generateQr() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    // 1. पहले डेटा सेट करें और प्रीव्यू UI दिखाएँ
    setState(() {
      _isGenerating = true;
      _currentTitle = _titleController.text;
      _currentLink = _linkController.text;
      _showPreview = true; // यहाँ UI बदल जाएगा
    });

    // 2. सबसे ज़रूरी: Flutter को फ्रेम ड्रॉ करने का समय दें
    // WidgetsBinding.instance.addPostFrameCallback इमेज कैप्चर के लिए सबसे सुरक्षित है
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // थोड़ा और इंतज़ार ताकि इमेज/QR पूरी तरह रेंडर हो जाए
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Preview rendering failed. Please try again.")),
          );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Processing image, please wait...")),
      );
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: Text(_showPreview ? "Preview" : "Generate QR Code"),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Center(
            child: Column(
              children: [
                if (!_showPreview) ...[
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          "Create your branded QR code",
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: "Card Title",
                            prefixIcon: const Icon(Icons.title),
                            filled: true,
                            fillColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withOpacity(0.3),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? "Required"
                              : null,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _linkController,
                          keyboardType: TextInputType.url,
                          decoration: InputDecoration(
                            labelText: "URL / Link",
                            prefixIcon: const Icon(Icons.link),
                            filled: true,
                            fillColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withOpacity(0.3),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? "Required"
                              : null,
                        ),
                        const SizedBox(height: 30),
                        ElevatedButton(
                          onPressed: _isGenerating ? null : _generateQr,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("GENERATE PREVIEW"),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_showPreview) ...[
                  // RepaintBoundary को हमेशा बिल्ड में रखें ताकि context मिल सके
                  RepaintBoundary(
                    key: _previewKey,
                    child: Container(
                      width: 350,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentTitle,
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          QrImageView(
                            data: _currentLink,
                            size: 260,
                            backgroundColor: Colors.white,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Image(
                              image: _logoImage,
                              width: 70,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Text("byndAi",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  if (_isGenerating)
                    const CircularProgressIndicator()
                  else
                    ElevatedButton.icon(
                      onPressed: _downloadQr,
                      icon: const Icon(Icons.file_download),
                      label: const Text("DOWNLOAD QR CODE"),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 55),
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextButton(
                      onPressed: _handleBack,
                      child: const Text("Edit Details")),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
