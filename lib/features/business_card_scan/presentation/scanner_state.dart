import 'package:flutter/material.dart';

/// State machine phases for the scanner lifecycle.
enum ScannerPhase {
  /// Camera initialising or no card detected.
  idle,

  /// Card-like text patterns detected; accumulating stable frames.
  scanning,

  /// Enough stable frames detected; ready to auto-capture.
  lockedIn,

  /// Image captured; AI parsing in progress.
  processing,

  /// Parsing done; showing result modal.
  done,
}

/// Immutable UI state for [GoogleLensScanner].
class ScannerState {
  final ScannerPhase phase;
  final String statusText;
  final List<Rect> detectedBlocks;
  final Size? imageSize;
  final bool isPortrait;
  final int lockInFrames;

  const ScannerState({
    this.phase = ScannerPhase.idle,
    this.statusText = 'Align business card',
    this.detectedBlocks = const [],
    this.imageSize,
    this.isPortrait = false,
    this.lockInFrames = 0,
  });

  ScannerState copyWith({
    ScannerPhase? phase,
    String? statusText,
    List<Rect>? detectedBlocks,
    Size? imageSize,
    bool? isPortrait,
    int? lockInFrames,
  }) =>
      ScannerState(
        phase: phase ?? this.phase,
        statusText: statusText ?? this.statusText,
        detectedBlocks: detectedBlocks ?? this.detectedBlocks,
        imageSize: imageSize ?? this.imageSize,
        isPortrait: isPortrait ?? this.isPortrait,
        lockInFrames: lockInFrames ?? this.lockInFrames,
      );

  bool get isProcessingOrDone =>
      phase == ScannerPhase.processing || phase == ScannerPhase.done;
}
