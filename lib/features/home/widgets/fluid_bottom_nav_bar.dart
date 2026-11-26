import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gridcard/core/theme/app_theme.dart';
import 'package:gridcard/widgets/app_network_image.dart';
import 'package:gridcard/core/services/auth_provider.dart';
import 'package:provider/provider.dart';

class FluidNavBarItem {
  final dynamic icon;
  final String? imageUrl;
  final String label;

  const FluidNavBarItem({
    required this.icon,
    required this.label,
    this.imageUrl,
  });
}

class FluidBottomNavBar extends StatefulWidget {
  final PageController pageController;
  final List<FluidNavBarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const FluidBottomNavBar({
    super.key,
    required this.pageController,
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  State<FluidBottomNavBar> createState() => _FluidBottomNavBarState();
}

class _FluidBottomNavBarState extends State<FluidBottomNavBar> {
  double _currentPage = 0.0;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.selectedIndex.toDouble();
    widget.pageController.addListener(_onPageScroll);
  }

  @override
  void didUpdateWidget(covariant FluidBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageController != widget.pageController) {
      oldWidget.pageController.removeListener(_onPageScroll);
      widget.pageController.addListener(_onPageScroll);
    }
  }

  @override
  void dispose() {
    widget.pageController.removeListener(_onPageScroll);
    super.dispose();
  }

  void _onPageScroll() {
    if (widget.pageController.hasClients &&
        widget.pageController.page != null) {
      setState(() {
        _currentPage = widget.pageController.page!;
      });
    }
  }

  void _handleDrag(DragUpdateDetails details, double totalWidth) {
    if (widget.items.isEmpty) return;
    final itemWidth = totalWidth / widget.items.length;
    final targetPage = (details.localPosition.dx / itemWidth)
        .clamp(0.0, widget.items.length - 1.0);
    if (widget.pageController.hasClients) {
      widget.pageController.jumpTo(
        targetPage * widget.pageController.position.viewportDimension,
      );
    }
  }

  void _handleDragEnd(DragEndDetails details, double totalWidth) {
    if (widget.items.isEmpty) return;
    final rawIndex = (_currentPage).round().clamp(0, widget.items.length - 1);
    widget.onItemSelected(rawIndex);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final palette = theme.extension<AppThemeColors>();

    final liquidColor = isDark
        ? (palette?.dockActive ?? theme.colorScheme.primary)
        : theme.colorScheme.primary;

    final inactiveColor = palette?.dockInactive ??
        theme.colorScheme.onSurface.withValues(alpha: 0.55);

    final activeColor = isDark ? const Color(0xFF060D2D) : Colors.white;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final itemCount = widget.items.length;
        if (itemCount == 0) return const SizedBox.shrink();
        final itemWidth = totalWidth / itemCount;

        // Clamp continuous page within tabs range
        final clampedPage = _currentPage.clamp(0.0, itemCount - 1.0);

        // Opacity of indicator fades out if page moves beyond the items (e.g. index 4 AI assistant)
        final double indicatorOpacity;
        if (_currentPage <= itemCount - 1.0) {
          indicatorOpacity = 1.0;
        } else {
          indicatorOpacity =
              (1.0 - (_currentPage - (itemCount - 1.0))).clamp(0.0, 1.0);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (d) => _handleDrag(d, totalWidth),
          onHorizontalDragEnd: (d) => _handleDragEnd(d, totalWidth),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Liquid Fluid Indicator
              if (indicatorOpacity > 0.01)
                Opacity(
                  opacity: indicatorOpacity,
                  child: CustomPaint(
                    size: Size(totalWidth, 52),
                    painter: _FluidIndicatorPainter(
                      page: clampedPage,
                      itemWidth: itemWidth,
                      color: liquidColor,
                      isDark: isDark,
                    ),
                  ),
                ),

              // Items Row
              SizedBox(
                height: 52,
                child: Row(
                  children: List.generate(itemCount, (index) {
                    final dist = (_currentPage - index).abs().clamp(0.0, 1.0);
                    // Smooth color interpolation
                    final fgColor =
                        Color.lerp(activeColor, inactiveColor, dist)!;

                    final item = widget.items[index];

                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => widget.onItemSelected(index),
                        child: Center(
                          child: item.imageUrl != null
                              ? _buildAvatar(item.imageUrl!, dist, fgColor)
                              : (item.icon is IconData
                                  ? Icon(
                                      item.icon as IconData,
                                      color: fgColor,
                                      size: 19 + (1.0 - dist) * 1.5,
                                    )
                                  : FaIcon(
                                      item.icon,
                                      color: fgColor,
                                      size: 19 + (1.0 - dist) * 1.5,
                                    )),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatar(String url, double dist, Color borderColor) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor.withValues(alpha: 0.8),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: AppNetworkImage(
          imageUrl: url,
          width: 28,
          height: 28,
          fit: BoxFit.cover,
          cacheKey:
              context.read<AuthProvider>().profileUpdateCounter.toString(),
        ),
      ),
    );
  }
}

class _FluidIndicatorPainter extends CustomPainter {
  final double page;
  final double itemWidth;
  final Color color;
  final bool isDark;

  _FluidIndicatorPainter({
    required this.page,
    required this.itemWidth,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = (page + 0.5) * itemWidth;
    final centerY = size.height / 2;

    // Movement fraction (distance from nearest whole tab 0.0 -> 0.5)
    final diff = (page - page.round()).abs();
    final stretchFactor =
        math.sin(diff * math.pi); // 0.0 at rest, 1.0 mid-swipe
/*  */
    // Base pill dimensions (wider horizontal pill shape)
    final baseWidth = math.min(itemWidth - 1.7, 80.0);
    final baseHeight = size.height;

    // Fluid liquid stretch: horizontally stretches, vertically compresses
    final pillWidth = baseWidth + (stretchFactor * 16.0);
    final pillHeight = baseHeight - (stretchFactor * 4.0);

    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: pillWidth,
        height: pillHeight,
      ),
      Radius.circular(pillHeight / 2),
    );

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Subtle liquid glow / shadow
    final shadowPaint = Paint()
      ..color = color.withValues(alpha: isDark ? 0.35 : 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawRRect(rect.shift(const Offset(0, 2)), shadowPaint);
    canvas.drawRRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _FluidIndicatorPainter oldDelegate) {
    return oldDelegate.page != page ||
        oldDelegate.color != color ||
        oldDelegate.itemWidth != itemWidth;
  }
}
