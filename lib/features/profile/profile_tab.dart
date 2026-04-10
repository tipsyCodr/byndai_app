import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:gridcard/core/services/auth_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:gridcard/widgets/top_alert.dart';
import 'package:gridcard/core/services/profile_service.dart';
import './crop_screen.dart';

class ProfileTab extends StatefulWidget {
  final Map<String, dynamic>? userDetails;
  final VoidCallback? onSaved;

  const ProfileTab({super.key, this.userDetails, this.onSaved});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _isJciSelected = false;
  bool _isBniSelected = false;

  // Controllers for text fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();

  // Additional email and mobile controllers - only one each allowed
  TextEditingController? _additionalEmailController;
  TextEditingController? _additionalMobileController;

  // Selected values
  Uint8List? _croppedImageBytes;
  String? _selectedGender;
  String? _selectedCountry = 'India'; // Default to India
  int? _selectedStateId;
  int? _selectedDistrictId;

  // Selected names for display
  String? _selectedStateName;
  String? _selectedDistrictName;

  // API Lists
  List<Map<String, dynamic>> _states = _cachedStates;
  List<Map<String, dynamic>> _districts = _cachedDistricts;
  List<Map<String, dynamic>> _filteredDistricts = [];

  // Static cache for locations to prevent redundant fetches
  static List<Map<String, dynamic>> _cachedStates = [];
  static List<Map<String, dynamic>> _cachedDistricts = [];
  static DateTime? _lastLocationsFetchTime;

  bool get _shouldRefreshLocations {
    if (_cachedStates.isEmpty ||
        _cachedDistricts.isEmpty ||
        _lastLocationsFetchTime == null) return true;
    return DateTime.now().difference(_lastLocationsFetchTime!) >
        const Duration(minutes: 60);
  }

  // Loading states
  bool _isLoadingStates = false;
  bool _isLoadingDistricts = false;
  bool _isSaving = false;

  // Media files
  XFile? _profileImage;
  XFile? _logoImage;
  XFile? _profileVideo;
  // XFile? _bannerImage;
  // Uint8List? _bannerBytes;
  Uint8List? _logoBytes;
  String? _bniIdCardUrl;
  String? _jciIdCardUrl;
  Uint8List? _bniIdCardBytes;
  Uint8List? _jciIdCardBytes;

  final ImagePicker _picker = ImagePicker();

  // ✅ GENDER: Removed "Other", only Male & Female
  final List<String> _genders = ['Male', 'Female'];

  final List<String> _countries = ['India']; // Only India

  static const String _baseUrl = AppConfig.apiBaseUrl;
  static const String _imgBaseUrl = AppConfig.apiProfileImg;

  // ================= HEADERS =================
  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, String>> _getHeadersMultipart() async {
    final token = await UserStorageService().getToken();
    return {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ================= FETCH STATES =================
  Future<void> _fetchStates() async {
    if (!_shouldRefreshLocations && _cachedStates.isNotEmpty) {
      if (mounted) setState(() => _states = _cachedStates);
      return;
    }

    try {
      setState(() => _isLoadingStates = true);

      final uri = Uri.parse("$_baseUrl/states");

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      debugPrint("========== PROFILE STATES API ==========");
      debugPrint("URL: $uri");
      debugPrint("STATUS: ${response.statusCode}");

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        if (jsonData["status"] == true) {
          final List list = jsonData["data"];

          setState(() {
            _states = list.map((e) {
              return {
                "id": e["id"],
                "state_name": e["state_name"],
                "c_id": e["c_id"],
              };
            }).toList();
            _cachedStates = _states;
          });

          debugPrint("TOTAL STATES: ${_states.length}");
        }
      }
    } catch (e) {
      debugPrint("States fetch error: $e");
    } finally {
      setState(() => _isLoadingStates = false);
    }
  }

  // ================= FETCH DISTRICTS =================
  Future<void> _fetchDistricts() async {
    if (!_shouldRefreshLocations && _cachedDistricts.isNotEmpty) {
      if (mounted) setState(() => _districts = _cachedDistricts);
      return;
    }

    try {
      setState(() => _isLoadingDistricts = true);

      final uri = Uri.parse("$_baseUrl/districts");

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      debugPrint("========== PROFILE DISTRICTS API ==========");
      debugPrint("URL: $uri");
      debugPrint("STATUS: ${response.statusCode}");

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        if (jsonData["status"] == true) {
          final List list = jsonData["data"];

          setState(() {
            _districts = list.map((e) {
              return {
                "id": e["id"],
                "district_name": e["district_name"],
                "s_id": e["s_id"],
              };
            }).toList();
            _cachedDistricts = _districts;
          });

          debugPrint("TOTAL DISTRICTS: ${_districts.length}");
        }
      }
    } catch (e) {
      debugPrint("Districts fetch error: $e");
    } finally {
      setState(() {
        _isLoadingDistricts = false;
        if (_states.isNotEmpty && _districts.isNotEmpty) {
          _lastLocationsFetchTime = DateTime.now();
        }
      });
    }
  }

