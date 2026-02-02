import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gridcard/core/services/profile_service.dart';

class ProfileProvider extends ChangeNotifier {
  Map<String, dynamic>? _profileData;
  Map<String, dynamic>? _profileCard;
  Map<String, dynamic>? _businessInfo;
  List<dynamic> _links = [];
  bool _isLoading = false;

  Map<String, dynamic>? get profileData => _profileData;
  Map<String, dynamic>? get businessInfo => _businessInfo;
  Map<String, dynamic>? get profileCard => _profileCard;
  List<dynamic> get links => _links;
  bool get isLoading => _isLoading;

  Future<void> fetchProfileCard() async {
    _isLoading = true;
    notifyListeners();

    final result = await ProfileService.fetchProfileCard();

    if (result != null) {
      _profileCard = result['data'] ?? result;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchAllProfileData() async {
    _isLoading = true;
    notifyListeners();

    final profile = await ProfileService.fetchProfile();
    if (profile != null) _profileData = profile['data'] ?? profile;

    final business = await ProfileService.fetchBusinessInfo();
    if (business != null) _businessInfo = business['data'] ?? business;

    final linksData = await ProfileService.fetchLinks();
    if (linksData != null) {
      _links = linksData['data'] is List ? linksData['data'] : [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchProfileData(String userId) async {
  _isLoading = true;
  notifyListeners();

  try {
    final response = await ProfileService.fetchProfileCardData(userId);

    if (response != null && response['status'] == true) {
      _profileData = response['data'];
    } else {
      _profileData = null;
      debugPrint('⚠️ Profile data empty or status false');
    }
  } catch (e) {
    debugPrint('🚨 Provider error while fetching profile: $e');
    _profileData = null;
  }

  _isLoading = false;
  notifyListeners();
}


  Future<bool> updateProfile({
    String? fname,
    String? dept,
    String? desg,
    File? profilePic,
    File? profileBanner,
  }) async {
    _isLoading = true;
    notifyListeners();
    final result = await ProfileService.updateProfile(
      fname: fname,
      dept: dept,
      desg: desg,
      profilePic: profilePic,
      profileBanner: profileBanner,
    );
    if (result != null) {
      _profileData = result['data'] ?? result;
      _isLoading = false;
      notifyListeners();
      return true;
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> updateBusinessInfo({
    required Map<String, String> fields,
    File? paymentQr,
  }) async {
    _isLoading = true;
    notifyListeners();
    final result = await ProfileService.updateBusinessInfo(
      fields: fields,
      paymentQr: paymentQr,
    );
    if (result != null) {
      _businessInfo = result['data'] ?? result;
      _isLoading = false;
      notifyListeners();
      return true;
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> createLink(Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();
    final result = await ProfileService.createLink(data);
    if (result != null) {
      await fetchAllProfileData(); // Refresh links
      return true;
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> updateLink(int linkId, Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();
    final result = await ProfileService.updateLink(linkId, data);
    if (result != null) {
      await fetchAllProfileData(); // Refresh links
      return true;
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> deleteLink(int linkId) async {
    _isLoading = true;
    notifyListeners();
    final result = await ProfileService.deleteLink(linkId);
    if (result) {
      await fetchAllProfileData(); // Refresh links
      return true;
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Fetch user profile by username (public profile)
  Future<bool> fetchUserProfileByUsername(String userName) async {
    _isLoading = true;
    notifyListeners();
  
    try {
      final response =
          await ProfileService.fetchUserProfileByUsername(userName);
  
      if (response != null && response['status'] == true) {
        _profileData = response['data'];
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _profileData = null;
        debugPrint('⚠️ Profile not found for username: $userName');
      }
    } catch (e) {
      debugPrint('🚨 Provider error (fetchUserProfileByUsername): $e');
      _profileData = null;
    }
  
    _isLoading = false;
    notifyListeners();
    return false;
  }

}
