import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gridcard/widgets/action_dock.dart';
import 'package:gridcard/widgets/connection_suggest.dart';
import 'package:provider/provider.dart';
import 'package:gridcard/features/qr_generator/qr_generator_page.dart';
import './widgets/feed_item_tile.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:gridcard/core/services/auth_provider.dart';
import 'package:gridcard/core/services/social_provider.dart';
import 'package:gridcard/core/services/user_stats_provider.dart';
import 'package:gridcard/widgets/top_alert.dart';
import 'package:gridcard/features/home/widgets/performance_dashboard.dart';
import 'package:http/http.dart' as http;
import '../profile/edit_profile_page.dart';
import '../leads/lead_scanner_2.dart';
import 'package:gridcard/widgets/share_profile_widget.dart';
import 'package:gridcard/features/business_feed/business_feed_page.dart';
import 'package:gridcard/features/business_feed/home_post_card.dart';
import '../flyer module/pages/flyer_home.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  FeedPageState createState() => FeedPageState();
}

class FeedPageState extends State<FeedPage> with TickerProviderStateMixin {
  final GlobalKey<ConnectionSuggestState> _connectionSuggestKey = GlobalKey();

  static const String _baseUrl = AppConfig.apiBaseUrl;
  Map<String, dynamic>? _userDetails;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  List<Map<String, dynamic>> _latestPosts = [];
  bool _isLatestLoading = false;

  final ScrollController _scrollController = ScrollController();

  void onBackToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    // Start UI animation immediately; do not block first paint on network.
    _fadeController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Fire-and-forget background fetches for better perceived performance.
      unawaited(_fetchUserDetails());
      if (mounted) {
        unawaited(context.read<UserStatsProvider>().fetchAllStats());
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> refreshFeed() async {
    await _handleRefresh();
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _handleRefresh({bool force = true}) async {
    if (!mounted) return;

    final userStats = context.read<UserStatsProvider>();
    final social = context.read<SocialProvider>();

    await Future.wait([
      social.fetchPosts('All'),
      userStats.fetchAllStats(force: force),
      _fetchLatest5Posts(),
    ]);

    if (mounted) {
      _connectionSuggestKey.currentState?.refresh();
    }
  }

  Future<void> _fetchUserDetails() async {
    try {
      final int? targetUserId = await UserStorageService().getUserId();
      if (targetUserId == null) return;

      final headers = await _getHeaders();
      final url = Uri.parse("$_baseUrl/user-details/$targetUserId");

      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded["status"] == true) {
          if (mounted) {
            setState(() {
              _userDetails = decoded["data"];
            });
          }
        }
      }
    } catch (e) {
      debugPrint("🔴 EXCEPTION in _fetchUserDetails(): $e");
    }
  }

