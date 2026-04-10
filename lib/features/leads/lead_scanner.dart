import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:gridcard/config/app_config.dart';

class LeadsScannerPage extends StatefulWidget {
  final Function(Map<String, dynamic>)? onDataExtracted;

  const LeadsScannerPage({super.key, this.onDataExtracted});

  @override
  State<LeadsScannerPage> createState() => _LeadsScannerPageState();
}

class _LeadsScannerPageState extends State<LeadsScannerPage> {
  final List<XFile> _capturedImages = [];
  bool _isLoading = false;
  String _errorMessage = '';
  String _ocrText = '';
  Map<String, dynamic>? _formData;
  static const double _scannerAspectRatio = 1.58; // Business-card friendly ratio

  // final String apiUrl = "http://byndai_server-main.test/api/ocr-extract";
  static const String _baseUrl = AppConfig.apiBaseUrl;
  final String apiUrl = "$_baseUrl/ocr-extract";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
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
            // Main scanner frame (fixed ratio, same for placeholder + captured)
            LayoutBuilder(
              builder: (context, constraints) {
                final frameWidth = constraints.maxWidth;
                return SizedBox(
                  width: frameWidth,
                  child: AspectRatio(
                    aspectRatio: _scannerAspectRatio,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blueGrey, width: 1.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _capturedImages.isNotEmpty
                            ? _buildImageWidget(_capturedImages.first, fit: BoxFit.cover)
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                                  SizedBox(height: 10),
                                  Text("Align card inside this frame"),
                                ],
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Captured image strip (same ratio thumbnails)
            if (_capturedImages.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 96,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _capturedImages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          AspectRatio(
                            aspectRatio: _scannerAspectRatio,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.blue, width: 2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _buildImageWidget(_capturedImages[index], fit: BoxFit.cover),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: const CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.red,
                                child: Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],

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
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[900]
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[700]!
                              : Colors.grey.shade300),
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
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.green[900]!.withOpacity(0.3)
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.green[700]!
                              : Colors.green),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _formData!.entries.map((entry) {
                        if (entry.value != null &&
                            entry.value.toString().isNotEmpty) {
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
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.blue),
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
        final cropped = await _openCropper(image);
        if (cropped == null) return;
        final normalized = await _normalizeToScannerRatio(cropped);
        setState(() => _capturedImages.add(normalized));
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  void _removeImage(int index) {
    setState(() => _capturedImages.removeAt(index));
  }

  Widget _buildImageWidget(XFile image, {BoxFit fit = BoxFit.cover}) {
    if (kIsWeb) {
      return Image.network(image.path, fit: fit);
    }
    return Image.file(File(image.path), fit: fit);
  }

  Future<XFile?> _openCropper(XFile image) async {
    return Navigator.push<XFile>(
      context,
      MaterialPageRoute(
        builder: (_) => _LeadImageCropPage(
          imageFile: image,
          aspectRatio: _scannerAspectRatio,
        ),
      ),
    );
  }

  Future<XFile> _normalizeToScannerRatio(XFile imageFile) async {
    try {
      final originalBytes = await imageFile.readAsBytes();
      final decoded = img.decodeImage(originalBytes);
      if (decoded == null) return imageFile;

      final fixedOrientation = img.bakeOrientation(decoded);
      final sourceW = fixedOrientation.width;
      final sourceH = fixedOrientation.height;
      final sourceRatio = sourceW / sourceH;
      final targetRatio = _scannerAspectRatio;

      int cropW = sourceW;
      int cropH = sourceH;
      int offsetX = 0;
      int offsetY = 0;

      if (sourceRatio > targetRatio) {
        // Source too wide -> crop left/right
        cropW = (sourceH * targetRatio).round();
        offsetX = ((sourceW - cropW) / 2).round();
      } else if (sourceRatio < targetRatio) {
        // Source too tall -> crop top/bottom
        cropH = (sourceW / targetRatio).round();
        offsetY = ((sourceH - cropH) / 2).round();
      }

      final cropped = img.copyCrop(
        fixedOrientation,
        x: offsetX,
        y: offsetY,
        width: cropW,
        height: cropH,
      );
      final outputBytes = Uint8List.fromList(img.encodeJpg(cropped, quality: 90));

      if (kIsWeb) {
        return XFile.fromData(
          outputBytes,
          name: imageFile.name,
          mimeType: 'image/jpeg',
        );
      }

      final dir = await getTemporaryDirectory();
      final outPath = '${dir.path}/scanner_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final outFile = File(outPath);
      await outFile.writeAsBytes(outputBytes, flush: true);
      return XFile(outFile.path);
    } catch (_) {
      return imageFile;
    }
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
    final emailRegex =
        RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b');
    final emails = emailRegex.allMatches(text).map((m) => m.group(0)).toList();
    if (emails.isNotEmpty) data['email1'] = emails[0];
    if (emails.length > 1) data['email2'] = emails[1];

    // Extract phone numbers
    final phoneRegex = RegExp(r'\b\d{10}\b');
    final phones = phoneRegex.allMatches(text).map((m) => m.group(0)).toList();
    for (int i = 0; i < phones.length && i < 3; i++) {
      data['mobile${i + 1}'] = phones[i];
    }

    return data;
  }
}

class _LeadImageCropPage extends StatefulWidget {
  final XFile imageFile;
  final double aspectRatio;

  const _LeadImageCropPage({
    required this.imageFile,
    required this.aspectRatio,
  });

  @override
  State<_LeadImageCropPage> createState() => _LeadImageCropPageState();
}

class _LeadImageCropPageState extends State<_LeadImageCropPage> {
  final CropController _controller = CropController();
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final bytes = await widget.imageFile.readAsBytes();
    if (!mounted) return;
    setState(() => _imageBytes = bytes);
  }

  Future<void> _finishCrop(Uint8List croppedData) async {
    if (kIsWeb) {
      Navigator.pop(
        context,
        XFile.fromData(
          croppedData,
          name: 'lead_crop_${DateTime.now().millisecondsSinceEpoch}.jpg',
          mimeType: 'image/jpeg',
        ),
      );
      return;
    }
    final dir = await getTemporaryDirectory();
    final outPath = '${dir.path}/lead_crop_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outFile = File(outPath);
    await outFile.writeAsBytes(croppedData, flush: true);
    if (!mounted) return;
    Navigator.pop(context, XFile(outFile.path));
  }

  @override
  Widget build(BuildContext context) {
    if (_imageBytes == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Adjust Card Crop'),
        actions: [
          IconButton(
            onPressed: () => _controller.crop(),
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: Crop(
        controller: _controller,
        image: _imageBytes!,
        aspectRatio: widget.aspectRatio,
        initialSize: 0.95,
        withCircleUi: false,
        onCropped: (croppedData) async {
          await _finishCrop(croppedData);
        },
      ),
    );
  }
}
