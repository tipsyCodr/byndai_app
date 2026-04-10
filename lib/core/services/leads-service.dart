import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:gridcard/core/services/api_header_service.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/models/lead_model.dart';
import 'package:http/http.dart' as http;

class LeadServices {
  static const String _baseUrl = AppConfig.apiBaseUrl;

  static Future<List<LeadModel>?> fetchLeads() async {
    final url = Uri.parse('$_baseUrl/leads');
    try {
      final response = await http.get(url, headers: await ApiHeaderService.getHeaders());

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

  static Future<LeadModel?> createLead(LeadModel lead) async {
    final url = Uri.parse('$_baseUrl/leads');
    try {
      final response = await http.post(
        url,
        headers: await ApiHeaderService.getHeaders(),
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
      final Map<String, dynamic> updateData = {
        'name': data['name'] ?? '',
        'company_name': data['company_name'] ?? '',
        'address': data['address'] ?? '',
        'website': data['website'] ?? '',
        'mobile_no_1': data['mobile_no_1'] ?? '',
        'mobile_no_2': data['mobile_no_2'],
        'mobile_no_3': data['mobile_no_3'],
        'email': data['email'],
        'email2': data['email2'],

        // ==========================
        // ✅ NEW FIELD - CATEGORY
        // ==========================
        if (data.containsKey('category')) 'category': data['category'],

        // ==========================
        // ✅ LEAD IMAGE
        // ==========================
        if (data.containsKey('lead_image') && data['lead_image'] != null)
          'lead_image': data['lead_image'],

        if (data.containsKey('image_filename') &&
            data['image_filename'] != null)
          'image_filename': data['image_filename'],

        // ==========================
        // ✅ SELFY IMAGE 1
        // ==========================
        if (data.containsKey('selfy_image_1') && data['selfy_image_1'] != null)
          'selfy_image_1': data['selfy_image_1'],

        // ==========================
        // ✅ SELFY IMAGE 2
        // ==========================
        if (data.containsKey('selfy_image_2') && data['selfy_image_2'] != null)
          'selfy_image_2': data['selfy_image_2'],

        // ==========================
        // ✅ SELFY VIDEO
        // ==========================
        if (data.containsKey('selfy_video') && data['selfy_video'] != null)
          'selfy_video': data['selfy_video'],

        if (data.containsKey('selfy_video_filename') &&
            data['selfy_video_filename'] != null)
          'selfy_video_filename': data['selfy_video_filename'],
      };

      debugPrint("📤 UPDATE REQUEST => $updateData");

      final response = await http.put(
        url,
        headers: await ApiHeaderService.getHeaders(),
        body: jsonEncode(updateData),
      );

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
      // Convert mobile list to individual fields.........
      List<String> mobilesList = [];
      if (data['mobiles'] != null && data['mobiles'] is List) {
        mobilesList = List<String>.from(data['mobiles'] as List);
      }

      final Map<String, dynamic> apiData = {
        // Required
        'user_id': data['user_id'],
        'name': data['name'] ?? '',
        // 'category': data['category'] ?? '',
        if (data['category_id'] != null) 'category': data['category_id'],
        // Existing
        'company_name': data['company_name'] ?? '',
        'email': data['email'] ?? '',
        'email2': data['email2'],
        'website': data['website'],
        'address': data['address'] ?? '',

        // Mobiles
        'mobile_no_1': mobilesList.isNotEmpty ? mobilesList[0] : '',
        'mobile_no_2': mobilesList.length > 1 ? mobilesList[1] : null,
        'mobile_no_3': mobilesList.length > 2 ? mobilesList[2] : null,

        // Scanned card image
        if (data['lead_image'] != null) 'lead_image': data['lead_image'],
        if (data['image_filename'] != null)
          'image_filename': data['image_filename'],

        // ✅ Selfy images (separate fields, always present)
        'selfy_image_1': data['selfy_image_1'] ?? '',
        'selfy_image_2': data['selfy_image_2'] ?? '',
        if (data['selfy_image_1_filename'] != null)
          'selfy_image_1_filename': data['selfy_image_1_filename'],
        if (data['selfy_image_2_filename'] != null)
          'selfy_image_2_filename': data['selfy_image_2_filename'],

        // ✅ Selfy video (always present)
        'selfy_video': data['selfy_video'] ?? '',
        if (data['selfy_video_filename'] != null)
          'selfy_video_filename': data['selfy_video_filename'],
      };

      debugPrint("📤 API Request Data => $apiData");

      final response = await http.post(
        url,
        headers: await ApiHeaderService.getHeaders(),
        body: jsonEncode(apiData),
      );

      // debugPrint("📥 API Response Status => ${response.statusCode}");
      // debugPrint("📥 API Response Body => ${response.body}");

      // return response.statusCode == 200 || response.statusCode == 201;

      final json = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json['success'] == true;
      } else {
        throw Exception(json['message'] ?? 'Something went wrong');
      }
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

    final uri =
        Uri.parse('$_baseUrl/leads').replace(queryParameters: queryParams);

    debugPrint("📡 FETCH LEADS URL => $uri");

    try {
      final response = await http.get(uri, headers: await ApiHeaderService.getHeaders());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        debugPrint("✅ API Response Structure:");
        debugPrint("   fetchLeadsAdvanced_success: ${data['success']}");
        debugPrint(
            "   fetchLeadsAdvanced_data_length: ${data['data'] is List ? (data['data'] as List).length : 'N/A'}");
        debugPrint("   fetchLeadsAdvanced_data: ${data['data']}");
        debugPrint("   fetchLeadsAdvanced_meta: ${data['meta']}");

        return {
          "leads":
              (data['data'] as List).map((e) => LeadModel.fromJson(e)).toList(),
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
        headers: await ApiHeaderService.getHeaders(),
      );

      debugPrint("🗑 DELETE RESPONSE => ${response.body}");

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("🚨 Delete Lead Error => $e");
      return false;
    }
  }

  static Future<Map<String, dynamic>?> fetchLeadsByUserId({
    required int userId,
    int perPage = 10,
    int? page,
    String? category, // ✅ ADD THIS
  }) async {
    final queryParams = {
      'user_id': userId.toString(),
      'per_page': perPage.toString(),
      if (page != null) 'page': page.toString(),

      // ✅ ADD CATEGORY HERE
      if (category != null && category.isNotEmpty) 'category': category,
    };

    final uri = Uri.parse('$_baseUrl/leads-list-by-user-id')
        .replace(queryParameters: queryParams);

    try {
      final response = await http.get(uri, headers: await ApiHeaderService.getHeaders());

      debugPrint('📡 Fetch leads URL: $uri');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        if (json['success'] == true) {
          final List<LeadModel> leads = (json['data'] as List)
              .map((item) => LeadModel.fromJson(item))
              .toList();

          return {
            'leads': leads,
            'meta': json['meta'],
          };
        }
      }
      return null;
    } catch (e) {
      debugPrint('🚨 Error fetching leads: $e');
      return null;
    }
  }
}
