import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:gridcard/core/services/social_provider.dart';
import 'package:gridcard/models/feed_item.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class PostDetailsPage extends StatefulWidget {
  final FeedItem item;
  final bool isLiked;

  const PostDetailsPage({super.key, required this.item, required this.isLiked});

  @override
  State<PostDetailsPage> createState() => _PostDetailsPageState();
}

class _PostDetailsPageState extends State<PostDetailsPage> {
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SocialProvider>().fetchComments(widget.item.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final socialProvider = context.watch<SocialProvider>();
    final comments = socialProvider.getComments(widget.item.id);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title:
            Text("Post Details", style: TextStyle(color: colorScheme.primary)),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.primary),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: isDark
                            ? colorScheme.surfaceContainerHighest
                            : Colors.grey[200],
                        backgroundImage: widget.item.user.imageUrl.isNotEmpty
                            ? NetworkImage(widget.item.user.imageUrl)
                            : null,
                        child: widget.item.user.imageUrl.isEmpty
                            ? Icon(CupertinoIcons.person_fill,
                                color: colorScheme.primary)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.item.user.fullName,
                                style: TextStyle(
                                    color: isDark
                                        ? colorScheme.onSurface
                                        : colorScheme.primary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                            Text(widget.item.user.designation,
                                style: TextStyle(
                                    color:
                                        colorScheme.onSurface.withOpacity(0.5),
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Content
                  if (widget.item.content != null &&
                      widget.item.content!.isNotEmpty)
                    Text(widget.item.content!,
                        style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 15,
                            height: 1.4)),

                  const SizedBox(height: 16),

                  // Image
                  if (widget.item.imageUrl != null &&
                      widget.item.imageUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        widget.item.imageUrl!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Actions Row
                  Row(
                    children: [
                      _ActionButton(
                        icon: widget.item.isLiked
                            ? CupertinoIcons.heart_fill
                            : CupertinoIcons.heart,
                        label: "${widget.item.likesCount}",
                        iconColor: widget.item.isLiked
                            ? Colors.red
                            : colorScheme.onSurface.withOpacity(0.6),
                        onTap: () => socialProvider.toggleLike(widget.item.id),
                      ),
                      const SizedBox(width: 20),
                      _ActionButton(
                        icon: CupertinoIcons.chat_bubble,
                        label: "${widget.item.commentsCount}",
                        iconColor: colorScheme.onSurface.withOpacity(0.6),
                        onTap: () {},
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () =>
                            socialProvider.toggleSave(widget.item.id),
                        icon: Icon(
                          widget.item.isSaved
                              ? CupertinoIcons.bookmark_fill
                              : CupertinoIcons.bookmark,
                          color: widget.item.isSaved
                              ? colorScheme.primary
                              : colorScheme.onSurface.withOpacity(0.5),
                          size: 22,
                        ),
                      ),
                    ],
                  ),

                  Divider(
                      color: colorScheme.onSurface.withOpacity(0.1),
                      height: 40),

                  // Comments
                  Text("Comments",
                      style: TextStyle(
                          color: colorScheme.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  if (comments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text("No comments yet. Be the first to comment!",
                            style: TextStyle(
                                color: colorScheme.onSurface.withOpacity(0.3),
                                fontSize: 14)),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor:
                                    colorScheme.onSurface.withOpacity(0.05),
                                child: Icon(CupertinoIcons.person_fill,
                                    size: 14,
                                    color:
                                        colorScheme.onSurface.withOpacity(0.3)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(comment['user']?['name'] ?? "User",
                                            style: TextStyle(
                                                color: isDark
                                                    ? colorScheme.onSurface
                                                    : colorScheme.primary,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold)),
                                        if (comment['created_at'] != null)
                                          Text(
                                            DateFormat('MMM dd').format(
                                                DateTime.parse(
                                                    comment['created_at'])),
                                            style: TextStyle(
                                                color: colorScheme.onSurface
                                                    .withOpacity(0.3),
                                                fontSize: 10),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(comment['comment'] ?? "",
                                        style: TextStyle(
                                            color: colorScheme.onSurface
                                                .withOpacity(0.7),
                                            fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),

          // Comment Input
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              top: 12,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                  top: BorderSide(
                      color: colorScheme.onSurface.withOpacity(0.05))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style:
                        TextStyle(color: colorScheme.onSurface, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "Write a comment...",
                      hintStyle: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.3)),
                      filled: true,
                      fillColor: isDark
                          ? colorScheme.surfaceContainerHighest
                          : Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () async {
                    if (_commentController.text.trim().isNotEmpty) {
                      final success = await socialProvider.addComment(
                          widget.item.id, _commentController.text.trim());
                      if (success) {
                        _commentController.clear();
                        FocusScope.of(context).unfocus();
                      }
                    }
                  },
                  icon: Icon(CupertinoIcons.arrow_up_circle_fill,
                      color: colorScheme.primary, size: 32),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = Colors.white70,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.6), fontSize: 14)),
        ],
      ),
    );
  }
}
