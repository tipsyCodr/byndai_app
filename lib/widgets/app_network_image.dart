import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';

class AppNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Map<String, String>? headers;

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.headers,
    this.cacheKey, // ✅ Added cacheKey for refreshing
  });

  final String? cacheKey;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildPlaceholder(context);
    }

    // 🔥 Centralized Laravel URL Rewriter
    String? finalUrl = AppConfig.getFullUrl(imageUrl);
    if (finalUrl == null) {
      debugPrint(
          '🖼 AppNetworkImage: getFullUrl returned null for "$imageUrl"');
      return _buildPlaceholder(context);
    }

    // Validate it's a proper URL
    final uri = Uri.tryParse(finalUrl);
    if (uri == null || !uri.hasScheme) {
      debugPrint(
          '🖼 AppNetworkImage: Invalid URL constructed: "$finalUrl" from "$imageUrl"');
      return _buildPlaceholder(context);
    }

    debugPrint('🖼 AppNetworkImage: Loading "$finalUrl"');

    // ✅ Apply Cache Buster if key provided
    if (cacheKey != null && cacheKey!.isNotEmpty) {
      final connector = finalUrl.contains('?') ? '&' : '?';
      finalUrl = "$finalUrl${connector}v=$cacheKey";
    }

    final imageWidget = CachedNetworkImage(
      imageUrl: finalUrl,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: 600, // Optimize memory
      fadeInDuration: const Duration(milliseconds: 400),
      httpHeaders: headers,
      placeholder: (context, url) =>
          _buildPlaceholder(context, isLoading: true),
      errorWidget: (context, url, error) {
        debugPrint("🖼 AppNetworkImage Error for $url: $error");
        return _buildPlaceholder(context, isError: true);
      },
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildPlaceholder(BuildContext context,
      {bool isLoading = false, bool isError = false}) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: borderRadius,
      ),
      child: Center(
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                isError
                    ? Icons.image_not_supported_outlined
                    : Icons.image_outlined,
                color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                size: (height != null && height! < 30) ? 14 : 24,
              ),
      ),
    );
  }
}
