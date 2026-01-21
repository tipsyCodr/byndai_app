import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/core/services/social_provider.dart';
import 'package:gridcard/features/events/events_page.dart';
import 'package:gridcard/widgets/connection_suggest.dart';
import 'package:gridcard/widgets/post_card.dart';
import 'package:provider/provider.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final TextEditingController _searchController = TextEditingController();

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

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchBar(),
                const SizedBox(height: 24),
                _buildSectionHeader("Suggested Connections", () {}),
                const SizedBox(height: 12),
                const ConnectionSuggest(), // We can enhance this later with real suggested data
                const SizedBox(height: 32),
                _buildSectionHeader("Upcoming Events", () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const EventsPage()));
                }),
                const SizedBox(height: 12),
                _buildEventCard(),
                const SizedBox(height: 32),
                _buildSectionHeader("Trending Updates", () {}),
              ],
            ),
          ),
        ),
        socialProvider.isLoading
            ? const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()))
            : SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final post = socialProvider.posts[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: PostCard(
                        userName: post.user.fullName,
                        userRole: post.user.designation,
                        location: post.industry ?? "Business",
                        avatarUrl: post.user.imageUrl,
                        postImageUrl: post.imageUrl ?? '',
                        description: post.content,
                        likesCount: post.likesCount,
                        commentsCount: post.commentsCount,
                        onLike: () => socialProvider.toggleLike(post.id),
                        onSave: () => socialProvider.toggleSave(post.id),
                      ),
                    );
                  },
                  childCount: socialProvider.posts.length,
                ),
              ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
      ],
    );
  }

  Widget _buildSearchBar() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainerHighest.withOpacity(0.5)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.onSurface.withOpacity(0.05)),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: colorScheme.onSurface),
        decoration: InputDecoration(
          icon: Icon(CupertinoIcons.search,
              color: colorScheme.onSurface.withOpacity(0.3), size: 20),
          hintText: "Search people, products, or industries...",
          hintStyle: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.2), fontSize: 14),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildEventCard() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.calendar_badge_plus,
              color: colorScheme.onPrimary, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Global Business Meet 2026",
                    style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                Text("Join 500+ entrepreneurs worldwide.",
                    style: TextStyle(
                        color: colorScheme.onPrimary.withOpacity(0.7),
                        fontSize: 12)),
              ],
            ),
          ),
          Icon(CupertinoIcons.chevron_right,
              color: colorScheme.onPrimary.withOpacity(0.7)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onSeeAll) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: TextStyle(
                color: colorScheme.primary,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        TextButton(
          onPressed: onSeeAll,
          child: Text("See all",
              style: TextStyle(color: colorScheme.primary, fontSize: 14)),
        ),
      ],
    );
  }
}
