import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/profile_provider.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:gridcard/features/profile/edit_profile_page.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfilePage extends StatefulWidget {
  final Map<String, dynamic>? userDetails;
  final int? userId;
  final int? viewerUserId;
  final String? fromConnectionTab; // 'pending', 'sent', or null
  final bool isConnected; // true if viewer is already connected

  const ProfilePage({
    super.key,
    this.userDetails,
    this.userId,
    this.viewerUserId,
    this.fromConnectionTab,
    this.isConnected = false,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ImagePicker _picker = ImagePicker();

  static const String _baseUrl = AppConfig.apiBaseUrl;
  static const String _imgBaseUrl = AppConfig.apiProfileImg;

  // ================= PROFILE VIEW TRACKING =================
  DateTime? _profileOpenTime;
  bool _viewStarted = false;

  // ================= USER DETAILS =================
  Map<String, dynamic>? _userDetails;

  // ================= MASTER LINKS =================
  bool _isLoadingMasterLinks = false;
  List<Map<String, dynamic>> _masterLinks = [];

  // ================= MESSAGE SECTION =================
  File? _selectedImage;
  final TextEditingController _messageController = TextEditingController();

  // ================= RATINGS SECTION =================
  int _selectedRating = 0;
  final TextEditingController _feedbackController = TextEditingController();

  // ================= REVIEWS SECTION =================
  List _reviews = [];
  bool _isLoadingReviews = false;

  // ================= AVG RATING SECTION =================
  double _avgRating = 0.0;
  int _totalReviews = 0;
  bool _isLoadingAvgRating = false;

  // ================= HEADERS =================
  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _trackProfileLinkClick(String platform) async {
    try {
      final viewerId =
          widget.viewerUserId ?? await UserStorageService().getUserId();
      final profileId = widget.userId ?? await UserStorageService().getUserId();

      if (viewerId == null || profileId == null) return;
      if (viewerId == profileId) return;

      final url = Uri.parse("$_baseUrl/profile-link/click");

      final res = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          "viewer_id": viewerId,
          "profile_id": profileId,
          "platform": platform,
        }),
      );

      debugPrint("🟠 LINK CLICK API: ${res.statusCode} => ${res.body}");
    } catch (e) {
      debugPrint("🔴 ERROR _trackProfileLinkClick(): $e");
    }
  }

  // ================= MASTER LINKS API =================
  Future<void> _fetchMasterLinks() async {
    if (_isLoadingMasterLinks) return;

    setState(() => _isLoadingMasterLinks = true);

    try {
      final url = Uri.parse("$_baseUrl/user/${widget.userId}/master-links");

      final res = await http.get(url);

      debugPrint("🟦 MASTER LINKS API: ${res.statusCode} => ${res.body}");

      final decoded = jsonDecode(res.body);

      if (res.statusCode == 200 && decoded["status"] == true) {
        final List data = decoded["data"] ?? [];

        final links = data
            .map((e) => Map<String, dynamic>.from(e))
            .where((e) => (e["name"] != null &&
                e["link"] != null &&
                e["name"].toString().trim().isNotEmpty &&
                e["link"].toString().trim().isNotEmpty))
            .toList();

        if (mounted) {
          setState(() {
            _masterLinks = links;
          });
        }
      } else {
        if (mounted) {
          setState(() => _masterLinks = []);
        }
      }
    } catch (e) {
      debugPrint("🔴 ERROR _fetchMasterLinks(): $e");
      if (mounted) setState(() => _masterLinks = []);
    } finally {
      if (mounted) setState(() => _isLoadingMasterLinks = false);
    }
  }

  // ================= PROFILE VIEW START =================
  Future<void> _startProfileView() async {
    try {
      final viewerId =
          widget.viewerUserId ?? await UserStorageService().getUserId();
      final profileId = widget.userId ?? await UserStorageService().getUserId();

      if (viewerId == null || profileId == null) return;

      // self view ignore
      if (viewerId == profileId) return;

      final url = Uri.parse("$_baseUrl/profile-view/start");

      final res = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          "viewer_user_id": viewerId,
          "profile_user_id": profileId,
        }),
      );

      debugPrint("🟢 START VIEW API: ${res.statusCode} => ${res.body}");

      _profileOpenTime = DateTime.now();
      _viewStarted = true;
    } catch (e) {
      debugPrint("🔴 ERROR _startProfileView(): $e");
    }
  }

  // ================= PROFILE VIEW END =================
  Future<void> _endProfileView() async {
    try {
      if (!_viewStarted || _profileOpenTime == null) return;

      final viewerId =
          widget.viewerUserId ?? await UserStorageService().getUserId();
      final profileId = widget.userId ?? await UserStorageService().getUserId();

      if (viewerId == null || profileId == null) return;
      if (viewerId == profileId) return;

      final durationSeconds =
          DateTime.now().difference(_profileOpenTime!).inSeconds;

      // ignore < 1 sec
      if (durationSeconds < 1) return;

      final url = Uri.parse("$_baseUrl/profile-view/end");

      final res = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          "viewer_user_id": viewerId,
          "profile_user_id": profileId,
          "duration_seconds": durationSeconds,
        }),
      );

      debugPrint("🟣 END VIEW API: ${res.statusCode} => ${res.body}");
    } catch (e) {
      debugPrint("🔴 ERROR _endProfileView(): $e");
    }
  }

  // ================= USER DETAILS =================
  Future<void> _fetchUserDetails() async {
    try {
      final int? targetUserId =
          widget.userId ?? await UserStorageService().getUserId();

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

  // ================= AVG RATING =================
  Future<void> _fetchAverageRating() async {
    if (_isLoadingAvgRating) return;

    setState(() => _isLoadingAvgRating = true);

    try {
      final headers = await _getHeaders();

      final int? targetUserId =
          widget.userId ?? await UserStorageService().getUserId();

      if (targetUserId == null) return;

      final url = Uri.parse("$_baseUrl/user-reviews/$targetUserId/average");

      final res = await http.get(url, headers: headers);
      final jsonData = jsonDecode(res.body);

      if (res.statusCode == 200 && jsonData["status"] == true) {
        final data = jsonData["data"] ?? {};

        if (mounted) {
          setState(() {
            _avgRating =
                double.tryParse(data["average_rating"].toString()) ?? 0.0;
            _totalReviews = int.tryParse(data["total_reviews"].toString()) ?? 0;
          });
        }
      }
    } catch (e) {
      debugPrint("🔴 ERROR _fetchAverageRating(): $e");
    } finally {
      if (mounted) setState(() => _isLoadingAvgRating = false);
    }
  }

  // ================= REVIEWS =================
  Future<void> _fetchReviews() async {
    if (_isLoadingReviews) return;

    setState(() => _isLoadingReviews = true);

    try {
      final headers = await _getHeaders();

      final int? targetUserId =
          widget.userId ?? await UserStorageService().getUserId();

      if (targetUserId == null) return;

      final url = Uri.parse("$_baseUrl/user-reviews/$targetUserId");

      final res = await http.get(url, headers: headers);
      final jsonData = jsonDecode(res.body);

      if (res.statusCode == 200 && jsonData["status"] == true) {
        final dataObj = jsonData["data"];

        if (dataObj != null && dataObj["data"] != null) {
          _reviews = dataObj["data"] as List;
        } else {
          _reviews = [];
        }
      } else {
        _reviews = [];
      }
    } catch (e) {
      _reviews = [];
    } finally {
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }

  // ================= LIFECYCLE =================
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _startProfileView();

      await _fetchMasterLinks();
      await _fetchUserDetails();

      // existing provider call (as it is)
      context.read<ProfileProvider>().fetchAllProfileData();

      // existing reviews/rating
      _fetchReviews();
      _fetchAverageRating();
      debugPrint("🟢 USER DETAILS JSON 121: ${jsonEncode(_userDetails)}");
    });
  }

  @override
  void dispose() {
    _endProfileView();
    _messageController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  // ================== UTILS ==================
  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  String _getFullName() {
    final apiMasterUser = _userDetails?['master_user'];
    final fname = apiMasterUser?['fname']?.toString() ?? '';
    final lname = apiMasterUser?['lname']?.toString() ?? '';

    if (fname.isNotEmpty && lname.isNotEmpty) return "$fname $lname";
    if (fname.isNotEmpty) return fname;

    return "";
  }

  Future<String?> _sendConnectionRequest(int receiverId) async {
    final url = Uri.parse("$_baseUrl/connection-create");

    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          "receiver_id": receiverId,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return null; // success
      }

      if (response.statusCode == 422) {
        if (data['errors'] != null && data['errors']['receiver_id'] != null) {
          return data['errors']['receiver_id'][0];
        }
        return data['message'] ?? "Validation error";
      }

      return data['message'] ?? "Something went wrong";
    } catch (e) {
      return "Server error, please try again";
    }
  }

  // ================== SOCIAL ICONS HELPERS ==================
  IconData? _getIconForName(String name) {
    final key = name.trim().toLowerCase();

    switch (key) {
      case "facebook":
        return FontAwesomeIcons.facebookF;
      case "instagram":
        return FontAwesomeIcons.instagram;
      case "twitter":
      case "x":
        return FontAwesomeIcons.twitter;
      case "linkedin":
        return FontAwesomeIcons.linkedinIn;
      case "youtube":
        return FontAwesomeIcons.youtube;
      case "whatsapp":
        return FontAwesomeIcons.whatsapp;
      case "telegram":
        return FontAwesomeIcons.telegram;
      case "snapchat":
        return FontAwesomeIcons.snapchat;
      default:
        return null;
    }
  }

  Color _getColorForName(String name) {
    final key = name.trim().toLowerCase();

    switch (key) {
      case "facebook":
        return const Color(0xFF1877F2);
      case "instagram":
        return const Color(0xFFE4405F);
      case "twitter":
      case "x":
        return const Color(0xFF1DA1F2);
      case "linkedin":
        return const Color(0xFF0A66C2);
      case "youtube":
        return const Color(0xFFFF0000);
      case "whatsapp":
        return const Color(0xFF25D366);
      case "telegram":
        return const Color(0xFF0088CC);
      case "snapchat":
        return const Color(0xFFFFFC00);
      default:
        return Colors.grey;
    }
  }

  Future<void> _openLink(String url, {required String platform}) async {
    try {
      final fixed = url.trim();
      if (fixed.isEmpty) return;

      // ✅ track click first
      await _trackProfileLinkClick(platform);

      final uri = Uri.parse(fixed);

      final canOpen = await canLaunchUrl(uri);

      if (!canOpen) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Cannot open link: $fixed")),
        );
        return;
      }

      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid link")),
      );
    }
  }

  Widget _socialIconClickable(
      IconData icon, Color color, String link, String name) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        if (link.trim().isEmpty) return;
        _openLink(link, platform: name.toLowerCase());
      },
      child: Builder(
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: cs.outlineVariant,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withOpacity(0.15),
                  child: FaIcon(
                    icon,
                    size: 16,
                    color: color,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.open_in_new,
                  size: 16,
                  color: cs.onSurfaceVariant,
                )
              ],
            ),
          );
        },
      ),
    );
  }

  // ✅ MAIN DYNAMIC GRID

  Widget _buildSocialIconsGrid() {
    if (_isLoadingMasterLinks) return const SizedBox.shrink();
    if (_masterLinks.isEmpty) return const SizedBox.shrink();

    final supportedLinks = _masterLinks.where((item) {
      final name = (item["name"] ?? "").toString();
      return _getIconForName(name) != null;
    }).toList();

    if (supportedLinks.isEmpty) return const SizedBox.shrink();

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1,
      children: supportedLinks.map((item) {
        final name = (item["name"] ?? "").toString();
        final link = (item["link"] ?? "").toString();

        final icon = _getIconForName(name)!;
        final color = _getColorForName(name);

        return _socialIconOnly(icon, color, link, name);
      }).toList(),
    );
  }

  Widget _socialIconOnly(IconData icon, Color color, String link, String name) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: () {
        if (link.trim().isEmpty) return;
        _openLink(link, platform: name.toLowerCase());
      },
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Center(
          child: FaIcon(
            icon,
            size: 28,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ================= MESSAGE METHODS =================
  Future<void> _pickImageForMessage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  void _sendMessage() {
    if (_messageController.text.isNotEmpty || _selectedImage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message sent!')),
      );

      setState(() {
        _messageController.clear();
        _selectedImage = null;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Type a message or select an image')),
      );
    }
  }

  // ================= RATINGS METHODS =================
  Widget _averageStarsRow(double rating) {
    final double safeRating = rating.clamp(0.0, 5.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;

        IconData icon;

        if (safeRating >= starValue) {
          icon = Icons.star;
        } else if (safeRating >= starValue - 0.5) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }

        return Icon(
          icon,
          size: 16,
          color: Colors.amber,
        );
      }),
    );
  }

  Future<void> _submitRating() async {
    try {
      final int? toUserId = widget.userId;
      final int? fromUserId =
          widget.viewerUserId ?? await UserStorageService().getUserId();

      if (toUserId == null || fromUserId == null) return;

      // self rating block
      if (toUserId == fromUserId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You can't rate yourself")),
        );
        return;
      }

      // ⭐ rating mandatory
      if (_selectedRating == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select rating")),
        );
        return;
      }

      final message = _feedbackController.text.trim();

      // message optional (but you can make mandatory if you want)
      // if (message.isEmpty) { ... }

      final url = Uri.parse("$_baseUrl/user-reviews");

      final res = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          "to_user_id": toUserId,
          "rating": _selectedRating,
          "message": message,
        }),
      );

      final jsonData = jsonDecode(res.body);

      debugPrint("🟦 REVIEW POST: ${res.statusCode} => ${res.body}");

      if (res.statusCode == 200 && jsonData["status"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(jsonData["message"] ?? "Review added")),
        );

        // reset fields
        setState(() {
          _selectedRating = 0;
          _feedbackController.clear();
        });

        // refresh reviews + avg rating
        await _fetchReviews();
        await _fetchAverageRating();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(jsonData["message"] ?? "Failed")),
        );
      }
    } catch (e) {
      debugPrint("🔴 ERROR _submitRating(): $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Network error")),
      );
    }
  }

  Widget _buildRatingsSection() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your ratings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _isLoadingAvgRating
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _averageStarsRow(_avgRating),
                          const SizedBox(height: 4),
                          Text(
                            '(${_avgRating.toStringAsFixed(1)}) $_totalReviews people',
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Rate your experience working with ${_getFullName()}',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < _selectedRating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 32,
                ),
                onPressed: () {
                  setState(() {
                    _selectedRating = index + 1;
                  });
                },
              );
            }),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _feedbackController,
            style: TextStyle(color: cs.onSurface),
            decoration: InputDecoration(
              hintText: 'Feedback',
              hintStyle: TextStyle(color: cs.onSurfaceVariant),
              filled: true,
              fillColor: cs.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitRating,
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Submit Rating',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

// ================= REVIEW CARD (LIGHT THEME) =================

  Widget _reviewCardHorizontal({
    required String username,
    required int rating,
    required String message,
    required String createdAt,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 240,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: cs.outlineVariant,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: cs.primaryContainer,
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : "U",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  username,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _starsRow(rating, isLight: true),
          const SizedBox(height: 6),
          Text(
            message.isNotEmpty ? message : "No message",
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 12,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            createdAt.isNotEmpty ? createdAt.split("T").first : "",
            style: TextStyle(
              color: cs.onSurfaceVariant.withOpacity(0.7),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ================= STAR ROW =================

  // ================= STAR ROW (with light/dark support) =================
  Widget _starsRow(int rating, {bool isLight = false}) {
    int safeRating = rating.clamp(0, 5);
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          Icons.star,
          size: 16,
          color: index < safeRating
              ? Colors.amber
              : isLight
                  ? Colors.grey.shade300
                  : Colors.grey.shade600,
        );
      }),
    );
  }

  // ================= EMPTY REVIEWS =================
  Widget _buildEmptyReviews() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Icon(Icons.rate_review, size: 40, color: cs.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              "No reviews yet",
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  // ================= NEW: ACCEPT PENDING REQUEST =================
  Future<void> _acceptPendingRequest() async {
    if (widget.userId == null || widget.viewerUserId == null) return;
    try {
      final url = Uri.parse("$_baseUrl/connection-request/update-status");
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          "sender_id": widget.userId,
          "receiver_id": widget.viewerUserId,
          "status": 2, // accepted
        }),
      );
      final jsonData = jsonDecode(response.body);
      if (response.statusCode == 200 && jsonData['status'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(jsonData['message'] ?? 'Accepted')),
        );
        Navigator.pop(context); // go back to connections page
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(jsonData['message'] ?? 'Failed')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error')),
      );
    }
  }

  // ================= EMPTY REVIEWS (LIGHT) =================
  Widget _buildEmptyReviewsLight() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Icon(Icons.rate_review, size: 40, color: cs.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              "No reviews yet",
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
  // ================= NEW: REMOVE SENT REQUEST =================

  Future<void> _removeSentRequest() async {
    if (widget.userId == null || widget.viewerUserId == null) return;
    try {
      final url = Uri.parse("$_baseUrl/connection-request/delete");
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          "sender_id": widget.viewerUserId,
          "receiver_id": widget.userId,
          "status": 1, // pending request
        }),
      );
      final jsonData = jsonDecode(response.body);
      if (response.statusCode == 200 && jsonData['status'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(jsonData['message'] ?? 'Removed')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(jsonData['message'] ?? 'Failed')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error')),
      );
    }
  }

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final profile = profileProvider.profileData;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ✅ VIEWER MODE CHECK
    final bool isViewerMode = widget.viewerUserId != null &&
        widget.userId != null &&
        widget.viewerUserId != widget.userId;

    final apiMasterUser = _userDetails?['master_user'];

    final String fullName = _getFullName();
    final String address = apiMasterUser?['address']?.toString() ?? "-";
    final String phone = apiMasterUser?['mobile']?.toString() ?? "9406037478";

    final String? apiProfilePic = apiMasterUser?['profile_pic'];

    final String? apiProfileLogo = apiMasterUser?['profile_logo'];

    final String? apiProfilePicUrl =
        (apiProfilePic != null && apiProfilePic.toString().isNotEmpty)
            ? "$_imgBaseUrl/$apiProfilePic"
            : null;

    final String? apiProfileLogoUrl =
        (apiProfileLogo != null && apiProfileLogo.toString().isNotEmpty)
            ? "$_imgBaseUrl/$apiProfileLogo"
            : null;

    // ✅ Move screenHeight here, outside of children list
    final double screenHeight = MediaQuery.of(context).size.height;

    debugPrint("🟦 FINAL PROFILE PIC URL = $apiProfilePicUrl");
    debugPrint("🟦 FINAL PROFILE Logo URL = $apiProfileLogoUrl");

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: profileProvider.isLoading && profile == null && _userDetails == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              // padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ================= PROFILE INFO CARD (UPDATED) =================

                  SizedBox(
                    width: double.infinity,
                    height: MediaQuery.of(context).size.height * 0.75,
                    child: Stack(
                      children: [
                        /// FULL WIDTH PROFILE COVER IMAGE
                        Positioned.fill(
                          child: (apiProfilePicUrl != null &&
                                  apiProfilePicUrl.isNotEmpty)
                              ? Image.network(
                                  apiProfilePicUrl,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: colorScheme.surfaceContainerHighest,
                                  child: Icon(
                                    Icons.person,
                                    size: 80,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                        ),

                        /// DARK GRADIENT OVERLAY
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.6),
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.7),
                                ],
                              ),
                            ),
                          ),
                        ),

                        /// BACK BUTTON
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 12,
                          left: 16,
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Icon(
                              Icons.arrow_back_ios,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),

                        /// EDIT BUTTON (ONLY OWNER)
                        if (!isViewerMode)
                          Positioned(
                            top: MediaQuery.of(context).padding.top + 12,
                            right: 16,
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditProfilePage(
                                        userDetails: _userDetails),
                                  ),
                                );
                              },
                              child: const Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),

                        /// PROFILE INFO BOTTOM CENTER
                        Positioned(
                          bottom: 24,
                          left: 16,
                          right: 16,
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundColor:
                                    colorScheme.surfaceContainerHighest,
                                backgroundImage: apiProfileLogoUrl != null
                                    ? NetworkImage(apiProfileLogoUrl)
                                    : null,
                                child: apiProfileLogoUrl == null
                                    ? const Icon(Icons.person,
                                        size: 42, color: Colors.white)
                                    : null,
                              ),

                              const SizedBox(height: 14),

                              /// FULL NAME
                              Text(
                                _capitalize(fullName),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),

                              const SizedBox(height: 6),

                              /// BUSINESS NAME
                              Text(
                                _userDetails?['business_info']?['legal_name'] ??
                                    "",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white70,
                                ),
                              ),

                              const SizedBox(height: 4),

                              /// INDUSTRY
                              Text(
                                _userDetails?['business_info']?['industry']
                                        ?['title'] ??
                                    "",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  /// ================= ACTION BUTTON (VIEWER ONLY, NOT CONNECTED) ==================
                  if (isViewerMode && !widget.isConnected)
                    Padding(
                      padding:
                          const EdgeInsets.all(16), // ✅ 16 padding applied here
                      child: Column(
                        children: [
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? colorScheme.surfaceContainerHighest
                                  : colorScheme.surface,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: isDark
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        spreadRadius: 1,
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                              border: isDark
                                  ? null
                                  : Border.all(
                                      color: colorScheme.outlineVariant,
                                      width: 1,
                                    ),
                            ),
                            child: ElevatedButton(
                              onPressed: () async {
                                if (widget.fromConnectionTab == 'pending') {
                                  _acceptPendingRequest();
                                } else if (widget.fromConnectionTab == 'sent') {
                                  _removeSentRequest();
                                } else {
                                  if (widget.userId == null) return;

                                  final error = await _sendConnectionRequest(
                                      widget.userId!);

                                  if (error == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text("✅ Connection request sent"),
                                        backgroundColor: Colors.green,
                                      ),
                                    );

                                    Navigator.pop(context, true);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(error),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                widget.fromConnectionTab == 'pending'
                                    ? 'Accept'
                                    : widget.fromConnectionTab == 'sent'
                                        ? 'Remove'
                                        : 'Connect',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ================= REST UI (ONLY FOR SELF OR CONNECTED USERS) =================
                  if (!isViewerMode || widget.isConnected) ...[
                    /// ================= SOCIAL LINKS SECTION ==================
                    if (!_isLoadingMasterLinks && _masterLinks.isNotEmpty)
                      Padding(
                        padding:
                            const EdgeInsets.all(16), // ✅ 16 padding outside
                        child: Column(
                          children: [
                            const SizedBox(height: 16),

                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? colorScheme.surfaceContainerHighest
                                    : colorScheme.surface,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: isDark
                                    ? []
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          spreadRadius: 1,
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                border: isDark
                                    ? null
                                    : Border.all(
                                        color: colorScheme.outlineVariant,
                                        width: 1,
                                      ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  /// SECTION TITLE
                                  Text(
                                    'Social Links',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  /// SOCIAL ICONS GRID
                                  _buildSocialIconsGrid(),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12), // spacing after section
                          ],
                        ),
                      ),

                    if (!_isLoadingMasterLinks && _masterLinks.isNotEmpty)

                      /// ================= HAVE A QUESTION SECTION ==================
                      Padding(
                        padding:
                            const EdgeInsets.all(16), // ✅ 16 padding outside
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? colorScheme.surfaceContainerHighest
                                    : colorScheme.surface,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: isDark
                                    ? []
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          spreadRadius: 1,
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                border: isDark
                                    ? null
                                    : Border.all(
                                        color: colorScheme.outlineVariant,
                                        width: 1,
                                      ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  /// TITLE
                                  Text(
                                    'Have a question?',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  /// NAME
                                  Text(
                                    fullName,
                                    style: TextStyle(
                                      color: colorScheme.onSurface,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),

                                  const SizedBox(height: 4),

                                  /// PHONE
                                  Text(
                                    '+91 $phone',
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                      fontSize: 14,
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  /// MESSAGE FIELD + SEND BUTTON
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _messageController,
                                          style: TextStyle(
                                              color: colorScheme.onSurface),
                                          decoration: InputDecoration(
                                            hintText: 'Message',
                                            hintStyle: TextStyle(
                                                color: colorScheme
                                                    .onSurfaceVariant),
                                            filled: true,
                                            fillColor: colorScheme
                                                .surfaceContainerHighest,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide.none,
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                            suffixIcon: IconButton(
                                              icon: Icon(
                                                Icons.camera_alt,
                                                color: colorScheme.primary,
                                              ),
                                              onPressed: _pickImageForMessage,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: _sendMessage,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: colorScheme.primary,
                                          foregroundColor:
                                              colorScheme.onPrimary,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 14,
                                          ),
                                        ),
                                        child: const Text('Send'),
                                      ),
                                    ],
                                  ),

                                  /// IMAGE PREVIEW
                                  if (_selectedImage != null) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      height: 60,
                                      width: 60,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        image: DecorationImage(
                                          image: FileImage(_selectedImage!),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(height: 12), // spacing after section
                          ],
                        ),
                      ),

                    if (isViewerMode)
                      Padding(
                        padding:
                            const EdgeInsets.all(16), // ✅ 16 padding applied
                        child: Column(
                          children: [
                            _buildRatingsSection(),

                            // const SizedBox(height: 12), // spacing after section
                          ],
                        ),
                      ),

                    /// ================= REVIEWS SECTION ==================
                    Padding(
                      padding: const EdgeInsets.all(16), // ✅ OUTER 16 PADDING
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(
                                16), // ✅ INNER CARD PADDING
                            decoration: BoxDecoration(
                              color: isDark
                                  ? colorScheme.surfaceContainerHighest
                                  : colorScheme.surface,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: isDark
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        spreadRadius: 1,
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                              border: isDark
                                  ? null
                                  : Border.all(
                                      color: colorScheme.outlineVariant,
                                      width: 1,
                                    ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                /// TITLE
                                Text(
                                  'Reviews',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),

                                const SizedBox(height: 12),

                                /// LOADING / EMPTY / LIST
                                _isLoadingReviews
                                    ? const Center(
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                              vertical: 20),
                                          child: CircularProgressIndicator(),
                                        ),
                                      )
                                    : _reviews.isEmpty
                                        ? _buildEmptyReviewsLight()
                                        : SizedBox(
                                            height: 200,
                                            child: ListView.builder(
                                              scrollDirection: Axis.horizontal,
                                              itemCount: _reviews.length,
                                              itemBuilder: (context, index) {
                                                final r = _reviews[index]
                                                    as Map<String, dynamic>;

                                                final fromUser =
                                                    (r["from_user"] ?? {})
                                                        as Map<String, dynamic>;

                                                final username =
                                                    (fromUser["user_name"] ??
                                                            "Unknown User")
                                                        .toString();

                                                final message =
                                                    (r["message"] ?? "")
                                                        .toString();

                                                final rating = int.tryParse(
                                                      r["rating"].toString(),
                                                    ) ??
                                                    0;

                                                final createdAt =
                                                    (r["created_at"] ?? "")
                                                        .toString();

                                                return _reviewCardHorizontal(
                                                  username: username,
                                                  rating: rating,
                                                  message: message,
                                                  createdAt: createdAt,
                                                );
                                              },
                                            ),
                                          ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24), // spacing after section
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