  // ================= MEDIA PICKERS =================
  Future<void> _pickProfileImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);

    if (pickedFile == null) return;

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CropScreen(
          imageFile: pickedFile,
          onCropped: (Uint8List croppedBytes) {
            setState(() {
              _croppedImageBytes = croppedBytes;
            });
            _updateProfile(); // Auto-upload immediately after cropping
          },
        ),
      ),
    );
  }

  // Future<void> _pickLogoImage() async {
  //   try {
  //     final XFile? image = await _picker.pickImage(
  //       source: ImageSource.gallery,
  //       maxWidth: 500,
  //       maxHeight: 500,
  //       imageQuality: 85,
  //     );
  //     if (image != null) {
  //       final bytes = await image.readAsBytes(); // Read bytes for preview
  //       setState(() {
  //         _logoImage = image;
  //         _logoBytes = bytes;
  //       });
  //     }
  //   } catch (e) {
  //     debugPrint("Error picking logo image: $e");
  //     _showErrorSnackBar('Error picking logo: ${e.toString()}');
  //   }
  // }

  Future<void> _pickLogoImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);

    if (pickedFile == null) return;

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CropScreen(
          imageFile: pickedFile,
          onCropped: (Uint8List croppedBytes) {
            setState(() {
              _logoImage = pickedFile; // optional
              _logoBytes = croppedBytes; // 👈 cropped image
            });
            _updateProfile(); // Auto-upload immediately after cropping
          },
        ),
      ),
    );
  }

  Future<void> _pickProfileVideo(ImageSource source) async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 30),
      );
      if (video != null) {
        setState(() {
          _profileVideo = video;
        });
        _updateProfile(); // Auto-upload immediately
      }
    } catch (e) {
      debugPrint("Error picking profile video: $e");
      _showErrorSnackBar('Error picking video: ${e.toString()}');
    }
  }

  Future<void> _deleteProfileVideo() async {
    final videoIdStr = getMedia('profile_video_id') ?? getMedia('video_id');
    if (videoIdStr == null) {
      // If we don't have a direct ID in settings,
      // check if it's stored under a different key in userDetails
      _showErrorSnackBar("No video ID found for deletion");
      return;
    }

    final int? id = int.tryParse(videoIdStr.toString());
    if (id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Video"),
        content:
            const Text("Are you sure you want to delete your profile video?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete")),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      final success = await ProfileService.deleteUserVideo(id);
      if (success) {
        _showSuccessSnackBar("Video deleted successfully");
        setState(() {
          _profileVideo = null;
        });
        // Refresh profile to update UI
        final updated = await _fetchUserDetails();
        if (updated != null && mounted) {
          Provider.of<AuthProvider>(context, listen: false)
              .updateUserFromDetails(updated);
        }
      } else {
        _showErrorSnackBar("Failed to delete video");
      }
    } catch (e) {
      _showErrorSnackBar("Error: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Future<void> _pickBannerImage() async {
  //   try {
  //     final XFile? image = await _picker.pickImage(
  //       source: ImageSource.gallery,
  //       maxWidth: 500,
  //       maxHeight: 500,
  //       imageQuality: 85,
  //     );
  //     if (image != null) {
  //       final bytes = await image.readAsBytes(); // Read bytes for preview
  //       setState(() {
  //         _bannerImage = image;
  //         _bannerBytes = bytes; // Store bytes
  //       });
  //     }
  //   } catch (e) {
  //     debugPrint("Error picking banner image: $e");
  //     _showErrorSnackBar('Error picking banner: ${e.toString()}');
  //   }
  // }

/*
  Future<void> _pickBannerImage() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CropScreen(
          imageFile: pickedFile,
          onCropped: (Uint8List croppedBytes) {
            setState(() {
              _bannerImage = pickedFile; // optional
              _bannerBytes = croppedBytes; // 👈 cropped image
            });
            _updateProfile(); // Auto-upload immediately after cropping
          },
        ),
      ),
    );
  }
*/

  // ================= UPDATE PROFILE API =================
  Future<void> _updateProfile() async {
    if (_nameController.text.isEmpty) {
      _showErrorSnackBar('Please enter your name');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final uri = Uri.parse("$_baseUrl/update_profile");
      final request = http.MultipartRequest("POST", uri);

      // Add headers
      request.headers.addAll(await _getHeadersMultipart());

      // Add text fields
      request.fields['user_name'] = _nameController.text.trim();

      if (_emailController.text.trim().isNotEmpty) {
        request.fields['email'] = _emailController.text.trim();
      }

      if (_dobController.text.trim().isNotEmpty) {
        request.fields['dob'] = _dobController.text.trim();
      }

      // ✅ GENDER: Convert display value to DB code
      if (_selectedGender != null) {
        final String genderCode = _selectedGender == 'Male' ? 'M' : 'F';
        request.fields['gender'] = genderCode;
      }

      // Primary mobile
      if (_mobileController.text.trim().isNotEmpty) {
        String digits =
            _mobileController.text.trim().replaceAll(RegExp(r'\D'), '');
        if (digits.length == 10) digits = '91$digits';
        request.fields['mobile_one'] = digits;
      }

      // Secondary mobile
      if (_additionalMobileController != null &&
          _additionalMobileController!.text.trim().isNotEmpty) {
        String digits = _additionalMobileController!.text
            .trim()
            .replaceAll(RegExp(r'\D'), '');
        if (digits.length == 10) digits = '91$digits';
        request.fields['mobile_two'] = digits;
      }

      // Secondary email
      if (_additionalEmailController != null &&
          _additionalEmailController!.text.trim().isNotEmpty) {
        request.fields['email_one'] = _additionalEmailController!.text.trim();
      }

      // Address
      if (_addressController.text.trim().isNotEmpty) {
        request.fields['address'] = _addressController.text.trim();
      }

      // Country ID (India = 1)
      request.fields['country_id'] = '1';

      // State ID
      if (_selectedStateId != null) {
        request.fields['state_id'] = _selectedStateId.toString();
      }

      // District ID
      if (_selectedDistrictId != null) {
        request.fields['district_id'] = _selectedDistrictId.toString();
      }

      request.fields['jci_member'] = _isJciSelected ? '1' : '0';
      request.fields['bni_member'] = _isBniSelected ? '1' : '0';

      // ========== MEDIA FILES ==========
      // Profile Image
      if (_croppedImageBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'profile_pic',
            _croppedImageBytes!,
            filename: 'profile.jpg',
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      }

      // Logo – prefer bytes if available
      if (_logoBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'profile_logo',
            _logoBytes!,
            filename: 'logo.jpg',
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      } else if (_logoImage != null) {
        final bytes = await _logoImage!.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'profile_logo',
            bytes,
            filename: _logoImage!.name,
            contentType:
                MediaType('image', _getFileExtension(_logoImage!.path)),
          ),
        );
      }

      /*
      // Banner Image – prefer bytes if available
      if (_bannerBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'profile_banner',
            _bannerBytes!,
            filename: 'banner.jpg',
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      } else if (_bannerImage != null) {
        final bytes = await _bannerImage!.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'profile_banner',
            bytes,
            filename: _bannerImage!.name,
            contentType:
                MediaType('image', _getFileExtension(_bannerImage!.path)),
          ),
        );
      }
      */

      // Profile Video
      if (_profileVideo != null) {
        final bytes = await _profileVideo!.readAsBytes();
        final ext = _getFileExtension(_profileVideo!.path);
        request.files.add(
          http.MultipartFile.fromBytes(
            'profile_video',
            bytes,
            filename: _profileVideo!.name,
            contentType: MediaType('video', ext),
          ),
        );
      }

      debugPrint("========== PROFILE UPDATE API ==========");
      debugPrint("URL: $uri");
      debugPrint("FIELDS: ${request.fields}");

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final jsonResponse = json.decode(responseBody);

      debugPrint("STATUS CODE: ${response.statusCode}");
      debugPrint("RESPONSE: $jsonResponse");

      if (response.statusCode == 200 && jsonResponse['status'] == true) {
        _showSuccessSnackBar(
            jsonResponse['message'] ?? 'Profile updated successfully!');

        // Refresh user details
        // await _fetchUserDetails();

        final updatedDetails = await _fetchUserDetails();
        if (updatedDetails != null && mounted) {
          final authProvider =
              Provider.of<AuthProvider>(context, listen: false);
          authProvider.updateUserFromDetails(updatedDetails);
        }
        if (mounted) {
          widget.onSaved?.call();
          // Navigator.pop(context, true); // Removed to allow side-editing other tabs
        }
      } else {
        _showErrorSnackBar(
            jsonResponse['message'] ?? 'Failed to update profile');
      }
    } catch (e) {
      debugPrint("EXCEPTION in _updateProfile: $e");
      _showErrorSnackBar("Error updating profile: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // ================= FETCH USER DETAILS (refresh) =================
  // Future<void> _fetchUserDetails() async {
  //   try {
  //     final userId = await UserStorageService().getUserId();
  //     if (userId == null) return;

  //     final headers = await _getHeaders();
  //     final url = Uri.parse("$_baseUrl/user-details/$userId");
  //     final response = await http.get(url, headers: headers);

  //     if (response.statusCode == 200) {
  //       final decoded = jsonDecode(response.body);
  //       if (decoded["status"] == true) {
  //         // Update the widget.userDetails if needed
  //         debugPrint("User details refreshed successfully");
  //       }
  //     }
  //   } catch (e) {
  //     debugPrint("Error refreshing user details: $e");
  //   }
  // }

  Future<Map<String, dynamic>?> _fetchUserDetails() async {
    try {
      final userId = await UserStorageService().getUserId();
      if (userId == null) return null;

      final headers = await _getHeaders();
      final url = Uri.parse("$_baseUrl/user-details/$userId");
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded["status"] == true) {
          return decoded["data"]; // return the updated user details
        }
      }
    } catch (e) {
      debugPrint("Error refreshing user details: $e");
    }
    return null;
  }

  // ================= HELPER METHODS =================
  String _getFileExtension(String path) {
    return path.split('.').last.toLowerCase();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    TopAlert.show(context, message, isError: true);
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    TopAlert.show(context, message, isSuccess: true);
  }

  // ================= INIT =================
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _fetchStates();
    await _fetchDistricts();
    await _fetchIdCards();
    _loadUserData();
  }

  Future<void> _fetchIdCards() async {
    try {
      final response = await ProfileService.getIdCards();
      debugPrint("ID CARDS RESPONSE DATA: ${response?['data']}");
      if (response != null && response['status'] == true) {
        final data = response['data'];
        setState(() {
          _bniIdCardUrl = data['bni_id_card_image'];
          _jciIdCardUrl = data['jci_id_card_image'];
          debugPrint("SET BNI URL: $_bniIdCardUrl");
          debugPrint("SET JCI URL: $_jciIdCardUrl");

          // Clear local bytes if we have a URL now
          if (_bniIdCardUrl != null) _bniIdCardBytes = null;
          if (_jciIdCardUrl != null) _jciIdCardBytes = null;
          
          // Also update member status if returned
          if (data['bni_member'] != null) {
            _isBniSelected = data['bni_member'].toString() == '1';
          }
          if (data['jci_member'] != null) {
            _isJciSelected = data['jci_member'].toString() == '1';
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching ID cards: $e");
    } finally {
      // Logic removed
    }
  }

  Future<void> _pickBniIdCard(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile == null) return;

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CropScreen(
          imageFile: pickedFile,
          onCropped: (Uint8List croppedBytes) {
            setState(() {
              _bniIdCardBytes = croppedBytes;
            });
            _uploadIdCard('bni', croppedBytes);
          },
        ),
      ),
    );
  }

  Future<void> _pickJciIdCard(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile == null) return;

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CropScreen(
          imageFile: pickedFile,
          onCropped: (Uint8List croppedBytes) {
            setState(() {
              _jciIdCardBytes = croppedBytes;
            });
            _uploadIdCard('jci', croppedBytes);
          },
        ),
      ),
    );
  }

  void _showPickOptions({required Function(ImageSource) onPick, bool isVideo = false}) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(isVideo ? Icons.videocam : Icons.camera_alt),
                title: Text(isVideo ? "Record Video" : "Take Photo"),
                onTap: () {
                  Navigator.pop(context);
                  onPick(ImageSource.camera);
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(isVideo ? Icons.video_library : Icons.photo_library),
                title: Text(isVideo ? "Choose Video" : "Choose from Gallery"),
                onTap: () {
                  Navigator.pop(context);
                  onPick(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadIdCard(String type, Uint8List bytes) async {
    setState(() => _isSaving = true);
    try {
      final response = await ProfileService.uploadIdCard(
        type: type,
        imageBytes: bytes,
      );
      if (response != null && response['status'] == true) {
        _showSuccessSnackBar('${type.toUpperCase()} ID Card uploaded successfully');
        await _fetchIdCards(); // Refresh URLs
      } else {
        _showErrorSnackBar('Failed to upload ${type.toUpperCase()} ID Card');
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ✅ GENDER: Convert DB code (M/F) to display text (Male/Female)
  void _loadUserData() {
    if (widget.userDetails != null) {
      final userDetails = widget.userDetails!;
      final apiMasterUser =
          userDetails['master_user'] ?? userDetails['user'] ?? userDetails;
      final user = userDetails;

      setState(() {
        // Name
        _nameController.text = apiMasterUser['fname']?.toString() ??
            user['fname']?.toString() ??
            user['user_name']?.toString() ??
            "";

        // Email
        _emailController.text = user['email']?.toString() ??
            apiMasterUser['email_one']?.toString() ??
            apiMasterUser['email']?.toString() ??
            "";

        // Mobile
        _mobileController.text = apiMasterUser['mobile_one']?.toString() ??
            apiMasterUser['mobile']?.toString() ??
            user['mobile']?.toString() ??
            "";

        // Secondary Mobile
        final String mobileTwo = apiMasterUser['mobile_two']?.toString() ?? "";
        if (mobileTwo.isNotEmpty) {
          _additionalMobileController = TextEditingController(text: mobileTwo);
        }

        // Secondary Email
        final String emailOne = apiMasterUser['email_one']?.toString() ?? "";
        if (emailOne.isNotEmpty && _emailController.text != emailOne) {
          _additionalEmailController = TextEditingController(text: emailOne);
        }

        // DOB
        _dobController.text =
            apiMasterUser['dob']?.toString() ?? user['dob']?.toString() ?? "";

        // Gender
        final apiGender = (apiMasterUser['gender'] ?? user['gender'] ?? '')
            .toString()
            .toUpperCase();

        if (apiGender == 'M') {
          _selectedGender = 'Male';
        } else if (apiGender == 'F') {
          _selectedGender = 'Female';
        } else {
          _selectedGender = null;
        }

        // ✅ JCI & BNI load
        _isJciSelected = (apiMasterUser['jci_member']?.toString() == '1' ||
            user['jci_member']?.toString() == '1');

        _isBniSelected = (apiMasterUser['bni_member']?.toString() == '1' ||
            user['bni_member']?.toString() == '1');

        // Address
        _addressController.text = apiMasterUser['address']?.toString() ??
            user['address']?.toString() ??
            "";

        // State
        _selectedStateId = apiMasterUser['state_id'] ?? user['state_id'];
        _selectedStateName = apiMasterUser['state_name'] ?? user['state_name'];

        // District
        _selectedDistrictId =
            apiMasterUser['district_id'] ?? user['district_id'];
        _selectedDistrictName =
            apiMasterUser['district_name'] ?? user['district_name'];

        // Filter districts if state is selected
        if (_selectedStateId != null && _districts.isNotEmpty) {
          _filteredDistricts =
              _districts.where((d) => d["s_id"] == _selectedStateId).toList();
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _dobController.dispose();
    _additionalEmailController?.dispose();
    _additionalMobileController?.dispose();
    super.dispose();
  }

  // Helper to find media keys anywhere in the hierarchy
  String? getMedia(String key) {
    if (widget.userDetails == null) return null;
    final userData = widget.userDetails!;
    final masterUser = userData['master_user'] ?? {};
    final userSub = userData['user'] ?? {};
    final val = userData[key] ?? masterUser[key] ?? userSub[key];
    return val?.toString();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Media Upload Section
          Text(
            'Media',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface),
          ),
          const SizedBox(height: 16),

          // Profile Image & Logo Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.95,
            ),
            itemCount: 2,
            itemBuilder: (context, index) {
              if (index == 0) {
                return MediaUploadCard(
                  title: 'Profile Image',
                  size: '500px x 500px',
                  mediaFile: _profileImage,
                  existingFile: getMedia('profile_pic'),
                  baseUrl: _imgBaseUrl,
                  onTap: () => _showPickOptions(onPick: _pickProfileImage),
                  croppedBytes: _croppedImageBytes,
                );
              } else {
                return MediaUploadCard(
                  title: 'Logo',
                  size: '500px x 500px',
                  mediaFile: _logoImage,
                  existingFile: getMedia('profile_logo'),
                  baseUrl: _imgBaseUrl,
                  onTap: () => _showPickOptions(onPick: _pickLogoImage),
                  croppedBytes: _logoBytes,
                );
              }
            },
          ),

          const SizedBox(height: 16),

          // Profile Video (Wide Format)
          SizedBox(
            height: 180,
            width: double.infinity,
            child: MediaUploadCard(
              title: 'Profile Video',
              size: 'Max 25 MB (Landscape/Portrait)',
              mediaFile: _profileVideo,
              existingFile: getMedia('profile_video'),
              baseUrl: _imgBaseUrl,
              onTap: () => _showPickOptions(onPick: _pickProfileVideo, isVideo: true),
              // onDelete: _deleteProfileVideo, // TODO: fixed the video ID not found error later
              isVideo: true,
            ),
          ),

          const SizedBox(height: 16),
          Divider(color: colorScheme.outlineVariant),
          const SizedBox(height: 16),

          // ID Cards Section
          Text(
            'Organization ID Cards',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface),
          ),
          const SizedBox(height: 16),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.95,
            children: [
              MediaUploadCard(
                title: 'BNI ID Card',
                size: 'Photo Upload',
                existingFile: _bniIdCardUrl,
                baseUrl: _imgBaseUrl,
                onTap: () => _showPickOptions(onPick: _pickBniIdCard),
                croppedBytes: _bniIdCardBytes,
              ),
              MediaUploadCard(
                title: 'JCI ID Card',
                size: 'Photo Upload',
                existingFile: _jciIdCardUrl,
                baseUrl: _imgBaseUrl,
                onTap: () => _showPickOptions(onPick: _pickJciIdCard),
                croppedBytes: _jciIdCardBytes,
              ),
            ],
          ),

          const SizedBox(height: 32),
          Divider(color: colorScheme.outlineVariant),
          const SizedBox(height: 16),

          // Personal Information Section
          Text(
            'Personal Information',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface),
          ),
          const SizedBox(height: 16),

          // Name Field
          TextField(
            controller: _nameController,
            style: TextStyle(color: colorScheme.onSurface),
            decoration: InputDecoration(
              labelText: 'Full Name *',
              labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              filled: true,
              fillColor: isDark ? colorScheme.surfaceContainerHighest : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: isDark ? BorderSide.none : const BorderSide(),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: isDark
                    ? BorderSide.none
                    : BorderSide(color: colorScheme.outline),
              ),
              prefixIcon: Icon(Icons.person, color: colorScheme.primary),
            ),
          ),
          const SizedBox(height: 16),

          // DOB Field
          TextField(
            controller: _dobController,
            style: TextStyle(color: colorScheme.onSurface),
            decoration: InputDecoration(
              labelText: 'Date of Birth',
              labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              filled: true,
              fillColor: isDark ? colorScheme.surfaceContainerHighest : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: isDark ? BorderSide.none : const BorderSide(),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: isDark
                    ? BorderSide.none
                    : BorderSide(color: colorScheme.outline),
              ),
              prefixIcon:
                  Icon(Icons.calendar_today, color: colorScheme.primary),
              suffixIcon: Icon(Icons.arrow_drop_down,
                  color: colorScheme.onSurfaceVariant),
            ),
            readOnly: true,
            onTap: () async {
              DateTime? pickedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
              );
              if (pickedDate != null) {
                _dobController.text =
                    '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';
              }
            },
          ),
          const SizedBox(height: 16),

          // ✅ GENDER DROPDOWN – Only Male & Female
          DropdownButtonFormField<String>(
            initialValue: _selectedGender,
            decoration: InputDecoration(
              labelText: 'Gender',
              labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              filled: true,
              fillColor: isDark ? colorScheme.surfaceContainerHighest : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: isDark ? BorderSide.none : const BorderSide(),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: isDark
                    ? BorderSide.none
                    : BorderSide(color: colorScheme.outline),
              ),
              prefixIcon: Icon(Icons.people, color: colorScheme.primary),
            ),
            dropdownColor: isDark ? colorScheme.surfaceContainerHighest : null,
            style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
            items: _genders.map((gender) {
              return DropdownMenuItem(
                value: gender,
                child: Text(gender),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedGender = value;
              });
            },
          ),
          const SizedBox(height: 16),

          // Email Section
          Text(
            'Email',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface),
          ),
          const SizedBox(height: 8),

          // Primary Email
          TextField(
            controller: _emailController,
            style: TextStyle(color: colorScheme.onSurface),
            decoration: InputDecoration(
              labelText: 'Primary Email',
              labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              filled: true,
              fillColor: isDark ? colorScheme.surfaceContainerHighest : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: isDark ? BorderSide.none : const BorderSide(),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: isDark
                    ? BorderSide.none
                    : BorderSide(color: colorScheme.outline),
              ),
              prefixIcon: Icon(Icons.email, color: colorScheme.primary),
              suffixIcon: IconButton(
                icon: const Icon(Icons.add),
                onPressed:
                    _additionalEmailController == null ? _addEmailField : null,
                color: _additionalEmailController == null
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Additional Email - Only ONE
          if (_additionalEmailController != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: _additionalEmailController,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Secondary Email',
                  labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                  filled: true,
                  fillColor:
                      isDark ? colorScheme.surfaceContainerHighest : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: isDark ? BorderSide.none : const BorderSide(),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: isDark
                        ? BorderSide.none
                        : BorderSide(color: colorScheme.outline),
                  ),
                  prefixIcon: Icon(Icons.email, color: colorScheme.primary),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: _removeEmailField,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Mobile Section
          Text(
            'Mobile',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface),
          ),
          const SizedBox(height: 8),

          // Primary Mobile
          TextField(
            controller: _mobileController,
            keyboardType: TextInputType.phone,
            style: TextStyle(color: colorScheme.onSurface),
            decoration: InputDecoration(
              labelText: 'Primary Mobile',
              labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              filled: true,
              fillColor: isDark ? colorScheme.surfaceContainerHighest : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: isDark ? BorderSide.none : const BorderSide(),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: isDark
                    ? BorderSide.none
                    : BorderSide(color: colorScheme.outline),
              ),
              prefixIcon: Icon(Icons.phone, color: colorScheme.primary),
              suffixIcon: IconButton(
                icon: const Icon(Icons.add),
                onPressed: _additionalMobileController == null
                    ? _addMobileField
                    : null,
                color: _additionalMobileController == null
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Additional Mobile - Only ONE
          if (_additionalMobileController != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: _additionalMobileController,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Secondary Mobile',
                  labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                  filled: true,
                  fillColor:
                      isDark ? colorScheme.surfaceContainerHighest : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: isDark ? BorderSide.none : const BorderSide(),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: isDark
                        ? BorderSide.none
                        : BorderSide(color: colorScheme.outline),
                  ),
                  prefixIcon: Icon(Icons.phone, color: colorScheme.primary),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: _removeMobileField,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Country Dropdown - India only with value 1
          DropdownButtonFormField<String>(
            initialValue: _selectedCountry,
            decoration: InputDecoration(
              labelText: 'Country',
              labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              filled: true,
              fillColor: isDark ? colorScheme.surfaceContainerHighest : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: isDark ? BorderSide.none : const BorderSide(),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: isDark
                    ? BorderSide.none
                    : BorderSide(color: colorScheme.outline),
              ),
              prefixIcon: Icon(Icons.public, color: colorScheme.primary),
            ),
            dropdownColor: isDark ? colorScheme.surfaceContainerHighest : null,
            style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
            items: const [
              DropdownMenuItem(
                value: 'India',
                child: Text('India'),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _selectedCountry = value;
              });
            },
          ),
          const SizedBox(height: 16),

          // State Dropdown
          DropdownButtonFormField<int>(
            initialValue: _selectedStateId,
            isExpanded: true,
            dropdownColor: isDark ? colorScheme.surfaceContainerHighest : null,
            style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
            icon: Icon(Icons.keyboard_arrow_down, color: colorScheme.primary),
            decoration: InputDecoration(
              labelText: "State",
              labelStyle:
                  TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
              filled: true,
              fillColor: isDark ? colorScheme.surfaceContainerHighest : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: isDark ? BorderSide.none : const BorderSide(),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: isDark
                    ? BorderSide.none
                    : BorderSide(color: colorScheme.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: colorScheme.primary, width: 1),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              prefixIcon: Icon(Icons.map, color: colorScheme.primary),
            ),
            items: _isLoadingStates
                ? [
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text('Loading states...'),
                    )
                  ]
                : _states.isEmpty
                    ? [
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text('No states available'),
                        )
                      ]
                    : _states.map((state) {
                        return DropdownMenuItem<int>(
                          value: state['id'],
                          child: Text(
                            state['state_name'],
                          ),
                        );
                      }).toList(),
            onChanged: (value) {
              if (value == null) return;

              final selectedState = _states.firstWhere(
                (state) => state['id'] == value,
                orElse: () => {},
              );

              setState(() {
                _selectedStateId = value;
                _selectedStateName = selectedState['state_name'];
                _selectedDistrictId = null;
                _selectedDistrictName = null;

                // Filter districts based on selected state
                _filteredDistricts =
                    _districts.where((d) => d["s_id"] == value).toList();
              });

              debugPrint("Selected State ID: $_selectedStateId");
              debugPrint("Selected State Name: $_selectedStateName");
              debugPrint("Filtered Districts: ${_filteredDistricts.length}");
            },
          ),
          const SizedBox(height: 16),

          // District Dropdown
          DropdownButtonFormField<int>(
            // value: _selectedDistrictId,
            initialValue:
                _filteredDistricts.any((d) => d['id'] == _selectedDistrictId)
                    ? _selectedDistrictId
                    : null,
            isExpanded: true,
            dropdownColor: isDark ? colorScheme.surfaceContainerHighest : null,
            style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
            icon: Icon(Icons.keyboard_arrow_down, color: colorScheme.primary),
            decoration: InputDecoration(
              labelText: "District",
              labelStyle:
                  TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
              filled: true,
              fillColor: isDark ? colorScheme.surfaceContainerHighest : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: isDark ? BorderSide.none : const BorderSide(),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: isDark
                    ? BorderSide.none
                    : BorderSide(color: colorScheme.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: colorScheme.primary, width: 1),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              prefixIcon: Icon(Icons.location_city, color: colorScheme.primary),
            ),
            items: _buildDistrictItems(),
            onChanged: _selectedStateId == null
                ? null
                : (value) {
                    if (value == null) return;

                    final selectedDistrict = _filteredDistricts.firstWhere(
                      (district) => district['id'] == value,
                      orElse: () => {},
                    );

                    setState(() {
                      _selectedDistrictId = value;
                      _selectedDistrictName = selectedDistrict['district_name'];
                    });

                    debugPrint("Selected District ID: $_selectedDistrictId");
                    debugPrint(
                        "Selected District Name: $_selectedDistrictName");
                  },
          ),
          const SizedBox(height: 16),

          // Address Field (4 lines)
          TextField(
            controller: _addressController,
            // maxLines: 4,
            style: TextStyle(color: colorScheme.onSurface),
            decoration: InputDecoration(
              labelText: 'Address',
              labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              filled: true,
              fillColor: isDark ? colorScheme.surfaceContainerHighest : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: isDark ? BorderSide.none : const BorderSide(),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: isDark
                    ? BorderSide.none
                    : BorderSide(color: colorScheme.outline),
              ),
              prefixIcon: Icon(Icons.home, color: colorScheme.primary),
              alignLabelWithHint: true,
            ),
          ),

          // const SizedBox(height: 16),

          // Row(
          //   children: [
          //     Expanded(
          //       child: CheckboxListTile(
          //         contentPadding: EdgeInsets.zero,
          //         title: const Text("JCI"),
          //         value: _isJciSelected,
          //         onChanged: (value) {
          //           setState(() {
          //             _isJciSelected = value ?? false;
          //           });
          //         },
          //       ),
          //     ),
          //     Expanded(
          //       child: CheckboxListTile(
          //         contentPadding: EdgeInsets.zero,
          //         title: const Text("BNI"),
          //         value: _isBniSelected,
          //         onChanged: (value) {
          //           setState(() {
          //             _isBniSelected = value ?? false;
          //           });
          //         },
          //       ),
          //     ),
          //   ],
          // ),

          const SizedBox(height: 32),

          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _updateProfile,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
              child: _isSaving
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onPrimary,
                      ),
                    )
                  : const Text(
                      'Save Profile',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // Helper method to build district dropdown items
  List<DropdownMenuItem<int>> _buildDistrictItems() {
    final colorScheme = Theme.of(context).colorScheme;

    if (_selectedStateId == null) {
      return [
        DropdownMenuItem<int>(
          value: null,
          child: Text(
            'Select state first',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        )
      ];
    }

    if (_isLoadingDistricts) {
      return [
        DropdownMenuItem<int>(
          value: null,
          child: Text(
            'Loading districts...',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        )
      ];
    }

    if (_filteredDistricts.isEmpty) {
      return [
        DropdownMenuItem<int>(
          value: null,
          child: Text(
            'No districts available',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        )
      ];
    }

    return _filteredDistricts.map((district) {
      return DropdownMenuItem<int>(
        value: district['id'],
        child: Text(
          district['district_name'],
        ),
      );
    }).toList();
  }

  void _addEmailField() {
    setState(() {
      _additionalEmailController = TextEditingController();
    });
  }

  void _removeEmailField() {
    setState(() {
      _additionalEmailController?.dispose();
      _additionalEmailController = null;
    });
  }

  void _addMobileField() {
    setState(() {
      _additionalMobileController = TextEditingController();
    });
  }

  void _removeMobileField() {
    setState(() {
      _additionalMobileController?.dispose();
      _additionalMobileController = null;
    });
  }
}

// Media Upload Card Component - Updated with existing file support and croppedBytes
class MediaUploadCard extends StatelessWidget {
  final String title;
  final String size;
  final XFile? mediaFile;
  final String? existingFile;
  final String baseUrl;
  final VoidCallback onTap;
  final bool isVideo;
  final Uint8List? croppedBytes;
  final VoidCallback? onDelete;

  const MediaUploadCard({
    super.key,
    required this.title,
    required this.size,
    this.mediaFile,
    this.existingFile,
    required this.baseUrl,
    required this.onTap,
    this.isVideo = false,
    this.croppedBytes,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasNewFile = mediaFile != null || croppedBytes != null;
    final hasExistingFile = (existingFile ?? '').isNotEmpty;
    final showPreview = hasNewFile || hasExistingFile;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(
          color: isDark ? Colors.white10 : colorScheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 0. Main Click Area
          Positioned.fill(
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(),
            ),
          ),

          // 1. Background Media/Placeholder
          IgnorePointer(
            child: Positioned.fill(
              child: Container(
                color: colorScheme.surfaceContainerHighest,
                child: showPreview
                    ? _buildPreview(hasNewFile, hasExistingFile)
                    : Icon(
                        isVideo ? Icons.videocam : Icons.image,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                        size: 40,
                      ),
              ),
            ),
          ),

          // 2. Status Badge Overlay (Top Left)
          if (showPreview)
            Positioned(
              top: 8,
              left: 8,
              child: IgnorePointer(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (hasNewFile ? Colors.green : Colors.blue)
                        .withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Text(
                    hasNewFile ? 'NEW' : 'SAVED',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),

          // 3. Delete Action Overlay (Top Right)
          if (showPreview && onDelete != null)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),

          // 4. Bottom Info Overlay (Title & Action)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          hasNewFile
                              ? Icons.sync
                              : (hasExistingFile
                                  ? Icons.check_circle_outline
                                  : Icons.add_circle_outline),
                          size: 14,
                          color: (hasNewFile || hasExistingFile)
                              ? Colors.white
                              : colorScheme.primary.withOpacity(0.8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hasNewFile
                              ? 'Change'
                              : (hasExistingFile ? 'Replace' : 'Upload'),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(bool hasNewFile, bool hasExistingFile) {
    // Priority 1: Cropped bytes
    if (croppedBytes != null) {
      return Image.memory(
        croppedBytes!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallbackIcon(),
      );
    }

    // Priority 2: New media file
    if (mediaFile != null) {
      if (isVideo) {
        return _buildVideoPlaceholder();
      } else {
        return Image.file(
          File(mediaFile!.path),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackIcon(),
        );
      }
    }

    // Priority 3: Existing file
    if (hasExistingFile) {
      if (isVideo) {
        return _buildVideoPlaceholder();
      } else {
        String validUrl = AppConfig.getFullUrl(existingFile) ?? existingFile!;
        return Image.network(
          validUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(
                child: CircularProgressIndicator(strokeWidth: 2));
          },
          errorBuilder: (context, error, stackTrace) {
            if (!validUrl.startsWith('http')) {
              return Image.network(
                '$baseUrl/$existingFile',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildErrorPlaceholder(validUrl),
              );
            }
            return _buildErrorPlaceholder(validUrl);
          },
        );
      }
    }

    return _buildFallbackIcon();
  }

  Widget _buildVideoPlaceholder() {
    return Container(
      color: Colors.black87,
      child: const Center(
        child: Icon(
          Icons.play_circle_fill,
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder(String url) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image, color: Colors.red, size: 24),
            const SizedBox(height: 4),
            Text(
              url,
              style: const TextStyle(fontSize: 8, color: Colors.red),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackIcon() {
    return Builder(
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.broken_image,
            color: colorScheme.onSurfaceVariant,
            size: 24,
          ),
        );
      },
    );
  }
}
