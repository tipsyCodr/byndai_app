import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:http/http.dart' as http;

class UserStatsProvider extends ChangeNotifier {
  // --- Analytics ---
  int _totalViewCount = 0;
  int _totalTimeSeconds = 0;
  bool _isAnalyticsLoading = false;

  // --- Profile Completion ---
  double _profileCompletionPercent = 0.0;
  Map<String, bool> _milestones = {};
  bool _isCompletionLoading = false;

  // --- Ratings ---
  double _averageRating = 0.0;
  int _totalReviews = 0;
  bool _isRatingLoading = false;

  DateTime? _lastFetchTime;

  // Getters
  int get totalViewCount => _totalViewCount;
  int get totalTimeSeconds => _totalTimeSeconds;
  bool get isAnalyticsLoading => _isAnalyticsLoading;

  double get profileCompletionPercent => _profileCompletionPercent;
  Map<String, bool> get milestones => _milestones;
  bool get isCompletionLoading => _isCompletionLoading;

  double get averageRating => _averageRating;
  int get totalReviews => _totalReviews;
  bool get isRatingLoading => _isRatingLoading;

  bool get isLoading => _isAnalyticsLoading || _isCompletionLoading || _isRatingLoading;

  bool get shouldRefresh {
    if (_lastFetchTime == null) return true;
    return DateTime.now().difference(_lastFetchTime!).inMinutes >= 5;
  }

  Future<void> fetchAllStats({bool force = false}) async {
    if (!force && !shouldRefresh) return;

    await Future.wait([
      fetchUserAnalytics(silent: true),
      fetchProfileCompletion(silent: true),
      fetchAverageRating(silent: true),
    ]);

    _lastFetchTime = DateTime.now();
    notifyListeners();
  }

  Future<void> fetchUserAnalytics({bool silent = false}) async {
    if (!silent) {
      _isAnalyticsLoading = true;
      notifyListeners();
    }

    try {
      final userId = await UserStorageService().getUserId();
      if (userId == null) return;

      final response = await http.post(
        Uri.parse("${AppConfig.apiBaseUrl}/user-analytics"),
        headers: await _getHeaders(),
        body: jsonEncode({"userId": userId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["status"] == true) {
          final stats = data["data"]?["profile_views"];
          _totalViewCount = stats?["total_view_count"] ?? 0;
          _totalTimeSeconds = stats?["total_time_seconds"] ?? 0;
        }
      }
    } catch (e) {
      debugPrint("UserStatsProvider: Analytics error: $e");
    } finally {
      _isAnalyticsLoading = false;
      if (!silent) notifyListeners();
    }
  }

  Future<void> fetchProfileCompletion({bool silent = false}) async {
    if (!silent) {
      _isCompletionLoading = true;
      notifyListeners();
    }

    try {
      final userId = await UserStorageService().getUserId();
      if (userId == null) return;

      final response = await http.post(
        Uri.parse("${AppConfig.apiBaseUrl}/profile-completion"),
        headers: await _getHeaders(),
        body: jsonEncode({"user_id": userId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) {
          _profileCompletionPercent = (data["percentage"] ?? 0).toDouble();
          _milestones = Map<String, bool>.from(data["milestones"] ?? {});
        }
      }
    } catch (e) {
      debugPrint("UserStatsProvider: Completion error: $e");
    } finally {
      _isCompletionLoading = false;
      if (!silent) notifyListeners();
    }
  }

  Future<void> fetchAverageRating({bool silent = false}) async {
    if (!silent) {
      _isRatingLoading = true;
      notifyListeners();
    }

    try {
      final userId = await UserStorageService().getUserId();
      if (userId == null) return;

      final response = await http.get(
        Uri.parse("${AppConfig.apiBaseUrl}/user-reviews/$userId/average"),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["status"] == true) {
          final ratingData = data["data"] ?? {};
          _averageRating = double.tryParse(ratingData["average_rating"].toString()) ?? 0.0;
          _totalReviews = int.tryParse(ratingData["total_reviews"].toString()) ?? 0;
        }
      }
    } catch (e) {
      debugPrint("UserStatsProvider: Rating error: $e");
    } finally {
      _isRatingLoading = false;
      if (!silent) notifyListeners();
    }
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}
