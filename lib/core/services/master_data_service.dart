import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:http/http.dart' as http;

class MasterDataService {
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

  /// GET /master-country
  static Future<List<dynamic>> fetchCountries() async {
    final url = Uri.parse('$_baseUrl/master-country');
    try {
      final response = await http.get(url, headers: await _getHeaders());
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) return data;
        if (data is Map && data['data'] != null) return data['data'];
      }
      return [];
    } catch (e) {
      debugPrint('🚨 Error fetching countries: $e');
      return [];
    }
  }

  /// POST /master-state
  /// Body: { "country_id": 1 }
  static Future<List<dynamic>> fetchStates(int countryId) async {
    final url = Uri.parse('$_baseUrl/master-state');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'country_id': countryId}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) return data;
        if (data is Map && data['data'] != null) return data['data'];
      }
      return [];
    } catch (e) {
      debugPrint('🚨 Error fetching states: $e');
      return [];
    }
  }

  /// POST /master-district
  /// Body: { "state_id": 1 }
  static Future<List<dynamic>> fetchDistricts(int stateId) async {
    final url = Uri.parse('$_baseUrl/master-district');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'state_id': stateId}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) return data;
        if (data is Map && data['data'] != null) return data['data'];
      }
      return [];
    } catch (e) {
      debugPrint('🚨 Error fetching districts: $e');
      return [];
    }
  }
}
