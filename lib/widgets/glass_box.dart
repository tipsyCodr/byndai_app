import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:gridcard/core/theme/app_theme.dart';

class GlassBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double blur;
  final double opacity;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final List<Color>? gradientColors;
  final BoxBorder? border;
  final Widget child;
  

  const GlassBox({
    super.key,
    this.width,
    this.height,
    this.blur = 15,
    this.opacity = 0.1,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.all(16),
    this.gradientColors,
    this.border,
    required this.child,
   
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppThemeColors>();
    final surfaceTint = palette?.glassTop ?? theme.colorScheme.surface;
    final borderTint = theme.colorScheme.primary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: border ??
                Border.all(
                  color: borderTint.withValues(alpha: 0.2),
                  width: 1.0,
                ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors ??
                  [
                    surfaceTint.withValues(alpha: opacity * 1.5),
                    (palette?.glassBottom ?? surfaceTint)
                        .withValues(alpha: opacity),
                  ],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
