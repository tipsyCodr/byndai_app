import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class SocialService {
  static const String _baseUrl = AppConfig.apiBaseUrl;
  static const _storage = FlutterSecureStorage();

  static Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'token');
    return {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// GET /show-postby-industry/{indus_type}
  static Future<List<dynamic>> fetchPosts(String industryType) async {
    final url = Uri.parse('$_baseUrl/show-postby-industry/$industryType');
    try {
      final response = await http.get(url, headers: await _getHeaders());
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) return data;
        if (data is Map && data['data'] != null) return data['data'];
      }
      return [];
    } catch (e) {
      debugPrint('🚨 Error fetching posts: $e');
      return [];
    }
  }

  /// POST /create-post
  /// Body: { "description", "image" }
  static Future<bool> createPost({
    required String description,
    File? image,
  }) async {
    final url = Uri.parse('$_baseUrl/create-post');
    try {
      var request = http.MultipartRequest('POST', url);
      request.headers.addAll(await _getHeaders());

      request.fields['description'] = description;

      if (image != null) {
        final stream = http.ByteStream(image.openRead());
        final length = await image.length();
        final multipartFile = http.MultipartFile(
          'image',
          stream,
          length,
          filename: image.path.split('/').last,
          contentType: MediaType('image', 'jpeg'),
        );
        request.files.add(multipartFile);
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('🚨 Error creating post: $e');
      return false;
    }
  }

  /// POST /toggle-like/{post_id}
  static Future<bool> toggleLike(int postId) async {
    final url = Uri.parse('$_baseUrl/toggle-like/$postId');
    try {
      final response = await http.post(url, headers: await _getHeaders());
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('🚨 Error toggling like: $e');
      return false;
    }
  }

  /// POST /save-post/{post_id}
  static Future<bool> toggleSave(int postId) async {
    final url = Uri.parse('$_baseUrl/save-post/$postId');
    try {
      final response = await http.post(url, headers: await _getHeaders());
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('🚨 Error toggling save: $e');
      return false;
    }
  }

  /// GET /comment/{post_id}
  static Future<List<dynamic>> fetchComments(int postId) async {
    final url = Uri.parse('$_baseUrl/comment/$postId');
    try {
      final response = await http.get(url, headers: await _getHeaders());
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) return data;
        if (data is Map && data['data'] != null) return data['data'];
      }
      return [];
    } catch (e) {
      debugPrint('🚨 Error fetching comments: $e');
      return [];
    }
  }

  /// POST /comment
  /// Body: { "post_id", "comment" }
  static Future<bool> addComment(int postId, String comment) async {
    final url = Uri.parse('$_baseUrl/comment');
    try {
      final headers = await _getHeaders();
      headers['Content-Type'] = 'application/json';
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'post_id': postId, 'comment': comment}),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('🚨 Error adding comment: $e');
      return false;
    }
  }
}
