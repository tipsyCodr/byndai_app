import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/models/subscription_plan_model.dart';
import 'package:gridcard/core/services/user_storage_service.dart';

class SubscriptionService {
  static const String _baseUrl = AppConfig.apiBaseUrl;

  static Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// GET /api/get-subscription-plan
  static Future<List<SubscriptionPlanModel>> fetchAllPlans() async {
    final url = Uri.parse('$_baseUrl/get-subscription-plan');
    try {
      final response = await http.get(url, headers: await _getHeaders());
      if (kDebugMode) {
        debugPrint('🔹 GET $url');
        debugPrint('🔹 Response: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['data'] != null) {
          return (data['data'] as List)
              .map((item) => SubscriptionPlanModel.fromJson(item))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('🚨 Error fetching subscription plans: $e');
      return [];
    }
  }

  /// GET /api/get_plan_by_id/{id}
  static Future<SubscriptionPlanModel?> fetchPlanById(int id) async {
    final url = Uri.parse('$_baseUrl/get_plan_by_id/$id');
    try {
      final response = await http.get(url, headers: await _getHeaders());
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['data'] != null) {
          return SubscriptionPlanModel.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('🚨 Error fetching plan by ID $id: $e');
      return null;
    }
  }

  /// GET /api/plans/{id}/features
  static Future<SubscriptionPlanModel?> fetchPlanWithFeatures(int id) async {
    final url = Uri.parse('$_baseUrl/plans/$id/features');
    try {
      final response = await http.get(url, headers: await _getHeaders());
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['data'] != null) {
          return SubscriptionPlanModel.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('🚨 Error fetching plan features for $id: $e');
      return null;
    }
  }
  /// GET /api/user/queued-subscriptions
  static Future<List<int>> fetchQueuedPlanIds() async {
    final url = Uri.parse('$_baseUrl/user/queued-subscriptions');
    try {
      final response = await http.get(url, headers: await _getHeaders());
      if (kDebugMode) {
        debugPrint('🔹 GET $url');
        debugPrint('🔹 Response: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['data'] != null) {
          return (data['data'] as List)
              .map((item) => int.tryParse(item['plan_id']?.toString() ?? item['id']?.toString() ?? '0') ?? 0)
              .where((id) => id != 0)
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('🚨 Error fetching queued plans: $e');
      return [];
    }
  }
}
