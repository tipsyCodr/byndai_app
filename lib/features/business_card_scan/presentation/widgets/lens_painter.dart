import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:gridcard/features/business_card_scan/presentation/scanner_state.dart';

/// Google-Lens-style overlay painter.
///
/// - Idle / Scanning: pulsing white dots over detected text blocks.
/// - LockedIn: Elegant glowing white dots + a subtle sweeping scan line.
/// - Processing: animated spinner arc drawn over the card guide rect.
class LensPainter extends CustomPainter {
  final List<Rect> blocks;
  final Size imageSize;
  final ScannerPhase phase;

  /// 0.0–1.0 pulse animation value (driven by AnimationController).
  final double pulse;

  /// 0.0–1.0 scan line position (driven by AnimationController).
  final double scanLine;

  /// 0.0–1.0 animation loop for processing phase (particles + rings)
  final double processAnim;

  LensPainter({
    required this.blocks,
    required this.imageSize,
    required this.phase,
    required this.pulse,
    required this.scanLine,
    required this.processAnim,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    final isLocked = phase == ScannerPhase.lockedIn;
    final dotPaint = Paint()..style = PaintingStyle.fill;

    // Draw dots
    for (int i = 0; i < blocks.length; i++) {
      final rect = blocks[i];
      final scaled = Rect.fromLTRB(
        rect.left * scaleX,
        rect.top * scaleY,
        rect.right * scaleX,
        rect.bottom * scaleY,
      );

      if (isLocked) {
        // Premium elegant dots
        dotPaint.color = Colors.white.withValues(alpha: 0.8);
        dotPaint.maskFilter = MaskFilter.blur(BlurStyle.normal, 2.0 + pulse * 2);

        final radius = 4.0 + pulse * 2;
        canvas.drawCircle(scaled.center, radius, dotPaint);

        // Inner bright core
        final corePaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(scaled.center, radius * 0.5, corePaint);
      } else {
        dotPaint.color = Colors.white.withValues(alpha: 0.4 + pulse * 0.4);
        dotPaint.maskFilter = null;
        canvas.drawCircle(scaled.center, 3.5, dotPaint);
      }
    }

    if (isLocked && blocks.isNotEmpty) {
      _drawScanLine(canvas, size, scaleX, scaleY);
    }

    // Draw processing magic if in processing phase
    if (phase == ScannerPhase.processing) {
      _drawProcessingOverlay(canvas, size, scaleX, scaleY);
    }
  }

  void _drawScanLine(Canvas canvas, Size size, double scaleX, double scaleY) {
    // Compute bounding box of all blocks.
    double minY = double.infinity, maxY = double.negativeInfinity;
    double minX = double.infinity, maxX = double.negativeInfinity;
    for (final r in blocks) {
      final sy = r.top * scaleY;
      final ey = r.bottom * scaleY;
      final sx = r.left * scaleX;
      final ex = r.right * scaleX;
      if (sy < minY) minY = sy;
      if (ey > maxY) maxY = ey;
      if (sx < minX) minX = sx;
      if (ex > maxX) maxX = ex;
    }

    // Clamp to screen
    minX = math.max(0, minX - 12);
    maxX = math.min(size.width, maxX + 12);
    minY = math.max(0, minY - 8);
    maxY = math.min(size.height, maxY + 8);

    final y = minY + (maxY - minY) * scanLine;

    // Elegant glowing scan line
    final glowPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(minX, y),
        Offset(maxX, y),
        [
          Colors.transparent,
          const Color(0xFF00E5FF).withValues(alpha: 0.3),
          const Color(0xFF00E5FF).withValues(alpha: 0.6),
          const Color(0xFF00E5FF).withValues(alpha: 0.3),
          Colors.transparent,
        ],
        const [0.0, 0.25, 0.5, 0.75, 1.0],
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0;

    canvas.drawLine(Offset(minX, y), Offset(maxX, y), glowPaint);

    // Bright core of the scan line
    final corePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(minX, y),
        Offset(maxX, y),
        [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.4),
          Colors.white.withValues(alpha: 0.9),
          Colors.white.withValues(alpha: 0.4),
          Colors.transparent,
        ],
        const [0.0, 0.25, 0.5, 0.75, 1.0],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(minX, y), Offset(maxX, y), corePaint);
  }

  void _drawProcessingOverlay(Canvas canvas, Size size, double scaleX, double scaleY) {
    // Use screen center if no blocks
    final Offset center;
    if (blocks.isEmpty) {
      center = Offset(size.width / 2, size.height / 2);
    } else {
      // Calculate bounding box of all blocks
      double minY = double.infinity, maxY = double.negativeInfinity;
      double minX = double.infinity, maxX = double.negativeInfinity;
      for (final r in blocks) {
        final sy = r.top * scaleY;
        final ey = r.bottom * scaleY;
        final sx = r.left * scaleX;
        final ex = r.right * scaleX;
        if (sy < minY) minY = sy;
        if (ey > maxY) maxY = ey;
        if (sx < minX) minX = sx;
        if (ex > maxX) maxX = ex;
      }

      minX = math.max(0, minX - 12);
      maxX = math.min(size.width, maxX + 12);
      minY = math.max(0, minY - 8);
      maxY = math.min(size.height, maxY + 8);

      final centerX = (minX + maxX) / 2;
      final centerY = (minY + maxY) / 2;
      center = Offset(centerX, centerY);
    }

    // 1. EXPANDING RINGS
    final ringCount = 4;
    for (int i = 0; i < ringCount; i++) {
      final delay = (i / ringCount);
      final progress = (processAnim + delay) % 1.0;
      final radius = 30.0 + (progress * 180.0);
      final alpha = (1.0 - progress) * 0.6;

      final ringPaint = Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

      canvas.drawCircle(center, radius, ringPaint);
    }

    // 2. SCANNING BEAMS across blocks
    final beamProgress = (processAnim * 1.5) % 1.0;
    for (final rect in blocks) {
      final scaled = Rect.fromLTRB(
        rect.left * scaleX,
        rect.top * scaleY,
        rect.right * scaleX,
        rect.bottom * scaleY,
      );

      final beamY = scaled.top + (scaled.height * beamProgress);
      final beamPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(scaled.left, beamY),
          Offset(scaled.right, beamY),
          [
            Colors.transparent,
            const Color(0xFF00E5FF).withValues(alpha: 0.5),
            Colors.transparent,
          ],
          const [0.0, 0.5, 1.0],
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);

      canvas.drawLine(
        Offset(scaled.left, beamY),
        Offset(scaled.right, beamY),
        beamPaint,
      );
    }

    // 3. PARTICLE SPARKLES
    final particleCount = 8;
    for (int i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * 2 * math.pi;
      final particleProgress = (processAnim + (i / particleCount)) % 1.0;
      
      final distance = 60.0 + (particleProgress * 120.0);
      final px = center.dx + math.cos(angle) * distance;
      final py = center.dy + math.sin(angle) * distance;
      
      final particleAlpha = (1.0 - particleProgress) * 0.8;
      final particleSize = 2.0 + (particleProgress * 3.0);

      final particlePaint = Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: particleAlpha)
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, particleSize);

      canvas.drawCircle(Offset(px, py), particleSize, particlePaint);
    }
  }

  @override
  bool shouldRepaint(LensPainter old) =>
      old.blocks != blocks ||
      old.imageSize != imageSize ||
      old.phase != phase ||
      old.pulse != pulse ||
      old.scanLine != scanLine ||
      old.processAnim != processAnim;
}
