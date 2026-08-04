import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';


/// Converts raw [CameraImage] frames to ML Kit [InputImage] with correct
/// sensor-aware rotation, then runs [TextRecognizer].
///
/// Frame deduplication: consecutive frames with identical text hashes are
/// skipped to avoid redundant OCR calls and API hits.
class OcrPipelineService {
  final TextRecognizer _recognizer = TextRecognizer();
  String _lastTextHash = '';
  bool _formatLogged = false; // log camera format only once


  /// Processes a [CameraImage] frame.
  ///
  /// Returns [RecognizedText] if the frame produced new content, or null if:
  /// - The frame is a duplicate of the previous result.
  /// - An error occurs.
  Future<RecognizedText?> processFrame(
    CameraImage image,
    CameraDescription cameraDescription,
    DeviceOrientation deviceOrientation,
  ) async {
    try {
      final inputImage = _buildInputImage(
        image,
        cameraDescription,
        deviceOrientation,
      );
      if (inputImage == null) {
        debugPrint('[OCR] ⚠️ Could not build InputImage (unsupported format?)');
        return null;
      }

      final result = await _recognizer.processImage(inputImage);
      final text = result.text.trim();

      debugPrint('[OCR] 📷 Frame processed — blocks: ${result.blocks.length}, chars: ${text.length}');

      if (text.isEmpty) {
        debugPrint('[OCR] 🔇 Empty text from frame');
        return null;
      }

      // Dedup: skip if text hasn't changed since last frame.
      if (text == _lastTextHash) {
        debugPrint('[OCR] 🔁 Duplicate frame skipped');
        return null;
      }
      _lastTextHash = text;
      debugPrint('[OCR] ✅ New text detected:\n---\n$text\n---');

      return result;
    } catch (e) {
      debugPrint('[OCR] ❌ processFrame error: $e');
      return null;
    }
  }

  /// Runs OCR on a captured still image file path (for manual capture).
  Future<RecognizedText?> processFilePath(String filePath) async {
    try {
      debugPrint('[OCR] 📂 Processing still image: $filePath');
      final inputImage = InputImage.fromFilePath(filePath);
      final result = await _recognizer.processImage(inputImage);
      debugPrint('[OCR] 📄 Still OCR result: ${result.blocks.length} blocks, text length: ${result.text.length}');
      debugPrint('[OCR] 📝 Text:\n${result.text}');
      return result;
    } catch (e) {
      debugPrint('[OCR] ❌ processFilePath error: $e');
      return null;
    }
  }

  void resetHash() => _lastTextHash = '';

  void dispose() => _recognizer.close();

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  InputImage? _buildInputImage(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) {
    final rawFormat = image.format.raw;

    if (!_formatLogged) {
      debugPrint('[OCR] 🎞️ Frame format: raw=$rawFormat planes=${image.planes.length} '
          'size=${image.width}x${image.height}');
      _formatLogged = true;
    }

    final rotation = _rotationForCamera(camera, deviceOrientation);

    // iOS: use bgra8888 bytes directly (single plane, no stride issues).
    if (Platform.isIOS) {
      final plane = image.planes[0];
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.bgra8888,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    }

    // Android: convert YUV_420_888 → NV21 respecting row/pixel strides.
    // Naive concatenation of planes FAILS because each plane may have
    // padding bytes (stride > width) that corrupt the byte count for ML Kit.
    final nv21 = _yuv420ToNv21(image);
    if (nv21 == null) return null;

    return InputImage.fromBytes(
      bytes: nv21,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.width, // NV21 has no padding
      ),
    );
  }

  /// Converts Android YUV_420_888 [CameraImage] to NV21 byte array.
  ///
  /// NV21 layout: [Y plane row-by-row] + [interleaved VU for each 2x2 block]
  /// Respects [bytesPerRow] (row stride) and [bytesPerPixel] (pixel stride).
  Uint8List? _yuv420ToNv21(CameraImage image) {
    try {
      final width = image.width;
      final height = image.height;

      final yPlane = image.planes[0];
      final uPlane = image.planes[1];
      final vPlane = image.planes[2];

      final yRowStride = yPlane.bytesPerRow;
      final uvRowStride = uPlane.bytesPerRow;
      final uvPixelStride = uPlane.bytesPerPixel ?? 1;

      // NV21 size = width*height Y bytes + width*height/2 VU bytes
      final nv21 = Uint8List(width * height + 2 * (width ~/ 2) * (height ~/ 2));
      int idx = 0;

      // Copy Y plane (luma), row by row, trimming stride padding.
      for (int row = 0; row < height; row++) {
        final rowStart = row * yRowStride;
        for (int col = 0; col < width; col++) {
          nv21[idx++] = yPlane.bytes[rowStart + col];
        }
      }

      // Interleave V then U (NV21 = Y + VU, not UV).
      for (int row = 0; row < height ~/ 2; row++) {
        final rowStart = row * uvRowStride;
        for (int col = 0; col < width ~/ 2; col++) {
          final offset = rowStart + col * uvPixelStride;
          nv21[idx++] = vPlane.bytes[offset]; // V
          nv21[idx++] = uPlane.bytes[offset]; // U
        }
      }

      return nv21;
    } catch (e) {
      debugPrint('[OCR] ❌ NV21 conversion error: $e');
      return null;
    }
  }



  /// Computes the correct [InputImageRotation] based on sensor orientation
  /// and the current device orientation.
  InputImageRotation _rotationForCamera(
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) {
    int deviceAngle;
    switch (deviceOrientation) {
      case DeviceOrientation.landscapeLeft:
        deviceAngle = 90;
        break;
      case DeviceOrientation.portraitDown:
        deviceAngle = 180;
        break;
      case DeviceOrientation.landscapeRight:
        deviceAngle = 270;
        break;
      default: // portraitUp
        deviceAngle = 0;
    }

    final sensorOrientation = camera.sensorOrientation;
    int rotationAngle;
    if (camera.lensDirection == CameraLensDirection.front) {
      rotationAngle = (sensorOrientation + deviceAngle) % 360;
    } else {
      rotationAngle = (sensorOrientation - deviceAngle + 360) % 360;
    }

    final rotation = InputImageRotationValue.fromRawValue(rotationAngle) ??
        InputImageRotation.rotation0deg;

    debugPrint('[OCR] 🔄 Rotation: sensor=$sensorOrientation device=$deviceAngle final=${rotation.rawValue}°');
    return rotation;
  }
}
