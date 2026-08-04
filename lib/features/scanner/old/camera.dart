import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:gridcard/features/leads/lead_scanner_2.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:gridcard/config/app_config.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  CameraScreenState createState() => CameraScreenState();
}

class CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  FlashMode _flashMode = FlashMode.off;
  bool _isProcessing = false;
  final TextRecognizer _textRecognizer = TextRecognizer();
  bool _isCameraInitialized = false;
  
  // Real-time detection state
  bool _isDetecting = false;
  String _detectionHint = "Align card within the frame";
  bool _cardDetected = false;
  bool _isPortrait = false;
  int _consecutiveDetections = 0;
  static const int _autoCaptureThreshold = 5; // Reduced for faster auto-capture

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    final controller = CameraController(
      cameras[0],
      ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup: Platform.isIOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.yuv420,
    );

    try {
      await controller.initialize();
      if (!mounted) return;
      
      setState(() {
        _controller = controller;
        _isCameraInitialized = true;
      });

      _startDetectionLoop();
      
    } catch (e) {
      if (kDebugMode) debugPrint('Camera initialization error: $e');
    }
  }

  void _startDetectionLoop() {
    if (_controller == null || !mounted) return;

    _controller!.startImageStream((CameraImage image) {
      if (_isDetecting || _isProcessing) return;
      
      _isDetecting = true;
      _detectText(image);
    });
  }

  Future<void> _detectText(CameraImage image) async {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.yuv420;

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: imageSize,
          rotation: InputImageRotation.rotation90deg,
          format: inputImageFormat,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      if (!mounted) return;

      // Determine orientation based on text block distribution
      if (recognizedText.blocks.isNotEmpty) {
        double minX = 10000, minY = 10000, maxX = 0, maxY = 0;
        for (var block in recognizedText.blocks) {
          final rect = block.boundingBox;
          if (rect.left < minX) minX = rect.left;
          if (rect.top < minY) minY = rect.top;
          if (rect.right > maxX) maxX = rect.right;
          if (rect.bottom > maxY) maxY = rect.bottom;
        }
        
        // ML Kit rotation90deg means width and height are swapped relative to the screen
        final detectedHeight = maxX - minX;
        final detectedWidth = maxY - minY;
        
        bool currentIsPortrait = detectedHeight > detectedWidth;
        if (currentIsPortrait != _isPortrait) {
          setState(() => _isPortrait = currentIsPortrait);
        }
      }

      // Card detection logic
      bool hasContactInfo = recognizedText.text.contains('@') || 
                            RegExp(r'\d{8,}').hasMatch(recognizedText.text);
      
      if (hasContactInfo && recognizedText.blocks.length > 2) {
        _consecutiveDetections++;
        
        if (_cardDetected == false) {
          setState(() {
            _cardDetected = true;
            _detectionHint = "Hold steady... Auto-scanning...";
          });
        }

        // Auto-capture after threshold met
        if (_consecutiveDetections >= _autoCaptureThreshold && !_isProcessing) {
          _consecutiveDetections = 0;
          _takePicture();
        }
      } else {
        _consecutiveDetections = 0;
        if (_cardDetected == true) {
          setState(() {
            _cardDetected = false;
            _detectionHint = "Align card within the frame";
          });
        }
      }

    } catch (e) {
      // Ignore stream errors
    } finally {
      _isDetecting = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    final newMode =
        _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    await _controller!.setFlashMode(newMode);
    setState(() => _flashMode = newMode);
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      _processImage(image.path);
    }
  }

  /// Uses OpenAI service (via backend) to extract structured data
  Future<void> _processImage(String path) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    
    try {
      final String apiUrl = "${AppConfig.apiBaseUrl}/gpt-ocr";
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.headers['Accept'] = 'application/json';
      
      final File imageFile = File(path);
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          path,
          filename: imageFile.uri.pathSegments.last,
        ),
      );

      final response = await request.send();
      final resStr = await response.stream.bytesToString();

      if (!mounted) return;

      if (response.statusCode == 200) {
        final json = jsonDecode(resStr);
        if (json['success'] == true && json['data'] != null) {
          final apiData = json['data'] as Map<String, dynamic>;

          // Map API data to what ExtractedDataModal expects
          final extractedData = <String, dynamic>{
            'name': apiData['name'] ?? '',
            'company_name': apiData['company_name'] ?? '',
            'email1': apiData['email'] ?? '',
            'email2': apiData['email2'] ?? '',
            'website': apiData['website'] ?? '',
            'address': apiData['address'] ?? '',
            'mobile1': apiData['mobile_no_1'] ?? '',
            'mobile2': apiData['mobile_no_2'] ?? '',
            'mobile3': apiData['mobile_no_3'] ?? '',
          };

          _showDataModal(path, extractedData);
        } else {
          throw Exception(json['message'] ?? 'Failed to extract data');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error processing image: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scanning card: $e')),
        );
      }
    }
  }

  void _showDataModal(String path, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: ExtractedDataModal(
              capturedImage: XFile(path),
              extractedData: data,
              onSave: (savedData) {
                Navigator.of(context).pop(); // Close modal
                Navigator.of(context).pop(); // Back to feed
              },
              onCancel: () {
                Navigator.of(context).pop();
                setState(() => _isProcessing = false);
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _takePicture() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isProcessing) return;
    try {
      final image = await _controller!.takePicture();
      _processImage(image.path);
    } catch (e) {
      if (kDebugMode) debugPrint('Error taking picture: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (!_isCameraInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Center(
              child: CameraPreview(_controller!),
            ),
          ),

          // Overlay Guide - Now Adaptive
          Positioned.fill(
            child: Container(
              decoration: ShapeDecoration(
                shape: _ScannerOverlayShape(
                  borderColor: _cardDetected ? Colors.green : colors.primary,
                  borderWidth: 3.0,
                  overlayColor: Colors.black.withOpacity(0.5),
                  isPortrait: _isPortrait,
                ),
              ),
            ),
          ),

          if (_isProcessing)
            const Positioned.fill(
              child: _ScanningAnimation(),
            ),

          // Top Controls
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                  style: IconButton.styleFrom(backgroundColor: Colors.black26),
                ),
                const Text(
                  "Scan Business Card",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: _toggleFlash,
                  icon: Icon(
                    _flashMode == FlashMode.torch
                        ? Icons.flash_on
                        : Icons.flash_off,
                    color: Colors.white,
                  ),
                  style: IconButton.styleFrom(backgroundColor: Colors.black26),
                ),
              ],
            ),
          ),

          // Bottom Controls
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  _isProcessing ? "Analyzing with AI..." : _detectionHint,
                  style: TextStyle(
                    color: _cardDetected || _isProcessing ? Colors.greenAccent : Colors.white70, 
                    fontSize: 14,
                    fontWeight: _cardDetected || _isProcessing ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildIconButton(
                      icon: Icons.photo_library_outlined,
                      onTap: _pickFromGallery,
                    ),
                    _buildCaptureButton(),
                    _buildIconButton(
                      icon: Icons.flip_camera_ios_outlined,
                      onTap: _flipCamera,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, required VoidCallback onTap}) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, size: 28),
      style: IconButton.styleFrom(
        padding: const EdgeInsets.all(16),
        backgroundColor: Colors.white24,
      ),
    );
  }

  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: _takePicture,
      child: Container(
        height: 84,
        width: 84,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _cardDetected ? Colors.green : Colors.white, width: 4),
        ),
        child: Center(
          child: Container(
            height: 68,
            width: 68,
            decoration: BoxDecoration(
              color: _cardDetected ? Colors.green.withOpacity(0.3) : Colors.white,
              shape: BoxShape.circle,
            ),
            child: _isProcessing
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.blue,
                    ),
                  )
                : (_cardDetected ? const Icon(Icons.check, color: Colors.white, size: 40) : null),
          ),
        ),
      ),
    );
  }

  Future<void> _flipCamera() async {
    final cameras = await availableCameras();
    if (cameras.length < 2) return;

    final newLensDirection = _controller!.description.lensDirection ==
            CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;

    final newCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == newLensDirection,
      orElse: () => cameras[0],
    );

    await _controller?.dispose();
    _initializeCameraWithDescription(newCamera);
  }

  Future<void> _initializeCameraWithDescription(CameraDescription description) async {
    final controller = CameraController(
      description,
      ResolutionPreset.max,
      enableAudio: false,
    );

    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _controller = controller;
      });
      _startDetectionLoop();
    } catch (e) {
      if (kDebugMode) debugPrint('Camera initialization error: $e');
    }
  }
}

