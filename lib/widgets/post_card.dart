import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';

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

    return Container(
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: colorScheme.onSurface.withOpacity(0.05), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(isDark ? 0.1 : 0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
              const SizedBox(height: 16),
              Text(
                description!,
                style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 14,
                    height: 1.5,
                    letterSpacing: 0.2,
                    fontWeight: FontWeight.w400),
              ),
            ],
            const SizedBox(height: 16),
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
      ),
    );
  }
}

// 👤 Header widget
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
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: colorScheme.primary.withOpacity(0.1), width: 1.5),
              ),
              child: CircleAvatar(
                radius: 26,
                backgroundColor:
                    isDark ? colorScheme.surface : Colors.grey[200],
                backgroundImage:
                    avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl.isEmpty
                    ? Icon(CupertinoIcons.person,
                        color: colorScheme.primary, size: 28)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(userName,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? colorScheme.onSurface
                            : colorScheme.primary,
                        letterSpacing: 0.3)),
                Text(userRole,
                    style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurface.withOpacity(0.5),
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(CupertinoIcons.location,
                        size: 10, color: colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(location.toUpperCase(),
                        style: TextStyle(
                            fontSize: 9,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1)),
                  ],
                ),
              ],
            ),
          ],
        ),
        Icon(CupertinoIcons.ellipsis,
            color: colorScheme.onSurface.withOpacity(0.3)),
      ],
    );
  }
}

// 🖼️ Image section
class _PostImage extends StatelessWidget {
  final String imageUrl;

  const _PostImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConfig.roundness),
      child: imageUrl.isEmpty
          ? Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple, Colors.blue],
                ),
              ),
              child: const SizedBox(
                height: 350,
                width: double.infinity,
                child: Center(
                    child: Icon(Icons.favorite, size: 80, color: Colors.white)),
              ),
            )
          : Image.network(
              imageUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
    );
  }
}

// ❤️ Like/Comment/Share Row (expand later)
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
    return Row(
      children: [
        _ActionButton(
          icon: CupertinoIcons.heart,
          label: likesCount > 0 ? likesCount.toString() : "Like",
          onTap: onLike,
        ),
        const SizedBox(width: 16),
        _ActionButton(
          icon: CupertinoIcons.chat_bubble,
          label: commentsCount > 0 ? commentsCount.toString() : "Comment",
          onTap: onComment,
        ),
        const Spacer(),
        IconButton(
          onPressed: onSave,
          icon: Icon(CupertinoIcons.bookmark,
              color: colorScheme.onSurface.withOpacity(0.5), size: 22),
        ),
        IconButton(
          onPressed: () {},
          icon: Icon(CupertinoIcons.share,
              color: colorScheme.onSurface.withOpacity(0.5), size: 22),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 22, color: colorScheme.onSurface.withOpacity(0.6)),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
