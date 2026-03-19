import 'dart:convert';
import 'dart:typed_data';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/features/business_feed/business_feed_page.dart';
import 'package:gridcard/widgets/action_dock.dart';
import 'package:gridcard/widgets/connection_suggest.dart';
import 'package:gridcard/widgets/share_profile_widget.dart';
import 'package:provider/provider.dart';
import '../leads/lead_scanner_2.dart';
import '../../features/qr_generator/qr_generator_page.dart';

// OLD PostCard (provider model)
import 'package:gridcard/widgets/post_card.dart' as old_post_card;
import '../../features/business_feed/home_post_card.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:gridcard/core/services/auth_provider.dart';
import 'package:gridcard/core/services/social_provider.dart';
import 'package:gridcard/core/theme/app_theme.dart';
import '../../features/analitics/user_analitics_page.dart';
import 'package:gridcard/widgets/top_alert.dart';
import 'package:gridcard/widgets/glass_box.dart';
import '../profile/edit_profile_page.dart';

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
  final GlobalKey<ConnectionSuggestState> _connectionSuggestKey = GlobalKey();

  Map<String, bool> _milestones = {}; // Store milestone status

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
  // static const String _baseUrl = AppConfig.apiBaseUrl;

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

      final uri = Uri.parse("${AppConfig.apiBaseUrl}/qr/store");
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

    final userId = await UserStorageService().getUserId();
    if (userId == null) return;

    setState(() => _isCompletionLoading = true);

    try {
      final uri = Uri.parse("${AppConfig.apiBaseUrl}/profile-completion");
      final headers = await _getHeaders();

      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({"user_id": userId}),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        if (jsonData["success"] == true) {
          setState(() {
            _profileCompletionPercent =
                (jsonData["percentage"] ?? 0).toDouble();
            _milestones = Map<String, bool>.from(jsonData["milestones"] ?? {});
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

  void _showMilestoneModal() {
    final incomplete = _milestones.entries
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
      isScrollControlled: true, // full height allow karta hai
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
                // Header with title and close icon
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
                // Milestone list – ab iske andar scroll nahi hoga
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
                            Navigator.pop(context); // bottom sheet band karo
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

  // void _navigateToMilestoneScreen(String milestoneKey) {
  //   // Define routes/screens for each milestone
  //   switch (milestoneKey) {
  //     case 'user_details':
  //       // Navigate to edit profile screen (replace with your actual route)
  //       // Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfilePage()));
  //       break;
  //     case 'links':
  //       // Navigator.push(context, MaterialPageRoute(builder: (_) => SocialLinksPage()));
  //       break;
  //     case 'keywords':
  //       // Navigator.push(context, MaterialPageRoute(builder: (_) => KeywordsPage()));
  //       break;
  //     case 'business_info':
  //       // Navigator.push(context, MaterialPageRoute(builder: (_) => BusinessInfoPage()));
  //       break;
  //     case 'product':
  //       // Navigator.push(context, MaterialPageRoute(builder: (_) => ProductsPage()));
  //       break;
  //     default:
  //       TopAlert.show(context, 'Screen not defined for $milestoneKey',
  //           isError: true);
  //   }
  // }

  void _navigateToMilestoneScreen(String milestoneKey) async {
    int tabIndex;
    switch (milestoneKey) {
      case 'user_details':
        tabIndex = 0; // ProfileTab
        break;
      case 'links':
        tabIndex = 1; // LinksTab
        break;
      case 'keywords':
        tabIndex = 2; // KeywordsTab
        break;
      case 'business_info':
        tabIndex = 3; // BusinessInfoTab
        break;
      case 'product':
        tabIndex = 4; // ProductsTab
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
          userDetails: null, // data will be fetched inside EditProfilePage
          initialTabIndex: tabIndex,
        ),
      ),
    );

    // After returning from edit, refresh milestones and other data
    if (mounted) {
      _handleRefresh();
    }
  }

  Future<void> _fetchAverageRating() async {
    final userId = await UserStorageService().getUserId();
    if (userId == null) return;

    try {
      // final userId = await UserStorageService().getUserId();
      // if (userId == null) return;

      final uri =
          Uri.parse("${AppConfig.apiBaseUrl}/user-reviews/$userId/average");
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

      final uri = Uri.parse("${AppConfig.apiBaseUrl}/user-analytics");
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
    final palette = Theme.of(context).extension<AppThemeColors>();

    return GestureDetector(
      onTap: _showMilestoneModal, // 👈 whole dashboard opens milestone modal
      child: GlassBox(
        padding: EdgeInsets.zero,
        borderRadius: 24,
        border: Border(
          bottom: BorderSide(
            color: (palette?.neonAccent ?? colorScheme.secondary)
                .withValues(alpha: isDark ? 0.42 : 0.55),
            width: 5,
          ),
        ),
        gradientColors: [
          isDark
              ? const Color(0xFF353D5A).withValues(alpha: 0.94)
              : colorScheme.primary.withValues(alpha: 0.92),
          isDark
              ? const Color(0xFF2D3550).withValues(alpha: 0.9)
              : colorScheme.primary.withValues(alpha: 0.88),
        ],
        child: Stack(
          children: [
            // ... (same background effects) ...
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: isDark ? 0.11 : 0.16),
                        Colors.white.withValues(alpha: isDark ? 0.04 : 0.08),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.42, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -52,
              left: -42,
              child: IgnorePointer(
                child: Container(
                  width: 220,
                  height: 170,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: isDark ? 0.12 : 0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// 🔹 HEADER with analytics icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'NETWORK IMPACT',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.94)
                              : colorScheme.onPrimary.withValues(alpha: 0.92),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 2.0,
                        ),
                      ),
                      Row(
                        children: [
                          // Analytics icon (tappable separately)
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const UserAnaliticsPage()),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.18)
                                    : Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.bar_chart,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.18)
                                  : Colors.white.withValues(alpha: 0.2),
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
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  /// 🔹 LOADING
                  if (_isAnalyticsLoading)
                    Center(
                      child: CircularProgressIndicator(
                          color: colorScheme.onPrimary),
                    )
                  else ...[
                    /// 🔢 TOTAL PROFILE VIEWS
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _totalViewCount.toString(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "views",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    /// 📈 PROFILE PROGRESS (only if < 100%)
                    if (_profileCompletionPercent < 100) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Profile Progress",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                          Text(
                            "${_profileCompletionPercent.toInt()}%",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      /// Progress Bar
                      Stack(
                        children: [
                          Container(
                            height: 10,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(seconds: 1),
                            curve: Curves.easeOutCubic,
                            height: 10,
                            width: (MediaQuery.of(context).size.width - 72) *
                                (_profileCompletionPercent / 100)
                                    .clamp(0.0, 1.0),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  palette?.neonAccent ?? colorScheme.secondary,
                                  (palette?.neonAccent ?? colorScheme.secondary)
                                      .withValues(alpha: 0.9),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.secondary
                                      .withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ] else

                      /// Optional: show completed badge when 100%
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle,
                                color: Colors.green, size: 16),
                            SizedBox(width: 6),
                            Text(
                              "Profile Completed",
                              style:
                                  TextStyle(color: Colors.green, fontSize: 12),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    /// 🔹 MINI STATS
                    Row(
                      children: [
                        _miniStatCard(
                          icon: FontAwesomeIcons.clock,
                          value:
                              "${(_totalTimeSeconds / 60).toStringAsFixed(1)}m",
                          label: "Time Spent",
                        ),
                        _miniStatCard(
                          icon: FontAwesomeIcons.star,
                          value: _averageRating.toStringAsFixed(1),
                          label: "$_totalReviews reviews",
                        ),
                      ],
                    ),
                  ]
                ],
              ),
            ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF58607B).withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.12),
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
                Icon(
                  icon,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.94)
                      : colorScheme.onPrimary.withValues(alpha: 0.78),
                  size: 14,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.94)
                          : colorScheme.onPrimary.withValues(alpha: 0.90),
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
                  color:
                      colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor:
                    isDark ? const Color(0xFFBEC3F9) : colorScheme.primary,
                foregroundColor:
                    isDark ? const Color(0xFF232A45) : colorScheme.onPrimary,
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
              icon: const Icon(FontAwesomeIcons.shareNodes, size: 20),
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
              border: isDark
                  ? Border.all(color: Colors.white.withValues(alpha: 0.08))
                  : Border.all(
                      color: colorScheme.primary,
                      width: 0.2,
                    ),
            ),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: isDark
                    ? const Color(0xFF131D3E)
                    : colorScheme.primary.withValues(alpha: 0.05),
                foregroundColor:
                    isDark ? colorScheme.onSurface : colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => const LeadScanner2()));
              },
              child: const Icon(FontAwesomeIcons.camera, size: 24),
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
      child: GlassBox(
        padding: const EdgeInsets.all(16),
        borderRadius: 20,
        opacity: isDark ? 0.18 : 0.1,
        gradientColors: isDark
            ? [
                const Color(0xFF1B2442).withValues(alpha: 0.88),
                const Color(0xFF151E39).withValues(alpha: 0.84),
              ]
            : null,
        child: Row(
          children: [
            // 🔹 Left Side: Icon with Background
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.onSurface.withValues(alpha: 0.12)
                    : colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                FontAwesomeIcons.briefcase,
                color: isDark ? colorScheme.onSurface : colorScheme.primary,
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
                      letterSpacing: 0.25,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Stay updated with recent activities',
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
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
                color:
                    colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.2)),
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

  Widget _buildGeneratedQrHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const shareAccent = Color(0xFFBEC3F9);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const QrGeneratorPage()),
        );
      },
      child: GlassBox(
        padding: const EdgeInsets.all(16),
        borderRadius: 20,
        opacity: isDark ? 0.2 : 0.1,
        gradientColors: isDark
            ? [
                const Color(0xFF1C2545).withValues(alpha: 0.9),
                const Color(0xFF141D38).withValues(alpha: 0.86),
              ]
            : null,
        child: Row(
          children: [
            // 🔹 Left Side: Icon with Background
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : colorScheme.secondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                FontAwesomeIcons.qrcode,
                color: isDark ? shareAccent : colorScheme.secondary,
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
                      letterSpacing: 0.25,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Make your own QR Codes',
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
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
                color: isDark
                    ? colorScheme.onSurface.withValues(alpha: 0.2)
                    : colorScheme.secondary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:
                        (isDark ? colorScheme.onSurface : colorScheme.secondary)
                            .withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Icon(
                FontAwesomeIcons.circleChevronRight,
                color: isDark ? shareAccent : Colors.white,
                size: 16,
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
    final colorScheme = Theme.of(context).colorScheme;
    if (_isLatestLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 25),
        child: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      );
    }

    if (_latestPosts.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 25),
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
    _connectionSuggestKey.currentState?.refresh(); // 👈 refresh suggestions
  }

  // ===========================
  // BUILD
  // ===========================
  @override
  Widget build(BuildContext context) {
    final socialProvider = context.watch<SocialProvider>();
    final posts = socialProvider.posts;

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
                          letterSpacing: 0.7,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // const ConnectionSuggest(),
                      ConnectionSuggest(
                        key: _connectionSuggestKey, // 👈 pass key
                        viewerUserId: viewerUserId, // 👈 pass ID
                      ),
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
                SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary,
                      ),
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