  Future<void> _fetchLatest5Posts() async {
    if (_isLatestLoading) return;
    setState(() => _isLatestLoading = true);

    try {
      final uri = Uri.parse("${AppConfig.apiBaseUrl}/posts/list?page=1");
      final headers = await _getHeaders();
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final List<dynamic> dataList = jsonData["data"] ?? [];
        final List<Map<String, dynamic>> posts =
            dataList.map((e) => Map<String, dynamic>.from(e)).toList();

        setState(() {
          _latestPosts = posts.take(5).toList();
        });
      }
    } catch (e) {
      debugPrint("Latest posts exception: $e");
    } finally {
      if (mounted) setState(() => _isLatestLoading = false);
    }
  }

  void _showMilestoneModal() {
    final stats = context.read<UserStatsProvider>();
    final incomplete = stats.milestones.entries
        .where((entry) => !entry.value)
        .map((entry) => entry.key)
        .toList();

    if (incomplete.isEmpty) {
      TopAlert.show(context, 'All milestones completed! 🎉', isSuccess: true);
      return;
    }

    final Map<String, String> milestoneNames = {
      'user_details': 'Profile Details',
      'links': 'Social Links',
      'keywords': 'Keywords',
      'business_info': 'Business Info',
      'product': 'Products',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Complete Your Profile',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add missing information to improve your profile',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: incomplete.length,
                  itemBuilder: (_, index) {
                    final key = incomplete[index];
                    final name = milestoneNames[key] ?? key;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(name),
                        trailing: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _navigateToMilestoneScreen(key);
                          },
                          child: const Text('Add'),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToMilestoneScreen(String milestoneKey) async {
    int tabIndex;
    switch (milestoneKey) {
      case 'user_details':
        tabIndex = 0;
        break;
      case 'links':
        tabIndex = 1;
        break;
      case 'keywords':
        tabIndex = 2;
        break;
      case 'business_info':
        tabIndex = 3;
        break;
      case 'product':
        tabIndex = 4;
        break;
      default:
        TopAlert.show(context, 'Screen not defined for $milestoneKey',
            isError: true);
        return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfilePage(
          userDetails: _userDetails,
          initialTabIndex: tabIndex,
        ),
      ),
    );

    if (mounted) {
      _handleRefresh();
    }
  }

  Widget _buildMainActions(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: _buildActionTile(
            context,
            icon: Icons.qr_code_scanner,
            label: "SCAN CARD",
            color: theme.colorScheme.primary,
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const LeadScanner2(autoOpenCamera: true))),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionTile(
            context,
            icon: Icons.share,
            label: "SHARE",
            color: theme.colorScheme.secondary,
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const ShareProfileWidget(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile(BuildContext context,
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.25 : 0.12),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.9),
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildByndCanvasBanner(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const FlyerHomePage())),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
                    theme.colorScheme.surfaceContainerHighest,
                  ]
                : [
                    theme.colorScheme.primary,
                    theme.colorScheme.tertiary,
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: isDark
              ? Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  width: 1.5,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : theme.colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? theme.colorScheme.primary.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.palette,
                color: isDark ? theme.colorScheme.primary : Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bynd Canvas',
                    style: TextStyle(
                      color: isDark
                          ? theme.colorScheme.onSurface
                          : Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Create professional flyers in seconds',
                    style: TextStyle(
                      color: isDark
                          ? theme.colorScheme.onSurfaceVariant
                          : Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? theme.colorScheme.onSurfaceVariant : Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrGeneratorBanner(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const QrGeneratorPage())),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [
                    theme.colorScheme.secondaryContainer.withValues(alpha: 0.7),
                    theme.colorScheme.surfaceContainerHighest,
                  ]
                : [
                    theme.colorScheme.secondary,
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: isDark
              ? Border.all(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                  width: 1.5,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.1)
                  : theme.colorScheme.secondary.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? theme.colorScheme.secondary.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.qr_code_2,
                color: isDark ? theme.colorScheme.secondary : Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QR Generator',
                    style: TextStyle(
                      color: isDark ? theme.colorScheme.onSurface : Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Generate custom QR codes',
                    style: TextStyle(
                      color: isDark
                          ? theme.colorScheme.onSurfaceVariant
                          : Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? theme.colorScheme.onSurfaceVariant : Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewBusinessHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Business Updates',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        TextButton(
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const BusinessFeedPage())),
          child: const Text("View All"),
        ),
      ],
    );
  }

  Widget _buildLatestBusinessCarousel() {
    final colorScheme = Theme.of(context).colorScheme;
    if (_isLatestLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 25),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_latestPosts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 25),
        child: Center(
          child: Text(
            "No business updates yet",
            style:
                TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
        ),
      );
    }

    return SizedBox(
      height: 496,
      child: HomePostCard(
        post: _latestPosts[0],
        onPostUpdated: (postId, updatedPost) {
          final i = _latestPosts.indexWhere((p) => p["id"] == postId);
          if (i != -1) {
            setState(() {
              _latestPosts[i] = updatedPost;
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final viewerUserId = authProvider.user?.id;

    if (viewerUserId == null) {
      return const Center(child: Text("User not logged in"));
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: Theme.of(context).colorScheme.primary,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    PerformanceDashboard(
                      onIncompleteMilestone: _showMilestoneModal,
                    ),
                    const SizedBox(height: 24),
                    _buildMainActions(context),
                    const SizedBox(height: 32),
                    const ActionDock(),
                    const SizedBox(height: 32),
                    _buildQrGeneratorBanner(context),
                    const SizedBox(height: 16),
                    _buildByndCanvasBanner(context),
                    const SizedBox(height: 32),
                    Text(
                      'Suggested Connections',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 18,
                        letterSpacing: 0.7,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ConnectionSuggest(
                      key: _connectionSuggestKey,
                      viewerUserId: viewerUserId,
                    ),
                    const SizedBox(height: 32),
                    _buildNewBusinessHeader(context),
                    const SizedBox(height: 16),
                    _buildLatestBusinessCarousel(),
                    const SizedBox(height: 82),
                    Center(
                      child: Text(
                        '🚀 Powered by Path Idea Infotech ',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Selector<SocialProvider, bool>(
              selector: (_, p) => p.isLoading && p.posts.isEmpty,
              builder: (context, isLoading, _) {
                if (isLoading) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
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
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => FeedItemTile(postId: postIds[index]),
                      childCount: postIds.length,
                    ),
                  ),
                );
              },
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 50)),
          ],
        ),
      ),
    );
  }
}
