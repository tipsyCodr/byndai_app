import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:http/http.dart' as http;

class ChatService {
  static const String _baseUrl = AppConfig.apiBaseUrl;
  static const _storage = FlutterSecureStorage();

  static Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// GET /connection-show
  static Future<List<dynamic>> fetchConnections() async {
    final url = Uri.parse('$_baseUrl/connection-show');
    try {
      final response = await http.get(url, headers: await _getHeaders());
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) return data;
        if (data is Map && data['data'] != null) return data['data'];
      }
      return [];
    } catch (e) {
      debugPrint('🚨 Error fetching connections: $e');
      return [];
    }
  }

  /// POST /connection-create
  /// Body: { "request_to": user_id }
  static Future<bool> createConnection(int userId) async {
    final url = Uri.parse('$_baseUrl/connection-create');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'request_to': userId}),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('🚨 Error creating connection: $e');
      return false;
    }
  }

  /// POST /chat/send-message
  /// Body: { "chat_id", "message" }
  static Future<bool> sendMessage(int chatId, String message) async {
    final url = Uri.parse('$_baseUrl/chat/send-message');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'chat_id': chatId, 'message': message}),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('🚨 Error sending message: $e');
      return false;
    }
  }

  //amit code start

  /// POST /connection-request
  static Future<Map<String, dynamic>?> sendConnectionRequest(
      int receiverId) async {
    final url = Uri.parse('$_baseUrl/connection-request');

    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'receiver_id': receiverId,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return data; // success response
      }

      // ❌ handled backend errors (409, 400 etc.)
      return data;
    } catch (e) {
      debugPrint('🚨 Error sending connection request: $e');
      return null;
    }
  }
}
