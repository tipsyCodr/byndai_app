import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';

class FlyerService {
  static const String _baseUrl = AppConfig.apiBaseUrl;

  static Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Fetch upcoming festive occasions
  /// [date] format: MM-DD
  static Future<List<Map<String, dynamic>>> fetchUpcoming({String? date}) async {
    final query = date != null ? '?date=$date' : '';
    final url = '$_baseUrl/flyers/upcoming$query';
    
    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      debugPrint("API Response ($url): ${response.body}");
      if (jsonResponse['status'] == true) {
        return List<Map<String, dynamic>>.from(jsonResponse['data']);
      }
      return [];
    } else {
      throw Exception("Failed to load upcoming occasions");
    }
  }

  /// Fetch all flyers categorized (Misc section)
  static Future<List<Map<String, dynamic>>> fetchAll() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/flyers'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      if (jsonResponse['status'] == true) {
        return List<Map<String, dynamic>>.from(jsonResponse['data']);
      }
      return [];
    } else {
      throw Exception("Failed to load flyer categories");
    }
  }

  /// Fetch flyers for a specific category id
  static Future<List<String>> fetchByCategory(int categoryId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/flyers/category/$categoryId'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      if (jsonResponse['status'] == true) {
        final data = jsonResponse['data'] as List;
        return data.map((e) => e['image_path'].toString()).toList();
      }
      return [];
    } else {
      throw Exception("Failed to load category flyers");
    }
  }
}
