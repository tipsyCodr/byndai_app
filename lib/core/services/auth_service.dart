import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/models/login_response.dart';
import 'package:gridcard/models/user_model.dart';
import 'package:http/http.dart' as http;
import 'package:gridcard/core/services/user_storage_service.dart';

class AuthService {
  static const String _baseUrl = AppConfig.apiBaseUrl;

  /// Stores the last error message from the backend for callers to read
  static String? lastError;

  /// Check if email already exists or not
  static Future<bool?> checkEmailAvailability(String email) async {
    final response = await _post(
      'check-email',
      {'email': email},
    );

    // Agar response mila aur status true hai
    if (response != null && response['status'] == true) {
      // Backend se 'exists' flag aa raha hai
      final bool exists = response['exists'] == true;

      // Agar exists true → email already registered
      // Agar exists false → email available
      return !exists;
    }

    // Agar null aaya → API error
    return null;
  }

  /// A centralized POST request handler.
  static Future<Map<String, dynamic>?> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse('$_baseUrl/$endpoint');
    try {
      if (kDebugMode) {
        debugPrint('🔹 POST $url');
        debugPrint('🔹 Body: $body');
      }

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: jsonEncode(body),
      );

      if (kDebugMode) {
        debugPrint('🔹 Status: ${response.statusCode}');
        debugPrint('🔹 Response_Data: ${response.body}');
      }

      final responseBody = jsonDecode(response.body);
      if (responseBody is! Map<String, dynamic>) {
        debugPrint('❌ Unexpected response format.');
        return null;
      }

      // A successful response can be indicated by a 2xx status code
      // and/or a 'status' or 'success' flag in the response body.
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final bool isSuccessByFlag =
            responseBody['status'] == true || responseBody['success'] == true;

        // Some endpoints like register return 201 without a success flag.
        if (isSuccessByFlag || response.statusCode == 201) {
          return responseBody;
        }
      }

      // If we reach here, it's an API-level error.
      final errorMsg = responseBody['message']?.toString() ?? 'Unknown error';
      debugPrint('⚠️ API Error: $errorMsg');

      // Map known errors to friendly messages
      if (errorMsg.contains('Duplicate entry') && errorMsg.contains('mobile')) {
        lastError = 'Mobile number already registered';
      } else if (errorMsg.contains('Duplicate entry') &&
          errorMsg.contains('email')) {
        lastError = 'Email already registered';
      } else if (errorMsg.contains('Duplicate entry')) {
        lastError = 'Account already exists';
      } else {
        lastError = errorMsg;
      }

      Fluttertoast.showToast(msg: lastError!);
      return null;
    } catch (e) {
      debugPrint('🚨 Exception on POST $url: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getResetOtp(String mobile) async {
    return await _post('reset-pin-otp', {'phone_no': mobile});
  }

  static Future<Map<String, dynamic>?> getOTP(String mobile) async {
    return await _post('check-mobile', {'phone_no': mobile});
  }

  static Future<Map<String, dynamic>?> verifyOTP(
      String mobile, String token, String otp) async {
    return await _post('verify-otp/$mobile/$token', {'otp': otp});
  }

  static Future<LoginResponse?> login(String email, String password) async {
    final json = await _post('login', {'email': email, 'password': password});
    return json != null ? LoginResponse.fromJson(json) : null;
  }

  static Future<bool> isRegistered(String mobile) async {
    final response = await _post('login/phone/check', {'phone_no': mobile});
    return response != null;
  }

  static Future<bool> checkPin(String mobile) async {
    final response = await _post('login/pin/check', {'phone_no': mobile});
    return response != null;
  }

  static Future<bool> setPin(String mobile, String pin) async {
    final response =
        await _post('login/pin/set', {'phone_no': mobile, 'pin': pin});
    return response != null;
  }

  static Future<LoginResponse?> loginWithPin(String mobile, String pin) async {
    final json = await _post('login/pin', {'phone_no': mobile, 'pin': pin});
    if (json == null) return null;

    // The response for loginWithPin might be structured differently.
    // We manually construct the LoginResponse if the structure is known.
    if (json['user'] != null && json['token'] != null) {
      return LoginResponse(
        token: json['token'],
        user: UserModel.fromJson(json['user']),
      );
    }
    return null;
  }

  static Future<UserModel?> register(Map<String, dynamic> data) async {
    final token = data['token'];
    final phone = data['mobile'];

    if (phone == null || token == null) {
      debugPrint('❌ Registration failed: Missing phone or token.');
      return null;
    }

    final json = await _post('registration/$phone/$token', data);
    return (json != null && json['user'] != null)
        ? UserModel.fromJson(json['user'])
        : null;
  }

  /// Check if username already exists or not
  static Future<bool?> checkUsernameAvailability(String userName) async {
    final response = await _post(
      'check-username',
      {'user_name': userName},
    );

    // response != null ka matlab:
    // statusCode 200 + status=true (username available)
    if (response != null && response['status'] == true) {
      return true; // ✅ available
    }

    // agar null aaya to ya to 422 error hai ya exception
    return false; // ❌ already exists
  }

  static Future<Map<String, dynamic>?> getSubscriptionDetails() async {
    final token = await UserStorageService().getToken();
    if (token == null) return null;

    final url = Uri.parse('$_baseUrl/user/subscription');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      final json = jsonDecode(response.body);

      if (response.statusCode == 200 && json['status'] == true) {
        return json['data'];
      }
    } catch (e) {
      debugPrint("Subscription API error: $e");
    }

    return null;
  }

  static Future<LoginResponse?> registerWithToken(
      Map<String, dynamic> data) async {
    final token = data['token'];
    final phone = data['mobile'];

    if (phone == null || token == null) {
      debugPrint('❌ Registration failed: Missing phone or token.');
      return null;
    }

    final json = await _post('registration/$phone/$token', data);
    if (json == null) return null;

    // ✅ Case 1: Backend returns token + user
    if (json['user'] != null && json['token'] != null) {
      return LoginResponse(
        token: json['token'],
        user: UserModel.fromJson(json['user']),
      );
    }

    // ✅ Case 2: Backend returns only user, token missing → use OTP token
    if (json['user'] != null) {
      return LoginResponse(
        token: token,
        user: UserModel.fromJson(json['user']),
      );
    }

    return null;
  }

  /// Google sign-in: sends ID token + profile to backend
  static Future<Map<String, dynamic>?> googleLogin({
    required String idToken,
    required String email,
    required String name,
  }) async {
    return await _post('google-login', {
      'id_token': idToken,
      'email': email,
      'name': name,
    });
  }

  /// Register a Google user (uses google_id_token instead of OTP token)
  static Future<LoginResponse?> registerGoogleUser(
      Map<String, dynamic> data) async {
    final json = await _post('google-register', data);
    if (json == null) return null;

    if (json['user'] != null && json['token'] != null) {
      return LoginResponse(
        token: json['token'],
        user: UserModel.fromJson(json['user']),
      );
    }

    if (json['user'] != null) {
      return LoginResponse(
        token: data['id_token'] ?? '',
        user: UserModel.fromJson(json['user']),
      );
    }

    return null;
  }

  /// Sync FCM token with backend
  static Future<void> updateFCMToken(String fcmToken) async {
    final token = await UserStorageService().getToken();
    if (token == null) return;

    final url = Uri.parse('$_baseUrl/update-fcm-token');
    try {
      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'fcm_token': fcmToken}),
      );
    } catch (e) {
      debugPrint('🚨 Error updating FCM token: $e');
    }
  }
}
