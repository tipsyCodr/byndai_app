import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/models/lead_model.dart';
import 'package:http/http.dart' as http;


class LeadServices {
  static const String _baseUrl = AppConfig.apiBaseUrl2;

  static Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<List<LeadModel>?> fetchLeads() async {
    final url = Uri.parse('$_baseUrl/leads');
    try {
      final response = await http.get(url, headers: await _getHeaders());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null && data['data'] is List) {
          return (data['data'] as List)
              .map((item) => LeadModel.fromJson(item))
              .toList();
        }
      }
      return null;
    } catch (e) {
      debugPrint('🚨 Error fetching leads: $e');
      return null;
    }
  }

  static Future<LeadModel?> createLead(
      LeadModel lead) async {
    final url = Uri.parse('$_baseUrl/leads');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode(lead.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['data'] != null) {
          return LeadModel.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('🚨 Error creating lead: $e');
      return null;
    }
  }
 

  static Future<LeadModel?> updateLead(
    int id, Map<String, dynamic> data) async {
  final url = Uri.parse('$_baseUrl/leads/$id');

  try {
    final response = await http.put(
      url,
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );

    debugPrint("📤 UPDATE REQUEST => $data");
    debugPrint("📥 UPDATE RESPONSE => ${response.body}");

    if (response.statusCode == 200) {
      final res = jsonDecode(response.body);
      return LeadModel.fromJson(res['data']);
    }
    return null;
  } catch (e) {
    debugPrint('🚨 Error updating lead: $e');
    return null;
  }
}


  static Future<bool> createLeadRaw(Map<String, dynamic> data) async {
    debugPrint("🟢 Leads services Received Data => $data");
  final url = Uri.parse('$_baseUrl/leads');

  try {
    final response = await http.post(
      url,
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );

    debugPrint("📤 leads Request => $data");
    debugPrint("📥 leads Response => ${response.body}");

    return response.statusCode == 200 || response.statusCode == 201;
  } catch (e) {
    debugPrint("🚨 Create lead error: $e");
    return false;
  }
}

static Future<Map<String, dynamic>?> fetchLeadsAdvanced({
  String? search,
  int page = 1,
  int perPage = 10,
  String? fromDate,
  String? toDate,
  String? company,
}) async {
  final queryParams = {
    'page': page.toString(),
    'per_page': perPage.toString(),
    if (search != null && search.isNotEmpty) 'search': search,
    if (fromDate != null) 'from_date': fromDate,
    if (toDate != null) 'to_date': toDate,
    if (company != null && company.isNotEmpty) 'company': company,
  };

  final uri = Uri.parse('$_baseUrl/leads').replace(queryParameters: queryParams);

  debugPrint("📡 FETCH LEADS URL => $uri");

  try {
    final response = await http.get(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      return {
        "leads": (data['data'] as List)
            .map((e) => LeadModel.fromJson(e))
            .toList(),
        "meta": data['meta'],
      };
    }
    return null;
  } catch (e) {
    debugPrint('🚨 Error fetching leads: $e');
    return null;
  }
}

static Future<bool> deleteLead(int id) async {
  final url = Uri.parse('$_baseUrl/leads/$id');

  try {
    final response = await http.delete(
      url,
      headers: await _getHeaders(),
    );

    debugPrint("🗑 DELETE RESPONSE => ${response.body}");

    return response.statusCode == 200;
  } catch (e) {
    debugPrint("🚨 Delete Lead Error => $e");
    return false;
  }
}


}
