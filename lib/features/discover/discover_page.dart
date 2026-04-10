import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:gridcard/core/services/social_provider.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../business_event/business_event_page.dart';
import 'package:gridcard/core/services/profile_service.dart';
import 'package:gridcard/widgets/top_alert.dart';
import 'package:gridcard/features/profile/profile_page.dart';
import 'package:gridcard/widgets/discover_page_connections.dart';
import 'package:gridcard/widgets/glass_box.dart';
import '../home/widgets/feed_item_tile.dart';
import 'package:gridcard/widgets/app_network_image.dart';

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

  DateTime? _lastEventsFetched;

  // Search Variables
  bool _isSearching = false;
  List<dynamic> _searchResults = [];
  String _searchQuery = '';

  bool get _shouldRefreshEvents {
    if (allEvents.isEmpty || _lastEventsFetched == null) return true;
    return DateTime.now().difference(_lastEventsFetched!) >
        const Duration(minutes: 5);
  }

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
      final headers = await _getHeaders();
      final loggedHeaders = Map<String, String>.from(headers);
      if (loggedHeaders['Authorization'] != null) {
        final auth = loggedHeaders['Authorization']!;
        loggedHeaders['Authorization'] = auth.length > 24
            ? '${auth.substring(0, 16)}...${auth.substring(auth.length - 6)}'
            : 'Bearer ***';
      }

      final response = await http.get(
        uri,
        headers: headers,
      );

      debugPrint("========== DISCOVER PAGE SHOW EVENT API ==========");
      debugPrint("URL: $uri");
      debugPrint("HEADERS: $loggedHeaders");
      debugPrint("STATUS CODE: ${response.statusCode}");
      debugPrint("RAW RESPONSE BODY: ${response.body}");

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
      if (mounted) {
        setState(() {
          isEventLoading = false;
          if (eventErrorMessage.isEmpty) {
            _lastEventsFetched = DateTime.now();
          }
        });
      }
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      _clearSearch();
      return;
    }

    setState(() {
      _searchQuery = query;
      _isSearching = true;
    });

    try {
      final results = await ProfileService.searchUsers(query);
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      debugPrint("🚨 Search error: $e");
      if (mounted) {
        TopAlert.show(context, "Search failed: $e", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _searchResults = [];
      _isSearching = false;
    });
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final socialProvider = context.read<SocialProvider>();
      if (socialProvider.shouldRefresh) {
        socialProvider.fetchPosts('All');
      }
      if (_shouldRefreshEvents) {
        _fetchEvents();
      }
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
    return RefreshIndicator(
      onRefresh: () async {
        if (_searchQuery.isNotEmpty) {
          await _performSearch(_searchQuery);
        } else {
          await Future.wait([
            context.read<SocialProvider>().fetchPosts('All'),
            _fetchEvents(),
          ]);
          connectionKey.currentState?.loadMore();
        }
      },
      child: CustomScrollView(
        controller: _mainScrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchBar(),
                  if (_searchQuery.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildSectionHeader(
                      "Search Results for '$_searchQuery'",
                      _clearSearch,
                      isResult: true,
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    const SizedBox(height: 24),
                    _buildSectionHeader("Events", () {}),
                    const SizedBox(height: 12),
                    _buildEventsCarousel(),
                    const SizedBox(height: 32),
                    _buildSectionHeader("Suggested Connections", () {}),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),

          if (_searchQuery.isNotEmpty)
            _buildSearchResultsSliver()
          else ...[
            DiscoverConnectionSuggest(key: connectionKey),

            /// Optimized Post Section
            Selector<SocialProvider, bool>(
              selector: (_, p) => p.isLoading && p.posts.isEmpty,
              builder: (context, isLoading, _) {
                if (isLoading) {
                  return const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              },
            ),
            Selector<SocialProvider, List<int>>(
              selector: (_, p) => p.posts.map((post) => post.id).toList(),
              builder: (context, postIds, _) {
                if (postIds.isEmpty) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: FeedItemTile(postId: postIds[index]),
                      );
                    },
                    childCount: postIds.length,
                  ),
                );
              },
            ),
          ],

          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: isDark
            ? null
            : Border.all(color: colorScheme.onSurface.withValues(alpha: 0.1)),
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
            hintText: "Search people, services, niches...",
            hintStyle: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.4),
              fontSize: 14,
            ),
            prefixIcon: Icon(
              CupertinoIcons.search,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
              size: 18,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      CupertinoIcons.clear_circled,
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                      size: 18,
                    ),
                    onPressed: _clearSearch,
                  )
                : null,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onChanged: (val) {
            setState(() {});
          },
          onSubmitted: _performSearch,
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

  Widget _buildSectionHeader(String title, VoidCallback onSeeAll,
      {bool isResult = false}) {
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
            isResult ? "Clear" : "See all",
            style: TextStyle(color: colorScheme.primary, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultsSliver() {
    if (_isSearching) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_searchResults.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: Text("No results found")),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final user = _searchResults[index];
          return _buildUserSearchCard(user);
        },
        childCount: _searchResults.length,
      ),
    );
  }

  Widget _buildUserSearchCard(dynamic user) {
    if (user == null) return const SizedBox.shrink();
    
    final colorScheme = Theme.of(context).colorScheme;

    // Robust extraction for nested search results
    final masterUser = user['master_user'] ?? {};
    final userSub = user['user'] ?? {};

    String? getVal(String key) {
      return (user[key] ?? masterUser[key] ?? userSub[key])?.toString();
    }

    final String profilePic = getVal('profile_pic') ?? '';
    final String fullName = getVal('fname') ?? getVal('user_name') ?? 'No Name';
    final String businessName = getVal('business_name') ?? getVal('company_name') ?? '';

    // Extracting user ID properly
    final int? userId = int.tryParse(user['id']?.toString() ?? '') ?? 
                        int.tryParse(user['user_id']?.toString() ?? '') ??
                        int.tryParse(masterUser['user_id']?.toString() ?? '') ??
                        int.tryParse(user['emp_id']?.toString() ?? '');

    return GestureDetector(
      onTap: () async {
        debugPrint("🖱️ Tapped Search Result: $fullName (ID: $userId)");
        if (userId != null) {
          final session = await UserStorageService().loadSession();
          final viewerId = session.user?.id;

          if (mounted) {
            // Dynamic check for any connection-related truthy value
            bool isConnected = false;
            
            // Check known keys
            final status = (user['connection_status'] ?? user['status'] ?? user['friend_status'] ?? '').toString().toLowerCase();
            if (status == 'accepted' || status == 'connected' || status == 'friend' || status == '1' || status == 'true') {
              isConnected = true;
            }
            
            // Check boolean keys
            if (!isConnected) {
              final boolKeys = ['is_connected', 'isConnected', 'connected', 'is_friend', 'isFriend'];
              for (var key in boolKeys) {
                if (user[key] == true || user[key] == 1 || user[key] == '1' || user[key] == 'true') {
                  isConnected = true;
                  break;
                }
              }
            }

            // Check nested connection object (Laravel style)
            if (!isConnected && user['connection'] != null) {
              final conn = user['connection'];
              if (conn is Map) {
                final cStatus = conn['status']?.toString();
                if (cStatus == '1' || cStatus == 'accepted') isConnected = true;
              }
            }

            // Check sub-user or master-user objects
            if (!isConnected) {
              final subObj = user['user'] ?? user['master_user'] ?? {};
              if (subObj is Map) {
                final subStatus = (subObj['connection_status'] ?? subObj['status'] ?? '').toString().toLowerCase();
                if (subStatus == 'accepted' || subStatus == '1') isConnected = true;
              }
            }
            
            debugPrint("🔗 Discover Search Result Tap | isConnected: $isConnected");
            debugPrint("📋 Full User Data Keys: ${user.keys.toList()}");
            debugPrint("📋 Full User Data: $user");

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfilePage(
                  userId: userId,
                  viewerUserId: viewerId,
                  isConnected: isConnected,
                ),
              ),
            );
          }
        } else {
          debugPrint("⚠️ Cannot navigate: userId is null for $fullName");
          debugPrint("📋 Keys in user object: ${user.keys.toList()}");
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: GlassBox(
          padding: const EdgeInsets.all(12),
          borderRadius: 16,
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: profilePic.isEmpty
                      ? LinearGradient(
                          colors: [
                            colorScheme.primary.withValues(alpha: 0.2),
                            colorScheme.primary.withValues(alpha: 0.05),
                          ],
                        )
                      : null,
                ),
                child: ClipOval(
                  child: AppNetworkImage(
                    imageUrl: profilePic,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (businessName.isNotEmpty)
                      Text(
                        businessName,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
