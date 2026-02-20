

import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/features/business_feed/business_feed_page.dart';
import 'package:gridcard/widgets/action_dock.dart';
import 'package:gridcard/widgets/connection_suggest.dart';
import 'package:gridcard/widgets/share_profile_widget.dart';
import 'package:provider/provider.dart';

import '../leads/lead_scanner_2.dart';

// OLD PostCard (provider model)
import 'package:gridcard/widgets/post_card.dart' as old_post_card;

// NEW PostCard (API Map model)
import '../business_feed/post_card.dart';

import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:http/http.dart' as http;

import 'package:gridcard/core/services/social_provider.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // =============================
  // NEW: Latest 5 Posts
  // =============================
  static const String _baseUrl = AppConfig.apiBaseUrl;

  List<Map<String, dynamic>> _latestPosts = [];
  bool _isLatestLoading = false;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // OLD functionality
      context.read<SocialProvider>().fetchPosts('All');

      // NEW functionality
      _fetchLatest5Posts();

      _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // ===========================
  // NEW: Headers
  // ===========================
  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ===========================
  // NEW: Fetch Latest 5 Posts
  // ===========================
  Future<void> _fetchLatest5Posts() async {
    if (_isLatestLoading) return;

    setState(() => _isLatestLoading = true);

    try {
      final uri = Uri.parse("$_baseUrl/posts/list?page=1");
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
      } else {
        debugPrint("Latest posts API failed: ${response.body}");
      }
    } catch (e) {
      debugPrint("Latest posts exception: $e");
    } finally {
      if (mounted) setState(() => _isLatestLoading = false);
    }
  }

  // ===========================
  // OLD: Dashboard (same)
  // ===========================
  Widget _buildPerformanceDashboard() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            isDark
                ? colorScheme.surfaceContainerHighest
                : colorScheme.primary.withOpacity(0.8),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.5 : 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'YOUR NETWORK IMPACT',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    fontSize: 10),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(CupertinoIcons.graph_circle,
                        color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      '+12%',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '1,248',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 42,
                letterSpacing: -1),
          ),
          const Text(
            'Total Profile Interactions',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.2),
          ),
          const SizedBox(height: 24),
          Stack(
            children: [
              Container(
                height: 6,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(seconds: 2),
                height: 6,
                width: 140,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.white, Colors.white70],
                  ),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Profile Completion',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              Text(
                '85%',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================
  // OLD: Actions (same)
  // ===========================
  Widget _buildMainActions(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(isDark ? 0.2 : 0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const ShareProfileWidget(),
                );
              },
              icon: const Icon(CupertinoIcons.share, size: 20),
              label: const Text("Share Card",
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 0.5)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.primary.withOpacity(0.1)),
            ),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary.withOpacity(0.05),
                foregroundColor: colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => const LeadScanner2()));
              },
              child: const Icon(CupertinoIcons.viewfinder, size: 24),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================
  // NEW Header
  // ===========================
  Widget _buildNewBusinessHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Business Updates',
            style: TextStyle(
              color: colorScheme.primary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BusinessFeedPage()),
              );
            },
            child: Text(
              'View all',
              style: TextStyle(
                color: colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          )
        ],
      ),
    );
  }

  // ===========================
  // NEW: Latest 5 Posts Carousel
  // ===========================
  Widget _buildLatestBusinessCarousel() {
    if (_isLatestLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 25),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF21254A)),
        ),
      );
    }

    if (_latestPosts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 25),
        child: Center(
          child: Text(
            "No business updates yet",
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return SizedBox(
      height: 470, // thoda safe height
      child: ListView.builder(
        padding: const EdgeInsets.only(left: 0, right: 6),
        scrollDirection: Axis.horizontal,
        itemCount: _latestPosts.length,
        itemBuilder: (context, index) {
          final post = _latestPosts[index];

          return Padding(
            padding: EdgeInsets.only(
              right: 14,
              left: index == 0 ? 0 : 0,
            ),
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.90,
              child: PostCard(
                post: post,
                onPostUpdated: (postId, updatedPost) {
                  final i = _latestPosts.indexWhere((p) => p["id"] == postId);
                  if (i != -1) {
                    setState(() {
                      _latestPosts[i] = updatedPost;
                    });
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================
  // BUILD
  // ===========================
  @override
  Widget build(BuildContext context) {
    final socialProvider = context.watch<SocialProvider>();
    final posts = socialProvider.posts;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPerformanceDashboard(),
                  const SizedBox(height: 24),
                  _buildMainActions(context),
                  const SizedBox(height: 32),
                  Text(
                    'Suggested Connections',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 18,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const ConnectionSuggest(),
                  const SizedBox(height: 32),
                  const ActionDock(),
                  const SizedBox(height: 32),

                  // NEW SECTION
                  _buildNewBusinessHeader(context),
                  _buildLatestBusinessCarousel(),
                ],
              ),
            ),
          ),

          // OLD provider post as it is
          if (socialProvider.isLoading && posts.isEmpty)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(color: Color(0xFF21254A)),
                ),
              ),
            )
          else if (posts.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: old_post_card.PostCard(
                  userName: posts[0].user.fullName,
                  userRole: posts[0].user.designation,
                  location: posts[0].industry ?? "Business",
                  avatarUrl: posts[0].user.imageUrl,
                  postImageUrl: posts[0].imageUrl ?? '',
                  description: posts[0].content,
                  likesCount: posts[0].likesCount,
                  commentsCount: posts[0].commentsCount,
                  onLike: () => socialProvider.toggleLike(posts[0].id),
                  onSave: () => socialProvider.toggleSave(posts[0].id),
                ),
              ),
            ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
        ],
      ),
    );
  }
}
