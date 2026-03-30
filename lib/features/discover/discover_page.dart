import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:gridcard/core/services/social_provider.dart';
import 'package:gridcard/widgets/post_card.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../business_event/business_event_page.dart';
import 'package:gridcard/widgets/discover_page_connections.dart';
import 'package:gridcard/widgets/glass_box.dart';

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

  final ScrollController _mainScrollController = ScrollController();
  final GlobalKey<DiscoverConnectionSuggestState> connectionKey = GlobalKey();

  static const String _baseUrl = AppConfig.apiBaseUrl;
  static const String _imageBaseUrl = AppConfig.imageBaseUrl;

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
      if (mounted) setState(() => isEventLoading = false);
    }
  }

  // @override
  // void initState() {
  //   super.initState();

  //   // Existing code (posts)
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     context.read<SocialProvider>().fetchPosts('All');
  //   });

  //   // 🔥 NEW: Fetch events also
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     _fetchEvents();
  //   });
  // }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SocialProvider>().fetchPosts('All');
      _fetchEvents();
    });

    _mainScrollController.addListener(() {
      if (_mainScrollController.position.pixels >=
          _mainScrollController.position.maxScrollExtent - 200) {
        connectionKey.currentState?.loadMore();
      }
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
      controller: _mainScrollController,
      slivers: [
        // SliverToBoxAdapter(
        //   child: Padding(
        //     padding: const EdgeInsets.all(16.0),
        //     child: Column(
        //       crossAxisAlignment: CrossAxisAlignment.start,
        //       children: [
        //         _buildSearchBar(),
        //         const SizedBox(height: 24),
        //         _buildSectionHeader("Upcoming Events", () {
        //           Navigator.push(
        //             context,
        //             MaterialPageRoute(
        //               builder: (context) => const BusinessEventPage(),
        //             ),
        //           );
        //         }),
        //         const SizedBox(height: 12),

        //         // Existing Event Card (as it is)
        //         // _buildEventCard(),
        //         _buildEventsCarousel(),
        //         const SizedBox(height: 32),

        //         _buildSectionHeader("Suggested Connections", () {}),
        //         const SizedBox(height: 12),
        //         // const ConnectionSuggest(),
        //         // const DiscoverConnectionSuggest(),

        //    DiscoverConnectionSuggest(key: connectionKey),

        //         const SizedBox(height: 32),
        //         // _buildSectionHeader("Trending Updates", () {}),
        //       ],
        //     ),
        //   ),
        // ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchBar(),
                const SizedBox(height: 24),
                _buildSectionHeader("Events", () {}),
                const SizedBox(height: 12),
                _buildEventsCarousel(),
                const SizedBox(height: 32),
                _buildSectionHeader("Suggested Connections", () {}),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
         DiscoverConnectionSuggest(key: connectionKey),
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
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        // Light mode mein edges smooth karne ke liye halka border
        border: isDark
            ? null
            : Border.all(color: colorScheme.onSurface.withValues(alpha: 0.1)),
        // Light mode mein depth dene ke liye halki shadow taaki edges kante hue na lagein
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      // clipBehavior edges ko sharp hone se rokta hai
      clipBehavior: Clip.antiAlias,
      child: GlassBox(
        padding: EdgeInsets.zero,
        borderRadius: 12,
        opacity: isDark ? 0.08 : 0.05,
        child: TextField(
          controller: _searchController,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 15,
          ),
          cursorColor: colorScheme.primary,
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            hintText: "Search people, products...",
            hintStyle: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.4),
              fontSize: 14,
            ),
            prefixIcon: Icon(
              CupertinoIcons.search,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
              size: 18,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String title = (event['title'] ?? '').toString();
    final String desc = (event['description'] ?? '').toString();

    String shortText(String text) {
      if (text.length <= 20) return text;
      return "${text.substring(0, 20)}...";
    }

    final int? eventId = event['id'];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BusinessEventPage(openEventId: eventId),
          ),
        );
      },
      child: GlassBox(
        width: 280,
        padding: const EdgeInsets.all(16),
        borderRadius: 16,
        gradientColors: isDark
            ? [
                colorScheme.primary.withValues(alpha: 0.2),
                colorScheme.primary.withValues(alpha: 0.1),
              ]
            : [
                colorScheme.primary.withValues(alpha: 0.8),
                colorScheme.primary.withValues(alpha: 0.6),
              ],
        child: Row(
          children: [
            Icon(
              CupertinoIcons.calendar_badge_plus,
              color: isDark ? colorScheme.primary : Colors.white,
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
                      color: isDark ? colorScheme.onSurface : Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    shortText(desc),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark
                          ? colorScheme.onSurface.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            Icon(
              CupertinoIcons.chevron_right,
              color: isDark
                  ? colorScheme.onSurface.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.6),
            ),
          ],
        ),
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
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
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
