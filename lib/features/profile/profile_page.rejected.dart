import 'dart:ui';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:gridcard/core/services/auth_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gridcard/core/services/profile_provider.dart';
import 'package:gridcard/widgets/app_network_image.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gridcard/widgets/top_alert.dart';
import 'package:gridcard/features/profile/widgets/profile_header.dart';
import 'package:gridcard/features/profile/edit_profile_page.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gridcard/widgets/glass_box.dart';
import 'package:gridcard/widgets/core/core_widgets.dart';
import 'package:gridcard/features/feature_map/feature_access_helper.dart';
import 'package:gridcard/features/feature_map/feature_mapper.dart';
import 'package:gridcard/features/home/SubscriptionPlans.dart';
import 'package:gridcard/features/profile/shorts_reel_page.dart';

class ProfilePage extends StatefulWidget {
  final int? userId;
  final int? viewerUserId;
  final String? fromConnectionTab;
  final bool? isConnected;
  final bool? fromSuggestion;

  const ProfilePage({
    super.key,
    this.userId,
    this.viewerUserId,
    this.fromConnectionTab,
    this.isConnected,
    this.fromSuggestion,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _reviewController = TextEditingController();
  int _selectedRating = 0;
  bool _isSubmittingReview = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDetails();
    });
  }

  void _fetchDetails() {
    final provider = context.read<ProfileProvider>();
    final authUserId = context.read<AuthProvider>().user?.id;
    final userId = widget.userId ?? authUserId;
    final isOwner = widget.userId == null || widget.userId == authUserId;
    if (userId != null) {
      provider.fetchProfileData(userId.toString()).then((_) {
        // Fallback: If Discover search didn't pass it and the Profile API didn't return it either,
        // we explicitly check the friends list.
        final status = _resolveConnectionStatus(
            provider.profileData ?? {}, widget.isConnected);
        if (status == 'none' && !isOwner) {
          provider.checkConnectionStatus(userId);
        }
      });
      provider.fetchMasterLinks(userId);
      provider.fetchProducts(userId);
      provider.fetchReviews(userId);
      provider.fetchProStatus(userId: userId, isOwner: isOwner);
      provider.fetchUserVideos(userId);
    }
  }

  String? _extractYoutubeId(String url) {
    final u = url.trim();
    final shorts = RegExp(r'youtube\.com\/shorts\/([A-Za-z0-9_-]{6,})')
        .firstMatch(u)
        ?.group(1);
    if (shorts != null) return shorts;
    final watch = RegExp(r'(?:v=)([A-Za-z0-9_-]{6,})').firstMatch(u)?.group(1);
    if (watch != null) return watch;
    final shortLink =
        RegExp(r'youtu\.be\/([A-Za-z0-9_-]{6,})').firstMatch(u)?.group(1);
    return shortLink;
  }

  String? _thumbnailFromUrl(String url) {
    final id = _extractYoutubeId(url);
    if (id == null) return null;
    return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
  }

  Future<void> _onAddShortVideoPressed(int profileId) async {
    // ignore: avoid_print
    print("🎬 _onAddShortVideoPressed triggered for profileId=$profileId");
    final auth = context.read<AuthProvider>();

    // 🔥 Ensures we have the latest subscription data
    await auth.refreshSubscription();

    final featureId = FeatureMapper.getFeatureId('product_short_videos');
    bool canUse = false;
    if (featureId != null) {
      canUse = FeatureAccessHelper.canUseFeature(
        featureId: featureId,
        subscription: auth.subscriptionDetails,
      );
    } else {
      canUse = auth.canUseFeature('product_short_videos');
    }

    if (!canUse) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SubscriptionPlans()),
      );
      return;
    }

    final titleController = TextEditingController();
    final linkController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Short Video'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppFormInput(
                controller: titleController,
                labelText: 'Title',
                hintText: 'e.g. Product Demo',
              ),
              const SizedBox(height: 10),
              AppFormInput(
                controller: linkController,
                labelText: 'YouTube Shorts URL',
                hintText: 'https://youtube.com/shorts/...',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'title': titleController.text.trim(),
                  'url': linkController.text.trim(),
                });
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (result == null) return;
    final title = (result['title'] ?? '').trim();
    final url = (result['url'] ?? '').trim();
    if (url.isEmpty || _extractYoutubeId(url) == null) {
      TopAlert.show(context, 'Please enter a valid YouTube Shorts link',
          isError: true);
      return;
    }

    final provider = context.read<ProfileProvider>();
    final success = await provider.addUserVideo({
      'title': title.isEmpty ? 'Short Video' : title,
      'url': url,
    });

    if (success && mounted) {
      TopAlert.show(context, "Video added successfully", isSuccess: true);
    }
  }

  Widget _buildShortVideosSection(
      ProfileProvider provider, bool isOwner, int profileId, bool isDark) {
    final onSurface = isDark ? Colors.white : Colors.black;
    final videos = provider.userVideos;

    if (videos.isEmpty && !provider.isLoadingVideos) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 305, // 🔥 Increased height for portrait cards
          child: provider.isLoadingVideos
              ? const Center(child: CircularProgressIndicator())
              : videos.isEmpty
                  ? Center(
                      // child: Text(
                      //   'No short videos added yet',
                      //   style: TextStyle(color: Colors.grey[500]),
                      // ),
                      )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: videos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final item = videos[index];
                        final title = (item['title'] ?? 'Video').toString();
                        final url =
                            (item['video_url'] ?? item['url'] ?? '').toString();
                        final thumb = _thumbnailFromUrl(url);
                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ShortsReelPage(
                                  videos: videos
                                      .map((v) => Map<String, dynamic>.from(v))
                                      .toList(),
                                  initialIndex: index,
                                ),
                              ),
                            ).then((_) {
                              // Force state refresh in case caching changed
                              setState(() {});
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width:
                                150, // 🔥 Narrower width for portrait aspect ratio
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E1E1E)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                // BoxShadow(
                                //   color: Colors.black.withOpacity(0.1),
                                //   blurRadius: 8,
                                //   offset: const Offset(0, 4),
                                // ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                        bottom: Radius.circular(10),
                                        top: Radius.circular(10)),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        AppNetworkImage(
                                          imageUrl: thumb,
                                          fit: BoxFit.cover,
                                        ),
                                        const Center(
                                          child: Icon(Icons.play_circle_fill,
                                              color: Colors.white, size: 38),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
        const SizedBox(height: 22),
      ],
    );
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _showRemoveConnectionDialog(int receiverId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Connection'),
        content: const Text('Are you sure you want to remove this connection?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final session = await UserStorageService().loadSession();
      final viewerId = session.user?.id;
      if (viewerId == null) return;

      final url =
          Uri.parse("${AppConfig.apiBaseUrl}/connection-request/delete");
      final payload = {
        "sender_id": viewerId,
        "receiver_id": receiverId,
        "status":
            2, // Accepted connections usually have status 1, deleting them might require status 1 or 2
      };

      try {
        final token = await UserStorageService().getToken();
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        );

        final jsonData = jsonDecode(response.body);
        if (response.statusCode == 200 && jsonData['status'] == true) {
          if (mounted) {
            TopAlert.show(context, "Connection removed", isSuccess: true);
            // Refresh profile data to update UI
            context
                .read<ProfileProvider>()
                .fetchProfileData(receiverId.toString());
          }
        } else {
          if (mounted) {
            TopAlert.show(
                context, jsonData['message'] ?? "Error removing connection",
                isError: true);
          }
        }
      } catch (e) {
        if (mounted) TopAlert.show(context, "Network error", isError: true);
      }
    }
  }

  String _resolveConnectionStatus(
      Map<String, dynamic> profile, bool? isConnected) {
    // 1. Check freshly fetched profile status from API
    // We look for any explicit status or boolean flag in the fetched data
    final status = (profile['connection_status'] ?? profile['status'] ?? '')
        .toString()
        .toLowerCase();

    final boolIsConnected = profile['is_connected'] ??
        profile['isConnected'] ??
        profile['connected'] ??
        profile['is_friend'];

    // If API says accepted
    if (status == 'accepted' ||
        status == 'connected' ||
        status == 'friend' ||
        status == '1' ||
        status == 'true' ||
        boolIsConnected == true ||
        boolIsConnected == 1 ||
        boolIsConnected == '1' ||
        boolIsConnected == 'true') {
      return 'accepted';
    }

    // If API says pending
    if (status == 'pending' || status == 'requested' || status == 'waiting') {
      return 'pending';
    }

    // 2. Fallback to the flag passed from the parent (e.g. DiscoverPage)
    // ONLY if the API didn't explicitly give us a "pending" or "none" status yet
    if (isConnected == true && status.isEmpty) {
      return 'accepted';
    }

    // 3. Status check for "none" variations
    if (status == 'none' ||
        status == 'null' ||
        status == '0' ||
        status == 'false' ||
        boolIsConnected == false ||
        boolIsConnected == 0) {
      return 'none';
    }

    // Final fallback
    return 'none';
  }

  Future<void> _launchURL(String url) async {
    if (url.isEmpty) return;

    // Sanitize URL
    String sanitizedUrl = url.trim();
    if (!sanitizedUrl.startsWith('http://') &&
        !sanitizedUrl.startsWith('https://')) {
      sanitizedUrl = 'https://$sanitizedUrl';
    }

    try {
      final uri = Uri.parse(sanitizedUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted)
          TopAlert.show(context, "Could not launch $url", isError: true);
      }
    } catch (e) {
      if (mounted) TopAlert.show(context, "Invalid link format", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = widget.userId == null ||
        widget.userId == context.read<AuthProvider>().user?.id;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = isDark ? Colors.white : Colors.black;

    return Consumer<ProfileProvider>(
      builder: (context, provider, _) {
        final profile = provider.profileData;
        final targetId = widget.userId?.toString() ??
            context.read<AuthProvider>().user?.id?.toString();
        final currentProfileId =
            (profile?['user_id'] ?? profile?['id'])?.toString();

        bool isCorrectUser = profile != null && currentProfileId == targetId;

        if (profile == null || !isCorrectUser) {
          if (provider.isLoading) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (profile == null) {
            return const Scaffold(
                body: Center(child: Text("Profile not found")));
          }
        }

        final userObj = profile['user'];
        final pId = profile['id'] ??
            profile['user_id'] ??
            profile['emp_id'] ??
            userObj?['id'];
        final pMobile = profile['mobile'] ??
            profile['mobile_one'] ??
            userObj?['user_mobile'] ??
            '';

        String fName =
            profile['fname']?.toString() ?? userObj?['fname']?.toString() ?? '';
        String lName =
            profile['lname']?.toString() ?? userObj?['lname']?.toString() ?? '';
        String fullName = "$fName $lName".trim();

        if (fullName.isEmpty || !fullName.contains(' ')) {
          final uName = userObj?['user_name']?.toString() ?? '';
          if (uName.isNotEmpty && uName.length > fullName.length) {
            fullName = uName;
          }
        }

        // Business name
        String businessName = '';
        final businessInfo =
            profile['business_info'] ?? userObj?['business_info'];
        if (businessInfo is Map) {
          businessName = businessInfo['business_name']?.toString() ??
              businessInfo['company_name']?.toString() ??
              '';
        } else if (businessInfo is List && businessInfo.isNotEmpty) {
          final b0 = businessInfo[0];
          businessName = b0['business_name']?.toString() ??
              b0['company_name']?.toString() ??
              '';
        }
        if (businessName.isEmpty) {
          businessName = profile['business_name']?.toString() ??
              profile['company_name']?.toString() ??
              userObj?['business_name']?.toString() ??
              userObj?['company_name']?.toString() ??
              profile['desg']?.toString() ??
              profile['dept']?.toString() ??
              profile['busi_type']?.toString() ??
              '';
        }

        String industryName = '';
        if (businessInfo is Map && businessInfo['industry'] is Map) {
          industryName = businessInfo['industry']['title']?.toString() ?? '';
        }
        if (industryName.isEmpty) {
          industryName = profile['industry_name']?.toString() ??
              profile['dept']?.toString() ??
              profile['category']?.toString() ??
              '';
        }

        // Location
        String location = '';
        Map<String, dynamic>? bMap;
        if (businessInfo is Map) {
          bMap = businessInfo as Map<String, dynamic>;
        } else if (businessInfo is List && businessInfo.isNotEmpty) {
          bMap = businessInfo[0] as Map<String, dynamic>?;
        }
        if (bMap != null) {
          final city = bMap['city']?.toString() ?? '';
          final state = bMap['state']?.toString() ?? '';
          final address = bMap['address']?.toString() ?? '';
          if (city.isNotEmpty || state.isNotEmpty) {
            location = [city, state].where((s) => s.isNotEmpty).join(', ');
          } else if (address.isNotEmpty) {
            location = address;
          }
        }
        if (location.isEmpty) {
          final city = profile['city']?.toString() ?? '';
          final state = profile['state']?.toString() ?? '';
          final address = profile['address']?.toString() ?? '';
          if (city.isNotEmpty || state.isNotEmpty) {
            location = [city, state].where((s) => s.isNotEmpty).join(', ');
          } else if (address.isNotEmpty) {
            location = address;
          }
        }
        if (location.isEmpty) location = 'Earth';

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.7, -0.6),
                radius: 1.2,
                colors: isDark
                    ? [const Color(0xFF1A1225), const Color(0xFF121018)]
                    : [const Color(0xFFF0F2F5), const Color(0xFFFFFFFF)],
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ProfileHeader(
                    coverUrl: profile['profile_pic']?.toString(), // Profile Pic
                    profilePicUrl: profile['profile_logo']?.toString(), // logo
                    videoUrl: _extractProfileVideoUrl(profile),
                    name: fullName,
                    designation: profile['desg']?.toString() ??
                        profile['designation']?.toString(),
                    department: profile['dept']?.toString() ??
                        profile['department']?.toString(),
                    onBack: () => Navigator.pop(context),
                    onEdit: !isOwner
                        ? null
                        : () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditProfilePage(
                                  userDetails: profile,
                                ),
                              ),
                            );
                            if (result == true) {
                              _fetchDetails();
                            }
                          },
                  ),
                  const SizedBox(height: 55),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // IDENTITY SECTION
                        Center(
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    fullName,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: onSurface,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.verified,
                                    color: Colors.blue,
                                    size: 20,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                profile['user_designation']?.toString() ??
                                    profile['designtion']?.toString() ??
                                    "Real Estate Consultant",
                                style: TextStyle(
                                  fontSize: 15,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.location_on,
                                      size: 14, color: Colors.grey[500]),
                                  const SizedBox(width: 4),
                                  Text(
                                    location,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[500],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              if (businessName.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.05)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.grey[800]!
                                          : Colors.grey[200]!,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.home_work_outlined,
                                          size: 16,
                                          color: theme.colorScheme.primary),
                                      const SizedBox(width: 8),
                                      Text(
                                        businessName,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: onSurface,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.chevron_right,
                                          size: 16, color: Colors.grey[500]),
                                    ],
                                  ),
                                ),
                              ]
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // STATS ROW
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatItem(
                                icon: Icons.people_alt_outlined,
                                iconColor: Colors.blue,
                                value: "238",
                                label: "Connections",
                                onSurface: onSurface,
                              ),
                              Container(
                                  width: 1,
                                  height: 30,
                                  color: Colors.grey[200]),
                              _buildStatItem(
                                icon: Icons.inventory_2_outlined,
                                iconColor: Colors.orange,
                                value: provider.products.length.toString(),
                                label: "Products",
                                onSurface: onSurface,
                              ),
                              Container(
                                  width: 1,
                                  height: 30,
                                  color: Colors.grey[200]),
                              _buildStatItem(
                                icon: Icons.article_outlined,
                                iconColor: Colors.brown,
                                value: provider.userVideos.length.toString(),
                                label: "Posts",
                                onSurface: onSurface,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // CTA BUTTONS ROW
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  final receiverId =
                                      int.tryParse(pId?.toString() ?? '0') ?? 0;
                                  if (receiverId == 0) return;
                                  final status = _resolveConnectionStatus(
                                      profile, widget.isConnected);
                                  if (status == 'accepted') {
                                    _showRemoveConnectionDialog(receiverId);
                                  } else if (status == 'none') {
                                    provider
                                        .toggleConnection(receiverId)
                                        .then((success) {
                                      if (success && mounted) {
                                        provider.fetchProfileData(
                                            receiverId.toString());
                                        TopAlert.show(context,
                                            "Connection request sent!");
                                      }
                                    });
                                  }
                                },
                                icon: const Icon(Icons.person_add, size: 16),
                                label: const Text("Connect"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1877F2),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  if (pMobile.toString().isNotEmpty) {
                                    _launchURL("https://wa.me/${pMobile}");
                                  }
                                },
                                icon: const Icon(Icons.message_outlined,
                                    size: 16),
                                label: const Text("Message"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF1877F2),
                                  side: const BorderSide(
                                      color: Color(0xFF1877F2)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final user =
                                      context.read<AuthProvider>().user;
                                  final profileId = user?.userName ??
                                      user?.id?.toString() ??
                                      'me';
                                  final baseUrl = AppConfig.apiBaseUrl
                                      .replaceAll(RegExp(r'/api$'), '');
                                  final profileUrl = "$baseUrl/u/$profileId";
                                  final message =
                                      "Hi, check out my bynd AI digital business card here: $profileUrl";
                                  await Share.share(message);
                                },
                                icon: const Icon(Icons.share, size: 16),
                                label: const Text("Share"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.grey[700],
                                  side: BorderSide(color: Colors.grey[300]!),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // QUICK CONTACT ROW
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildQuickContactItem(
                              icon: FontAwesomeIcons.phone,
                              label: "Call",
                              color: Colors.green,
                              onTap: () {
                                if (pMobile.toString().isNotEmpty) {
                                  _launchURL("tel:${pMobile}");
                                }
                              },
                            ),
                            _buildQuickContactItem(
                              icon: FontAwesomeIcons.whatsapp,
                              label: "WhatsApp",
                              color: Colors.green,
                              onTap: () {
                                if (pMobile.toString().isNotEmpty) {
                                  _launchURL("https://wa.me/${pMobile}");
                                }
                              },
                            ),
                            _buildQuickContactItem(
                              icon: FontAwesomeIcons.envelope,
                              label: "Email",
                              color: Colors.purple,
                              onTap: () {
                                final email = profile['email'] ?? '';
                                if (email.toString().isNotEmpty) {
                                  _launchURL("mailto:${email}");
                                }
                              },
                            ),
                            _buildQuickContactItem(
                              icon: FontAwesomeIcons.language,
                              label: "Website",
                              color: Colors.blue,
                              onTap: () {
                                final links = provider.masterLinks;
                                final web = links.firstWhere(
                                  (l) => l['name']
                                      .toString()
                                      .toLowerCase()
                                      .contains('web'),
                                  orElse: () => {},
                                );
                                if (web.isNotEmpty) {
                                  _launchURL(web['link'].toString());
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // ABOUT SECTION
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "About",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              profile['about']?.toString() ??
                                  "Helping people find the perfect residential and commercial properties. Serving in Durg, Bhilai and Raipur with transparency and trust.",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () {},
                              child: const Text(
                                "Read More",
                                style: TextStyle(
                                  color: Color(0xFF1877F2),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // SERVICES SECTION
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Services",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            GestureDetector(
                              onTap: () {},
                              child: const Text(
                                "See All",
                                style: TextStyle(
                                    color: Color(0xFF1877F2),
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildServiceChip(
                              icon: Icons.home_outlined,
                              label: "Residential",
                              color: Colors.blue,
                            ),
                            _buildServiceChip(
                              icon: Icons.business_outlined,
                              label: "Commercial",
                              color: Colors.purple,
                            ),
                            _buildServiceChip(
                              icon: Icons.landscape_outlined,
                              label: "Land",
                              color: Colors.green,
                            ),
                            _buildServiceChip(
                              icon: Icons.construction_outlined,
                              label: "Construction",
                              color: Colors.orange,
                            ),
                            _buildServiceChip(
                              icon: Icons.handshake_outlined,
                              label: "Consultation",
                              color: Colors.amber,
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // FEATURED PRODUCTS
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Featured Products",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            GestureDetector(
                              onTap: () {},
                              child: const Text(
                                "See All",
                                style: TextStyle(
                                    color: Color(0xFF1877F2),
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 195,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _buildProductCard(
                                image:
                                    "https://images.unsplash.com/photo-1564013799919-ab600027ffc6?auto=format&fit=crop&w=400&q=80",
                                title: "2 BHK House",
                                price: "₹34 Lakh",
                                location: "Shivnath Nagar, Durg",
                              ),
                              const SizedBox(width: 12),
                              _buildProductCard(
                                image:
                                    "https://images.unsplash.com/photo-1512917774080-9991f1c4c750?auto=format&fit=crop&w=400&q=80",
                                title: "Premium Villa",
                                price: "₹1.50 Cr",
                                location: "Bhilai, Chhattisgarh",
                              ),
                              const SizedBox(width: 12),
                              _buildProductCard(
                                image:
                                    "https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=400&q=80",
                                title: "3 BHK House",
                                price: "₹42 Lakh",
                                location: "Anjora, Durg",
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                                width: 16,
                                height: 6,
                                decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(3))),
                            const SizedBox(width: 4),
                            Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                    color: Colors.grey,
                                    shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                    color: Colors.grey,
                                    shape: BoxShape.circle)),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // RECENT ACTIVITY
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Recent Activity",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            GestureDetector(
                              onTap: () {},
                              child: const Text(
                                "See All",
                                style: TextStyle(
                                    color: Color(0xFF1877F2),
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Column(
                          children: [
                            _buildActivityItem(
                              icon: Icons.home_outlined,
                              iconBgColor: Colors.blue.withOpacity(0.1),
                              iconColor: Colors.blue,
                              boldText: "Amit",
                              normalText: " posted a new property",
                              time: "2 hours ago",
                            ),
                            const SizedBox(height: 12),
                            _buildActivityItem(
                              icon: Icons.calendar_month_outlined,
                              iconBgColor: Colors.pink.withOpacity(0.1),
                              iconColor: Colors.pink,
                              boldText: "Amit",
                              normalText: " is attending Real Estate Meet",
                              time: "Yesterday",
                            ),
                            const SizedBox(height: 12),
                            _buildActivityItem(
                              icon: Icons.insert_drive_file_outlined,
                              iconBgColor: Colors.green.withOpacity(0.1),
                              iconColor: Colors.green,
                              boldText: "Amit",
                              normalText: " shared a property flyer",
                              time: "2 days ago",
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // CONNECTIONS
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Connections",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            GestureDetector(
                              onTap: () {},
                              child: const Text(
                                "See All",
                                style: TextStyle(
                                    color: Color(0xFF1877F2),
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ...List.generate(5, (index) {
                              return Container(
                                margin: const EdgeInsets.only(right: 8),
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundImage: NetworkImage(
                                    "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=100&q=80",
                                  ),
                                ),
                              );
                            }),
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.blue.withOpacity(0.1),
                              child: const Text(
                                "+32",
                                style: TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // REVIEWS
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Reviews",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            GestureDetector(
                              onTap: () {},
                              child: const Text(
                                "See All",
                                style: TextStyle(
                                    color: Color(0xFF1877F2),
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                const Text(
                                  "4.8",
                                  style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900),
                                ),
                                Row(
                                  children: List.generate(5, (index) {
                                    return const Icon(Icons.star,
                                        color: Colors.amber, size: 14);
                                  }),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "(32 Reviews)",
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 11),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.05)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: isDark
                                          ? Colors.grey[800]!
                                          : Colors.grey[200]!),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.02),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const CircleAvatar(
                                      radius: 16,
                                      backgroundImage: NetworkImage(
                                        "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=100&q=80",
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                "Rakesh Verma",
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12),
                                              ),
                                              Row(
                                                children:
                                                    List.generate(5, (index) {
                                                  return const Icon(Icons.star,
                                                      color: Colors.amber,
                                                      size: 10);
                                                }),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "Very professional and helpful. Great experience!",
                                            style: TextStyle(
                                                color: isDark
                                                    ? Colors.grey[350]
                                                    : Colors.grey[800],
                                                fontSize: 11),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "2 weeks ago",
                                            style: TextStyle(
                                                color: Colors.grey[500],
                                                fontSize: 9),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (pMobile.toString().isNotEmpty) {
                          _launchURL("https://wa.me/${pMobile}");
                        }
                      },
                      icon: const FaIcon(FontAwesomeIcons.whatsapp,
                          color: Colors.white, size: 18),
                      label: const Text("WhatsApp",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final receiverId =
                            int.tryParse(pId?.toString() ?? '0') ?? 0;
                        if (receiverId == 0) return;
                        final status = _resolveConnectionStatus(
                            profile, widget.isConnected);
                        if (status == 'accepted') {
                          _showRemoveConnectionDialog(receiverId);
                        } else if (status == 'none') {
                          provider.toggleConnection(receiverId).then((success) {
                            if (success && mounted) {
                              provider.fetchProfileData(receiverId.toString());
                              TopAlert.show(
                                  context, "Connection request sent!");
                            }
                          });
                        }
                      },
                      icon: const Icon(Icons.person_add,
                          color: Colors.white, size: 18),
                      label: const Text("Connect",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1877F2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Redundant _buildClassicHeader removed in favor of ProfileHeader widget

  String? _extractProfileVideoUrl(Map<String, dynamic> profile) {
    final userObj = profile['user'];
    final masterObj = profile['master_user'];
    final candidate = profile['profile_video'] ??
        userObj?['profile_video'] ??
        masterObj?['profile_video'];
    final url = candidate?.toString().trim();
    if (url == null || url.isEmpty) return null;
    return url;
  }

  Widget _buildBadgeRow(ProfileProvider provider, Map<String, dynamic> profile,
      bool isDark, bool isOwner) {
    final business = profile['business_info'];
    final master = profile['master_user'] ?? profile;

    Map<String, dynamic>? bMap;
    if (business is Map) {
      bMap = Map<String, dynamic>.from(business);
    } else if (business is List && business.isNotEmpty) {
      bMap = Map<String, dynamic>.from(business[0]);
    }

    Map<String, dynamic>? masterMap;
    if (master is Map) {
      masterMap = Map<String, dynamic>.from(master);
    } else if (master is List && master.isNotEmpty) {
      masterMap = Map<String, dynamic>.from(master[0]);
    } else {
      masterMap = profile;
    }

    final hasGST = (bMap?['gst_no'] != null && bMap?['gst_no'] != '') ||
        (profile['gst_no'] != null && profile['gst_no'] != '');
    final hasJCI = masterMap['jci_member']?.toString() == '1';
    final hasBNI = masterMap['bni_member']?.toString() == '1';

    final hasPro =
        provider.isProUser ?? _hasProAccess(profile, isOwner: isOwner);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Reviews Badge
          _badgeCard(
            icon: const Icon(Icons.star, color: Colors.amber, size: 28),
            title: "${provider.avgRating ?? '0.0'} ★",
            subtitle: "${provider.totalReviewsCount} Reviews",
            titleColor: Theme.of(context).colorScheme.onSurface,
            isDark: isDark,
          ),

          // PRO Badge
          if (hasPro)
            _badgeCard(
              icon: const Icon(Icons.emoji_events,
                  color: Color(0xFF3E2C00), size: 28),
              title: "PRO",
              subtitle: "User",
              titleColor: const Color(0xFF3E2C00),
              subtitleColor: const Color(0xFF5A4300),
              backgroundColor: const Color(0xFFD4AF37),
              borderColor: const Color(0xFFB8860B),
              isPremium: true,
              isDark: isDark,
            ),

          // JCI Badge
          if (hasJCI)
            _logoOnlyBadge(
              logo: Image.asset('assets/jci.jpeg', width: 94, height: 54),
              isDark: isDark,
              backgroundColor: Colors.white,
              borderColor: Colors.grey[300],
            ),

          // BNI Badge
          if (hasBNI)
            _logoOnlyBadge(
              logo: Image.asset('assets/bni.png', width: 64, height: 44),
              isDark: isDark,
              backgroundColor: const Color(0xFFbc262f),
              borderColor: const Color(0xFFbc262f),
            ),

          // GST Badge
          if (hasGST)
            _badgeCard(
              icon: const Icon(Icons.verified, color: Colors.blue, size: 28),
              title: "GST",
              subtitle: "Verified business",
              titleColor: Theme.of(context).colorScheme.onSurface,
              isDark: isDark,
            ),
        ],
      ),
    );
  }

  bool _hasProAccess(Map<String, dynamic> profile, {bool isOwner = false}) {
    bool truthy(dynamic value) {
      if (value == null) return false;
      final v = value.toString().toLowerCase().trim();
      return value == true || v == '1' || v == 'true' || v == 'yes';
    }

    bool isPaidPlanName(dynamic value) {
      final name = value?.toString().toLowerCase().trim() ?? '';
      if (name.isEmpty) return false;
      return !(name.contains('free') || name == 'basic');
    }

    bool hasPaidActiveSub(dynamic rawSubs) {
      if (rawSubs is! List) return false;
      for (final sub in rawSubs) {
        if (sub is! Map) continue;
        final isActive = truthy(sub['is_active']) ||
            truthy(sub['active']) ||
            truthy(sub['status']);
        if (!isActive) continue;

        final plan = sub['plan'];
        final planPrice = double.tryParse(
              (plan is Map ? plan['price'] : sub['price'])?.toString() ?? '0',
            ) ??
            0;
        if (planPrice > 0) return true;

        final planName =
            plan is Map ? plan['name'] ?? plan['title'] : sub['plan_name'];
        if (isPaidPlanName(planName)) return true;
      }
      return false;
    }

    final user = profile['user'];
    final master = profile['master_user'];

    final profileIsPro = truthy(profile['is_pro']);
    final profileIsPremium = truthy(profile['is_premium']);
    final userIsPro = truthy(user is Map ? user['is_pro'] : null);
    final userIsPremium = truthy(user is Map ? user['is_premium'] : null);
    final masterIsPro = truthy(master is Map ? master['is_pro'] : null);
    final masterIsPremium = truthy(master is Map ? master['is_premium'] : null);

    if (profileIsPro ||
        profileIsPremium ||
        userIsPro ||
        userIsPremium ||
        masterIsPro ||
        masterIsPremium) {
      debugPrint(
        'PRO CHECK: TRUE via boolean flags '
        '(profile.is_pro=$profileIsPro, profile.is_premium=$profileIsPremium, '
        'user.is_pro=$userIsPro, user.is_premium=$userIsPremium, '
        'master.is_pro=$masterIsPro, master.is_premium=$masterIsPremium)',
      );
      return true;
    }

    final rawPlanName = profile['plan_name'] ??
        profile['subscription_plan'] ??
        (user is Map ? user['plan_name'] : null) ??
        (master is Map ? master['plan_name'] : null);
    if (isPaidPlanName(rawPlanName)) {
      debugPrint('PRO CHECK: TRUE via paid plan name: $rawPlanName');
      return true;
    }

    final subsFromProfile = profile['subscriptions'];
    if (hasPaidActiveSub(subsFromProfile)) {
      final count = subsFromProfile is List ? subsFromProfile.length : 0;
      debugPrint('PRO CHECK: TRUE via profile.subscriptions (count=$count)');
      return true;
    }

    if (user is Map && hasPaidActiveSub(user['subscriptions'])) {
      final userSubs = user['subscriptions'];
      final count = userSubs is List ? userSubs.length : 0;
      debugPrint('PRO CHECK: TRUE via user.subscriptions (count=$count)');
      return true;
    }
    if (master is Map && hasPaidActiveSub(master['subscriptions'])) {
      final masterSubs = master['subscriptions'];
      final count = masterSubs is List ? masterSubs.length : 0;
      debugPrint(
          'PRO CHECK: TRUE via master_user.subscriptions (count=$count)');
      return true;
    }

    if (isOwner) {
      final authSubscription = context.read<AuthProvider>().subscriptionDetails;
      if (_hasProFromAuthSubscription(authSubscription)) {
        debugPrint('PRO CHECK: TRUE via auth.subscriptionDetails fallback');
        return true;
      }
    }

    final profileSubCount = profile['subscriptions'] is List
        ? (profile['subscriptions'] as List).length
        : 0;
    final userSubCount = user is Map && user['subscriptions'] is List
        ? (user['subscriptions'] as List).length
        : 0;
    final masterSubCount = master is Map && master['subscriptions'] is List
        ? (master['subscriptions'] as List).length
        : 0;
    debugPrint(
      'PRO CHECK: FALSE '
      '(plan_name=$rawPlanName, profileSubs=$profileSubCount, '
      'userSubs=$userSubCount, masterSubs=$masterSubCount)',
    );

    return false;
  }

  bool _hasProFromAuthSubscription(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return false;

    bool truthy(dynamic value) {
      if (value == null) return false;
      final v = value.toString().toLowerCase().trim();
      return value == true || v == '1' || v == 'true' || v == 'yes';
    }

    bool isPaidPlanName(dynamic value) {
      final name = value?.toString().toLowerCase().trim() ?? '';
      if (name.isEmpty) return false;
      return !(name.contains('free') || name == 'basic');
    }

    dynamic firstPresent(Iterable<String> keys) {
      for (final key in keys) {
        if (data.containsKey(key) && data[key] != null) return data[key];
      }
      return null;
    }

    if (truthy(firstPresent(['is_pro', 'is_premium', 'premium']))) {
      return true;
    }

    final planName = firstPresent(
        ['plan_name', 'plan', 'subscription_plan', 'title', 'name']);
    if (isPaidPlanName(planName)) {
      return true;
    }

    final planPriceRaw = firstPresent(['price', 'amount', 'plan_price']);
    final planPrice = double.tryParse(planPriceRaw?.toString() ?? '0') ?? 0;
    if (planPrice > 0) {
      return true;
    }

    final features = data['features'];
    if (features is List && features.isNotEmpty) {
      for (final feature in features) {
        if (feature is! Map) continue;
        final limit = int.tryParse(feature['limit']?.toString() ?? '');
        if (limit == -1) {
          return true;
        }
      }
    }

    return false;
  }

  Widget _badgeCard({
    required Widget icon,
    required String title,
    String? subtitle,
    required Color titleColor,
    required bool isDark,
    Color? backgroundColor,
    Color? subtitleColor,
    Color? borderColor,
    bool isPremium = false,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 155,
          height: 65,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isPremium
                ? null
                : (backgroundColor ??
                    (isDark ? const Color(0xFF1E1E1E) : Colors.white)),
            gradient: isPremium
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFF7E08A),
                      Color(0xFFD4AF37),
                      Color(0xFFB8860B),
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor ??
                  (isDark
                      ? Colors.grey[800]!.withOpacity(0.5)
                      : Colors.grey[300]!),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 40, height: 40, child: Center(child: icon)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: titleColor,
                        height: 1.1,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          fontSize: 11,
                          color: subtitleColor ??
                              (isDark ? Colors.grey[400] : Colors.grey[600]),
                          height: 1.1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _logoOnlyBadge({
    required Widget logo,
    required bool isDark,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    return Container(
      width: 155,
      height: 65,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: backgroundColor ??
            (isDark ? const Color(0xFF1E1E1E) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor ??
              (isDark ? Colors.grey[800]!.withOpacity(0.5) : Colors.grey[300]!),
        ),
      ),
      child: Center(child: logo),
    );
  }

  Widget _buildActionGrid(ProfileProvider provider, bool isDark) {
    // Filter out custom action buttons from the icon grid
    final links = provider.masterLinks
        .where((l) => !(l['name']?.toString().startsWith('btn:') ?? false))
        .toList();

    if (links.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: links.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemBuilder: (context, index) {
        final link = links[index];
        final name = link['name'] ?? 'Link';
        final url = link['link'] ?? '';
        final iconData = _getIconForName(name);
        final bgColor = _getColorForName(name);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _launchURL(url),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              decoration: BoxDecoration(
                color: bgColor.withOpacity(isDark ? 0.85 : 1.0),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: (bgColor == Colors.white ||
                            bgColor == const Color(0xFFFFFFFF))
                        ? Colors.black.withOpacity(0.12)
                        : bgColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: _buildIconWidget(name, iconData, Colors.white),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openFullScreenImage(String? url) {
    if (url == null || url.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    panEnabled: true,
                    boundaryMargin: const EdgeInsets.all(20),
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: SizedBox.expand(
                      child: Image.network(url, fit: BoxFit.contain),
                    ),
                  ),
                ),
                Positioned(
                  top: 20,
                  left: 20,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductsSection(ProfileProvider provider, bool isDark) {
    final products = provider.products;
    final onSurface = isDark ? Colors.white : Colors.black;
    final colorScheme = Theme.of(context).colorScheme;
    final profile = provider.profileData;
    final profileId = int.tryParse(
          (profile?['id'] ?? profile?['user_id'] ?? widget.userId ?? '')
              .toString(),
        ) ??
        0;
    final isOwner = widget.userId == null ||
        widget.userId == context.read<AuthProvider>().user?.id;

    // ignore: avoid_print
    print("📦 _buildProductsSection: profileId=$profileId, isOwner=$isOwner");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (profileId > 0)
          _buildShortVideosSection(provider, isOwner, profileId, isDark),
        Row(
          children: [
            Container(width: 4, height: 20, color: colorScheme.primary),
            const SizedBox(width: 10),
            Text("Products & Services",
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: onSurface)),
          ],
        ),
        const SizedBox(height: 20),
        if (products.isEmpty)
          GlassBox(
            borderRadius: 20,
            opacity: isDark ? 0.05 : 0.03,
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: 1,
            ),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  Icon(Icons.inventory_2_outlined,
                      color: Colors.grey[600], size: 40),
                  const SizedBox(height: 12),
                  Text("No products listed yet.",
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          )
        else
          ...products.map((p) {
            final List links = p['product_link'] ?? [];
            final rawTitle =
                (p['title'] ?? p['product_name'] ?? 'Product').toString();
            final title = rawTitle == rawTitle.toLowerCase()
                ? rawTitle
                    .split(' ')
                    .map((word) => word.isNotEmpty
                        ? word[0].toUpperCase() + word.substring(1)
                        : '')
                    .join(' ')
                : rawTitle;
            final rawPrice =
                (p['price'] ?? p['product_price'] ?? '0').toString();
            final price = _formatPrice(rawPrice);
            final desc = p['description'] ?? '';
            final imageUrl = _pImg(p);

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.3)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? colorScheme.primary.withValues(alpha: 0.15)
                        : colorScheme.outlineVariant.withValues(alpha: 0.4),
                    width: 1,
                  ),
                  boxShadow: isDark
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => _openFullScreenImage(imageUrl),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(19)),
                        child: AppNetworkImage(
                          imageUrl: imageUrl,
                          width: double.infinity,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Price (on the left)
                          Text(
                            "₹$price",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              color: colorScheme.primary,
                            ),
                          ),
                          if (desc.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? colorScheme.primary
                                        .withValues(alpha: 0.06)
                                    : colorScheme.primary
                                        .withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colorScheme.primary
                                      .withValues(alpha: 0.08),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                desc,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: isDark
                                      ? onSurface.withValues(alpha: 0.8)
                                      : onSurface.withValues(alpha: 0.7),
                                  height: 1.55,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                          ],
                          if (links.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: links.map<Widget>((link) {
                                final lTitle =
                                    (link['title'] ?? 'Link').toString();
                                final lUrl = (link['links'] ?? '').toString();
                                return AppButton(
                                    label: lTitle,
                                    onPressed: () => _launchURL(lUrl));
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  String _formatPrice(String priceStr) {
    try {
      final cleanStr = priceStr.replaceAll(RegExp(r'[^\d.]'), '');
      if (cleanStr.isEmpty) return priceStr;
      final value = double.parse(cleanStr);
      final isWhole = value == value.toInt();
      final numberToFormat =
          isWhole ? value.toInt().toString() : value.toStringAsFixed(2);
      final parts = numberToFormat.split('.');
      final wholePart = parts[0];
      final decimalPart = parts.length > 1 ? '.' + parts[1] : '';
      if (wholePart.length <= 3) {
        return wholePart + decimalPart;
      }
      final lastThree = wholePart.substring(wholePart.length - 3);
      final other = wholePart.substring(0, wholePart.length - 3);
      final List<String> chunks = [];
      int i = other.length;
      while (i > 0) {
        if (i >= 2) {
          chunks.add(other.substring(i - 2, i));
          i -= 2;
        } else {
          chunks.add(other.substring(0, i));
          i = 0;
        }
      }
      final otherFormatted = chunks.reversed.join(',');
      return '$otherFormatted,$lastThree$decimalPart';
    } catch (_) {
      return priceStr;
    }
  }

  String? _pImg(Map<String, dynamic> p) {
    // Robust image check
    final img = p['product_image'];
    String? path;
    if (img != null) {
      if (img is List && img.isNotEmpty) {
        path =
            img[0]['product_images']?.toString() ?? img[0]['image']?.toString();
      } else if (img is String) {
        path = img;
      }
    }
    path ??= p['image']?.toString() ?? p['img']?.toString();
    return AppConfig.getFullUrl(path);
  }

  Widget _buildReviewsSection(
      ProfileProvider provider, bool isOwner, bool isDark) {
    final theme = Theme.of(context);
    final onSurface = isDark ? Colors.white : Colors.black;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 4, height: 20, color: Colors.amber),
            const SizedBox(width: 10),
            Text("Reviews",
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: onSurface)),
          ],
        ),
        const SizedBox(height: 20),
        if (provider.reviews.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text("Be the first to review!",
                  style: TextStyle(
                      color: Colors.grey[600], fontStyle: FontStyle.italic)),
            ),
          )
        else
          ...provider.reviews.map((r) => Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.03)
                      : Colors.black.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blueAccent.withOpacity(0.1),
                      radius: 20,
                      child: Text(_getReviewerName(r)[0].toUpperCase(),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_getReviewerName(r),
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: onSurface,
                                      fontSize: 15)),
                              Row(
                                  children: List.generate(
                                      5,
                                      (i) => Icon(Icons.star,
                                          size: 14,
                                          color: i < (r['rating'] ?? 0)
                                              ? Colors.amber
                                              : Colors.grey[800]))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(r['message'] ?? '',
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[700],
                                  height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        if (!isOwner) ...[
          const Divider(height: 80, thickness: 1),
          Text("How was your experience?",
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: onSurface)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
                5,
                (i) => IconButton(
                      onPressed: () => setState(() => _selectedRating = i + 1),
                      icon: Icon(
                          _selectedRating > i ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 32),
                    )),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reviewController,
            style: TextStyle(color: onSurface),
            decoration: InputDecoration(
              hintText: "Your feedback helps others...",
              hintStyle: TextStyle(color: Colors.grey[600]),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.03),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(16),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isSubmittingReview ? null : _submitReview,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            child: _isSubmittingReview
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 3, color: Colors.white))
                : const Text("Post Review",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ],
    );
  }

  Future<void> _saveToContacts(
      String name, String phone, Map<String, dynamic> profile) async {
    try {
      if (await FlutterContacts.requestPermission()) {
        final contact = Contact()
          ..name.first = name.split(' ').first
          ..name.last = name.contains(' ') ? name.split(' ').last : ''
          ..phones = [Phone(phone)]
          ..emails = [
            if (profile['email'] != null) Email(profile['email'].toString())
          ];

        // Add company info if available
        final business = profile['business_info'];
        if (business is Map && business['company_name'] != null) {
          contact.organizations = [
            Organization(company: business['company_name'].toString())
          ];
        }

        // Add website from links if available
        final links = profile['master_links'];
        if (links is List) {
          final web = links.firstWhere(
              (l) => l['name'].toString().toLowerCase().contains('web'),
              orElse: () => null);
          if (web != null) {
            contact.websites = [Website(web['link'].toString())];
          }
        }

        final result = await FlutterContacts.openExternalInsert(contact);
        if (result != null && mounted) {
          TopAlert.show(context, "Contact saved successfully!");
        }
      } else {
        if (mounted)
          TopAlert.show(context, "Permission denied to save contact",
              isError: true);
      }
    } catch (e) {
      if (mounted)
        TopAlert.show(context, "Failed to save contact: $e", isError: true);
    }
  }

  Widget _buildCustomActionButtons(ProfileProvider provider, bool isDark) {
    final customButtons = provider.masterLinks
        .where((l) => l['name']?.toString().startsWith('btn:') ?? false)
        .toList();

    if (customButtons.isEmpty) return const SizedBox.shrink();

    return Column(
      children: customButtons.map((btn) {
        final rawName = btn['name']?.toString() ?? '';
        final label = rawName.replaceFirst('btn:', '');
        final url = btn['link']?.toString() ?? '';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppButton(
            label: label,
            onPressed: () => _launchURL(url),
            variant: AppButtonVariant.filled,
            // You can also add an icon if you want, e.g. Icons.ads_click
          ),
        );
      }).toList(),
    );
  }

  Future<void> _submitReview() async {
    if (_selectedRating == 0) {
      TopAlert.show(context, "Share your rating stars first!", isError: true);
      return;
    }
    setState(() => _isSubmittingReview = true);

    // 🔥 Ensure we use the profile-owner's ID if we are viewing someone else
    final targetId = widget.userId;
    if (targetId == null) {
      setState(() => _isSubmittingReview = false);
      return;
    }

    final error = await context.read<ProfileProvider>().submitReview(
          profileId: targetId,
          rating: _selectedRating,
          message: _reviewController.text.trim(),
        );

    setState(() => _isSubmittingReview = false);
    if (error == null) {
      _reviewController.clear();
      _selectedRating = 0;
      TopAlert.show(context, "Review posted successfully!");
    } else {
      TopAlert.show(context, error, isError: true);
    }
  }

  FaIconData _getIconForName(String name) {
    final key = name.toLowerCase();
    if (key.contains("whatsapp")) return FontAwesomeIcons.whatsapp;
    if (key.contains("justdial")) return FontAwesomeIcons.magnifyingGlass;
    if (key.contains("indiamart")) return FontAwesomeIcons.store;
    if (key.contains("telegram")) return FontAwesomeIcons.telegram;
    if (key.contains("instagram")) return FontAwesomeIcons.instagram;
    if (key.contains("linkedin")) return FontAwesomeIcons.linkedinIn;
    if (key.contains("facebook")) return FontAwesomeIcons.facebookF;
    if (key.contains("youtube")) return FontAwesomeIcons.youtube;
    if (key.contains("twitter") || key.contains("x"))
      return FontAwesomeIcons.xTwitter;
    if (key.contains("email") || key.contains("gmail"))
      return FontAwesomeIcons.envelope;
    if (key.contains("web") || key.contains("site"))
      return FontAwesomeIcons.globe;
    if (key.contains("store") || key.contains("shop"))
      return FontAwesomeIcons.bagShopping;
    if (key.contains("google")) return FontAwesomeIcons.google;
    return FontAwesomeIcons.link;
  }

  Color _getColorForName(String name) {
    final key = name.toLowerCase();
    if (key.contains("whatsapp")) return const Color(0xFF25D366);
    if (key.contains("justdial")) return const Color(0xFF1a73e8);
    if (key.contains("indiamart"))
      return const Color.fromARGB(255, 255, 255, 255);
    if (key.contains("telegram")) return const Color(0xFF0088CC);
    if (key.contains("instagram")) return const Color(0xFFE4405F);
    if (key.contains("linkedin")) return const Color(0xFF0077B5);
    if (key.contains("facebook")) return const Color(0xFF1877F2);
    if (key.contains("youtube")) return const Color(0xFFFF0000);
    if (key.contains("twitter") || key.contains("x")) return Colors.black;
    if (key.contains("email")) return const Color(0xFFEA4335);
    if (key.contains("web")) return const Color(0xFF2196F3);
    if (key.contains("store")) return const Color(0xFFFF9800);
    if (key.contains("google")) return const Color(0xFF4285F4);
    return Colors.blueAccent;
  }

  Widget _buildIconWidget(String name, FaIconData iconData, Color color) {
    final key = name.toLowerCase();

    // Check for custom SVG assets
    if (key.contains("justdial")) {
      return SvgPicture.asset(
        'assets/icons/justdial.svg',
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }
    if (key.contains("indiamart")) {
      return Image.asset(
        'assets/icons/indiamart.png',
        fit: BoxFit.cover,
      );
    }

    // Default to FontAwesome or Material Icon
    // FaIcon handles FontAwesomeIcons specifically
    if (iconData.fontFamily?.contains('FontAwesome') ?? false) {
      return FaIcon(iconData, color: color, size: 26);
    }
    return FaIcon(iconData, color: color, size: 26);
  }

  /// Robustly extract reviewer name from various possible API structures
  String _getReviewerName(dynamic r) {
    if (r is! Map) return 'Guest';

    // Helper: treat null, empty, and 'NONE' as invalid
    bool isValid(String? s) =>
        s != null && s.isNotEmpty && s.toUpperCase() != 'NONE';

    // Check nested from_user object first (API uses from_user)
    final fromUser = r['from_user'];
    if (fromUser is Map) {
      final name =
          fromUser['fname']?.toString() ?? fromUser['name']?.toString();
      if (isValid(name)) return name!;
    }

    // Check nested user object
    final user = r['user'];
    if (user is Map) {
      final name = user['fname']?.toString() ?? user['name']?.toString();
      if (isValid(name)) return name!;
    }

    // Check reviewer object
    final reviewer = r['reviewer'];
    if (reviewer is Map) {
      final name =
          reviewer['fname']?.toString() ?? reviewer['name']?.toString();
      if (isValid(name)) return name!;
    }

    // Check flat keys: reviewer_name first (confirmed in API)
    final reviewerName = r['reviewer_name']?.toString();
    if (isValid(reviewerName)) return reviewerName!;

    final directName = r['fname']?.toString() ??
        r['name']?.toString() ??
        r['review_by']?.toString();
    if (isValid(directName)) return directName!;

    return 'Guest';
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required Color onSurface,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickContactItem({
    required FaIconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: FaIcon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard({
    required String image,
    required String title,
    required String price,
    required String location,
  }) {
    return Container(
      width: 145,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.network(
              image,
              height: 90,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.black),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  price,
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  location,
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String boldText,
    required String normalText,
    required String time,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconBgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.black, fontSize: 13),
                  children: [
                    TextSpan(
                        text: boldText,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: normalText),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                time,
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileCoverMedia extends StatefulWidget {
  final String? imageUrl;
  final String? videoUrl;
  final bool isPro;

  const _ProfileCoverMedia({
    required this.imageUrl,
    required this.videoUrl,
    required this.isPro,
  });

  @override
  State<_ProfileCoverMedia> createState() => _ProfileCoverMediaState();
}

class _ProfileCoverMediaState extends State<_ProfileCoverMedia> {
  VideoPlayerController? _controller;
  bool _isReady = false;
  bool _visible = false;
  bool _initStarted = false;

  @override
  void initState() {
    super.initState();
    _initVideoIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _ProfileCoverMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.videoUrl ?? '') != (widget.videoUrl ?? '')) {
      _controller?.dispose();
      _controller = null;
      _isReady = false;
      _initStarted = false;
      _initVideoIfNeeded();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initVideoIfNeeded() async {
    final raw = (widget.videoUrl ?? '').trim();
    if (raw.isEmpty || _initStarted) return;
    _initStarted = true;
    try {
      final resolved = AppConfig.getFullUrl(raw);
      if (resolved == null) return;
      _controller = VideoPlayerController.networkUrl(
        Uri.parse('$resolved?t=${DateTime.now().millisecondsSinceEpoch}'),
      );
      await _controller!.initialize();
      await _controller!.setLooping(true);
      await _controller!.setVolume(0);
      if (!mounted) return;
      setState(() => _isReady = true);
      if (_visible) _controller?.play();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: const Key('profile-page-cover-media'),
      onVisibilityChanged: (info) {
        _visible = info.visibleFraction > 0.45;
        if (_visible) {
          if (_isReady &&
              _controller != null &&
              !_controller!.value.isPlaying) {
            _controller!.play();
          } else {
            _initVideoIfNeeded();
          }
        } else if (_controller != null && _controller!.value.isPlaying) {
          _controller!.pause();
        }
      },
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(30),
        ),
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            AppNetworkImage(
              imageUrl: widget.imageUrl,
              fit: BoxFit.cover,
            ),
            if (_isReady && _controller != null)
              ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              ),
            if (widget.isPro)
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0x26FFD54F),
                        const Color(0x08FFD54F),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
