import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/models/login_response.dart';
import 'package:gridcard/models/user_model.dart';
import 'package:http/http.dart' as http;

class AuthService {
  static const String _baseUrl = AppConfig.apiBaseUrl;

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
        debugPrint('🔹 Response: ${response.body}');
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
      debugPrint('⚠️ API Error: ${responseBody['message'] ?? 'Unknown error'}');
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
}
