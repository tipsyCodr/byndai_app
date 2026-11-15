import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gridcard/core/services/ai_flyer_service.dart';

class AiFlyerProgressSheet extends StatefulWidget {
  final int generationId;
  final String title;

  const AiFlyerProgressSheet({
    super.key,
    required this.generationId,
    required this.title,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required int generationId,
    required String title,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiFlyerProgressSheet(
        generationId: generationId,
        title: title,
      ),
    );
  }

  @override
  State<AiFlyerProgressSheet> createState() => _AiFlyerProgressSheetState();
}

class _AiFlyerProgressSheetState extends State<AiFlyerProgressSheet> {
  Timer? _pollingTimer;
  int _secondsElapsed = 0;
  String _currentStepText = 'Contacting AI Creative Studio...';
  String? _errorMessage;
  bool _isFailed = false;

  final List<String> _steps = [
    'Initializing creative prompt & branding...',
    'Generating high-resolution artistic background...',
    'Applying business logo, typography & contact info...',
    'Optimizing quality & finalizing flyer...',
  ];

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _secondsElapsed += 2;
        int stepIdx = (_secondsElapsed ~/ 6) % _steps.length;
        _currentStepText = _steps[stepIdx];
      });

      try {
        final flyer = await AiFlyerService.checkStatus(widget.generationId);
        final status = flyer['status'];

        if (status == 'completed') {
          timer.cancel();
          if (mounted) {
            Navigator.of(context).pop(flyer);
          }
        } else if (status == 'failed') {
          timer.cancel();
          if (mounted) {
            setState(() {
              _isFailed = true;
              _errorMessage = flyer['error_message'] ?? 'Generation failed. Please try again.';
            });
          }
        }
      } catch (e) {
        // Continue polling until timeout or explicit failure
        debugPrint('Polling check failed: $e');
      }

      // Timeout after 90 seconds
      if (_secondsElapsed >= 90) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _isFailed = true;
            _errorMessage = 'Generation is taking longer than usual. Please check "My AI Flyers" shortly.';
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (!_isFailed) ...[
            Container(
              width: 80,
              height: 80,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.15),
                    theme.colorScheme.secondary.withValues(alpha: 0.15),
                  ],
                ),
              ),
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _currentStepText,
                key: ValueKey<String>(_currentStepText),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${_secondsElapsed}s elapsed',
              style: theme.textTheme.labelSmall?.copyWith(color: theme.disabledColor),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Run in Background'),
            ),
          ] else ...[
            Icon(Icons.error_outline_rounded, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Generation Failed',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Something went wrong while generating the flyer.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text('Dismiss'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      setState(() {
                        _isFailed = false;
                        _errorMessage = null;
                        _secondsElapsed = 0;
                      });
                      _startPolling();
                    },
                    child: const Text('Retry Check'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

