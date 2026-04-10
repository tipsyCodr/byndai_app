import 'package:flutter/material.dart';

/// A modern, full-width top notification overlay.
/// Use `TopAlert.show(context, ...)` from any widget.
class TopAlert {
  static void show(
    BuildContext context,
    String message, {
    bool isSuccess = false,
    bool isError = false,
  }) {
    final overlay = Overlay.of(context);
    final topPadding = MediaQuery.of(context).padding.top;

    Color bgColor;
    IconData icon;
    if (isSuccess) {
      bgColor = const Color(0xFF2E7D32);
      icon = Icons.check_circle_rounded;
    } else if (isError) {
      bgColor = const Color(0xFFC62828);
      icon = Icons.error_rounded;
    } else {
      bgColor = const Color(0xFFE65100);
      icon = Icons.info_rounded;
    }

    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: (topPadding > 0 ? topPadding : 20) + 48,

        left: 12,
        right: 12,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Transform.translate(
              offset: Offset(0, -30 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: bgColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (overlayEntry.mounted) overlayEntry.remove();
                    },
                    child: const Icon(Icons.close,
                        color: Colors.white70, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 4), () {
      if (overlayEntry.mounted) overlayEntry.remove();
    });
  }
}
