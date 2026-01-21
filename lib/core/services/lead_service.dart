import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/models/customer_master_model.dart';
import 'package:http/http.dart' as http;

class LeadService {
  static const String _baseUrl = AppConfig.apiBaseUrl;

  static Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<List<CustomerMasterModel>?> fetchLeads() async {
    final url = Uri.parse('$_baseUrl/customer-master/index');
    try {
      final response = await http.post(url, headers: await _getHeaders());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null && data['data'] is List) {
          return (data['data'] as List)
              .map((item) => CustomerMasterModel.fromJson(item))
              .toList();
        }
      }
      return null;
    } catch (e) {
      debugPrint('🚨 Error fetching leads: $e');
      return null;
    }
  }

  static Future<CustomerMasterModel?> createLead(
      CustomerMasterModel lead) async {
    final url = Uri.parse('$_baseUrl/customer-master/create');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode(lead.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['data'] != null) {
          return CustomerMasterModel.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('🚨 Error creating lead: $e');
      return null;
    }
  }

  static Future<CustomerMasterModel?> updateLead(
      int id, CustomerMasterModel lead) async {
    final url = Uri.parse('$_baseUrl/customer-master/update/$id');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode(lead.toJson()),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null) {
          return CustomerMasterModel.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('🚨 Error updating lead: $e');
      return null;
    }
  }
}
