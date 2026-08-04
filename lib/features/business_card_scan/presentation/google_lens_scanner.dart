import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import 'package:gridcard/features/business_card_scan/data/services/ai_parsing_service.dart';
import 'package:gridcard/features/business_card_scan/data/services/ocr_pipeline_service.dart';
import 'package:gridcard/features/business_card_scan/domain/models/business_card.dart';
import 'package:gridcard/features/business_card_scan/presentation/scanner_state.dart';
import 'package:gridcard/features/business_card_scan/presentation/widgets/lens_painter.dart';
import 'package:gridcard/features/leads/lead_scanner_2.dart';

/// Google-Lens-style real-time business card scanner.
///
/// Pipeline:
///  Camera stream → OCR (MLKit, 1fps throttle, frame dedup)
///  → lock-in (3 stable frames) → auto-capture still
///  → AI parsing (raw_text JSON to /gpt-ocr)
///  → ExtractedDataModal form pre-fill
///
String _processImageIsolate(Map<String, dynamic> params) {
  final path = params['path'] as String;
  final isPortrait = params['isPortrait'] as bool;

  try {
    final bytes = File(path).readAsBytesSync();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return path;

    // Apply EXIF orientation to pixel data before any size checks
    image = img.bakeOrientation(image);

    // If the camera returned a sensor-oriented image (landscape) without EXIF,
    // force it to portrait since the scanner UI is always in portrait.
    if (image.width > image.height) {
      image = img.copyRotate(image, angle: 90);
    }

    // Determine crop dimensions based on the card orientation!
    // This perfectly matches the _CardGuideOverlay in the UI.
    int cropW, cropH;
    if (isPortrait) {
      // Portrait card guide: cardH = h * 0.68; cardW = cardH / 1.58
      cropH = (image.height * 0.68).toInt();
      cropW = (cropH ~/ 1.58).toInt();
    } else {
      // Landscape card guide: cardW = w * 0.84; cardH = cardW / 1.58
      cropW = (image.width * 0.84).toInt();
      cropH = (cropW ~/ 1.58).toInt();
    }

    if (cropW > image.width) cropW = image.width;
    if (cropH > image.height) cropH = image.height;

    final x = (image.width - cropW) ~/ 2;
    int y = (image.height - cropH) ~/ 2;

    // Shift up slightly to match the UI guide (-24 pts on a typical 800 pt screen is approx -3%)
    y -= (image.height * 0.03).toInt();
    if (y < 0) y = 0;

    // Safeguard out of bounds crop which crashes the isolate
    if (x + cropW > image.width) cropW = image.width - x;
    if (y + cropH > image.height) cropH = image.height - y;

    img.Image cropped =
        img.copyCrop(image, x: x, y: y, width: cropW, height: cropH);

    final outPath = '${path}_cropped.jpg';
    File(outPath).writeAsBytesSync(img.encodeJpg(cropped, quality: 85));
    return outPath;
  } catch (e) {
    // Silently fallback to original
    return path;
  }
}

class GoogleLensScanner extends StatefulWidget {
  const GoogleLensScanner({super.key});

  @override
  State<GoogleLensScanner> createState() => _GoogleLensScannerState();
}

