import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:gridcard/core/services/social_provider.dart';
import 'package:gridcard/models/feed_item.dart';
import 'package:gridcard/widgets/app_network_image.dart';
import 'package:gridcard/widgets/glass_box.dart';

class FeedItemTile extends StatelessWidget {
  final int postId;

  const FeedItemTile({
    super.key,
    required this.postId,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Selector<SocialProvider, FeedItem?>(
      selector: (_, provider) {
        try {
          return provider.posts.firstWhere((post) => post.id == postId);
        } catch (_) {
          return null;
        }
      },
      builder: (context, post, _) {
        if (post == null) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: GlassBox(
            padding: const EdgeInsets.all(14),
            borderRadius: 20,
            blur: 10,
            opacity: isDark ? 0.18 : 0.24,
            border: Border.all(
              color: colorScheme.primary.withOpacity(isDark ? 0.16 : 0.12),
              width: 0.8,
            ),
            gradientColors: isDark
                ? [
                    const Color(0xFF1A2342).withOpacity(0.9),
                    const Color(0xFF121A34).withOpacity(0.86),
                  ]
                : [
                    Colors.white.withOpacity(0.94),
                    const Color(0xFFEEF4FF).withOpacity(0.82),
                  ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      child: ClipOval(
                        child: AppNetworkImage(
                          imageUrl: post.user.imageUrl,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.user.fullName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            post.user.designation,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (post.industry != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          post.industry!,
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                /// Content
                if (post.content?.isNotEmpty ?? false)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      post.content!,
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ),

                /// Image
                if (post.imageUrl?.isNotEmpty ?? false)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AppNetworkImage(
                      imageUrl: post.imageUrl!,
                      width: double.infinity,
                      height: 250,
                      fit: BoxFit.cover,
                    ),
                  ),

                const SizedBox(height: 12),

                /// Footer
                Row(
                  children: [
                    _ActionButton(
                      icon: post.isLiked
                          ? FontAwesomeIcons.solidThumbsUp
                          : FontAwesomeIcons.thumbsUp,
                      label: post.likesCount.toString(),
                      color: post.isLiked ? colorScheme.primary : null,
                      onTap: () =>
                          context.read<SocialProvider>().toggleLike(post.id),
                    ),
                    const SizedBox(width: 16),
                    _ActionButton(
                      icon: FontAwesomeIcons.comment,
                      label: post.commentsCount.toString(),
                      onTap: () {
                        // Navigate to comments
                      },
                    ),
                    const Spacer(),
                    _ActionButton(
                      icon: post.isSaved
                          ? FontAwesomeIcons.solidBookmark
                          : FontAwesomeIcons.bookmark,
                      color: post.isSaved ? colorScheme.primary : null,
                      onTap: () =>
                          context.read<SocialProvider>().toggleSave(post.id),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  final FaIconData icon;
  final String? label;
  final Color? color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    this.label,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          FaIcon(
            icon,
            size: 18,
            color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          if (label != null) ...[
            const SizedBox(width: 6),
            Text(
              label!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
