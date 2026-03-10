import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/features/business_feed/business_feed_page.dart';
import 'package:gridcard/widgets/action_dock.dart';
import 'package:gridcard/widgets/connection_suggest.dart';
import 'package:gridcard/widgets/share_profile_widget.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import '../leads/lead_scanner_2.dart';
import '../../features/qr_generator/qr_generator_page.dart';

// OLD PostCard (provider model)
//K:\amit\bynd-ai\byndai_app-main\lib\features\business_feed\home_post_card.dart
import 'package:gridcard/widgets/post_card.dart' as old_post_card;
import '../../features/business_feed/home_post_card.dart';

import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:http/http.dart' as http;

import 'package:gridcard/core/services/social_provider.dart';
import '../../features/analitics/user_analitics_page.dart';
import 'package:gridcard/widgets/top_alert.dart';

// class FeedPage extends StatefulWidget {
//   const FeedPage({super.key});

//   @override
//   State<FeedPage> createState() => _FeedPageState();
// }

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  FeedPageState createState() => FeedPageState();
}

// class _FeedPageState extends State<FeedPage> with TickerProviderStateMixin {
class FeedPageState extends State<FeedPage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  int _totalViewCount = 0;
  int _totalTimeSeconds = 0;
  bool _isAnalyticsLoading = false;

  double _averageRating = 0.0;
  int _totalReviews = 0;

  double _profileCompletionPercent = 0; // 0 to 100
  bool _isCompletionLoading = false;

  // =============================
  // NEW: Latest 5 Posts
  // =============================
  static const String _baseUrl = AppConfig.apiBaseUrl;

  List<Map<String, dynamic>> _latestPosts = [];
  bool _isLatestLoading = false;

  Future<void> refreshFeed() async {
    await _handleRefresh();
  }

  Future<void> _uploadQrImage(
      String title, String link, Uint8List imageBytes) async {
    try {
      final int? userId = await UserStorageService().getUserId();
      if (userId == null) {
        if (mounted) {
          TopAlert.show(context, 'User not logged in', isError: true);
        }
        return;
      }

      final uri =
          Uri.parse("$_baseUrl/qr/store"); // Replace with your actual endpoint
      var request = http.MultipartRequest('POST', uri);
      request.headers.addAll(await _getHeaders()); // includes auth token

      request.fields['title'] = title;
      request.fields['link'] = link;
      request.fields['user_id'] = userId.toString();

      request.files.add(
        http.MultipartFile.fromBytes(
          'qr_image', // Field name expected by your API
          imageBytes,
          filename: 'qr_$title.png',
        ),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          TopAlert.show(context, 'QR Code saved successfully!',
              isSuccess: true);
        }
      } else {
        debugPrint("QR upload failed: $responseBody");
        if (mounted) {
          TopAlert.show(context, 'Upload failed: ${response.statusCode}',
              isError: true);
        }
      }
    } catch (e) {
      debugPrint("QR upload error: $e");
      if (mounted) {
        TopAlert.show(context, 'Error: $e', isError: true);
      }
    }
  }

  Future<void> _fetchProfileCompletion() async {
    if (_isCompletionLoading) return;

    setState(() => _isCompletionLoading = true);

    try {
      final userId = await UserStorageService().getUserId();
      if (userId == null) return;

      final uri = Uri.parse("$_baseUrl/profile-completion");
      final headers = await _getHeaders();

      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({
          "user_id": userId,
        }),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        if (jsonData["success"] == true) {
          setState(() {
            _profileCompletionPercent =
                (jsonData["percentage"] ?? 0).toDouble();
          });
        }
      } else {
        debugPrint("Profile completion API failed: ${response.body}");
      }
    } catch (e) {
      debugPrint("Profile completion error: $e");
    } finally {
      if (mounted) setState(() => _isCompletionLoading = false);
    }
  }

  Future<void> _fetchAverageRating() async {
    try {
      final userId = await UserStorageService().getUserId();
      if (userId == null) return;

      final uri = Uri.parse("$_baseUrl/user-reviews/$userId/average");
      final headers = await _getHeaders();

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        if (jsonData["status"] == true) {
          final data = jsonData["data"];

          setState(() {
            _averageRating =
                double.tryParse(data["average_rating"].toString()) ?? 0.0;
            _totalReviews = int.tryParse(data["total_reviews"].toString()) ?? 0;
          });
        }
      }
    } catch (e) {
      debugPrint("Rating API error: $e");
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fadeController.forward();
      _handleRefresh();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserAnalytics() async {
    if (_isAnalyticsLoading) return;

    setState(() => _isAnalyticsLoading = true);

    try {
      final userId = await UserStorageService().getUserId();
      if (userId == null) return;

      final uri = Uri.parse("$_baseUrl/user-analytics");
      final headers = await _getHeaders();

      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({
          "userId": userId,
        }),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        if (jsonData["status"] == true) {
          final profileViews = jsonData["data"]?["profile_views"];

          setState(() {
            _totalViewCount = profileViews?["total_view_count"] ?? 0;
            _totalTimeSeconds = profileViews?["total_time_seconds"] ?? 0;
          });
        }
      } else {
        debugPrint("Analytics API failed: ${response.body}");
      }
    } catch (e) {
      debugPrint("Analytics exception: $e");
    } finally {
      if (mounted) setState(() => _isAnalyticsLoading = false);
    }
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

  Widget _buildPerformanceDashboard() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const UserAnaliticsPage(),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary,
              isDark
                  ? colorScheme.surfaceContainerHighest
                  : colorScheme.primary.withOpacity(0.85),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.4 : 0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 🔹 HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'YOUR NETWORK IMPACT',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "LIVE",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              ],
            ),

            const SizedBox(height: 20),

            /// 🔹 LOADING
            if (_isAnalyticsLoading)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            else ...[
              /// 🔢 TOTAL PROFILE VIEWS
              Text(
                _totalViewCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              // const Text(
              //   "Total Profile Views",
              //   style: TextStyle(
              //     color: Colors.white70,
              //     fontSize: 13,
              //   ),
              // ),

              // const SizedBox(height: 18),

              /// 📊 MINI STATS ROW
              // Row(
              //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //   children: [
              //     /// ⭐ Rating Card
              //     _miniStatCard(
              //       icon: Icons.star,
              //       value: _averageRating.toStringAsFixed(1),
              //       label: "Rating",
              //     ),

              //     /// 📝 Reviews Card
              //     _miniStatCard(
              //       icon: Icons.rate_review,
              //       value: _totalReviews.toString(),
              //       label: "Reviews",
              //     ),

              //     /// ⏱ Time Spent Card
              //     _miniStatCard(
              //       icon: Icons.timer,
              //       value: "${_totalTimeSeconds}s",
              //       label: "Watch",
              //     ),
              //   ],
              // ),

              // const SizedBox(height: 24),

              /// 📈 PROFILE COMPLETION
              const Text(
                "Profile Completion",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),

              /// Progress Bar
              Stack(
                children: [
                  Container(
                    height: 8,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  FractionallySizedBox(
                    // widthFactor: 0.85, // 85%
                    widthFactor:
                        (_profileCompletionPercent / 100).clamp(0.0, 1.0),
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // const Align(
              //   alignment: Alignment.centerRight,
              //   child: Text(
              //     "85%",
              //     style: TextStyle(
              //       color: Colors.white,
              //       fontSize: 12,
              //       fontWeight: FontWeight.bold,
              //     ),
              //   ),
              // ),

              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  "${_profileCompletionPercent.toInt()}%",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _miniStatCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            /// 🔢 VALUE TOP
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),

            const SizedBox(height: 6),

            /// 🔹 ICON + LABEL ROW
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
              // border: Border.all(color: colorScheme.primary.withOpacity(0.1)),
              border: isDark
                  ? Border.all(color: colorScheme.primary.withOpacity(0.1))
                  : Border.all(
                      color: colorScheme.primary,
                      width: 0.2,
                    ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BusinessFeedPage()),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? colorScheme.surfaceVariant.withOpacity(0.3)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          // border: Border.all(color: colorScheme.primary.withOpacity(0.1)),
          border: isDark
              ? Border.all(color: colorScheme.primary.withOpacity(0.1))
              : Border.all(
                  color: colorScheme.primary,
                  width: 0.2,
                ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // 🔹 Left Side: Icon with Background
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.business_center_rounded,
                color: colorScheme.primary,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),

            // 🔹 Middle: Text Labels
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Business Updates',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Stay updated with recent activities',
                    style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // 🔹 Right Side: View All Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'View all',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget _buildGeneratedQrHeader(BuildContext context) {
  //   final colorScheme = Theme.of(context).colorScheme;

  //   return Padding(
  //     padding: const EdgeInsets.symmetric(vertical: 24.0),
  //     child: Row(
  //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //       children: [
  //         Text(
  //           'Generated QR',
  //           style: TextStyle(
  //             color: colorScheme.primary,
  //             fontSize: 20,
  //             fontWeight: FontWeight.bold,
  //           ),
  //         ),
  //         IconButton(
  //           onPressed: () {
  //             Navigator.push(
  //               context,
  //               MaterialPageRoute(
  //                 builder: (_) =>
  //                     const QrGeneratorPage(), // onGenerate hata diya
  //               ),
  //             );
  //           },
  //           icon: const Icon(Icons.add_circle_outline),
  //           color: colorScheme.primary,
  //           iconSize: 26,
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildGeneratedQrHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const QrGeneratorPage()),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          // border: Border.all(color: colorScheme.primary.withOpacity(0.1)),
          border: isDark
              ? Border.all(color: colorScheme.primary.withOpacity(0.1))
              : Border.all(
                  color: colorScheme.primary,
                  width: 0.2,
                ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // 🔹 Left Side: Icon with Background
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.qr_code_2_rounded,
                color: colorScheme.primary,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),

            // 🔹 Middle: Text Labels
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QR Code Generator',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Make your own QR Codes',
                    style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // 🔹 Right Side: Plus Button
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
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
      height: 496, // thoda safe height
      // height: MediaQuery.of(context).size.height * 0.65,
      child: _latestPosts.isNotEmpty
          ? SizedBox(
              width: double.infinity,
              child: HomePostCard(
                post: _latestPosts[0], // Sirf first post
                onPostUpdated: (postId, updatedPost) {
                  final i = _latestPosts.indexWhere((p) => p["id"] == postId);
                  if (i != -1) {
                    setState(() {
                      _latestPosts[i] = updatedPost;
                    });
                  }
                },
              ),
            )
          : const SizedBox(),
    );
  }

  Future<void> _handleRefresh() async {
    if (!mounted) return;
    context.read<SocialProvider>().fetchPosts('All');
    await Future.wait([
      _fetchLatest5Posts(),
      _fetchUserAnalytics(),
      _fetchAverageRating(),
      _fetchProfileCompletion(),
    ]);
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
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: Theme.of(context).colorScheme.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
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
                      const SizedBox(height: 24),
                      _buildGeneratedQrHeader(context),

                      const SizedBox(height: 16),
                      const ActionDock(),
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

                      // NEW SECTION
                      // NEW SECTION
                      _buildNewBusinessHeader(context),
                      const SizedBox(height: 16),
                      _buildLatestBusinessCarousel(),

                      // const SizedBox(height: 32),

                      // _buildGeneratedQrHeader(context),

                      // const SizedBox(height: 16),
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
                      child:
                          CircularProgressIndicator(color: Color(0xFF21254A)),
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
        ));
  }
}
