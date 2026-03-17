import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/core/services/profile_service.dart';
import 'package:gridcard/features/qr_scan/qr_scan_view_profile.dart';
import 'package:gridcard/core/services/auth_provider.dart';
import 'package:provider/provider.dart';
import 'dart:async';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  void initialize() {
    _appLinks = AppLinks();

    // 1. Handle links when app is already open
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      debugPrint('[DEEP LINK] Received: $uri');
      _handleDeepLink(uri);
    });

    // 2. Handle links that opened the app
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        debugPrint('[DEEP LINK] Initial link: $uri');
        _handleDeepLink(uri);
      }
    });
  }

  void _handleDeepLink(Uri uri) async {
    // Expected format: https://app.byndai.in/u/username
    if (uri.path.startsWith('/u/')) {
      final username = uri.pathSegments.last;
      debugPrint('[DEEP LINK] Username extracted: $username');
      _openProfile(username);
    }
  }

  Future<void> _openProfile(String username) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    try {
      final response = await ProfileService.fetchUserProfileByUsername(username);
      
      if (response != null && response['status'] == true && response['data'] != null) {
        final profileData = response['data'];
        
        final profilePic = profileData['profile_pic'] ?? '';
        final profileLogo = profileData['profile_logo'] ?? '';

        final legalName =
            profileData['user']?['business_info']?['legal_name'] ?? '';

        final industryTitle = profileData['user']?['business_info']
                ?['industry']?['title'] ??
            '';
            
        final authUser = Provider.of<AuthProvider>(context, listen: false).user;

        // Navigate to profile scan view
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => QRScanViewProfile(
              receiverId: profileData['user_id']?.toString() ?? '',
              name: profileData['fname'] ?? 'N/A',
              mobile: profileData['mobile_one'] ??
                  profileData['user']?['user_mobile'] ??
                  'N/A',
              email: profileData['email_one'] ??
                  profileData['user']?['email'] ??
                  'N/A',
              senderId: authUser?.id?.toString() ?? '',
              senderName: authUser?.masterUser?.fname ?? '',
              profilePic: profilePic,
              profileLogo: profileLogo,
              legalName: legalName,
              industryTitle: industryTitle,
            ),
          ),
        );
      } else {
        debugPrint('[DEEP LINK] Profile not found or error: ${response?['message']}');
      }
    } catch (e) {
      debugPrint('[DEEP LINK] Exception opening profile: $e');
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
