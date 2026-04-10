import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gridcard/core/services/profile_service.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:http/http.dart' as http;

class ProfileProvider extends ChangeNotifier {
  Map<String, dynamic>? _myProfileData;
  Map<String, dynamic>? _profileData;
  String? _targetProfileId; // Current target ID being viewed/fetched

  Map<String, dynamic>? _profileCard;
  Map<String, dynamic>? _businessInfo;
  List<dynamic> _links = [];
  List<Map<String, dynamic>> _masterLinks = [];
  List<dynamic> _products = [];
  List<dynamic> _reviews = [];
  List<Map<String, dynamic>> _userVideos = [];
  double _avgRating = 0.0;
  int _totalReviews = 0;
  bool _isLoading = false;
  bool _isLoadingMasterLinks = false;
  bool _isLoadingProducts = false;
  bool _isLoadingReviews = false;
  bool _isLoadingVideos = false;
  bool? _isProUser;

  Map<String, dynamic>? get myProfileData => _myProfileData;
  Map<String, dynamic>? get profileData => _profileData;
  String? get targetProfileId => _targetProfileId;
  Map<String, dynamic>? get businessInfo => _businessInfo;
  Map<String, dynamic>? get profileCard => _profileCard;
  List<dynamic> get links => _links;
  List<Map<String, dynamic>> get masterLinks => _masterLinks;
  List<dynamic> get products => _products;
  List<dynamic> get reviews => _reviews;
  List<Map<String, dynamic>> get userVideos => _userVideos;
  double get avgRating => _avgRating;
  int get totalReviewsCount => _totalReviews;
  bool get isLoading => _isLoading;
  bool get isLoadingMasterLinks => _isLoadingMasterLinks;
  bool get isLoadingProducts => _isLoadingProducts;
  bool get isLoadingReviews => _isLoadingReviews;
  bool get isLoadingVideos => _isLoadingVideos;
  bool? get isProUser => _isProUser;

  Future<void> fetchProfileCard() async {
    _isLoading = true;
    notifyListeners();

    final result = await ProfileService.fetchProfileCard();

    if (result != null) {
      _profileCard = result['data'] ?? result;
    }

    _isLoading = false;
    notifyListeners();
  }

  // Future<void> fetchAllProfileData() async {
  //   _isLoading = true;
  //   notifyListeners();

  //   final profile = await ProfileService.fetchProfile();
  //   if (profile != null) _profileData = profile['data'] ?? profile;

  //   final business = await ProfileService.fetchBusinessInfo();
  //   if (business != null) _businessInfo = business['data'] ?? business;

  //   final linksData = await ProfileService.fetchLinks();
  //   if (linksData != null) {
  //     _links = linksData['data'] is List ? linksData['data'] : [];
  //   }

  //   _isLoading = false;
  //   notifyListeners();
  // }

