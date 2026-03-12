import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import '../../models/login_response.dart';

import '../../models/user_model.dart';
import 'auth_service.dart';

enum GoogleSignInResult { loggedIn, needsRegistration, failed }

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  bool _isAuthenticated = false;
  bool _forceNewUser = false;

  final _storageService = UserStorageService();

  // Pending state for multi-step auth flows
  Map<String, dynamic>? _pendingOtpData;
  bool _pendingIsNewUser = false;
  String? _pendingProcess;
  String? _pendingRegisterToken;
  Map<String, dynamic>? _pendingRegisterUser;
  Map<String, String>? _googleSignInData;

  // Getters
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  Map<String, dynamic>? get pendingOtpData => _pendingOtpData;
  bool get pendingIsNewUser => _pendingIsNewUser;
  String? get pendingProcess => _pendingProcess;
  String? get pendingRegisterToken => _pendingRegisterToken;
  String? get pendingRegisterMobile => _pendingRegisterUser?['user_mobile'];
  Map<String, dynamic>? get pendingRegisterUser => _pendingRegisterUser;
  Map<String, String>? get googleSignInData => _googleSignInData;

  void updateUserFromDetails(Map<String, dynamic> userDetails) {
    try {
      final user = UserModel.fromJson(userDetails);
      _user = user;
      _storageService.updateUser(user); // update stored user
      notifyListeners();
      debugPrint("AuthProvider: User updated from profile details");
    } catch (e) {
      debugPrint("AuthProvider: Error updating user from details: $e");
    }
  }

  /// Restores authentication state from a pre-loaded session.
  /// Called from main() to avoid async issues in widgets.
  void restoreSession(UserSession session) {
    if (session.isValid) {
      _user = session.user;
      _isAuthenticated = true;
      debugPrint('Auth: ✅ Session restored from main()');
      notifyListeners();
    }
  }

  /// Wraps an async function with loading state management.
  Future<T?> _handleLoading<T>(Future<T?> Function() action) async {
    _isLoading = true;
    notifyListeners();
    try {
      return await action();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Handles the response from an OTP request.
  Future<bool> _handleOtpResponse(
      Map<String, dynamic>? responseData, String mobile) async {
    if (responseData == null) {
      Fluttertoast.showToast(msg: "Failed to send OTP");
      return false;
    }

    _pendingProcess = responseData['process']?.toString();
    _pendingOtpData = (responseData['data'] is Map
            ? responseData['data']
            : responseData['user']) ??
        responseData;

    // Determine if it's a new user flow
    _pendingIsNewUser = _pendingProcess?.toLowerCase() == 'register' ||
        responseData['is_new_user'] == true ||
        (_pendingOtpData?.containsKey('otp') ?? false);

    await _savePendingState(mobile);

    debugPrint('OTP data: $_pendingOtpData');
    debugPrint('Detected process: $_pendingProcess');
    debugPrint('Is new user: $_pendingIsNewUser');

    Fluttertoast.showToast(msg: "OTP sent successfully!");
    return true;
  }

  Future<bool> getOTP(String mobile, {bool isNewUser = false}) async {
    if (isNewUser) {
      _forceNewUser = true;
    }
    return await _handleLoading(() async {
          final responseData = await AuthService.getOTP(mobile);
          return await _handleOtpResponse(responseData, mobile);
        }) ??
        false;
  }

  Future<bool> getResetOtp(String mobile) async {
    return await _handleLoading(() async {
          final responseData = await AuthService.getResetOtp(mobile);
          return await _handleOtpResponse(responseData, mobile);
        }) ??
        false;
  }

  Future<bool> verifyOTP(String mobile, String otp) async {
    return await _handleLoading(() async {
          final token = _pendingOtpData?['token']?.toString();
          if (token == null) {
            Fluttertoast.showToast(msg: "Session expired. Please try again.");
            return false;
          }

          final result = await AuthService.verifyOTP(mobile, token, otp);
          if (result == null) {
            Fluttertoast.showToast(msg: "OTP verification failed");
            return false;
          }

          return await _processOtpVerificationResult(result);
        }) ??
        false;
  }

  /// Processes the result of a successful OTP verification.
  Future<bool> _processOtpVerificationResult(
      Map<String, dynamic> result) async {
    final process =
        (result['process'] as String?)?.toLowerCase() ?? _pendingProcess;
    final dataMap = (result['data'] is Map
            ? result['data']
            : (result['user'] is Map ? result['user'] : null))
        as Map<String, dynamic>?;
    // final newToken = dataMap?['token']?.toString();
    final newToken =
        result['token']?.toString() ?? dataMap?['token']?.toString();

    _pendingProcess = process;

    // If we know this is a new user, override any confusing signals from the backend.
    if (_forceNewUser) {
      await _prepareForRegistration(dataMap, newToken);
      return true;
    }

    if (process == 'register') {
      await _prepareForRegistration(dataMap, newToken);
      return true;
    }

    if (process == 'login') {
      await _prepareForLogin(dataMap);
      return true;
    }

    // Implicit login if response contains full user data and a token
    if (dataMap != null &&
        dataMap['user'] != null &&
        dataMap['token'] != null) {
      final loginResponse = LoginResponse.fromJson(dataMap);
      await _processSuccessfulLogin(loginResponse, "Logged in successfully!");
      return true;
    }

    // Fallback to registration flow
    await _prepareForRegistration(dataMap, newToken);
    return true;
  }

  Future<bool> login(String email, String password) async {
    return await _handleLoading(() async {
          final response = await AuthService.login(email, password);
          if (response != null) {
            await _processSuccessfulLogin(response, "Login successful!");
            return true;
          }
          return false;
        }) ??
        false;
  }

  Future<bool> loginWithPin(String mobile, String pin) async {
    return await _handleLoading(() async {
          final response = await AuthService.loginWithPin(mobile, pin);
          if (response != null) {
            await _processSuccessfulLogin(response, "Login successful!");
            return true;
          }
          return false;
        }) ??
        false;
  }

  Future<bool> register(Map<String, dynamic> data) async {
    return await _handleLoading(() async {
          final response = await AuthService.registerWithToken(data);

          if (response != null) {
            await _processSuccessfulLogin(response, "Registration successful!");
            return true;
          }

          return false;
        }) ??
        false;
  }

  Future<bool> isRegistered(String mobile) async {
    return await _handleLoading(() => AuthService.isRegistered(mobile)) ??
        false;
  }

  /// Check username availability (used during registration)
  Future<bool> checkUsernameAvailability(String userName) async {
    return await _handleLoading(() async {
          final isAvailable =
              await AuthService.checkUsernameAvailability(userName);

          if (isAvailable == true) {
            return true; // ✅ username free
          }

          // ❌ username already exists
          Fluttertoast.showToast(msg: "Username already exists");
          return false;
        }) ??
        false;
  }

  Future<bool> checkPin(String mobile) async {
    return await _handleLoading(() => AuthService.checkPin(mobile)) ?? false;
  }

  Future<bool> setPin(String mobile, String pin) async {
    return await _handleLoading(() async {
          final success = await AuthService.setPin(mobile, pin);
          if (success) {
            await _storageService.savePin(pin);
          }
          return success;
        }) ??
        false;
  }

  // void logout() async {
  //   _user = null;
  //   _isAuthenticated = false;
  //   await _storageService.clearSession();
  //   notifyListeners();
  // }

  Future<void> logout() async {
    _user = null;
    _isAuthenticated = false;
    await _storageService.clearSession();
    notifyListeners();
  }

  Future<void> loadUserFromStorage() async {
    debugPrint("Auth: loadUserFromStorage called");

    try {
      final session = await _storageService.loadSession();

      debugPrint("Auth: token=${session.token}");
      debugPrint("Auth: user=${session.user?.userMobile}");
      debugPrint("Auth: isValid=${session.isValid}");

      // ✅ Primary check (preferred)
      if (session.isValid) {
        _user = session.user;
        _isAuthenticated = true;
        debugPrint("Auth: ✅ Session restored via isValid");
      }
      // ✅ EXTRA HARDENING fallback (THIS is the part you asked about)
      else if (session.token != null && session.user != null) {
        _user = session.user;
        _isAuthenticated = true;
        debugPrint("Auth: ⚠️ Session restored via fallback");
      }
      // ❌ No session
      else {
        _isAuthenticated = false;
        debugPrint("Auth: ❌ No valid session found");
      }
    } catch (e) {
      debugPrint("Auth: Failed to load session: $e");
      _isAuthenticated = false;
    }

    notifyListeners();
  }

  // --- Private Helper Methods ---

  Future<void> _processSuccessfulLogin(
      LoginResponse response, String message) async {
    _user = response.user;
    _isAuthenticated = true;
    await _storageService.saveSession(response);
    await _clearPendingState();
    // Fluttertoast.showToast(msg: message);
  }

  Future<void> _prepareForRegistration(
      Map<String, dynamic>? dataMap, String? token) async {
    _pendingIsNewUser = true;
    _pendingRegisterToken = token;
    _pendingRegisterUser = dataMap;
    await _savePendingState(dataMap?['user_mobile']);
    Fluttertoast.showToast(msg: 'OTP verified. Please complete registration.');
  }

  Future<void> _prepareForLogin(Map<String, dynamic>? dataMap) async {
    _pendingIsNewUser = false;
    await _savePendingState(dataMap?['user_mobile']);
    Fluttertoast.showToast(
        msg: 'OTP verified. Please enter your PIN to login.');
  }

  // --- Secure Storage and SharedPreferences Helpers ---

  Future<void> _savePendingState(String? mobile) async {
    final prefs = await SharedPreferences.getInstance();
    if (mobile != null) await prefs.setString('phone_no', mobile);

    // For pending OTP/Token, we can use secure storage via a temporary instance if needed,
    // or just handle it within the logic. Keeping it simple here.
    // Ideally UserStorageService could handle this too, but for now we keep pending state separate logic.
    await prefs.setBool('is_new_user', _pendingIsNewUser);
    if (_pendingProcess != null) {
      await prefs.setString('pending_process', _pendingProcess!);
    }
    if (_pendingRegisterUser != null) {
      await prefs.setString(
          'pending_register_user', jsonEncode(_pendingRegisterUser));
    }

    // We can use secure storage directly for sensitive pending tokens if wanted,
    // or rely on provider state if app doesn't restart during otp flow.
    // For this refactor, we focus on Session Persistence.
  }

  Future<void> _clearPendingState() async {
    _pendingOtpData = null;
    _pendingIsNewUser = false;
    _pendingProcess = null;
    _pendingRegisterToken = null;
    _pendingRegisterUser = null;
    _forceNewUser = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('phone_no');
    await prefs.remove('is_new_user');
    await prefs.remove('pending_process');
    await prefs.remove('pending_register_user');
  }

  Future<bool> updatePin(String oldPin, String newPin) async {
    return await _handleLoading(() async {
          final success =
              await AuthService.setPin(_user?.userMobile ?? '', newPin);
          if (success) {
            await _storageService.savePin(newPin);
          }
          return success;
        }) ??
        false;
  }

  /// Check email availability (used during registration)
  Future<bool> checkEmailAvailability(String email) async {
    return await _handleLoading(() async {
          final isAvailable = await AuthService.checkEmailAvailability(email);

          if (isAvailable == true) {
            return true; // ✅ email available
          }

          if (isAvailable == false) {
            Fluttertoast.showToast(msg: "Email already exists");
            return false; // ❌ email already exists
          }

          // null case → API error
          Fluttertoast.showToast(msg: "Unable to verify email. Try again.");
          return false;
        }) ??
        false;
  }

  // ================= GOOGLE SIGN-IN =================

  /// Full Google Sign-In flow:
  /// 1. Google Sign-In popup
  /// 2. Get Firebase ID token
  /// 3. Send to backend
  /// 4. Auto-login or redirect to registration
  Future<GoogleSignInResult> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Initialize & authenticate with Google Sign-In v7
      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize();

      GoogleSignInAccount? googleUser;
      try {
        googleUser = await googleSignIn.authenticate();
      } on GoogleSignInException catch (e) {
        debugPrint('Google Sign-In cancelled or failed: ${e.code}');
        _isLoading = false;
        notifyListeners();
        return GoogleSignInResult.failed;
      }

      // 2. Get the ID token from Google Sign-In authentication
      final googleIdToken = googleUser.authentication.idToken;

      // 3. Sign in to Firebase using the Google credential
      final credential = firebase_auth.GoogleAuthProvider.credential(
        idToken: googleIdToken,
      );
      final firebaseUser = await firebase_auth.FirebaseAuth.instance
          .signInWithCredential(credential);
      final firebaseIdToken = await firebaseUser.user?.getIdToken();

      if (firebaseIdToken == null) {
        Fluttertoast.showToast(msg: 'Failed to get authentication token');
        _isLoading = false;
        notifyListeners();
        return GoogleSignInResult.failed;
      }

      // 4. Call backend
      final response = await AuthService.googleLogin(
        idToken: firebaseIdToken,
        email: googleUser.email,
        name: googleUser.displayName ?? '',
      );

      if (response == null) {
        Fluttertoast.showToast(msg: 'Google sign-in failed');
        _isLoading = false;
        notifyListeners();
        return GoogleSignInResult.failed;
      }

      // 5. Check if auto-login or registration needed
      if (response['token'] != null && response['user'] != null) {
        // Auto-login: user exists with mobile
        final loginResponse = LoginResponse(
          token: response['token'],
          user: UserModel.fromJson(response['user']),
        );
        await _processSuccessfulLogin(
            loginResponse, 'Google login successful!');
        _isLoading = false;
        notifyListeners();
        return GoogleSignInResult.loggedIn;
      }

      // Registration needed: store Google data for prefilling
      _googleSignInData = {
        'id_token': firebaseIdToken,
        'email': googleUser.email,
        'name': googleUser.displayName ?? '',
        'photo_url': googleUser.photoUrl ?? '',
      };
      _isLoading = false;
      notifyListeners();
      return GoogleSignInResult.needsRegistration;
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      Fluttertoast.showToast(msg: 'Google sign-in failed: ${e.toString()}');
      _isLoading = false;
      notifyListeners();
      return GoogleSignInResult.failed;
    }
  }

  /// Register a Google user after mobile verification
  Future<bool> registerGoogleUser(Map<String, dynamic> data) async {
    return await _handleLoading(() async {
          final response = await AuthService.registerGoogleUser(data);
          if (response != null) {
            await _processSuccessfulLogin(response, 'Registration successful!');
            _googleSignInData = null; // Clear Google data
            return true;
          }
          return false;
        }) ??
        false;
  }

  /// Clear Google sign-in data (e.g., if user cancels registration)
  void clearGoogleSignInData() {
    _googleSignInData = null;
    notifyListeners();
  }
}
