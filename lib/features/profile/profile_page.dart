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

class ProfilePage extends StatefulWidget {
  final Map<String, dynamic>? userDetails;
  const ProfilePage({super.key, this.userDetails});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ImagePicker _picker = ImagePicker();
  static const String _baseUrl = AppConfig.apiBaseUrl;
  static const String _imgBaseUrl = AppConfig.apiProfileImg;
  Map<String, dynamic>? _userDetails; // ✅ NEW

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
  Future<void> _fetchUserDetails() async {
    try {
      final userId = await UserStorageService().getUserId();
      debugPrint("🟣 LOGGED IN USER ID = $userId");

      if (userId == null) {
        debugPrint("🔴 ERROR: userId is null, cannot call user-details api");
        return;
      }

      final headers = await _getHeaders();

      final url = Uri.parse("$_baseUrl/user-details/$userId");

      debugPrint("🟡 CALLING API: $url");
      debugPrint("🟡 HEADERS: $headers");

      final response = await http.get(url, headers: headers);

      debugPrint("🟢 STATUS CODE: ${response.statusCode}");
      debugPrint("🟢 RAW RESPONSE: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        // ✅ console me pura response print
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

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 🔥 NEW: user-details api call
      await _fetchUserDetails();

      // Existing call
      context.read<ProfileProvider>().fetchAllProfileData();
    });
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

  void _showEditProfileDialog() {
    final profile = context.read<ProfileProvider>().profileData;
    final colorScheme = Theme.of(context).colorScheme;

    // ✅ prefer api data first
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

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final profile = profileProvider.profileData;
    final business = profileProvider.businessInfo;
    final links = profileProvider.links;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ✅ API DATA (user-details) priority
    final apiMasterUser = _userDetails?['master_user'];

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
            // onPressed: _showEditProfileDialog,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 18,
          fontWeight: FontWeight.bold),
    );
  }



  
}
