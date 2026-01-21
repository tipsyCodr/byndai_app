import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/core/services/social_provider.dart';
import 'package:gridcard/features/business_feed/post_creation_page.dart';
import 'package:gridcard/features/business_feed/post_details_page.dart';
import 'package:gridcard/models/feed_item.dart';
import 'package:gridcard/widgets/post_card.dart';
import 'package:provider/provider.dart';

class BusinessFeedPage extends StatefulWidget {
  final String industryType;
  const BusinessFeedPage({super.key, this.industryType = 'All'});

  @override
  State<BusinessFeedPage> createState() => _BusinessFeedPageState();
}

class _BusinessFeedPageState extends State<BusinessFeedPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SocialProvider>().fetchPosts(widget.industryType);
    });
  }

  @override
  Widget build(BuildContext context) {
    final socialProvider = context.watch<SocialProvider>();
    final posts = socialProvider.posts;
    final isLoading = socialProvider.isLoading;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title:
            const Text("Business Feed", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => socialProvider.fetchPosts(widget.industryType),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  PostCreationPage(industryType: widget.industryType),
            ),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: isLoading && posts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => socialProvider.fetchPosts(widget.industryType),
              child: ListView.separated(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                itemCount: posts.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final FeedItem item = posts[index];

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
            ),
    );
  }
}