class _GoogleLensScannerState extends State<GoogleLensScanner>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // ─── Services ────────────────────────────────────────────────────────────
  CameraController? _controller;
  final OcrPipelineService _ocr = OcrPipelineService();
  final AIParsingService _ai = AIParsingService();

  // ─── State ────────────────────────────────────────────────────────────────
  ScannerState _state = const ScannerState();
  DeviceOrientation _deviceOrientation = DeviceOrientation.portraitUp;

  // ─── Frame throttle ──────────────────────────────────────────────────────
  bool _frameBusy = false;
  DateTime? _lastFrameTime;
  static const _frameInterval = Duration(milliseconds: 900);

  // ─── Lock-in counter ─────────────────────────────────────────────────────
  static const int _lockInThreshold = 3;

  // ─── Animations ──────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late AnimationController _scanLineCtrl;
  late AnimationController _processCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _scanLineAnim;
  late Animation<double> _processAnim;

  // ─── Lifecycle ───────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    _scanLineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _scanLineAnim =
        CurvedAnimation(parent: _scanLineCtrl, curve: Curves.easeInOut);

    _processCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _processAnim =
        CurvedAnimation(parent: _processCtrl, curve: Curves.easeInOut);

    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseCtrl.dispose();
    _scanLineCtrl.dispose();
    _processCtrl.dispose();
    _safeDisposeController();
    _ocr.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.inactive ||
        lifecycle == AppLifecycleState.paused) {
      // Pause animations so AnimatedBuilder stops rebuilding
      // while the controller is null — prevents null crash.
      _pulseCtrl.stop();
      _scanLineCtrl.stop();
      _processCtrl.stop();
      _safeDisposeController();
    } else if (lifecycle == AppLifecycleState.resumed) {
      _pulseCtrl.repeat(reverse: true);
      _scanLineCtrl.repeat();
      _processCtrl.repeat();
      _initCamera();
    }
  }

  @override
  void didChangeMetrics() {
    // Track device orientation for correct OCR rotation.
    final orientation = MediaQuery.maybeOf(context)?.devicePixelRatio == null
        ? DeviceOrientation.portraitUp
        : _platformOrientation();
    if (orientation != _deviceOrientation) {
      setState(() => _deviceOrientation = orientation);
    }
  }

  DeviceOrientation _platformOrientation() {
    final data = MediaQueryData.fromView(
        WidgetsBinding.instance.platformDispatcher.views.first);
    if (data.orientation == Orientation.landscape) {
      return DeviceOrientation.landscapeLeft;
    }
    return DeviceOrientation.portraitUp;
  }

  // ─── Camera ──────────────────────────────────────────────────────────────
  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _updateState(_state.copyWith(statusText: 'No camera found'));
        return;
      }

      final cam = cameras.first;
      final controller = CameraController(
        cam,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted) return;

      debugPrint(
          '[SCANNER] 📹 Camera initialized: ${cameras.first.name}, sensor=${cameras.first.sensorOrientation}°');
      setState(() => _controller = controller);
      controller.startImageStream(_onFrame);
      debugPrint('[SCANNER] ▶️ Image stream started');
    } catch (e) {
      debugPrint('[SCANNER] ❌ Camera init error: $e');
      if (mounted) {
        _updateState(_state.copyWith(statusText: 'Camera error: $e'));
      }
    }
  }

  void _safeDisposeController() {
    try {
      if (_controller?.value.isStreamingImages ?? false) {
        _controller?.stopImageStream();
      }
      _controller?.dispose();
    } catch (_) {}
    _controller = null; // no setState — safe from dispose()
  }

  // ─── Frame processing ────────────────────────────────────────────────────
  void _onFrame(CameraImage image) async {
    // Guard: don't process while busy or in a terminal phase.
    if (_frameBusy || _state.isProcessingOrDone) return;
    final now = DateTime.now();
    if (_lastFrameTime != null &&
        now.difference(_lastFrameTime!) < _frameInterval) {
      return;
    }
    _frameBusy = true;
    _lastFrameTime = now;

    try {
      final camera = _controller?.description;
      if (camera == null) return;

      final result = await _ocr.processFrame(image, camera, _deviceOrientation);
      if (result == null || !mounted) return;

      final blocks = result.blocks.map((b) => b.boundingBox).toList();
      final imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final isPortrait = _detectPortrait(blocks, imageSize);
      final hasCard = _looksLikeBusinessCard(result.text);

      debugPrint(
          '[SCANNER] 🔍 hasCard=$hasCard isPortrait=$isPortrait blocks=${blocks.length}');

      if (!hasCard) {
        _updateState(_state.copyWith(
          phase: ScannerPhase.idle,
          statusText: 'Align business card',
          detectedBlocks: blocks,
          imageSize: imageSize,
          isPortrait: isPortrait,
          lockInFrames: 0,
        ));
        return;
      }

      final newFrames = _state.lockInFrames + 1;
      debugPrint('[SCANNER] 🔒 Lock-in: $newFrames/$_lockInThreshold');

      if (newFrames >= _lockInThreshold) {
        debugPrint(
            '[SCANNER] 🚀 Lock-in threshold reached — triggering auto-capture');
        _updateState(_state.copyWith(
          phase: ScannerPhase.lockedIn,
          statusText: 'Card detected!',
          detectedBlocks: blocks,
          imageSize: imageSize,
          isPortrait: isPortrait,
          lockInFrames: newFrames,
        ));
        Future.microtask(() => _autoCapture());
      } else {
        _updateState(_state.copyWith(
          phase: ScannerPhase.scanning,
          statusText: 'Hold steady…',
          detectedBlocks: blocks,
          imageSize: imageSize,
          isPortrait: isPortrait,
          lockInFrames: newFrames,
        ));
      }
    } catch (e) {
      debugPrint('[SCANNER] ❌ Frame error: $e');
    } finally {
      _frameBusy = false;
    }
  }

  /// Simple heuristic: looks for email (@) OR 8+ digit phone OR www/.com
  bool _looksLikeBusinessCard(String text) {
    return text.contains('@') ||
        RegExp(r'\d{8,}').hasMatch(text) ||
        text.toLowerCase().contains('www.') ||
        text.toLowerCase().contains('.com');
  }

  /// Determine card orientation from block bounding-box spread.
  bool _detectPortrait(List<Rect> blocks, Size imageSize) {
    if (blocks.isEmpty) return false;
    double minX = imageSize.width, maxX = 0, minY = imageSize.height, maxY = 0;
    for (final r in blocks) {
      if (r.left < minX) minX = r.left;
      if (r.right > maxX) maxX = r.right;
      if (r.top < minY) minY = r.top;
      if (r.bottom > maxY) maxY = r.bottom;
    }
    return (maxY - minY) > (maxX - minX);
  }

  // ─── Auto capture ────────────────────────────────────────────────────────
  Future<void> _autoCapture() async {
    if (_state.isProcessingOrDone) {
      debugPrint('[SCANNER] ⏭️ _autoCapture skipped — already processing/done');
      return;
    }
    debugPrint('[SCANNER] 📸 Auto-capture starting...');
    _updateState(_state.copyWith(
      phase: ScannerPhase.processing,
      statusText: 'AI Extracting…',
    ));

    try {
      if (_controller?.value.isStreamingImages ?? false) {
        debugPrint('[SCANNER] ⏸️ Stopping image stream before capture');
        await _controller!.stopImageStream();
      }
      final photo = await _controller!.takePicture();
      debugPrint('[SCANNER] 📸 Photo captured: ${photo.path}');

      final processedPath = await compute(_processImageIsolate, {
        'path': photo.path,
        'isPortrait': _state.isPortrait,
      });

      await _runAiAndShowModal(processedPath);
    } catch (e) {
      debugPrint('[SCANNER] ❌ Auto capture error: $e');
      _resetToScanning('Error — try manual capture');
    }
  }

  // ─── Manual capture ──────────────────────────────────────────────────────
  Future<void> _manualCapture() async {
    if (_state.isProcessingOrDone) return;
    if (_controller == null || !_controller!.value.isInitialized) return;

    debugPrint('[SCANNER] 👆 Manual capture triggered');
    _updateState(_state.copyWith(
      phase: ScannerPhase.processing,
      statusText: 'AI Extracting…',
    ));

    try {
      if (_controller!.value.isStreamingImages) {
        debugPrint('[SCANNER] ⏸️ Stopping image stream before manual capture');
        await _controller!.stopImageStream();
      }
      final photo = await _controller!.takePicture();
      debugPrint('[SCANNER] 📸 Photo captured: ${photo.path}');

      final processedPath = await compute(_processImageIsolate, {
        'path': photo.path,
        'isPortrait': _state.isPortrait,
      });

      await _runAiAndShowModal(processedPath);
    } catch (e) {
      debugPrint('[SCANNER] ❌ Manual capture error: $e');
      _resetToScanning('Error scanning — try again');
    }
  }

  // ─── AI parsing → modal ──────────────────────────────────────────────────
  Future<void> _runAiAndShowModal(String photoPath) async {
    debugPrint('[SCANNER] 🤖 Calling AI parser...');
    try {
      final card = await _ai.parseCardImage(photoPath);
      if (!mounted) return;

      debugPrint(
          '[SCANNER] ✅ AI done. name="${card.name}" company="${card.company}"');
      _updateState(_state.copyWith(phase: ScannerPhase.done));
      _showModal(photoPath, card);
    } catch (e) {
      debugPrint('[SCANNER] ❌ AI error: $e');
      _resetToScanning('AI error — try again');
    }
  }

  void _showModal(String photoPath, BusinessCard card) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: ExtractedDataModal(
              capturedImage: XFile(photoPath),
              extractedData: card.toFormMap(),
              onSave: (savedData) {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              onCancel: () {
                Navigator.of(ctx).pop();
                _resetToScanning('Align business card');
              },
            ),
          ),
        ),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────
  void _updateState(ScannerState s) {
    if (!mounted) return;
    setState(() => _state = s);
  }

  void _resetToScanning(String msg) {
    _ocr.resetHash();
    _updateState(ScannerState(statusText: msg));
    // Restart stream.
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted &&
          _controller != null &&
          _controller!.value.isInitialized &&
          !_controller!.value.isStreamingImages) {
        _controller!.startImageStream(_onFrame);
      }
    });
  }

  // ─── UI ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(_state.statusText,
                  style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnim, _scanLineAnim, _processAnim]),
        builder: (context, _) => Stack(
          children: [
            // ── Camera preview ────────────────────────────────────────────
            if (_controller != null && _controller!.value.isInitialized)
              Positioned.fill(child: CameraPreview(_controller!)),

            // ── Lens dot overlay ─────────────────────────────────────────
            if (_state.imageSize != null)
              Positioned.fill(
                child: CustomPaint(
                  painter: LensPainter(
                    blocks: _state.detectedBlocks,
                    imageSize: _state.imageSize!,
                    phase: _state.phase,
                    pulse: _pulseAnim.value,
                    scanLine: _scanLineAnim.value,
                    processAnim: _processAnim.value,
                  ),
                ),
              ),

            // ── Card guide frame ─────────────────────────────────────────
            Positioned.fill(
              child: CustomPaint(
                painter: _CardGuideOverlay(
                  isPortrait: _state.isPortrait,
                  phase: _state.phase,
                  pulse: _pulseAnim.value,
                ),
              ),
            ),

            // ── Top bar ──────────────────────────────────────────────────
            _buildTopBar(),
            _buildStatusPill(),

            // ── Bottom controls ──────────────────────────────────────────
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _iconButton(Icons.close, () => Navigator.pop(context)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0x881C203C), Color(0x881F8BFF)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome,
                    color: Color(0xFF00E5FF), size: 14),
                const SizedBox(width: 6),
                const Text(
                  'Bynd AI Scanner',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          _iconButton(Icons.flash_off, () {}), // placeholder for flash
        ],
      ),
    );
  }

  Widget _buildStatusPill() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 80,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _StatusPill(
            key: ValueKey(_state.statusText),
            text: _state.statusText,
            phase: _state.phase,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 48,
      left: 0,
      right: 0,
      child: Column(
        children: [
          const SizedBox(height: 28),

          // Shutter row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Gallery
              _iconButton(Icons.photo_library_outlined, () {},
                  size: 48, opacity: 0.6),
              const SizedBox(width: 28),

              // Main shutter
              _ShutterButton(
                phase: _state.phase,
                spinValue: _processCtrl.value,
                onTap: _manualCapture,
              ),

              const SizedBox(width: 28),

              // Flip camera
              _iconButton(Icons.flip_camera_ios_outlined, () {},
                  size: 48, opacity: 0.6),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconButton(
    IconData icon,
    VoidCallback onTap, {
    double size = 44,
    double opacity = 1,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black38,
          ),
          child: Icon(icon, color: Colors.white, size: size * 0.48),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Widgets
// ═══════════════════════════════════════════════════════════════════════════

class _StatusPill extends StatelessWidget {
  final String text;
  final ScannerPhase phase;

  const _StatusPill({super.key, required this.text, required this.phase});

  @override
  Widget build(BuildContext context) {
    final isLocked = phase == ScannerPhase.lockedIn;

    final isProcessing = phase == ScannerPhase.processing;
    final isIdle = phase == ScannerPhase.idle;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: isLocked
            ? const LinearGradient(
                colors: [Color(0xFF00E5FF), Color(0xFF1F8BFF)])
            : isProcessing
                ? const LinearGradient(
                    colors: [Color(0xFF7B2FFF), Color(0xFF1F8BFF)])
                : null,
        color: (isLocked || isProcessing)
            ? null
            : Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isLocked
              ? const Color(0xFF00E5FF)
              : isProcessing
                  ? const Color(0xFF7B2FFF)
                  : Colors.white.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: (isLocked || isProcessing)
            ? [
                BoxShadow(
                  color: isLocked
                      ? const Color(0xFF00E5FF).withValues(alpha: 0.4)
                      : const Color(0xFF7B2FFF).withValues(alpha: 0.4),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isProcessing
                ? Icons.auto_awesome
                : isLocked
                    ? Icons.lock
                    : Icons.center_focus_weak,
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  final ScannerPhase phase;
  final double spinValue;
  final VoidCallback onTap;

  const _ShutterButton(
      {required this.phase, required this.spinValue, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active =
        phase != ScannerPhase.processing && phase != ScannerPhase.done;
    final isLocked = phase == ScannerPhase.lockedIn;

    return GestureDetector(
      onTap: active ? onTap : null,
      child: Container(
        height: 80,
        width: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: isLocked ? 1.0 : 0.5),
            width: 3,
          ),
          boxShadow: isLocked
              ? [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                    blurRadius: 30,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: isLocked ? 66 : 60,
            width: isLocked ? 66 : 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: phase == ScannerPhase.processing ? null : Colors.white,
              gradient: phase == ScannerPhase.processing
                  ? SweepGradient(
                      colors: const [
                        Color(0xFF00E5FF),
                        Color(0xFF7B2FFF),
                        Color(0xFF00E5FF),
                        Color(0xFF1F8BFF),
                        Color(0xFF00E5FF),
                      ],
                      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                      transform: GradientRotation(spinValue * 2 * 3.14159),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Card guide overlay shape
// ═══════════════════════════════════════════════════════════════════════════

class _CardGuideOverlay extends CustomPainter {
  final bool isPortrait;
  final ScannerPhase phase;
  final double pulse;

  const _CardGuideOverlay({
    required this.isPortrait,
    required this.phase,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    double cardW, cardH;
    if (isPortrait) {
      cardH = h * 0.68;
      cardW = cardH / 1.58;
    } else {
      cardW = w * 0.84;
      cardH = cardW / 1.58;
    }

    final cardRect = Rect.fromCenter(
      center: Offset(w / 2, h / 2 - 24),
      width: cardW,
      height: cardH,
    );
    final rRect = RRect.fromRectAndRadius(cardRect, const Radius.circular(24));

    // Elegant Dim surround
    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.65);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, w, h))
      ..addRRect(rRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, dimPaint);

    final isLockedOrProcessing =
        phase == ScannerPhase.lockedIn || phase == ScannerPhase.processing;

    // We only draw rounded corners now, no full border.
    final cornerColor = Colors.white
        .withValues(alpha: isLockedOrProcessing ? 1.0 : 0.5 + pulse * 0.3);

    // Add subtle glow if locked
    if (isLockedOrProcessing) {
      final glowPaint = Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.7 + pulse * 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);

      // Outer deep glow
      final deepGlowPaint = Paint()
        ..color = const Color(0xFF1F8BFF).withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20.0);
      _drawRoundedCorners(canvas, rRect, deepGlowPaint);

      _drawRoundedCorners(canvas, rRect, glowPaint);
    }

    final cornerPaint = Paint()
      ..color = cornerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    _drawRoundedCorners(canvas, rRect, cornerPaint);
  }

  void _drawRoundedCorners(Canvas canvas, RRect rRect, Paint paint) {
    const len = 32.0; // Length of the straight edge
    final radius = rRect.tlRadiusX;
    final rect = rRect.outerRect;

    // Top Left
    var path = Path()
      ..moveTo(rect.left, rect.top + radius + len)
      ..lineTo(rect.left, rect.top + radius)
      ..arcToPoint(Offset(rect.left + radius, rect.top),
          radius: Radius.circular(radius))
      ..lineTo(rect.left + radius + len, rect.top);
    canvas.drawPath(path, paint);

    // Top Right
    path = Path()
      ..moveTo(rect.right - radius - len, rect.top)
      ..lineTo(rect.right - radius, rect.top)
      ..arcToPoint(Offset(rect.right, rect.top + radius),
          radius: Radius.circular(radius))
      ..lineTo(rect.right, rect.top + radius + len);
    canvas.drawPath(path, paint);

    // Bottom Right
    path = Path()
      ..moveTo(rect.right, rect.bottom - radius - len)
      ..lineTo(rect.right, rect.bottom - radius)
      ..arcToPoint(Offset(rect.right - radius, rect.bottom),
          radius: Radius.circular(radius))
      ..lineTo(rect.right - radius - len, rect.bottom);
    canvas.drawPath(path, paint);

    // Bottom Left
    path = Path()
      ..moveTo(rect.left + radius + len, rect.bottom)
      ..lineTo(rect.left + radius, rect.bottom)
      ..arcToPoint(Offset(rect.left, rect.bottom - radius),
          radius: Radius.circular(radius))
      ..lineTo(rect.left, rect.bottom - radius - len);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CardGuideOverlay old) =>
      old.isPortrait != isPortrait || old.phase != phase || old.pulse != pulse;
}
