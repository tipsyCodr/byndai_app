import 'package:flutter/material.dart';

enum AppButtonVariant { filled, outlined, text }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool expanded;
  final IconData? icon;
  final AppButtonVariant variant;
  final double height;
  final EdgeInsetsGeometry? padding;
  final BorderRadiusGeometry borderRadius;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? fontSize;
  final FontWeight? fontWeight;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.expanded = true,
    this.icon,
    this.variant = AppButtonVariant.filled,
    this.height = 48,
    this.padding,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.backgroundColor,
    this.foregroundColor,
    this.fontSize,
    this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final disabled = onPressed == null || isLoading;

    final child = SizedBox(
      height: height,
      child: Center(
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _contentColor(colorScheme),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: fontWeight,
                      color: _contentColor(colorScheme),
                    ),
                  ),
                ],
              ),
      ),
    );

    Widget button;
    switch (variant) {
      case AppButtonVariant.outlined:
        button = OutlinedButton(
          onPressed: disabled ? null : onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: Size(0, height),
            padding: padding,
            foregroundColor: foregroundColor ?? colorScheme.primary,
            side: BorderSide(color: backgroundColor ?? colorScheme.primary),
            shape: RoundedRectangleBorder(borderRadius: borderRadius),
          ),
          child: child,
        );
        break;
      case AppButtonVariant.text:
        button = TextButton(
          onPressed: disabled ? null : onPressed,
          style: TextButton.styleFrom(
            minimumSize: Size(0, height),
            padding: padding,
            foregroundColor: foregroundColor ?? colorScheme.primary,
            shape: RoundedRectangleBorder(borderRadius: borderRadius),
          ),
          child: child,
        );
        break;
      case AppButtonVariant.filled:
        button = ElevatedButton(
          onPressed: disabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            minimumSize: Size(0, height),
            padding: padding,
            backgroundColor: backgroundColor ?? colorScheme.primary,
            foregroundColor: foregroundColor ?? colorScheme.onPrimary,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: borderRadius),
          ),
          child: child,
        );
        break;
    }

    if (!expanded) return button;
    return SizedBox(width: double.infinity, child: button);
  }

  Color _contentColor(ColorScheme colorScheme) {
    if (foregroundColor != null) return foregroundColor!;
    switch (variant) {
      case AppButtonVariant.filled:
        return colorScheme.onPrimary;
      case AppButtonVariant.outlined:
      case AppButtonVariant.text:
        return colorScheme.primary;
    }
  }
}
