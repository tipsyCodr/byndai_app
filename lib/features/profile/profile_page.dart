import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/core/services/profile_provider.dart';
import 'package:gridcard/features/profile/business_info_page.dart';
import 'package:gridcard/features/profile/links_management_page.dart';
import 'package:gridcard/features/profile/products_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:gridcard/features/profile/edit_profile_page.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ProfilePage extends StatefulWidget {
  final Map<String, dynamic>? userDetails;
  final int? userId;
  const ProfilePage({super.key, this.userDetails, this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ImagePicker _picker = ImagePicker();
  static const String _baseUrl = AppConfig.apiBaseUrl;
  static const String _imgBaseUrl = AppConfig.apiProfileImg;

  Map<String, dynamic>? _userDetails;

  // ================= MESSAGE SECTION =================
  File? _selectedImage;
  final TextEditingController _messageController = TextEditingController();

  // ================= RATINGS SECTION =================
  int _selectedRating = 0;
  final TextEditingController _feedbackController = TextEditingController();

  // ================= REVIEWS SECTION =================
  List _reviews = [];
  bool _isLoadingReviews = false;

  // ================= HEADERS =================
  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ================= USER DETAILS API CALL =================
  // Future<void> _fetchUserDetails() async {
  //   try {
  //     final userId = await UserStorageService().getUserId();
  //     debugPrint("🟣 LOGGED IN USER ID = $userId");

  //     if (userId == null) {
  //       debugPrint("🔴 ERROR: userId is null, cannot call user-details api");
  //       return;
  //     }

  //     final headers = await _getHeaders();
  //     final url = Uri.parse("$_baseUrl/user-details/$userId");

  //     debugPrint("🟡 CALLING API: $url");
  //     debugPrint("🟡 HEADERS: $headers");

  //     final response = await http.get(url, headers: headers);

  //     debugPrint("🟢 STATUS CODE: ${response.statusCode}");
  //     debugPrint("🟢 RAW RESPONSE: ${response.body}");

  //     if (response.statusCode == 200) {
  //       final decoded = jsonDecode(response.body);

  //       debugPrint("✅ USER DETAILS API RESPONSE: $decoded");

  //       if (decoded["status"] == true) {
  //         setState(() {
  //           _userDetails = decoded["data"];
  //         });
  //       } else {
  //         debugPrint("🔴 API status false: ${decoded["message"]}");
  //       }
  //     } else {
  //       debugPrint("🔴 API FAILED: ${response.statusCode} => ${response.body}");
  //     }
  //   } catch (e) {
  //     debugPrint("🔴 EXCEPTION in _fetchUserDetails(): $e");
  //   }
  // }

  // // ================= FETCH REVIEWS =================
  // Future<void> _fetchReviews() async {
  //   if (_isLoadingReviews) return;
  //   setState(() => _isLoadingReviews = true);
  //   try {
  //     final headers = await _getHeaders();
  //     final userId = await UserStorageService().getUserId();
  //     if (userId == null) throw "User not logged in";
  //     final url = Uri.parse("$_baseUrl/user-reviews/$userId");
  //     final res = await http.get(url, headers: headers);
  //     final jsonData = jsonDecode(res.body);
  //     if (res.statusCode == 200 && jsonData["status"] == true) {
  //       final dataObj = jsonData["data"];
  //       if (dataObj != null && dataObj["data"] != null) {
  //         _reviews = dataObj["data"] as List;
  //       } else {
  //         _reviews = [];
  //       }
  //     } else {
  //       throw (jsonData["message"] ?? "Failed to load reviews");
  //     }
  //   } catch (e) {
  //     if (!mounted) return;
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text("Error loading reviews: $e")),
  //     );
  //   } finally {
  //     if (mounted) setState(() => _isLoadingReviews = false);
  //   }
  // }

  Future<void> _fetchUserDetails() async {
    try {
      // Determine which user ID to fetch: provided userId or fallback to logged-in user
      final int? targetUserId =
          widget.userId ?? await UserStorageService().getUserId();
      if (targetUserId == null) {
        debugPrint("🔴 ERROR: No userId available for fetching user details");
        return;
      }

      debugPrint("🟣 FETCHING USER DETAILS FOR USER ID = $targetUserId");

      final headers = await _getHeaders();
      final url = Uri.parse("$_baseUrl/user-details/$targetUserId");

      debugPrint("🟡 CALLING API: $url");
      debugPrint("🟡 HEADERS: $headers");

      final response = await http.get(url, headers: headers);

      debugPrint("🟢 STATUS CODE: ${response.statusCode}");
      debugPrint("🟢 RAW RESPONSE: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        debugPrint("✅ USER DETAILS API RESPONSE: $decoded");

        if (decoded["status"] == true) {
          setState(() {
            _userDetails = decoded["data"];
          });
        } else {
          debugPrint("🔴 API status false: ${decoded["message"]}");
        }
      } else {
        debugPrint("🔴 API FAILED: ${response.statusCode} => ${response.body}");
      }
    } catch (e) {
      debugPrint("🔴 EXCEPTION in _fetchUserDetails(): $e");
    }
  }

// ================= FETCH REVIEWS =================
  Future<void> _fetchReviews() async {
    if (_isLoadingReviews) return;
    setState(() => _isLoadingReviews = true);
    try {
      final headers = await _getHeaders();
      final int? targetUserId =
          widget.userId ?? await UserStorageService().getUserId();
      if (targetUserId == null)
        throw "No user ID available for fetching reviews";
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
        throw (jsonData["message"] ?? "Failed to load reviews");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading reviews: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _fetchUserDetails();
      context.read<ProfileProvider>().fetchAllProfileData();
      _fetchReviews(); // Load reviews after user details
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _updateImage(bool isProfile) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      final provider = context.read<ProfileProvider>();
      if (isProfile) {
        await provider.updateProfile(profilePic: File(image.path));
      } else {
        await provider.updateProfile(profileBanner: File(image.path));
      }
    }
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
      debugPrint("Sending message: ${_messageController.text}");
      debugPrint("With image: ${_selectedImage?.path}");

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
  void _submitRating() {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }
    debugPrint("Submitting rating: $_selectedRating stars");
    debugPrint("Feedback: ${_feedbackController.text}");

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rating submitted!')),
    );

    setState(() {
      _selectedRating = 0;
      _feedbackController.clear();
    });
  }

  void _showEditProfileDialog() {
    final profile = context.read<ProfileProvider>().profileData;
    final colorScheme = Theme.of(context).colorScheme;

    final apiMasterUser = _userDetails?['master_user'];

    final nameController = TextEditingController(
      text: apiMasterUser?['fname'] ??
          profile?['name'] ??
          profile?['fname'] ??
          profile?['master_user']?['fname'] ??
          '',
    );

    final deptController = TextEditingController(
      text: apiMasterUser?['dept'] ?? profile?['dept'] ?? '',
    );

    final desgController = TextEditingController(
      text: apiMasterUser?['desg'] ?? profile?['desg'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title:
            Text('Edit Profile', style: TextStyle(color: colorScheme.primary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle:
                    TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
              ),
            ),
            TextField(
              controller: deptController,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Department',
                labelStyle:
                    TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
              ),
            ),
            TextField(
              controller: desgController,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Designation',
                labelStyle:
                    TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await context.read<ProfileProvider>().updateProfile(
                    fname: nameController.text,
                    dept: deptController.text,
                    desg: desgController.text,
                  );
              if (mounted) Navigator.pop(context);
            },
            child: Text('Save', style: TextStyle(color: colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  String _getFullName() {
    final apiMasterUser = _userDetails?['master_user'];
    final fname = apiMasterUser?['fname']?.toString() ?? '';
    final lname = apiMasterUser?['lname']?.toString() ?? '';
    if (fname.isNotEmpty && lname.isNotEmpty) {
      return "$fname $lname";
    } else if (fname.isNotEmpty) {
      return fname;
    } else {
      return "Hemant Kumar";
    }
  }

  // ================= RATINGS WIDGET =================
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '4.0 (84)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
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

  // ================= REVIEW CARD FOR HORIZONTAL CAROUSEL =================
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
                      fontSize: 12, fontWeight: FontWeight.bold),
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

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final profile = profileProvider.profileData;
    final colorScheme = Theme.of(context).colorScheme;

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
        title:
            Text('Your Profile', style: TextStyle(color: colorScheme.primary)),
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: colorScheme.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
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
                  // Profile info card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 22, horizontal: 16),
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

                  const SizedBox(height: 16),

                  // Social Icons
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      _socialIcon(
                          FontAwesomeIcons.facebookF, const Color(0xFF1877F2)),
                      _socialIcon(
                          FontAwesomeIcons.instagram, const Color(0xFFE4405F)),
                      _socialIcon(
                          FontAwesomeIcons.twitter, const Color(0xFF1DA1F2)),
                      _socialIcon(
                          FontAwesomeIcons.linkedinIn, const Color(0xFF0A66C2)),
                      _socialIcon(
                          FontAwesomeIcons.youtube, const Color(0xFFFF0000)),
                      _socialIcon(
                          FontAwesomeIcons.whatsapp, const Color(0xFF25D366)),
                      _socialIcon(
                          FontAwesomeIcons.telegram, const Color(0xFF0088CC)),
                      _socialIcon(
                          FontAwesomeIcons.snapchat, const Color(0xFFFFFC00)),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ========== MESSAGE SECTION ==========
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
                                      horizontal: 16, vertical: 12),
                                  suffixIcon: IconButton(
                                    icon: Icon(Icons.camera_alt,
                                        color: Colors.blue.shade300),
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
                                    horizontal: 20, vertical: 14),
                              ),
                              child: const Text('Send',
                                  style: TextStyle(color: Colors.white)),
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

                  // ========== RATINGS SECTION ==========
                  _buildRatingsSection(),

                  const SizedBox(height: 24),

                  // ========== REVIEWS CAROUSEL ==========
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
                            ? const Center(child: CircularProgressIndicator())
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
                                        final fromUser = (r["from_user"] ?? {})
                                            as Map<String, dynamic>;
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
                                            (r["created_at"] ?? "").toString();
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
              ),
            ),
    );
  }

  Widget _socialIcon(IconData icon, Color color) {
    return Container(
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
    );
  }
}
