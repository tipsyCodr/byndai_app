// lib/core/services/navigation_service.dart

import 'package:flutter/material.dart';

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  BuildContext? get context => navigatorKey.currentContext;

  Future<dynamic> navigateTo(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushNamed(
      routeName,
      arguments: arguments,
    );
  }

  Future<dynamic> navigateToAndRemoveUntil(
    String routeName, {
    Object? arguments,
  }) {
    return navigatorKey.currentState!.pushNamedAndRemoveUntil(
      routeName,
      (route) => false,
      arguments: arguments,
    );
  }

  Future<dynamic> navigateToAndReplace(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushReplacementNamed(
      routeName,
      arguments: arguments,
    );
  }

  void goBack({dynamic result}) {
    return navigatorKey.currentState!.pop(result);
  }

  // ✅ NEW: Specific function for opening lead form with data
  static void openLeadFormWithData(Map<String, dynamic> formData) {
    final context = _instance.context;
    if (context != null) {
      Navigator.of(context).pushNamed(
        '/addLead',
        arguments: formData,
      );
    } else {
      print('Navigation context is null');
    }
  }

  // ✅ NEW: Open leads page modal with data
  static void openLeadsPageModal(Map<String, dynamic> formData) {
    final context = _instance.context;
    if (context != null) {
      // We'll use a custom route name
      Navigator.of(context).pushNamed(
        '/leads/modal',
        arguments: formData,
      );
    }
  }

  // ✅ NEW: Open camera for leads scanning
  static Future<Map<String, dynamic>?> openCameraForLeads() async {
    final context = _instance.context;
    if (context != null) {
      final result = await Navigator.of(context).pushNamed(
        '/camera/scan',
        arguments: {'purpose': 'leads'},
      );
      
      if (result != null && result is Map<String, dynamic>) {
        return result;
      }
    }
    return null;
  }
}

// Global instance
final navigationService = NavigationService();