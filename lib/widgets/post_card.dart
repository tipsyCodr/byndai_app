import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/widgets/glass_box.dart';

class PostCard extends StatelessWidget {
  final String userName;
  final String userRole;
  final String location;
  final String avatarUrl;
  final String postImageUrl;
  final String? description;
  final int likesCount;
  final int commentsCount;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onSave;

  const PostCard({
    super.key,
    required this.userName,
    required this.userRole,
    required this.location,
    this.avatarUrl = '',
    this.postImageUrl = '',
    this.description,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.onLike,
    this.onComment,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassBox(
      padding: const EdgeInsets.all(16),
      borderRadius: 24,
      blur: 12,
      opacity: isDark ? 0.18 : 0.26,
      gradientColors: isDark
          ? [
              const Color(0xFF1A2342).withValues(alpha: 0.9),
              const Color(0xFF121A34).withValues(alpha: 0.86),
            ]
          : [
              Colors.white.withValues(alpha: 0.92),
              const Color(0xFFEDF3FF).withValues(alpha: 0.84),
            ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PostHeader(
            userName: userName,
            userRole: userRole,
            location: location,
            avatarUrl: avatarUrl,
          ),
          if (description != null && description!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              description!,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.9),
                fontSize: 14,
                height: 1.45,
                letterSpacing: 0.15,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
          const SizedBox(height: 14),
          _PostImage(imageUrl: postImageUrl),
          const SizedBox(height: 12),
          _PostActions(
            likesCount: likesCount,
            commentsCount: commentsCount,
            onLike: onLike,
            onComment: onComment,
            onSave: onSave,
          ),
        ],
      ),
    );
  }
}

class _PostHeader extends StatelessWidget {
  final String userName;
  final String userRole;
  final String location;
  final String avatarUrl;

  const _PostHeader({
    required this.userName,
    required this.userRole,
    required this.location,
    required this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.2),
                    width: 1.2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: isDark
                      ? const Color(0xFF202A49)
                      : const Color(0xFFEAF0FF),
                  backgroundImage:
                      avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl.isEmpty
                      ? FaIcon(
                          FontAwesomeIcons.user,
                          color: colorScheme.primary,
                          size: 18,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                        letterSpacing: 0.25,
                      ),
                    ),
                    Text(
                      userRole,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        FaIcon(
                          FontAwesomeIcons.locationDot,
                          size: 10,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            location.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9,
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.9,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        FaIcon(
          FontAwesomeIcons.ellipsis,
          color: colorScheme.onSurface.withValues(alpha: 0.4),
          size: 16,
        ),
      ],
    );
  }
}

class _PostImage extends StatelessWidget {
  final String imageUrl;

  const _PostImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: imageUrl.isEmpty
          ? Container(
              height: 260,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: const [
                    Color(0xFF303852),
                    Color(0xFF1C2540),
                  ],
                ),
              ),
              child: const Center(
                child: FaIcon(
                  FontAwesomeIcons.image,
                  size: 54,
                  color: Colors.white70,
                ),
              ),
            )
          : Image.network(
              imageUrl,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
    );
  }
}

class _PostActions extends StatelessWidget {
  final int likesCount;
  final int commentsCount;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onSave;

  const _PostActions({
    required this.likesCount,
    required this.commentsCount,
    this.onLike,
    this.onComment,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        _ActionChip(
          icon: FontAwesomeIcons.heart,
          label: likesCount > 0 ? likesCount.toString() : 'Like',
          onTap: onLike,
        ),
        const SizedBox(width: 10),
        _ActionChip(
          icon: FontAwesomeIcons.comment,
          label: commentsCount > 0 ? commentsCount.toString() : 'Comment',
          onTap: onComment,
        ),
        const Spacer(),
        _CircleAction(
          icon: FontAwesomeIcons.bookmark,
          onTap: onSave,
          bgColor: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : colorScheme.primary.withValues(alpha: 0.08),
        ),
        const SizedBox(width: 8),
        _CircleAction(
          icon: FontAwesomeIcons.shareNodes,
          onTap: () {},
          bgColor: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : colorScheme.primary.withValues(alpha: 0.08),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final FaIconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionChip({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            FaIcon(
              icon,
              size: 14,
              color: colorScheme.onSurface.withValues(alpha: 0.74),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.74),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final FaIconData icon;
  final VoidCallback? onTap;
  final Color bgColor;

  const _CircleAction({
    required this.icon,
    required this.onTap,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
        ),
        child: FaIcon(
          icon,
          size: 14,
          color: colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