class _ScanningAnimation extends StatefulWidget {
  const _ScanningAnimation();

  @override
  State<_ScanningAnimation> createState() => _ScanningAnimationState();
}

class _ScanningAnimationState extends State<_ScanningAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned(
              top: MediaQuery.of(context).size.height * 0.3 +
                  (MediaQuery.of(context).size.height * 0.4 * _controller.value),
              left: MediaQuery.of(context).size.width * 0.1,
              right: MediaQuery.of(context).size.width * 0.1,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                  color: Colors.blue,
                ),
              ),
            ),
          ],
        );
      }
    );
  }
}

class _ScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final bool isPortrait;

  const _ScannerOverlayShape({
    this.borderColor = Colors.white,
    this.borderWidth = 3.0,
    this.overlayColor = const Color(0x88000000),
    this.isPortrait = false,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path();

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRect(rect);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;

    // Business card aspect ratio is roughly 1.75:1
    double cardWidth, cardHeight;
    if (isPortrait) {
      cardHeight = height * 0.7;
      cardWidth = cardHeight / 1.75;
    } else {
      cardWidth = width * 0.85;
      cardHeight = cardWidth / 1.75;
    }

    final cardRect = Rect.fromCenter(
      center: Offset(width / 2, height / 2 - 20),
      width: cardWidth,
      height: cardHeight,
    );

    final backgroundPaint = Paint()..color = overlayColor;
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final path = Path()
      ..addRect(rect)
      ..addRRect(RRect.fromRectAndRadius(cardRect, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, backgroundPaint);

    final rrect = RRect.fromRectAndRadius(cardRect, const Radius.circular(16));
    canvas.drawRRect(rrect, borderPaint);

    final markerLength = 30.0;
    final markerPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth + 2
      ..strokeCap = StrokeCap.round;

    // Top Left
    canvas.drawLine(Offset(cardRect.left, cardRect.top + markerLength),
        Offset(cardRect.left, cardRect.top), markerPaint);
    canvas.drawLine(Offset(cardRect.left, cardRect.top),
        Offset(cardRect.left + markerLength, cardRect.top), markerPaint);

    // Top Right
    canvas.drawLine(Offset(cardRect.right - markerLength, cardRect.top),
        Offset(cardRect.right, cardRect.top), markerPaint);
    canvas.drawLine(Offset(cardRect.right, cardRect.top),
        Offset(cardRect.right, cardRect.top + markerLength), markerPaint);

    // Bottom Left
    canvas.drawLine(Offset(cardRect.left, cardRect.bottom - markerLength),
        Offset(cardRect.left, cardRect.bottom), markerPaint);
    canvas.drawLine(Offset(cardRect.left, cardRect.bottom),
        Offset(cardRect.left + markerLength, cardRect.bottom), markerPaint);

    // Bottom Right
    canvas.drawLine(Offset(cardRect.right - markerLength, cardRect.bottom),
        Offset(cardRect.right, cardRect.bottom), markerPaint);
    canvas.drawLine(Offset(cardRect.right, cardRect.bottom),
        Offset(cardRect.right, cardRect.bottom - markerLength), markerPaint);
  }

  @override
  ShapeBorder scale(double t) => this;
}
