import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/social_provider.dart';
import 'package:gridcard/features/business_feed/post_details_page.dart';
import 'package:gridcard/widgets/app_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
                final avatarUrl = AppConfig.getFullUrl(item.user.imageUrl) ?? '';
                final postImageUrl = AppConfig.getFullUrl(item.imageUrl) ?? '';
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
                  child: _buildEventPostCard(
                    context: context,
                    item: item,
                    avatarUrl: avatarUrl,
                    postImageUrl: postImageUrl,
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEventPostCard({
    required BuildContext context,
    required dynamic item,
    required String avatarUrl,
    required String postImageUrl,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final eventLink = _extractFirstUrl(item.content ?? '');

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (postImageUrl.isNotEmpty)
            SizedBox(
              width: double.infinity,
              height: 220,
              child: AppNetworkImage(
                imageUrl: postImageUrl,
                fit: BoxFit.cover,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage:
                          avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                      child:
                          avatarUrl.isEmpty ? const Icon(Icons.person, size: 18) : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.user.fullName,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if ((item.content ?? '').toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    item.content.toString(),
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (eventLink != null) {
                        await launchUrl(
                          Uri.parse(eventLink),
                          mode: LaunchMode.externalApplication,
                        );
                        return;
                      }
                      if (!context.mounted) return;
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
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(
                      eventLink != null ? 'Open Event Link' : 'View Event Details',
                    ),
                  ),
                ),
                // Event details section intentionally removed from this page design.
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _extractFirstUrl(String input) {
    final match = RegExp(r'(https?:\/\/[^\s]+)').firstMatch(input);
    return match?.group(0);
  }
}
