import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/core/services/social_provider.dart';
import 'package:gridcard/features/business_feed/post_details_page.dart';
import 'package:gridcard/widgets/post_card.dart';
import 'package:provider/provider.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SocialProvider>().fetchPosts('All');
    });
  }

  @override
  Widget build(BuildContext context) {
    final socialProvider = context.watch<SocialProvider>();
    final posts = socialProvider.posts;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Featured Stories",
            style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: socialProvider.isLoading && posts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: posts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final item = posts[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PostDetailsPage(
                          item: item,
                          isLiked: item.isLiked,
                        ),
                      ),
                    );
                  },
                  child: PostCard(
                    userName: item.user.fullName,
                    userRole: item.user.designation,
                    location: item.industry ?? "Business",
                    avatarUrl: item.user.imageUrl,
                    postImageUrl: item.imageUrl ?? '',
                    description: item.content,
                    likesCount: item.likesCount,
                    commentsCount: item.commentsCount,
                    onLike: () => socialProvider.toggleLike(item.id),
                    onSave: () => socialProvider.toggleSave(item.id),
                  ),
                );
              },
            ),
    );
  }
}
