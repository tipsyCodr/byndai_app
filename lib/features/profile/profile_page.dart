import 'dart:convert';
import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
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
import 'package:gridcard/widgets/top_alert.dart';
import 'dart:async';
import 'dart:ui';
import './product_list_widget.dart';

class ProfilePage extends StatefulWidget {
  final Map<String, dynamic>? userDetails;
  final int? userId;
  final int? viewerUserId;
  final String? fromConnectionTab; // 'pending', 'sent', or null
  final bool isConnected; // true if viewer is already connected
  final bool fromSuggestion;

  const ProfilePage({
    super.key,
    this.userDetails,
    this.userId,
    this.viewerUserId,
    this.fromConnectionTab,
    this.isConnected = false,
    this.fromSuggestion = false,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ImagePicker _picker = ImagePicker();

  static const String _baseUrl = AppConfig.apiBaseUrl;
  static const String _imgBaseUrl = AppConfig.apiProfileImg;

  String _requestStatus = "none";
  bool _isCheckingConnection = false;

  bool _isGeneratingAI = false;

  bool _hasGivenReview = false;

  Map<String, dynamic>? _givenReviewData;

  VideoPlayerController? _videoController;
  bool _showVideo = false;
  bool _isVideoInitialized = false;
  Timer? _videoDelayTimer;

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

  // ================= PRODUCTS SECTION =================
  bool _isLoadingProducts = false;
  List _products = [];

  // ================= HEADERS =================
  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Future<void> _initProfileVideo(String videoUrl) async {
  //   try {
  //     // _videoController = VideoPlayerController.network(videoUrl);
  //     _videoController = VideoPlayerController.networkUrl(
  //       Uri.parse("$videoUrl?t=${DateTime.now().millisecondsSinceEpoch}"),
  //     );

  //     await _videoController!.initialize();

  //     _videoController!.setLooping(true);
  //     _videoController!.setVolume(0);

  //     if (mounted) {
  //       setState(() {
  //         _isVideoInitialized = true;
  //       });
  //     }
  //   } catch (e) {
  //     debugPrint("Video init error: $e");
  //   }
  // }

  Future<void> _initProfileVideo(String videoUrl) async {
    try {
      _videoController?.dispose();

      _videoController = VideoPlayerController.networkUrl(
        Uri.parse("$videoUrl?t=${DateTime.now().millisecondsSinceEpoch}"),
      );

      await _videoController!.initialize();

      _videoController!.setLooping(true);
      _videoController!.setVolume(0);

      if (!mounted) return;

      setState(() {
        _isVideoInitialized = true;
      });

      /// 👇 2 second delay before showing video
      _videoDelayTimer?.cancel();
      _videoDelayTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;

        setState(() {
          _showVideo = true;
        });

        _videoController!.play();
      });
    } catch (e) {
      debugPrint("Video init error: $e");
    }
  }

  Future<void> _checkConnectionStatus() async {
    try {
      setState(() => _isCheckingConnection = true);

      final token = await UserStorageService().getToken();

      final res = await http.post(
        Uri.parse("$_baseUrl/connection/status"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "viewerUserId": widget.viewerUserId,
          "profileUserId": widget.userId,
        }),
      );

      final jsonData = jsonDecode(res.body);

      if (res.statusCode == 200) {
        setState(() {
          _requestStatus = jsonData["request_status"] ?? "none";
        });
      }
    } catch (e) {
      debugPrint("connection status error $e");
    } finally {
      setState(() => _isCheckingConnection = false);
    }
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

  // ================= FETCH PRODUCTS =================
  Future<void> _fetchProducts() async {
    try {
      final int? targetUserId =
          widget.userId ?? await UserStorageService().getUserId();
      if (targetUserId == null) {
        debugPrint("🟠 targetUserId is null for _fetchProducts");
        return;
      }

      if (mounted) setState(() => _isLoadingProducts = true);

      final headers = await _getHeaders();
      final url = Uri.parse("$_baseUrl/products-by-user/$targetUserId");

      debugPrint("🟦 PRODUCTS FETCH URL: $url");

      final response = await http.get(url, headers: headers);

      debugPrint("🟦 PRODUCTS API STATUS: ${response.statusCode}");

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        debugPrint("🟦 PRODUCTS JSON: ${jsonEncode(jsonData)}");

        if (jsonData["status"] == true) {
          final dataObject = jsonData["data"];
          // Handle both paginated and direct list responses
          List fetchedProducts = [];
          if (dataObject is Map && dataObject["data"] != null) {
            fetchedProducts = dataObject["data"] as List;
          } else if (dataObject is List) {
            fetchedProducts = dataObject;
          }

          if (mounted) {
            setState(() {
              _products = fetchedProducts;
            });
            debugPrint("🟢 SET STATE PRODUCTS: ${_products.length} items");
          }
        }
      } else {
        debugPrint(
            "🔴 Error fetching products: ${response.statusCode} ${response.body}");
      }
    } catch (e) {
      debugPrint("🔴 EXCEPTION in _fetchProducts(): $e");
    } finally {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  /// Constructs full image URL from relative path
  String _getFullProductImageUrl(Map<String, dynamic> product) {
    try {
      if (product['product_image'] != null &&
          (product['product_image'] as List).isNotEmpty) {
        var imagePath =
            product['product_image'][0]['product_images'] as String?;
        if (imagePath != null && imagePath.isNotEmpty) {
          if (imagePath.startsWith('http')) return imagePath;
          if (imagePath.startsWith('/')) imagePath = imagePath.substring(1);

          String base = _baseUrl;
          if (base.endsWith('/api')) {
            base = base.substring(0, base.length - 4);
          }
          if (base.endsWith('/')) base = base.substring(0, base.length - 1);

          return '$base/$imagePath';
        }
      }
    } catch (e) {
      debugPrint('Error constructing image URL: $e');
    }
    return '';
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

  Widget _buildConnectionButton() {
    if (!widget.fromSuggestion) {
      return _existingButtonWidget(); // 👈 पुराना logic
    }

    if (_isCheckingConnection) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: CircularProgressIndicator(),
      );
    }

    if (_requestStatus == "none") {
      return _connectButton();
    }

    if (_requestStatus == "received") {
      return _acceptButton();
    }

    if (_requestStatus == "sent") {
      return _removeButton();
    }

    return _connectButton();
  }

  Widget _connectButton() {
    return ElevatedButton(
      onPressed: () async {
        if (widget.userId == null) return;

        final error = await _sendConnectionRequest(widget.userId!);

        if (error == null) {
          TopAlert.show(context, "Connection request sent", isSuccess: true);
          _checkConnectionStatus();
        } else {
          TopAlert.show(context, error, isError: true);
        }
      },
      child: const Text("Connect"),
    );
  }

  Widget _acceptButton() {
    return ElevatedButton(
      onPressed: () async {
        await _acceptPendingRequest();
        _checkConnectionStatus();
      },
      child: const Text("Accept"),
    );
  }

  Widget _removeButton() {
    return ElevatedButton(
      onPressed: () async {
        await _removeSentRequest();
        _checkConnectionStatus();
      },
      child: const Text("Remove"),
    );
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _printRatingJson();
      await _startProfileView();
      await _fetchMasterLinks();
      await _fetchUserDetails();

      Future.delayed(const Duration(seconds: 2), () async {
        final video = _userDetails?['master_user']?['profile_video'];

        if (video != null && video.toString().isNotEmpty) {
          String videoUrl = "$_imgBaseUrl/$video";

          await _initProfileVideo(videoUrl);

          if (mounted) {
            // setState(() {
            //   _showVideo = true;
            // });

            // _videoController?.play();
          }
        }
      });

      await _fetchProducts();

      // existing provider call (as it is)
      context.read<ProfileProvider>().fetchAllProfileData();

      // existing reviews/rating
      _fetchReviews();
      _fetchAverageRating();
      debugPrint("🟢 USER DETAILS JSON 121: ${jsonEncode(_userDetails)}");
    });

