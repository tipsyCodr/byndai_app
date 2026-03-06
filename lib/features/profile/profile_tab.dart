import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:gridcard/widgets/top_alert.dart';

class ProfileTab extends StatefulWidget {
  final Map<String, dynamic>? userDetails;

  const ProfileTab({super.key, this.userDetails});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
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
  String? _selectedGender;
  String? _selectedCountry = 'India'; // Default to India
  int? _selectedStateId;
  int? _selectedDistrictId;

  // Selected names for display
  String? _selectedStateName;
  String? _selectedDistrictName;

  // API Lists
  List<Map<String, dynamic>> _states = [];
  List<Map<String, dynamic>> _districts = [];
  List<Map<String, dynamic>> _filteredDistricts = [];

  // Loading states
  bool _isLoadingStates = false;
  bool _isLoadingDistricts = false;
  bool _isSaving = false;

  // Media files
  XFile? _profileImage;
  XFile? _logoImage;
  XFile? _profileVideo;
  XFile? _bannerImage;

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
          });

          debugPrint("TOTAL DISTRICTS: ${_districts.length}");
        }
      }
    } catch (e) {
      debugPrint("Districts fetch error: $e");
    } finally {
      setState(() => _isLoadingDistricts = false);
    }
  }

  // ================= MEDIA PICKERS =================
  Future<void> _pickProfileImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _profileImage = image;
        });
      }
    } catch (e) {
      debugPrint("Error picking profile image: $e");
      _showErrorSnackBar('Error picking image: ${e.toString()}');
    }
  }

  Future<void> _pickLogoImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _logoImage = image;
        });
      }
    } catch (e) {
      debugPrint("Error picking logo image: $e");
      _showErrorSnackBar('Error picking logo: ${e.toString()}');
    }
  }

  Future<void> _pickProfileVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 30),
      );
      if (video != null) {
        setState(() {
          _profileVideo = video;
        });
      }
    } catch (e) {
      debugPrint("Error picking profile video: $e");
      _showErrorSnackBar('Error picking video: ${e.toString()}');
    }
  }

  Future<void> _pickBannerImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _bannerImage = image;
        });
      }
    } catch (e) {
      debugPrint("Error picking banner image: $e");
      _showErrorSnackBar('Error picking banner: ${e.toString()}');
    }
  }

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
        request.fields['mobile_one'] = _mobileController.text.trim();
      }

      // Secondary mobile
      if (_additionalMobileController != null &&
          _additionalMobileController!.text.trim().isNotEmpty) {
        request.fields['mobile_two'] = _additionalMobileController!.text.trim();
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

      // ========== MEDIA FILES ==========
      // Profile Image
      if (_profileImage != null) {
        final bytes = await _profileImage!.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'profile_pic',
            bytes,
            filename: _profileImage!.name,
            contentType:
                MediaType('image', _getFileExtension(_profileImage!.path)),
          ),
        );
      }

      // Logo
      if (_logoImage != null) {
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

      // Banner Image
      if (_bannerImage != null) {
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
        await _fetchUserDetails();

        if (mounted) {
          Navigator.pop(context, true); // Return with success
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
  Future<void> _fetchUserDetails() async {
    try {
      final userId = await UserStorageService().getUserId();
      if (userId == null) return;

      final headers = await _getHeaders();
      final url = Uri.parse("$_baseUrl/user-details/$userId");
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded["status"] == true) {
          // Update the widget.userDetails if needed
          debugPrint("User details refreshed successfully");
        }
      }
    } catch (e) {
      debugPrint("Error refreshing user details: $e");
    }
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
  // @override
  // void initState() {
  //   super.initState();
  //   _fetchStates();
  //   _fetchDistricts();

  //   // Prefill from API data
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     _loadUserData();
  //   });
  // }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _fetchStates();
    await _fetchDistricts();
    _loadUserData();
  }

  // ✅ GENDER: Convert DB code (M/F) to display text (Male/Female)
  void _loadUserData() {
    if (widget.userDetails != null) {
      final apiMasterUser = widget.userDetails?['master_user'];
      final user = widget.userDetails;

      setState(() {
        // Name
        _nameController.text =
            apiMasterUser?['fname'] ?? user?['user_name'] ?? "";

        // Email
        _emailController.text =
            user?['email'] ?? apiMasterUser?['email_one'] ?? "";

        // Mobile
        _mobileController.text = apiMasterUser?['mobile_one'] ?? "";

        // Secondary Mobile
        if (apiMasterUser?['mobile_two'] != null &&
            apiMasterUser!['mobile_two'].toString().isNotEmpty) {
          _additionalMobileController = TextEditingController(
            text: apiMasterUser['mobile_two'],
          );
        }

        // Secondary Email
        if (apiMasterUser?['email_one'] != null &&
            apiMasterUser!['email_one'].toString().isNotEmpty &&
            _emailController.text != apiMasterUser['email_one']) {
          _additionalEmailController = TextEditingController(
            text: apiMasterUser['email_one'],
          );
        }

        // DOB
        _dobController.text = apiMasterUser?['dob'] ?? "";

        // ✅ GENDER: Convert DB code (M/F) to display text
        // final apiGender = apiMasterUser?['gender'];
        // if (apiGender == 'M') {
        //   _selectedGender = 'Male';
        // } else if (apiGender == 'F') {
        //   _selectedGender = 'Female';
        // } else {
        //   _selectedGender = null;
        // }

        final apiGender =
            (apiMasterUser?['gender'] ?? '').toString().toUpperCase();

        if (apiGender == 'M') {
          _selectedGender = 'Male';
        } else if (apiGender == 'F') {
          _selectedGender = 'Female';
        } else {
          _selectedGender = null;
        }

        // Address
        _addressController.text = apiMasterUser?['address'] ?? "";

        // State
        _selectedStateId = apiMasterUser?['state_id'];
        _selectedStateName = apiMasterUser?['state_name'];

        // District
        _selectedDistrictId = apiMasterUser?['district_id'];
        _selectedDistrictName = apiMasterUser?['district_name'];

        // Filter districts if state is selected
        if (_selectedStateId != null) {
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

          // Profile Image, Logo, Video, Banner Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.9,
            ),
            itemCount: 4,
            itemBuilder: (context, index) {
              switch (index) {
                case 0:
                  return MediaUploadCard(
                    title: 'Profile Image',
                    size: '500px x 500px',
                    mediaFile: _profileImage,
                    existingFile: widget.userDetails?['master_user']
                        ?['profile_pic'],
                    baseUrl: _imgBaseUrl,
                    onTap: _pickProfileImage,
                  );
                case 1:
                  return MediaUploadCard(
                    title: 'Logo',
                    size: '500px x 500px',
                    mediaFile: _logoImage,
                    existingFile: widget.userDetails?['master_user']
                        ?['profile_logo'],
                    baseUrl: _imgBaseUrl,
                    onTap: _pickLogoImage,
                  );
                case 2:
                  return MediaUploadCard(
                    title: 'Profile Video',
                    size: '500px x 500px (25 MB)',
                    mediaFile: _profileVideo,
                    existingFile: widget.userDetails?['master_user']
                        ?['profile_video'],
                    baseUrl: _imgBaseUrl,
                    onTap: _pickProfileVideo,
                    isVideo: true,
                  );
                case 3:
                  return MediaUploadCard(
                    title: 'Banner Image',
                    size: '500px x 500px',
                    mediaFile: _bannerImage,
                    existingFile: widget.userDetails?['master_user']
                        ?['profile_banner'],
                    baseUrl: _imgBaseUrl,
                    onTap: _pickBannerImage,
                  );
                default:
                  return const SizedBox();
              }
            },
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

// Media Upload Card Component - Updated with existing file support
class MediaUploadCard extends StatelessWidget {
  final String title;
  final String size;
  final XFile? mediaFile;
  final String? existingFile;
  final String baseUrl;
  final VoidCallback onTap;
  final bool isVideo;

  const MediaUploadCard({
    super.key,
    required this.title,
    required this.size,
    this.mediaFile,
    this.existingFile,
    required this.baseUrl,
    required this.onTap,
    this.isVideo = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasNewFile = mediaFile != null;
    final hasExistingFile = existingFile != null && existingFile!.isNotEmpty;
    final showPreview = hasNewFile || hasExistingFile;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? colorScheme.surfaceContainerHighest : null,
          border: isDark ? null : Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview or Icon
            SizedBox(
              width: 50,
              height: 50,
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: showPreview
                    ? _buildPreview(hasNewFile, hasExistingFile)
                    : Icon(
                        isVideo ? Icons.videocam : Icons.image,
                        color: colorScheme.onSurfaceVariant,
                        size: 24,
                      ),
              ),
            ),
            const SizedBox(height: 4),
            // Title
            Text(
              title,
              style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                  color: colorScheme.onSurface),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // Size/Status
            Text(
              hasNewFile
                  ? 'New Selected'
                  : (hasExistingFile ? 'Uploaded' : size),
              style: TextStyle(
                color: hasNewFile
                    ? Colors.green
                    : (hasExistingFile
                        ? Colors.blue
                        : colorScheme.onSurfaceVariant),
                fontSize: 10,
                fontWeight: hasNewFile || hasExistingFile
                    ? FontWeight.w500
                    : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Upload Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: hasNewFile
                    ? Colors.green.withOpacity(0.1)
                    : (hasExistingFile
                        ? Colors.blue.withOpacity(0.1)
                        : colorScheme.primary.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                hasNewFile
                    ? 'Change'
                    : (hasExistingFile ? 'Replace' : 'Upload'),
                style: TextStyle(
                  color: hasNewFile
                      ? Colors.green
                      : (hasExistingFile ? Colors.blue : colorScheme.primary),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(bool hasNewFile, bool hasExistingFile) {
    if (hasNewFile) {
      // Show newly selected file
      if (isVideo) {
        return const Icon(
          Icons.play_circle_filled,
          color: Colors.blue,
          size: 30,
        );
      } else {
        try {
          return ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.file(
              File(mediaFile!.path),
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildFallbackIcon();
              },
            ),
          );
        } catch (e) {
          return _buildFallbackIcon();
        }
      }
    } else if (hasExistingFile) {
      // Show existing file from server
      if (isVideo) {
        return const Icon(
          Icons.play_circle_filled,
          color: Colors.blue,
          size: 30,
        );
      } else {
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.network(
            '$baseUrl/$existingFile',
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildFallbackIcon();
            },
          ),
        );
      }
    }

    return _buildFallbackIcon();
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
