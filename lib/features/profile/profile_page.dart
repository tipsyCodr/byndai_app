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
    return GestureDetector(
      onTap: () {
        if (link.trim().isEmpty) return;
        _openLink(link, platform: name.toLowerCase());
      },
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: FaIcon(
            icon,
            color:
                icon == FontAwesomeIcons.snapchat ? Colors.black : Colors.white,
            size: 22,
          ),
        ),
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
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      children: supportedLinks.map((item) {
        final name = (item["name"] ?? "").toString();
        final link = (item["link"] ?? "").toString();

        final icon = _getIconForName(name)!;
        final color = _getColorForName(name);

        return _socialIconClickable(icon, color, link, name);
      }).toList(),
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

  // void _submitRating() {
  //   if (_selectedRating == 0) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('Please select a rating')),
  //     );
  //     return;
  //   }

  //   ScaffoldMessenger.of(context).showSnackBar(
  //     const SnackBar(content: Text('Rating submitted!')),
  //   );

  //   setState(() {
  //     _selectedRating = 0;
  //     _feedbackController.clear();
  //   });
  // }

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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your ratings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
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
                              color: Colors.grey.shade300,
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
            style: const TextStyle(
              color: Colors.white,
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
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Feedback',
              hintStyle: TextStyle(color: Colors.grey.shade500),
              filled: true,
              fillColor: Colors.grey.shade800,
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
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Submit Rating',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= REVIEW CARD =================
  Widget _reviewCardHorizontal({
    required String username,
    required int rating,
    required String message,
    required String createdAt,
  }) {
    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.blue.shade200,
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : "U",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _starsRow(rating),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              message.isNotEmpty ? message : "No message",
              style: TextStyle(
                color: Colors.grey.shade300,
                fontSize: 12,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            createdAt.isNotEmpty ? createdAt.split("T").first : "",
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ================= STAR ROW =================
  Widget _starsRow(int rating) {
    int safeRating = rating.clamp(0, 5);
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          Icons.star,
          size: 16,
          color: index < safeRating ? Colors.amber : Colors.grey.shade600,
        );
      }),
    );
  }

  // ================= EMPTY REVIEWS =================
  Widget _buildEmptyReviews() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Icon(Icons.rate_review, size: 40, color: Colors.grey.shade500),
            const SizedBox(height: 8),
            Text(
              "No reviews yet",
              style: TextStyle(color: Colors.grey.shade400),
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

    final String? apiProfilePicUrl =
        (apiProfilePic != null && apiProfilePic.toString().isNotEmpty)
            ? "$_imgBaseUrl/$apiProfilePic"
            : null;

    debugPrint("🟦 FINAL PROFILE PIC URL = $apiProfilePicUrl");

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        centerTitle: true,
        title: Text(
          isViewerMode ? "Profile" : "Your Profile",
          style: TextStyle(color: colorScheme.primary),
        ),
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: colorScheme.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (!isViewerMode)
            IconButton(
              icon: Icon(Icons.edit, color: colorScheme.primary),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        EditProfilePage(userDetails: _userDetails),
                  ),
                );
              },
            ),
        ],
      ),
      body: profileProvider.isLoading && profile == null && _userDetails == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // ================= PROFILE INFO CARD =================
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 22,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _capitalize(fullName),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Grid Club",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade300,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "GRID",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          address,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ================= ACTION BUTTON (VIEWER ONLY, NOT CONNECTED) =================
                  if (isViewerMode && !widget.isConnected) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          if (widget.fromConnectionTab == 'pending') {
                            _acceptPendingRequest();
                          } else if (widget.fromConnectionTab == 'sent') {
                            _removeSentRequest();
                          } else {
                            // default connect
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Connect clicked")),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
                          style: const TextStyle(
                              fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],

                  // ================= REST UI (ONLY FOR SELF OR CONNECTED USERS) =================
                  if (!isViewerMode || widget.isConnected) ...[
                    const SizedBox(height: 16),

                    // SOCIAL ICONS
                    _buildSocialIconsGrid(),

                    if (!_isLoadingMasterLinks && _masterLinks.isNotEmpty)
                      const SizedBox(height: 24),

                    // MESSAGE SECTION
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Have a question?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            fullName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '+91    $phone',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: 'Message',
                                    hintStyle:
                                        TextStyle(color: Colors.grey.shade500),
                                    filled: true,
                                    fillColor: Colors.grey.shade800,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        Icons.camera_alt,
                                        color: Colors.blue.shade300,
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
                                  backgroundColor: Colors.blue,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 14,
                                  ),
                                ),
                                child: const Text(
                                  'Send',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          if (_selectedImage != null) ...[
                            const SizedBox(height: 8),
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

                    const SizedBox(height: 24),

                    // RATINGS
                    // _buildRatingsSection(),

                    if (isViewerMode) ...[
                      _buildRatingsSection(),
                      const SizedBox(height: 24),
                    ],

                    // const SizedBox(height: 24),

                    // REVIEWS
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Reviews',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _isLoadingReviews
                              ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                              : _reviews.isEmpty
                                  ? _buildEmptyReviews()
                                  : SizedBox(
                                      height: 200,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: _reviews.length,
                                        itemBuilder: (context, index) {
                                          final r = _reviews[index]
                                              as Map<String, dynamic>;

                                          final fromUser = (r["from_user"] ??
                                              {}) as Map<String, dynamic>;

                                          final username =
                                              (fromUser["user_name"] ??
                                                      "Unknown User")
                                                  .toString();

                                          final message =
                                              (r["message"] ?? "").toString();

                                          final rating = int.tryParse(
                                                  r["rating"].toString()) ??
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
                  ],
                ],
              ),
            ),
    );
  }
}