  Future<void> fetchAllProfileData() async {
    _isLoading = true;
    notifyListeners();

    // Fetch profile data
    final profile = await ProfileService.fetchProfile();
    if (profile != null) {
      debugPrint("ProfileProvider: profile: ${profile['data']}");
      _myProfileData = profile['data'] ?? profile;
      _profileData = _myProfileData; // Also set as current profile
    }

    // Fetch business info (backend returns data as array)
    final business = await ProfileService.fetchBusinessInfo();
    if (business != null) {
      var businessData = business['data'] ?? business;
      // 🔥 FIX: If it's a list with at least one item, take the first item as map
      if (businessData is List && businessData.isNotEmpty) {
        businessData = businessData[0] as Map<String, dynamic>;
      }
      _businessInfo = businessData;
    }

    // Fetch links
    final linksData = await ProfileService.fetchLinks();
    if (linksData != null) {
      _links = linksData['data'] is List ? linksData['data'] : [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchProfileData(String userId) async {
    // If we are switching users, clear the current profile data to avoid "flicker"
    if (_targetProfileId != userId) {
      _profileData = null;
      _masterLinks = [];
      _products = [];
      _reviews = [];
      _userVideos = [];
      _avgRating = 0.0;
      _totalReviews = 0;
    }

    _targetProfileId = userId;
    _isLoading = true;
    Future.microtask(() => notifyListeners());

    try {
      final response = await ProfileService.fetchProfileCardData(userId);

      if (response != null && response['status'] == true) {
        _profileData = response['data'];

        // 🔥 Fetch Business Info specifically using the API endpoint
        try {
          final busiRes = await _get("$baseUrl/business-info-by-user/$userId");
          if (busiRes != null && busiRes['status'] == true) {
            var busiData = busiRes['data'];
            if (busiData is List && busiData.isNotEmpty) {
              busiData = busiData[0] as Map<String, dynamic>;
            }
            _profileData!['business_info'] = busiData;
            debugPrint('📋 Extracted business_info from API: $busiData');
          }
        } catch (e) {
          debugPrint('⚠️ Error fetching business info: $e');
        }

        // 🔍 Debug: log the actual profile data keys for troubleshooting
        if (_profileData != null) {
          debugPrint('📋 FULL PROFILE JSON: ${jsonEncode(_profileData)}');
          debugPrint('📋 Profile keys: ${_profileData!.keys.toList()}');
          debugPrint('📋 business_name: ${_profileData!['business_name']}');
          debugPrint('📋 busi_type: ${_profileData!['busi_type']}');
          debugPrint('📋 category: ${_profileData!['category']}');
          debugPrint(
              '📋 business_info type: ${_profileData!['business_info']?.runtimeType}');
          debugPrint('📋 business_info: ${_profileData!['business_info']}');
          debugPrint('📋 address: ${_profileData!['address']}');
          debugPrint('📋 city: ${_profileData!['city']}');
          debugPrint('📋 state: ${_profileData!['state']}');
          debugPrint('📋 dept: ${_profileData!['dept']}');
          debugPrint('📋 desg: ${_profileData!['desg']}');
          final userSub = _profileData!['user'];
          if (userSub is Map) {
            debugPrint('📋 user keys: ${userSub.keys.toList()}');
            debugPrint('📋 user.user_name: ${userSub['user_name']}');
            debugPrint('📋 user.business_name: ${userSub['business_name']}');
            debugPrint('📋 user.company_name: ${userSub['company_name']}');
          }
        }
      } else {
        _profileData = null;
        debugPrint('⚠️ Profile data empty or status false');
      }
    } catch (e) {
      debugPrint('🚨 Provider error while fetching profile: $e');
      _profileData = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchProStatus({
    required int userId,
    required bool isOwner,
  }) async {
    try {
      Map<String, dynamic>? response;
      if (isOwner) {
        response = await ProfileService.fetchIsProForCurrentUser();
      } else {
        response = await ProfileService.fetchIsProForUser(userId);
      }

      if (response != null && response['status'] == true) {
        final isProRaw = response['is_pro'];
        final asString = isProRaw?.toString().toLowerCase().trim();
        _isProUser = isProRaw == true || asString == '1' || asString == 'true';
        debugPrint(
          'PRO API CHECK: is_pro=$_isProUser, plan_name=${response['plan_name']}, userId=$userId, isOwner=$isOwner',
        );
      } else {
        debugPrint('PRO API CHECK: response unavailable for userId=$userId');
        _isProUser = null;
      }
    } catch (e) {
      debugPrint('PRO API CHECK: error for userId=$userId -> $e');
      _isProUser = null;
    }
    notifyListeners();
  }

  Future<bool> updateProfile({
    String? fname,
    String? dept,
    String? desg,
    File? profilePic,
    File? profileBanner,
  }) async {
    _isLoading = true;
    notifyListeners();
    final result = await ProfileService.updateProfile(
      fname: fname,
      dept: dept,
      desg: desg,
      profilePic: profilePic,
      profileBanner: profileBanner,
    );
    if (result != null) {
      _profileData = result['data'] ?? result;
      _isLoading = false;
      notifyListeners();
      return true;
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Future<bool> updateBusinessInfo({
  //   required Map<String, String> fields,
  //   File? paymentQr,
  // }) async {
  //   _isLoading = true;
  //   notifyListeners();
  //   final result = await ProfileService.updateBusinessInfo(
  //     fields: fields,
  //     paymentQr: paymentQr,
  //   );
  //   if (result != null) {
  //     _businessInfo = result['data'] ?? result;
  //     _isLoading = false;
  //     notifyListeners();
  //     return true;
  //   }
  //   _isLoading = false;
  //   notifyListeners();
  //   return false;
  // }

  Future<bool> updateBusinessInfo({
    required Map<String, String> fields,
    File? paymentQr,
  }) async {
    _isLoading = true;
    notifyListeners();
    final result = await ProfileService.updateBusinessInfo(
      fields: fields,
      paymentQr: paymentQr,
    );
    if (result != null) {
      var businessData = result['data'] ?? result;
      // 🔥 Same fix: handle possible list response
      if (businessData is List && businessData.isNotEmpty) {
        businessData = businessData[0] as Map<String, dynamic>;
      }
      _businessInfo = businessData;
      _isLoading = false;
      notifyListeners();
      return true;
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> createLink(Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();
    final result = await ProfileService.createLink(data);
    if (result != null) {
      await fetchAllProfileData(); // Refresh links
      if (_targetProfileId != null) {
        await fetchMasterLinks(int.parse(_targetProfileId!));
      }
      return true;
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> updateLink(int linkId, Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();
    final result = await ProfileService.updateLink(linkId, data);
    if (result != null) {
      await fetchAllProfileData(); // Refresh links
      if (_targetProfileId != null) {
        await fetchMasterLinks(int.parse(_targetProfileId!));
      }
      return true;
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> deleteLink(int linkId) async {
    _isLoading = true;
    notifyListeners();
    final result = await ProfileService.deleteLink(linkId);
    if (result) {
      await fetchAllProfileData(); // Refresh links
      if (_targetProfileId != null) {
        await fetchMasterLinks(int.parse(_targetProfileId!));
      }
      return true;
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Fetch user profile by username (public profile)
  Future<bool> fetchUserProfileByUsername(String userName) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response =
          await ProfileService.fetchUserProfileByUsername(userName);

      if (response != null && response['status'] == true) {
        _profileData = response['data'];
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _profileData = null;
        debugPrint('⚠️ Profile not found for username: $userName');
      }
    } catch (e) {
      debugPrint('🚨 Provider error (fetchUserProfileByUsername): $e');
      _profileData = null;
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> fetchMasterLinks(int userId) async {
    _isLoadingMasterLinks = true;
    Future.microtask(() => notifyListeners());
    try {
      final response = await _get("$baseUrl/user/$userId/master-links");
      if (response != null && response['status'] == true) {
        _masterLinks = List<Map<String, dynamic>>.from(response['data'] ?? []);
      }
    } finally {
      _isLoadingMasterLinks = false;
      notifyListeners();
    }
  }

  Future<void> fetchProducts(int userId) async {
    _isLoadingProducts = true;
    Future.microtask(() => notifyListeners());
    try {
      // 🔥 Primary: Use GET /products-by-user/{user_id} (per updated API docs)
      final response = await _get("$baseUrl/products-by-user/$userId");

      Map<String, dynamic>? finalResponse = response;

      if (finalResponse != null) {
        final data = finalResponse['data'] ?? finalResponse;
        if (data is List) {
          _products = List<dynamic>.from(data);
        } else if (data is Map) {
          final list = data['data'] ?? data['products'] ?? [];
          _products = List<dynamic>.from(list is List ? list : []);
        } else {
          _products = [];
        }
      }
      debugPrint('📦 Products loaded: ${_products.length}');
    } catch (e) {
      debugPrint('🚨 fetchProducts error: $e');
    } finally {
      _isLoadingProducts = false;
      notifyListeners();
    }
  }

  Future<bool> toggleConnection(int receiverId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = await UserStorageService().getToken();
      final response = await http.post(
        Uri.parse("$baseUrl/connection-create"),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'receiver_id': receiverId}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("ProfileProvider: toggleConnection error: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  static const String baseUrl = ProfileService.baseUrl;

  Future<void> fetchReviews(int userId) async {
    _isLoadingReviews = true;
    Future.microtask(() => notifyListeners());
    try {
      final response = await _get("$baseUrl/user-reviews/$userId");
      debugPrint('📝 Reviews response: $response');
      if (response != null &&
          (response['status'] == true || response['success'] == true)) {
        final data = response['data'];
        if (data is List) {
          _reviews = List<dynamic>.from(data);
        } else if (data is Map) {
          // Handle common keys like 'reviews' or 'data' sub-key
          final potentialList = data['reviews'] ?? data['data'];
          _reviews =
              List<dynamic>.from(potentialList is List ? potentialList : []);
        } else {
          _reviews = [];
        }
        if (_reviews.isNotEmpty) {
          debugPrint(
              '📝 First review keys: ${_reviews[0] is Map ? (_reviews[0] as Map).keys.toList() : "not a map"}');
          debugPrint('📝 First review: ${_reviews[0]}');
        }
      }

      final avgRes = await _get("$baseUrl/user-reviews/$userId/average");
      if (avgRes != null && avgRes['status'] == true) {
        _avgRating = double.tryParse(
                avgRes['data']?['average_rating']?.toString() ?? "0") ??
            0.0;
        _totalReviews =
            int.tryParse(avgRes['data']?['total_reviews']?.toString() ?? "0") ??
                0;
      }
    } finally {
      _isLoadingReviews = false;
      notifyListeners();
    }
  }

  Future<String?> submitReview({
    required int profileId,
    required int rating,
    required String message,
  }) async {
    _isLoadingReviews = true;
    notifyListeners();

    try {
      final token = await UserStorageService().getToken();
      final response = await http.post(
        Uri.parse("$baseUrl/user-reviews"),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'to_user_id': profileId,
          'rating': rating,
          'message': message,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchReviews(profileId); // Refresh reviews
        return null; // Success
      }
      return data['message'] ?? "Couldn't post review. Please try again.";
    } catch (e) {
      debugPrint("ProfileProvider: submitReview error: $e");
      return "An unexpected error occurred. Please try again.";
    } finally {
      _isLoadingReviews = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> _get(String url) async {
    try {
      final token = await UserStorageService().getToken();
      final response = await http.get(Uri.parse(url), headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });
      debugPrint('🌐 GET $url → ${response.statusCode}');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint('🌐 Response body: ${response.body}');
      }
    } catch (e) {
      debugPrint("ProfileProvider: _get error for $url: $e");
    }
    return null;
  }

  Future<void> fetchUserVideos(int userId) async {
    _targetProfileId = userId.toString();
    _isLoadingVideos = true;
    Future.microtask(() => notifyListeners());
    try {
      final response = await ProfileService.fetchUserVideos(userId);
      debugPrint('🎥 GET User Videos Response: $response');
      if (response != null && response['status'] == true) {
        final data = response['data'];
        if (data is List) {
          _userVideos = List<Map<String, dynamic>>.from(data);
        } else if (data is Map) {
          final list = data['data'] ?? [];
          _userVideos =
              List<Map<String, dynamic>>.from(list is List ? list : []);
        }
        debugPrint('🎥 Parsed Videos Count: ${_userVideos.length}');
        if (_userVideos.isNotEmpty) {
          debugPrint('🎥 First Video Keys: ${_userVideos.first.keys}');
        }
      }
    } finally {
      _isLoadingVideos = false;
      notifyListeners();
    }
  }

  Future<bool> addUserVideo(Map<String, dynamic> data) async {
    _isLoadingVideos = true;
    notifyListeners();
    try {
      final success = await ProfileService.addUserVideo(data);
      if (success) {
        if (_targetProfileId != null) {
          await fetchUserVideos(int.parse(_targetProfileId!));
        }
        return true;
      }
      return false;
    } finally {
      _isLoadingVideos = false;
      notifyListeners();
    }
  }

  Future<bool> updateUserVideo(int videoId, Map<String, dynamic> data) async {
    _isLoadingVideos = true;
    notifyListeners();
    try {
      final success = await ProfileService.updateUserVideo(videoId, data);
      if (success) {
        if (_targetProfileId != null) {
          await fetchUserVideos(int.parse(_targetProfileId!));
        }
        return true;
      }
      return false;
    } finally {
      _isLoadingVideos = false;
      notifyListeners();
    }
  }

  void reorderVideos(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = _userVideos.removeAt(oldIndex);
    _userVideos.insert(newIndex, item);
    notifyListeners();
    // Persistence would require a sorting API
  }

  Future<bool> deleteUserVideo(int id) async {
    _isLoadingVideos = true;
    notifyListeners();
    try {
      final success = await ProfileService.deleteUserVideo(id);
      if (success) {
        if (_targetProfileId != null) {
          await fetchUserVideos(int.parse(_targetProfileId!));
        }
        return true;
      }
      return false;
    } finally {
      _isLoadingVideos = false;
      notifyListeners();
    }
  }

  Future<bool> checkConnectionStatus(int targetUserId) async {
    final session = await UserStorageService().loadSession();
    final viewerId = session.user?.id;
    if (viewerId == null) return false;

    try {
      // Use the friends list API with a search query for the specific user
      final url = "$baseUrl/friends/$viewerId?search=$targetUserId&per_page=1";
      final response = await _get(url);
      
      if (response != null && response['status'] == true) {
        final List data = response['data'] ?? [];
        // If data is not empty, it means this user was found in our friends list
        if (data.isNotEmpty) {
          // Double check the ID matches to be safe
          final firstFriend = data[0];
          final friendId = int.tryParse((firstFriend['friend_id'] ?? firstFriend['id'] ?? '0').toString());
          if (friendId == targetUserId) {
             _profileData?['connection_status'] = 'accepted';
             notifyListeners();
             return true;
          }
        }
      }
    } catch (e) {
       debugPrint("🚨 Error checking connection status fallback: $e");
    }
    return false;
  }
}

// In ProfileProvider, I used http and jsonDecode, so I need to import them.
