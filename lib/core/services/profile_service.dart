import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ProfileService {
  static const String baseUrl = AppConfig.apiBaseUrl;
  static const String _baseUrl = baseUrl;

  static Future<Map<String, String>> _getHeaders(
      {bool isMultipart = false}) async {
    final token = await UserStorageService().getToken();
    return {
      if (!isMultipart) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// GET /profile
  static Future<Map<String, dynamic>?> fetchProfile() async {
    final url = Uri.parse('$_baseUrl/profile');
    try {
      final response = await http.get(url, headers: await _getHeaders());
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('🚨 Error fetching profile: $e');
      return null;
    }
  }

  /// GET /is-pro (current logged-in user)
  static Future<Map<String, dynamic>?> fetchIsProForCurrentUser() async {
    final url = Uri.parse('$_baseUrl/is-pro');
    try {
      final response = await http.get(url, headers: await _getHeaders());
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      debugPrint('❌ fetchIsProForCurrentUser failed: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('🚨 Error fetching current user pro status: $e');
      return null;
    }
  }

  /// GET /user/{id}/is-pro
  static Future<Map<String, dynamic>?> fetchIsProForUser(int userId) async {
    final url = Uri.parse('$_baseUrl/user/$userId/is-pro');
    try {
      final response = await http.get(url, headers: await _getHeaders());
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      debugPrint('❌ fetchIsProForUser failed: ${response.statusCode} (userId=$userId)');
      return null;
    } catch (e) {
      debugPrint('🚨 Error fetching pro status for user $userId: $e');
      return null;
    }
  }

  /// POST /profile
  /// Form-data: fname, dept, desg, profile_pic (file), profile_banner (file)
  static Future<Map<String, dynamic>?> updateProfile({
    String? fname,
    String? dept,
    String? desg,
    File? profilePic,
    File? profileBanner,
  }) async {
    final url = Uri.parse('$_baseUrl/profile');
    try {
      var request = http.MultipartRequest('POST', url);
      request.headers.addAll(await _getHeaders(isMultipart: true));

      if (fname != null) request.fields['fname'] = fname;
      if (dept != null) request.fields['dept'] = dept;
      if (desg != null) request.fields['desg'] = desg;

      if (profilePic != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'profile_pic',
          profilePic.path,
          contentType: MediaType('image', 'jpeg'),
        ));
      }

      if (profileBanner != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'profile_banner',
          profileBanner.path,
          contentType: MediaType('image', 'jpeg'),
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('🚨 Error updating profile: $e');
      return null;
    }
  }

  /// GET /profile-card
  static Future<Map<String, dynamic>?> fetchProfileCard() async {
    final url = Uri.parse('$_baseUrl/profile-card');
    try {
      final response = await http.get(url, headers: await _getHeaders());
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('🚨 Error fetching profile card: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> fetchProfileCardData(String userId) async {
    final url = Uri.parse('$_baseUrl/profile-card/$userId');

    try {
      final response = await http.get(url, headers: await _getHeaders());

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Return the entire response or just the data part based on your need
        // Option 1: Return entire response
        // return responseData;

        // Option 2: Return only data field (uncomment below if needed)
        return {
          'status': responseData['status'],
          'message': responseData['message'],
          'data': responseData['data']
        };
      } else if (response.statusCode == 404) {
        debugPrint('⚠️ Profile not found for user ID: $userId');
        return {'status': false, 'message': 'Profile not found', 'data': null};
      } else {
        debugPrint('❌ Error fetching profile card. Status code: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('🚨 Error fetching profile card: $e');
      return null;
    }
  }

  /// GET /user-profile/{user_name}
static Future<Map<String, dynamic>?> fetchUserProfileByUsername(
    String userName) async {
  final encodedUserName = Uri.encodeComponent(userName);
  final url = Uri.parse('$_baseUrl/user-profile/$encodedUserName');

  try {
    final response = await http.get(
      url,
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);

      return {
        'status': responseData['status'],
        'message': responseData['message'],
        'data': responseData['data'],
      };
    }

    if (response.statusCode == 404) {
      return {
        'status': false,
        'message': 'Profile not found',
        'data': null,
      };
    }

    debugPrint(
        '❌ fetchUserProfileByUsername failed: ${response.statusCode}');
    return null;
  } catch (e) {
    debugPrint('🚨 Error fetching user profile by username: $e');
    return null;
  }
}


  /// GET /links
  static Future<Map<String, dynamic>?> fetchLinks() async {
    final url = Uri.parse('$_baseUrl/links');
    try {
      final response = await http.get(url, headers: await _getHeaders());
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('🚨 Error fetching links: $e');
      return null;
    }
  }

  /// POST /links (Create)
  static Future<Map<String, dynamic>?> createLink(
      Map<String, dynamic> data) async {
    final url = Uri.parse('$_baseUrl/links');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('🚨 Error creating link: $e');
      return null;
    }
  }

  /// PUT /links (Update)
  static Future<Map<String, dynamic>?> updateLink(
      int linkId, Map<String, dynamic> data) async {
    final url = Uri.parse(
        '$_baseUrl/links'); // Assuming POST with link_id or actual PUT
    // The guide says GET|POST|PUT|DELETE /links
    try {
      final response = await http.put(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({...data, 'link_id': linkId}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('🚨 Error updating link: $e');
      return null;
    }
  }

  /// DELETE /links
  static Future<bool> deleteLink(int linkId) async {
    final url = Uri.parse('$_baseUrl/links');
    try {
      final response = await http.delete(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'link_id': linkId}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('🚨 Error deleting link: $e');
      return false;
    }
  }

  /// GET /business-info
  static Future<Map<String, dynamic>?> fetchBusinessInfo() async {
    final url = Uri.parse('$_baseUrl/business-info');
    try {
      final response = await http.get(url, headers: await _getHeaders());
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('🚨 Error fetching business info: $e');
      return null;
    }
  }

  

  /// POST /business-info
  /// Form-data: company_name, gst_no, address, bank_acc_no, ifsc_code, branch_name, payment_qr (image)
  static Future<Map<String, dynamic>?> updateBusinessInfo({
    required Map<String, String> fields,
    File? paymentQr,
  }) async {
    final url = Uri.parse('$_baseUrl/business-info');
    try {
      var request = http.MultipartRequest('POST', url);
      request.headers.addAll(await _getHeaders(isMultipart: true));

      request.fields.addAll(fields);

      if (paymentQr != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'payment_qr',
          paymentQr.path,
          contentType: MediaType('image', 'jpeg'),
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('🚨 Error updating business info: $e');
      return null;
    }
  }

  /// GET /user-videos/{user_id}
  static Future<Map<String, dynamic>?> fetchUserVideos(int userId) async {
    final url = Uri.parse('$_baseUrl/user-videos/$userId');
    try {
      final response = await http.get(url, headers: await _getHeaders());
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('🚨 Error fetching user videos: $e');
      return null;
    }
  }

  /// POST /user-videos
  static Future<bool> addUserVideo(Map<String, dynamic> videoData) async {
    final url = Uri.parse('$_baseUrl/user-videos');
    final headers = await _getHeaders();
    debugPrint('🎥 POST Add Video: $url');
    debugPrint('🎥 Headers: $headers');
    debugPrint('🎥 Body: ${jsonEncode(videoData)}');

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(videoData),
      );
      debugPrint('🎥 Response Status: ${response.statusCode}');
      debugPrint('🎥 Response Body: ${response.body}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('🚨 Error adding user video: $e');
      return false;
    }
  }

  /// PUT /user-videos/{id}
  static Future<bool> updateUserVideo(int videoId, Map<String, dynamic> videoData) async {
    final url = Uri.parse('$_baseUrl/user-videos/$videoId');
    final headers = await _getHeaders();
    debugPrint('🎥 PUT Update Video: $url');
    debugPrint('🎥 Body: ${jsonEncode(videoData)}');

    try {
      final response = await http.put(
        url,
        headers: headers,
        body: jsonEncode(videoData),
      );
      debugPrint('🎥 Response Status: ${response.statusCode}');
      debugPrint('🎥 Response Body: ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('🚨 Error updating user video: $e');
      return false;
    }
  }

  /// DELETE /user-videos/{id}
  static Future<bool> deleteUserVideo(int id) async {
    final url = Uri.parse('$_baseUrl/user-videos/$id');
    try {
      final response = await http.delete(url, headers: await _getHeaders());
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('🚨 Error deleting user video: $e');
      return false;
    }
  }

  /// GET /user/subscription
  static Future<Map<String, dynamic>?> fetchUserSubscription() async {
    final url = Uri.parse('$_baseUrl/user/subscription');
    try {
      final response = await http.get(url, headers: await _getHeaders());
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('🚨 Error fetching subscription: $e');
      return null;
    }
  }

  /// POST /search-users
  static Future<List<dynamic>> searchUsers(String query) async {
    final url = Uri.parse('$_baseUrl/search-users');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'keywords': query,
          'keyword': query,
        }),
      );
      
      debugPrint("🔍 [API] POST /search-users | Query: $query");
      debugPrint("🔍 [API] Status: ${response.statusCode}");
      debugPrint("🔍 [API] Response: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true) {
          final results = data['data'] ?? [];
          return results;
        }
      }
      return [];
    } catch (e) {
      debugPrint('🚨 Error searching users: $e');
      return [];
    }
  }
  /// GET /profile/id-card
  static Future<Map<String, dynamic>?> getIdCards() async {
    final url = Uri.parse('$_baseUrl/profile/id-card');
    debugPrint('🔍 [API] GET $url');
    try {
      final response = await http.get(url, headers: await _getHeaders());
      debugPrint('📥 Status: ${response.statusCode}');
      debugPrint('📥 Response: ${response.body}');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('🚨 Error fetching ID cards: $e');
      return null;
    }
  }

  /// POST /profile/id-card
  static Future<Map<String, dynamic>?> uploadIdCard({
    required String type, // 'bni' or 'jci'
    required List<int> imageBytes,
    String filename = 'id_card.jpg',
  }) async {
    final url = Uri.parse('$_baseUrl/profile/id-card');
    debugPrint('📤 [API] POST $url');
    try {
      var request = http.MultipartRequest('POST', url);
      request.headers.addAll(await _getHeaders(isMultipart: true));

      request.fields['type'] = type.toLowerCase();
      debugPrint('📤 Fields: ${request.fields}');

      request.files.add(http.MultipartFile.fromBytes(
        'id_card',
        imageBytes,
        filename: filename,
        contentType: MediaType('image', 'jpeg'),
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('📥 Status: ${response.statusCode}');
      debugPrint('📥 Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('🚨 Error uploading ID card: $e');
      return null;
    }
  }
}
