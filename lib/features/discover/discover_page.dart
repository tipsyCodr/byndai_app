import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:gridcard/widgets/shimmer_box.dart';
import 'package:gridcard/core/theme/app_theme.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();

  // ================= EVENT FETCH VARIABLES (NEW) =================
  bool isEventLoading = false;
  List<dynamic> allEvents = [];
  String eventErrorMessage = '';

  final ScrollController _mainScrollController = ScrollController();
  final GlobalKey<DiscoverConnectionSuggestState> connectionKey = GlobalKey();

  DateTime? _lastEventsFetched;

  // Search & Filter Variables
  bool _isSearching = false;
  List<dynamic> _searchResults = [];
  String _searchQuery = '';
  String _selectedFilter = 'All';
  List<String> _connectionFilters = [];

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
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
                    _buildFilterChips(),
                    const SizedBox(height: 18),
                    _buildSectionHeader("Events", () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BusinessEventPage(),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    _buildEventsCarousel(),
                    const SizedBox(height: 32),
                    _buildSectionHeader("Suggested Connections", () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const _SuggestedConnectionsPage(),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),

          if (_searchQuery.isNotEmpty)
            _buildSearchResultsSliver()
          else ...[
            DiscoverConnectionSuggest(
              key: connectionKey,
              selectedFilter: _selectedFilter,
              onFiltersDiscovered: (tags) {
                if (mounted) {
                  setState(() => _connectionFilters = tags);
                }
              },
            ),

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

  List<String> get _availableFilters {
    final tags = <String>{'All'};
    for (final e in allEvents) {
      if (e is! Map) continue;
      for (final candidate in [
        e['industry'] is Map ? e['industry']['name'] : e['industry'],
        e['city'],
        e['location'],
        e['state'],
      ]) {
        final s = candidate?.toString().trim() ?? '';
        if (s.isNotEmpty && s.length <= 24) tags.add(s);
      }
    }
    tags.addAll(_connectionFilters);
    return tags.toList();
  }

  Widget _buildFilterChips() {
    final filters = _availableFilters;
    if (filters.length <= 1) return const SizedBox(height: 8);

    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final label = filters[index];
            final selected = _selectedFilter == label;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedFilter = label);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: selected
                      ? colorScheme.primary
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.07)
                          : Colors.white.withValues(alpha: 0.85)),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected
                        ? colorScheme.primary
                        : colorScheme.outline.withValues(alpha: 0.16),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEventsCarousel() {
    final colorScheme = Theme.of(context).colorScheme;

    if (isEventLoading) {
      return SizedBox(
        height: 148,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 2,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, __) => const ShimmerBox(
            width: 270,
            height: 148,
            borderRadius: 20,
          ),
        ),
      );
    }

    if (eventErrorMessage.isNotEmpty) {
      return Text(
        eventErrorMessage,
        style: const TextStyle(color: Colors.red),
      );
    }

    final filteredEvents = _selectedFilter == 'All'
        ? allEvents
        : allEvents.where((e) {
            if (e is! Map) return false;
            final q = _selectedFilter.toLowerCase();
            final haystack = [
              e['industry'] is Map ? e['industry']['name'] : e['industry'],
              e['city'],
              e['location'],
              e['state'],
              e['title'],
              e['event_name'],
            ].map((v) => (v ?? '').toString().toLowerCase()).join(' ');
            return haystack.contains(q);
          }).toList();

    if (filteredEvents.isEmpty) {
      return const Text(
        "No matching events found",
        style: TextStyle(color: Colors.grey),
      );
    }

    return SizedBox(
      height: 148,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: filteredEvents.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final event = filteredEvents[index];
          return _buildEventCard(event);
        },
      ),
    );
  }

  String? _resolveEventImage(dynamic event) {
    final images = event['images'] as List?;
    if (images == null || images.isEmpty) return null;
    final first = images.first;
    if (first is! Map) return null;
    final fullUrl = first['full_url']?.toString();
    if (fullUrl != null && fullUrl.trim().isNotEmpty) {
      return fullUrl.trim().replaceAll(' ', '%20');
    }
    final path = first['event_img_path']?.toString();
    if (path != null && path.trim().isNotEmpty) {
      final resolved = AppConfig.getFullUrl(path);
      if (resolved != null && resolved.trim().isNotEmpty) {
        return resolved.trim().replaceAll(' ', '%20');
      }
    }
    return null;
  }

  String _formatEventDate(String raw) {
    final dt = DateTime.tryParse(raw.trim());
    if (dt == null) return raw.trim();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final datePart = '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    if (dt.hour == 0 && dt.minute == 0 && dt.second == 0) {
      return datePart;
    }
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$datePart • $hour12:$min $period';
  }

  Widget _buildEventCard(dynamic event) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = Theme.of(context).extension<AppThemeColors>();

    final String title =
        (event['title'] ?? event['event_name'] ?? 'Untitled Event').toString();
    final String desc = (event['description'] ?? '').toString();
    final String? imageUrl = _resolveEventImage(event);
    final String? dateStr =
        (event['start_date'] ?? event['event_date'] ?? event['date'])
            ?.toString();
    final String? industryName = event['industry']?['name']?.toString();
    final String badgeText = (dateStr != null && dateStr.trim().isNotEmpty)
        ? _formatEventDate(dateStr)
        : (industryName != null && industryName.trim().isNotEmpty
            ? industryName.trim()
            : 'Event');

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
      child: Container(
        width: 270,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1F2642),
                    const Color(0xFF13182B),
                  ]
                : [
                    palette?.heroStart ?? colorScheme.primary,
                    palette?.heroEnd ?? colorScheme.secondary,
                  ],
          ),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.25),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : colorScheme.primary)
                  .withValues(alpha: isDark ? 0.35 : 0.18),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null)
              AppNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
              ),

            // Dark scrim for readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: imageUrl != null
                      ? [
                          Colors.black.withValues(alpha: 0.20),
                          Colors.black.withValues(alpha: 0.82),
                        ]
                      : [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.32),
                        ],
                ),
              ),
            ),

            if (imageUrl == null)
              Positioned(
                right: -12,
                top: -12,
                child: Icon(
                  CupertinoIcons.calendar,
                  size: 96,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              CupertinoIcons.calendar,
                              size: 11.5,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 5),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 160),
                              child: Text(
                                badgeText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.arrow_up_right,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15.5,
                      letterSpacing: 0.1,
                    ),
                  ),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
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

class _SuggestedConnectionsPage extends StatefulWidget {
  const _SuggestedConnectionsPage();

  @override
  State<_SuggestedConnectionsPage> createState() =>
      _SuggestedConnectionsPageState();
}

class _SuggestedConnectionsPageState extends State<_SuggestedConnectionsPage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<DiscoverConnectionSuggestState> _connectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 250) {
        _connectionKey.currentState?.loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suggested Connections'),
        centerTitle: true,
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          const SliverPadding(padding: EdgeInsets.only(top: 12)),
          DiscoverConnectionSuggest(key: _connectionKey),
          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
      ),
    );
  }
}
