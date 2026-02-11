import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:gridcard/core/services/social_provider.dart';
import 'package:gridcard/features/events/events_page.dart';
import 'package:gridcard/widgets/connection_suggest.dart';
import 'package:gridcard/widgets/post_card.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../business_event/business_event_page.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final TextEditingController _searchController = TextEditingController();

  // ================= EVENT FETCH VARIABLES (NEW) =================
  bool isEventLoading = false;
  List<dynamic> allEvents = [];
  String eventErrorMessage = '';

  static const String _baseUrl = AppConfig.apiBaseUrl;
  static const String _imageBaseUrl =
      "https://powderblue-jellyfish-554082.hostingersite.com";

  // ================= HEADERS (SAME AS COMPONENT 1) =================
  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ================= FETCH EVENTS API (NEW) =================
  Future<void> _fetchEvents() async {
    try {
      setState(() {
        isEventLoading = true;
        eventErrorMessage = '';
      });

      final uri = Uri.parse("$_baseUrl/show-event");

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      debugPrint("========== DISCOVER PAGE SHOW EVENT API ==========");
      debugPrint("URL: $uri");
      debugPrint("STATUS CODE: ${response.statusCode}");

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        if (jsonData['status'] == true) {
          setState(() {
            allEvents = jsonData['data'] ?? [];
          });

          debugPrint("✅ TOTAL EVENTS FETCHED: ${allEvents.length}");

          // 🔥 PRINT FULL EVENTS DATA IN CONSOLE
          debugPrint("✅ EVENTS DATA: ${jsonEncode(allEvents)}");
        } else {
          setState(() {
            eventErrorMessage = jsonData['message'] ?? 'Failed to fetch events';
          });
          debugPrint("❌ API ERROR: ${jsonData['message']}");
        }
      } else {
        try {
          final error = jsonDecode(response.body);
          setState(() {
            eventErrorMessage = error['message'] ??
                'Failed to fetch events. Status: ${response.statusCode}';
          });
        } catch (e) {
          setState(() {
            eventErrorMessage = 'Server error: ${response.statusCode}';
          });
        }

        debugPrint("❌ API ERROR BODY: ${response.body}");
      }

      debugPrint("==================================================");
    } catch (e) {
      setState(() {
        eventErrorMessage = 'Network error: $e';
      });
      debugPrint("❌ EXCEPTION: $e");
    } finally {
      setState(() => isEventLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();

    // Existing code (posts)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SocialProvider>().fetchPosts('All');
    });

    // 🔥 NEW: Fetch events also
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchEvents();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
                const ConnectionSuggest(),
                const SizedBox(height: 32),

                _buildSectionHeader("Upcoming Events", () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BusinessEventPage(),
                    ),
                  );
                }),

                const SizedBox(height: 12),

                // Existing Event Card (as it is)
                // _buildEventCard(),
                _buildEventsCarousel(),

                const SizedBox(height: 32),
                _buildSectionHeader("Trending Updates", () {}),
              ],
            ),
          ),
        ),

        // Existing posts code (as it is)
        socialProvider.isLoading
            ? const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            : SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final post = socialProvider.posts[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
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
          icon: Icon(
            CupertinoIcons.search,
            color: colorScheme.onSurface.withOpacity(0.3),
            size: 20,
          ),
          hintText: "Search people, products, or industries...",
          hintStyle: TextStyle(
            color: colorScheme.onSurface.withOpacity(0.2),
            fontSize: 14,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildEventsCarousel() {
    final colorScheme = Theme.of(context).colorScheme;

    if (isEventLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (eventErrorMessage.isNotEmpty) {
      return Text(
        eventErrorMessage,
        style: const TextStyle(color: Colors.red),
      );
    }

    if (allEvents.isEmpty) {
      return const Text(
        "No upcoming events found",
        style: TextStyle(color: Colors.grey),
      );
    }

    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: allEvents.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final event = allEvents[index];
          return _buildEventCard(event);
        },
      ),
    );
  }

  Widget _buildEventCard(dynamic event) {
    final colorScheme = Theme.of(context).colorScheme;

    final String title = (event['title'] ?? '').toString();
    final String desc = (event['description'] ?? '').toString();

    String shortText(String text) {
      if (text.length <= 20) return text;
      return "${text.substring(0, 20)}...";
    }

    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.calendar_badge_plus,
            color: colorScheme.onPrimary,
            size: 38,
          ),
          const SizedBox(width: 14),

          // Title + desc
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  shortText(title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  shortText(desc),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onPrimary.withOpacity(0.75),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),          

          GestureDetector(
            onTap: () {
              final int? eventId = event['id'];

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BusinessEventPage(openEventId: eventId),
                ),
              );
            },
            child: Icon(
              CupertinoIcons.chevron_right,
              color: colorScheme.onPrimary.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

 
  Widget _buildSectionHeader(String title, VoidCallback onSeeAll) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colorScheme.primary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        TextButton(
          onPressed: onSeeAll,
          child: Text(
            "See all",
            style: TextStyle(color: colorScheme.primary, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