    if (widget.fromSuggestion) {
      _checkConnectionStatus();
    }
  }

  @override
  void dispose() {
    _endProfileView();
    _messageController.dispose();
    _feedbackController.dispose();

    _videoController?.dispose();
    _videoDelayTimer?.cancel();
    super.dispose();
  }

  // ================== UTILS ==================
  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  int? _parseConnectionStatus(Map<String, dynamic>? connection) {
    if (connection == null) return null;
    return int.tryParse(connection['status']?.toString() ?? '');
  }

  bool _isPendingConnectionStatus(int? status) {
    return status == 0 || status == 1;
  }

  bool _isIncomingPendingRequest(Map<String, dynamic>? connection) {
    final viewerId = widget.viewerUserId;
    if (viewerId == null) return false;

    final status = _parseConnectionStatus(connection);
    final receiverId =
        int.tryParse(connection?['receiver_id']?.toString() ?? '');

    return _isPendingConnectionStatus(status) && receiverId == viewerId;
  }

  bool _isOutgoingPendingRequest(Map<String, dynamic>? connection) {
    final viewerId = widget.viewerUserId;
    if (viewerId == null) return false;

    final status = _parseConnectionStatus(connection);
    final senderId = int.tryParse(connection?['sender_id']?.toString() ?? '');

    return _isPendingConnectionStatus(status) && senderId == viewerId;
  }

  String _getConnectionActionLabel(Map<String, dynamic>? connection) {
    if (widget.fromConnectionTab == 'pending' ||
        _isIncomingPendingRequest(connection)) {
      return 'Accept';
    }
    if (widget.fromConnectionTab == 'sent' ||
        _isOutgoingPendingRequest(connection)) {
      return 'Remove';
    }
    return 'Connect';
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
      String fixed = url.trim();
      if (fixed.isEmpty) return;

      // Ensure URL starts with http:// or https://
      if (!fixed.startsWith('http://') && !fixed.startsWith('https://')) {
        fixed = 'https://$fixed';
      }

      // ✅ track click first
      await _trackProfileLinkClick(platform);

      final uri = Uri.parse(fixed);

      final canOpen = await canLaunchUrl(uri);

      if (!canOpen) {
        if (!mounted) return;
        TopAlert.show(context, "Cannot open link: $fixed", isError: true);
        return;
      }

      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (!mounted) return;
      TopAlert.show(context, "Invalid link", isError: true);
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
                  CupertinoIcons.arrow_up_right_square,
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

  void _sendMessage() async {
    final phone = _userDetails?['master_user']?['mobile_one']?.toString() ?? '';
    final message = _messageController.text.trim();

    // Get logged‑in user's mobile from secure storage
    final session = await UserStorageService().loadSession();
    final loggedInMobile = session.user?.userMobile ?? 'Unknown';

    if (message.isEmpty) {
      TopAlert.show(context, 'Please enter a message', isError: true);
      return;
    }

    // Log to console (as you already see)
    final output = jsonEncode({
      'target_mobile': phone,
      'message': message,
      'logged_in_mobile': loggedInMobile,
    });
    debugPrint('📤 SEND MESSAGE: $output');
    TopAlert.show(context, 'Message logged to console', isSuccess: true);

    // Now open WhatsApp for the target number
    if (phone.isEmpty) {
      TopAlert.show(context, 'No phone number available', isError: true);
      return;
    }

    // Clean phone number: remove spaces/dashes, ensure country code
    String cleanPhone = phone.replaceAll(RegExp(r'[\s\-]'), '');
    if (!cleanPhone.startsWith('+')) {
      // Assume Indian numbers if 10 digits, otherwise just add '+'
      if (cleanPhone.length == 10) {
        cleanPhone = '+91$cleanPhone';
      } else {
        cleanPhone = '+$cleanPhone';
      }
    }

    final encodedMessage = Uri.encodeComponent(message);
    final whatsappUrl =
        'whatsapp://send?phone=$cleanPhone&text=$encodedMessage';
    final webUrl = 'https://wa.me/$cleanPhone?text=$encodedMessage';

    try {
      final uri = Uri.parse(whatsappUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // Fallback to web WhatsApp
        final webUri = Uri.parse(webUrl);
        if (await canLaunchUrl(webUri)) {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
        } else {
          TopAlert.show(context, 'WhatsApp is not installed', isError: true);
        }
      }
    } catch (e) {
      debugPrint('🔴 Error launching WhatsApp: $e');
      TopAlert.show(context, 'Could not open WhatsApp', isError: true);
    }

    // Clear the message field after sending
    _messageController.clear();
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
        TopAlert.show(context, "You can't rate yourself", isError: true);
        return;
      }

      // ⭐ rating mandatory
      if (_selectedRating == 0) {
        TopAlert.show(context, "Please select rating", isError: true);
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
        TopAlert.show(context, jsonData["message"] ?? "Review added",
            isSuccess: true);

        // reset fields
        setState(() {
          _selectedRating = 0;
          _feedbackController.clear();
        });

        // refresh reviews + avg rating
        await _fetchReviews();
        await _fetchAverageRating();
      } else {
        TopAlert.show(context, jsonData["message"] ?? "Failed", isError: true);
      }
    } catch (e) {
      debugPrint("🔴 ERROR _submitRating(): $e");
      TopAlert.show(context, "Network error", isError: true);
    }
  }

  Future<void> _printRatingJson() async {
    try {
      final int? fromUserId =
          widget.viewerUserId ?? await UserStorageService().getUserId();

      final int? toUserId =
          widget.userId ?? await UserStorageService().getUserId();

      if (fromUserId == null || toUserId == null) return;

      final ratingData = {
        "from_user_id": fromUserId,
        "to_user_id": toUserId,
      };

      debugPrint("⭐ RATING DATA JSON: ${jsonEncode(ratingData)}");

      // ✅ CALL API
      await _checkExistingReview(fromUserId, toUserId);
    } catch (e) {
      debugPrint("🔴 ERROR _printRatingJson(): $e");
    }
  }

  Future<void> _checkExistingReview(int fromUserId, int toUserId) async {
    try {
      final url = Uri.parse("$_baseUrl/user-review/find");

      final res = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          "from_user_id": fromUserId,
          "to_user_id": toUserId,
        }),
      );

      debugPrint("🟦 FIND REVIEW API: ${res.body}");

      final jsonData = jsonDecode(res.body);

      if (res.statusCode == 200 && jsonData["status"] == true) {
        if (mounted) {
          setState(() {
            _hasGivenReview = true;
            _givenReviewData = jsonData["data"];
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _hasGivenReview = false;
          });
        }
      }
    } catch (e) {
      debugPrint("🔴 ERROR _checkExistingReview(): $e");
    }
  }

  Widget _buildGivenRatingCard() {
    if (_givenReviewData == null) return const SizedBox();

    final rating = _givenReviewData!["rating"];
    final message = _givenReviewData!["message"];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Your Given Rating",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: List.generate(
                5,
                (index) => Icon(
                  index < rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message ?? "",
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateAIReview() async {
    try {
      if (_selectedRating == 0) return;

      final int? toUserId = widget.userId;
      if (toUserId == null) return;

      setState(() {
        _isGeneratingAI = true;
      });

      final url = Uri.parse("$_baseUrl/reviews/generate");

      final res = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          "to_user_id": toUserId,
          "rating": _selectedRating,
        }),
      );

      final jsonData = jsonDecode(res.body);

      debugPrint("🤖 AI REVIEW RESPONSE: ${res.body}");

      if (res.statusCode == 200 && jsonData["success"] == true) {
        final content = jsonData["content"] ?? "";

        setState(() {
          _feedbackController.text = content;
        });
      } else {
        TopAlert.show(context, "Failed to generate AI review", isError: true);
      }
    } catch (e) {
      debugPrint("🔴 ERROR _generateAIReview(): $e");
      TopAlert.show(context, "Network error", isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingAI = false;
        });
      }
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
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
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
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              // onPressed: () {
              //   final jsonData = {
              //     "to_user_id": widget.userId,
              //     "rating": _selectedRating
              //   };

              //   debugPrint("🤖 GENERATE AI JSON: ${jsonEncode(jsonData)}");

              //   TopAlert.show(context, "AI request printed in console",
              //       isSuccess: true);
              // },
              onPressed: _selectedRating == 0 || _isGeneratingAI
                  ? null
                  : _generateAIReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              // child: const Text(
              //   "Generate AI",
              //   style: TextStyle(fontSize: 16),
              // ),
              child: _isGeneratingAI
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      "Generate AI",
                      style: TextStyle(fontSize: 16),
                    ),
            ),
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
          width: 0.4,
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

  Widget _existingButtonWidget() {
    final connection = _userDetails?['connection'] as Map<String, dynamic>?;

    return ElevatedButton(
      onPressed: () async {
        if (widget.fromConnectionTab == 'pending' ||
            _isIncomingPendingRequest(connection)) {
          _acceptPendingRequest();
        } else if (widget.fromConnectionTab == 'sent' ||
            _isOutgoingPendingRequest(connection)) {
          _removeSentRequest();
        } else {
          if (widget.userId == null) return;

          final error = await _sendConnectionRequest(widget.userId!);

          if (error == null) {
            TopAlert.show(context, "Connection request sent", isSuccess: true);
            _fetchUserDetails();
          } else {
            TopAlert.show(context, error, isError: true);
          }
        }
      },
      child: Text(
        _getConnectionActionLabel(
          _userDetails?['connection'] as Map<String, dynamic>?,
        ),
      ),
    );
  }

  // ================= NEW: ACCEPT PENDING REQUEST =================
  Future<void> _acceptPendingRequest() async {
    final int? senderId = widget.userId;
    final int? receiverId = widget.viewerUserId;

    if (senderId == null || receiverId == null) return;

    try {
      final url = Uri.parse("$_baseUrl/connection-request/update-status");
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          "sender_id": senderId,
          "receiver_id": receiverId,
          "status": 2, // accepted
        }),
      );

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 && jsonData['status'] == true) {
        TopAlert.show(context, jsonData['message'] ?? 'Accepted',
            isSuccess: true);

        // Refresh UI
        await _fetchUserDetails();
      } else {
        TopAlert.show(context, jsonData['message'] ?? 'Failed', isError: true);
      }
    } catch (e) {
      debugPrint("🔴 ERROR _acceptPendingRequest(): $e");
      TopAlert.show(context, 'Network error', isError: true);
    }
  }

  // ================= NEW: REMOVE SENT REQUEST =================
  Future<void> _removeSentRequest() async {
    final int? senderId = widget.viewerUserId;
    final int? receiverId = widget.userId;

    if (senderId == null || receiverId == null) return;

    try {
      final url = Uri.parse("$_baseUrl/connection-request/delete");
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          "sender_id": senderId,
          "receiver_id": receiverId,
          "status": 0, // connection status
        }),
      );

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 && jsonData['status'] == true) {
        TopAlert.show(context, jsonData['message'] ?? 'Removed',
            isSuccess: true);

        // Refresh UI
        await _fetchUserDetails();
      } else {
        TopAlert.show(context, jsonData['message'] ?? 'Failed', isError: true);
      }
    } catch (e) {
      debugPrint("🔴 ERROR _removeSentRequest(): $e");
      TopAlert.show(context, 'Network error', isError: true);
    }
  }

  // ================= NEW: SEND CONNECTION REQUEST =================
  Future<String?> _sendConnectionRequest(int profileId) async {
    try {
      final viewerId =
          widget.viewerUserId ?? await UserStorageService().getUserId();
      if (viewerId == null) return "User not logged in";

      // Consistently use connection-create as per codebase pattern
      final url = Uri.parse("$_baseUrl/connection-create");
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          "receiver_id": profileId,
        }),
      );

      final jsonData = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (jsonData['status'] == true) return null;
        return null; // Some endpoints might not return status true but still 200/201
      } else {
        return jsonData['message'] ?? "Failed to send request";
      }
    } catch (e) {
      debugPrint("🔴 ERROR _sendConnectionRequest(): $e");
      return "Network error";
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

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final profile = profileProvider.profileData;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bool isViewerMode = widget.viewerUserId != null &&
        widget.userId != null &&
        widget.viewerUserId != widget.userId;

    final connectionData = _userDetails?['connection'];
    final int? connectionStatus =
        _parseConnectionStatus(connectionData as Map<String, dynamic>?);

    final bool isAlreadyConnected = widget.isConnected || connectionStatus == 2;

    final apiMasterUser = _userDetails?['master_user'];

    final String fullName = _getFullName();
    final String address = apiMasterUser?['address']?.toString() ?? "-";
    final String phone =
        apiMasterUser?['mobile_one']?.toString() ?? "9406037478";

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

    final String? apiProfileVideo = apiMasterUser?['profile_video'];

    final String? apiProfileVideoUrl =
        (apiProfileVideo != null && apiProfileVideo.toString().isNotEmpty)
            ? "$_imgBaseUrl/$apiProfileVideo"
            : null;

    debugPrint("🟦 FINAL PROFILE PIC URL = $apiProfilePicUrl");
    debugPrint("🟦 FINAL PROFILE Logo URL = $apiProfileLogoUrl");
    debugPrint("🟦 FINAL PROFILE video URL = $apiProfileVideoUrl");
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
                    height: MediaQuery.of(context).size.height * 0.65,
                    child: Stack(
                      children: [
                        /// FULL WIDTH PROFILE COVER IMAGE
                        Positioned.fill(
                          child: (apiProfilePicUrl != null &&
                                  apiProfilePicUrl.isNotEmpty)
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    /// Profile Image
                                    AnimatedOpacity(
                                      opacity: _showVideo ? 0.0 : 1.0,
                                      duration:
                                          const Duration(milliseconds: 600),
                                      child: Image.network(
                                        apiProfilePicUrl!,
                                        fit: BoxFit.cover,
                                      ),
                                    ),

                                    /// Profile Video............
                                    if (_isVideoInitialized)
                                      AnimatedOpacity(
                                        opacity: _showVideo ? 1.0 : 0.0,
                                        duration:
                                            const Duration(milliseconds: 600),
                                        child: FittedBox(
                                          fit: BoxFit.cover,
                                          child: SizedBox(
                                            width: _videoController!
                                                .value.size.width,
                                            height: _videoController!
                                                .value.size.height,
                                            child:
                                                VideoPlayer(_videoController!),
                                          ),
                                        ),
                                      ),
                                  ],
                                )
                              : Container(
                                  color: colorScheme.surfaceContainerHighest,
                                  child: Icon(
                                    CupertinoIcons.person_fill,
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
                          // top: MediaQuery.of(context).padding.top + 12,
                          // left: 12,
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 56,
                              height: 56,
                              alignment: Alignment.center,
                              color: Colors.transparent,
                              child: const Icon(
                                CupertinoIcons.back,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),

                        if (!isViewerMode)
                          Positioned(
                            right: 12,
                            child: GestureDetector(
                              onTap: () async {
                                // 👈 make the function async
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditProfilePage(
                                      userDetails: _userDetails,
                                    ),
                                  ),
                                );
                                if (result == true) {
                                  // 👈 if profile was saved successfully
                                  // Refresh all data
                                  await _fetchUserDetails();
                                  await _fetchMasterLinks();
                                  await _fetchReviews();
                                  await _fetchAverageRating();
                                  // Also refresh the provider if you use it
                                  if (mounted) {
                                    context
                                        .read<ProfileProvider>()
                                        .fetchAllProfileData();
                                  }
                                }
                              },
                              child: Container(
                                width: 56,
                                height: 56,
                                alignment: Alignment.center,
                                color: Colors.transparent,
                                child: const Icon(
                                  CupertinoIcons.pencil,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),

                        /// PROFILE INFO BOTTOM CENTER
                      ],
                    ),
                  ),

                  /// ================= PROFILE INFO CARD =================

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    child: Container(
                      width: double.infinity,
                      // transform: Matrix4.translationValues(
                      //     0, -50, 0), // card half over image
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          // color: isDark
                          //     ? colorScheme.surfaceContainerHighest
                          //     : colorScheme.surface,
                          // borderRadius: BorderRadius.circular(0),
                          // borderRadius: const BorderRadius.only(
                          //   bottomLeft: Radius.circular(20),
                          //   bottomRight: Radius.circular(20),
                          // ),
                          // boxShadow: isDark
                          //     ? []
                          //     : [
                          //         BoxShadow(
                          //           color: Colors.black.withOpacity(0.12),
                          //           blurRadius: 10,
                          //           spreadRadius: 1,
                          //           offset: const Offset(0, 4),
                          //         ),
                          //       ],
                          // border: Border.all(
                          //   color: colorScheme.outlineVariant,
                          //   width: 0.2,
                          // ),
                          ),
                      child: Column(
                        children: [
                          /// PROFILE LOGO
                          CircleAvatar(
                            radius: 40,
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                            backgroundImage: apiProfileLogoUrl != null
                                ? NetworkImage(apiProfileLogoUrl)
                                : null,
                            child: apiProfileLogoUrl == null
                                ? Icon(
                                    CupertinoIcons.person_fill,
                                    size: 40,
                                    color: colorScheme.onSurfaceVariant,
                                  )
                                : null,
                          ),

                          const SizedBox(height: 14),

                          /// FULL NAME
                          Text(
                            _capitalize(fullName),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.35,
                              color: colorScheme.onSurface,
                            ),
                          ),

                          const SizedBox(height: 6),

                          /// BUSINESS NAME
                          Text(
                            _userDetails?['business_info']?['legal_name'] ?? "",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),

                          const SizedBox(height: 4),

                          /// INDUSTRY
                          Text(
                            _userDetails?['business_info']?['industry']
                                    ?['title'] ??
                                "",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  /// ================= ACTION BUTTON (VIEWER ONLY, NOT CONNECTED) ==================
                  if (isViewerMode && !isAlreadyConnected)
                    Padding(
                      padding: const EdgeInsets.all(16),
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
                              // borderRadius: BorderRadius.circular(18),
                              // boxShadow: isDark
                              //     ? []
                              //     : [
                              //         BoxShadow(
                              //           color: Colors.black.withOpacity(0.1),
                              //           spreadRadius: 1,
                              //           blurRadius: 6,
                              //           offset: const Offset(0, 2),
                              //         ),
                              //       ],
                              // border: isDark
                              //     ? null
                              //     : Border.all(
                              //         color: colorScheme.outlineVariant,
                              //         width: 0.2,
                              //       ),
                            ),
                            child: _buildConnectionButton(),
                          ),
                        ],
                      ),
                    ),

                  // ================= REST UI (ALWAYS SHOWN) =================
                  if (true) ...[
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
                                        width: 0.2,
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
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.4,
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

                    // if (!_isLoadingMasterLinks && _masterLinks.isNotEmpty)
                    if (isViewerMode)

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
                                        width: 0.2,
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
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.4,
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

                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? colorScheme.surfaceContainerHighest
                                          : colorScheme.surface,
                                      borderRadius: BorderRadius.circular(18),
                                      boxShadow: isDark
                                          ? []
                                          : [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.1),
                                                spreadRadius: 1,
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                      border: isDark
                                          ? null
                                          : Border.all(
                                              color: colorScheme.outlineVariant,
                                              width: 0.2,
                                            ),
                                    ),
                                    child: Row(
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
                                              fillColor:
                                                  colorScheme.surfaceContainer,
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
                                              // suffixIcon: IconButton(
                                              //   icon: Icon(
                                              //     Icons.camera_alt,
                                              //     color: colorScheme.primary,
                                              //   ),
                                              //   onPressed: _pickImageForMessage,
                                              // ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton(
                                          onPressed: _sendMessage,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                colorScheme.primary,
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
                            // _buildRatingsSection(),

                            _hasGivenReview
                                ? _buildGivenRatingCard()
                                : _buildRatingsSection(),
                            // const SizedBox(height: 12), // spacing after section
                          ],
                        ),
                      ),

                    /// ================= PRODUCTS SECTION ==================

                    if (_products.isNotEmpty || _isLoadingProducts)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ProductListWidget(
                          products: _products,
                          isLoading: _isLoadingProducts,
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
                                      width: 0.2,
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

                                                // Safely get from_user as a map or null
                                                final fromUser = r["from_user"]
                                                    as Map<String, dynamic>?;

                                                String username;
                                                if (fromUser != null &&
                                                    fromUser["user_name"] !=
                                                        null) {
                                                  username =
                                                      fromUser["user_name"]
                                                          .toString();
                                                } else if (r["reviewer_name"] !=
                                                    null) {
                                                  username = r["reviewer_name"]
                                                      .toString();
                                                } else {
                                                  username = "Anonymous";
                                                }

                                                final message =
                                                    (r["message"] ?? "")
                                                        .toString();
                                                final rating = int.tryParse(
                                                        r["rating"]
                                                            .toString()) ??
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

