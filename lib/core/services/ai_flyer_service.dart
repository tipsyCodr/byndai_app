import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';

class AiFlyerService {
  static const String _baseUrl = AppConfig.apiBaseUrl;

  static Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// GET /api/flyers/occasions/today
  static Future<List<Map<String, dynamic>>> fetchTodayOccasions() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/flyers/occasions/today'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      if (jsonResponse['status'] == true && jsonResponse['data'] != null) {
        final data = jsonResponse['data'];
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } else if (data is Map) {
          if (data['occasions'] != null && (data['occasions'] as List).isNotEmpty) {
            return List<Map<String, dynamic>>.from(data['occasions']);
          } else if (data['upcoming_recommendations'] != null) {
            return List<Map<String, dynamic>>.from(data['upcoming_recommendations']);
          }
        }
      }
      return [];
    }
    throw Exception('Failed to load today occasions');
  }

  /// GET /api/flyers/categories
  static Future<Map<String, dynamic>> fetchCategoriesAndOptions() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/flyers/categories'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      if (jsonResponse['status'] == true && jsonResponse['data'] != null) {
        return Map<String, dynamic>.from(jsonResponse['data']);
      }
      return {};
    }
    throw Exception('Failed to load flyer categories');
  }

  /// POST /api/flyers/generate
  static Future<Map<String, dynamic>> generateFlyer({
    required String type, // 'occasion' or 'special'
    required String category,
    int? occasionId,
    String? language,
    String? designStyle,
    String? aspectRatio,
    String? customPrompt,
    Map<String, dynamic>? brandingToggles,
  }) async {
    String langCode = 'en';
    if (language != null) {
      final l = language.toLowerCase();
      if (l.contains('hindi') && l.contains('english')) {
        langCode = 'bilingual';
      } else if (l.contains('hindi')) {
        langCode = 'hi';
      } else {
        langCode = 'en';
      }
    }

    final body = {
      'type': type,
      'category': category,
      if (occasionId != null) 'occasion_id': occasionId,
      'language': langCode,
      if (designStyle != null) 'design_style': designStyle,
      if (aspectRatio != null) 'aspect_ratio': aspectRatio,
      if (customPrompt != null && customPrompt.trim().isNotEmpty)
        'custom_prompt': customPrompt.trim(),
      if (brandingToggles != null) ...{
        'branding_toggles': brandingToggles,
        'branding_options': brandingToggles,
      },
    };

    final response = await http.post(
      Uri.parse('$_baseUrl/flyers/generate'),
      headers: await _getHeaders(),
      body: json.encode(body),
    );

    final jsonResponse = json.decode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (jsonResponse['status'] == true) {
        return Map<String, dynamic>.from(jsonResponse['data']);
      }
    }
    final errMsg = jsonResponse['message'] ??
        (jsonResponse['errors'] != null ? json.encode(jsonResponse['errors']) : 'Failed to initiate flyer generation');
    throw Exception(errMsg);
  }

  /// GET /api/flyers/{id} - Status Polling
  static Future<Map<String, dynamic>> checkStatus(int generationId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/flyers/$generationId'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      if (jsonResponse['status'] == true && jsonResponse['data'] != null) {
        return Map<String, dynamic>.from(jsonResponse['data']);
      }
    }
    throw Exception('Failed to check flyer status');
  }

  /// GET /api/flyers/history
  static Future<Map<String, dynamic>> fetchHistory({int page = 1}) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/flyers/history?page=$page'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      if (jsonResponse['status'] == true && jsonResponse['data'] != null) {
        return Map<String, dynamic>.from(jsonResponse['data']);
      }
      return {'data': [], 'meta': {}};
    }
    throw Exception('Failed to load history');
  }

  /// POST /api/flyers/{id}/regenerate
  static Future<Map<String, dynamic>> regenerateFlyer(int id) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/flyers/$id/regenerate'),
      headers: await _getHeaders(),
    );

    final jsonResponse = json.decode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (jsonResponse['status'] == true) {
        return Map<String, dynamic>.from(jsonResponse['data']);
      }
    }
    throw Exception(jsonResponse['message'] ?? 'Failed to regenerate flyer');
  }

  /// DELETE /api/flyers/{id}
  static Future<bool> deleteFlyer(int id) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/flyers/$id'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      return jsonResponse['status'] == true;
    }
    return false;
  }

  /// GET /api/flyers/brand-kit
  static Future<Map<String, dynamic>> getBrandKit() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/flyers/brand-kit'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      if (jsonResponse['status'] == true && jsonResponse['data'] != null) {
        return Map<String, dynamic>.from(jsonResponse['data']);
      }
    }
    return {};
  }

  /// POST /api/flyers/brand-kit (Supports multipart if uploading new logo)
  static Future<Map<String, dynamic>> updateBrandKit({
    required Map<String, String> fields,
    File? logoFile,
  }) async {
    final token = await UserStorageService().getToken();
    final uri = Uri.parse('$_baseUrl/flyers/brand-kit');

    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll({
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    });

    fields.forEach((k, v) => request.fields[k] = v);

    if (logoFile != null && await logoFile.exists()) {
      request.files.add(await http.MultipartFile.fromPath('logo', logoFile.path));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final jsonResponse = json.decode(response.body);

    if (response.statusCode == 200 && jsonResponse['status'] == true) {
      return Map<String, dynamic>.from(jsonResponse['data']);
    }
    throw Exception(jsonResponse['message'] ?? 'Failed to update brand kit');
  }
}
