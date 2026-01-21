import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import '../../models/login_response.dart';

class UserSession {
  final UserModel? user;
  final String? token;

  UserSession({this.user, this.token});

  bool get isValid => token != null && token!.isNotEmpty && user != null;
}

class UserStorageService {
  // Use EncryptedSharedPreferences for reliable persistence on Android
  static FlutterSecureStorage get _secureStorage {
    const androidOptions = AndroidOptions(
      encryptedSharedPreferences: true,
    );
    return const FlutterSecureStorage(aOptions: androidOptions);
  }

  // Keys
  static const String _kKeyUser = 'user';
  static const String _kKeyToken = 'token';
  static const String _kKeyPin = 'user_pin';

  static const String _kPrefUserBackup = 'user_backup';
  static const String _kPrefTokenBackup = 'token_backup';
  static const String _kPrefUserId = 'user_id';

  /// Saves the user session to both SecureStorage (primary) and SharedPreferences (backup).
  Future<void> saveSession(LoginResponse response) async {
    debugPrint("UserStorage: Saving session...");
    final userJson = jsonEncode(response.user.toJson());
    final token = response.token;

    // 1. Try Secure Storage
    try {
      await _secureStorage.write(key: _kKeyUser, value: userJson);
      await _secureStorage.write(key: _kKeyToken, value: token);
      debugPrint("UserStorage: Saved to SecureStorage.");
    } catch (e) {
      debugPrint("UserStorage: ⚠️ SecureStorage failed: $e");
    }

    // 2. Save Backup to SharedPreferences (Critical for persistence on some Androids)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefUserBackup, userJson);
      await prefs.setString(_kPrefTokenBackup, token);
      await prefs.setInt(
          _kPrefUserId, response.user.id ?? 0); // Legacy/Quick check
      debugPrint("UserStorage: Saved backup to SharedPreferences.");
    } catch (e) {
      debugPrint("UserStorage: ⚠️ Backup failed: $e");
    }
  }

  /// Loads the session, attempting SecureStorage first, then falling back to Backup.
  Future<UserSession> loadSession() async {
    debugPrint("UserStorage: Loading session...");

    // 1. Try Secure Storage
    try {
      final userJson = await _secureStorage.read(key: _kKeyUser);
      final token = await _secureStorage.read(key: _kKeyToken);

      if (userJson != null && token != null) {
        final user = UserModel.fromJson(jsonDecode(userJson));
        debugPrint("UserStorage: Loaded from SecureStorage.");
        // return UserSession(user: user, token: token, isValid: true);
        return UserSession(user: user, token: token);
      }
    } catch (e) {
      debugPrint("UserStorage: ⚠️ SecureStorage load failed: $e");
    }

    // 2. Fallback to Backup
    debugPrint("UserStorage: Attempting backup restore...");
    try {
      final prefs = await SharedPreferences.getInstance();
      final userBackup = prefs.getString(_kPrefUserBackup);
      final tokenBackup = prefs.getString(_kPrefTokenBackup);

      if (userBackup != null && tokenBackup != null) {
        final user = UserModel.fromJson(jsonDecode(userBackup));

        // Self-heal: Restore to SecureStorage
        _secureStorage.write(key: _kKeyUser, value: userBackup).ignore();
        _secureStorage.write(key: _kKeyToken, value: tokenBackup).ignore();

        debugPrint("UserStorage: Restored from Backup & Self-healed.");
        return UserSession(user: user, token: tokenBackup);
      }
    } catch (e) {
      debugPrint("UserStorage: ⚠️ Backup load failed: $e");
    }

    debugPrint("UserStorage: No valid session found.");
    return UserSession();
  }

  /// Clears all session data from both storage types.
  Future<void> clearSession() async {
    debugPrint("UserStorage: Clearing session...");
    try {
      await _secureStorage.delete(key: _kKeyUser);
      await _secureStorage.delete(key: _kKeyToken);
      await _secureStorage.delete(key: _kKeyPin);
    } catch (e) {
      debugPrint("UserStorage: Error clearing secure storage: $e");
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPrefUserBackup);
      await prefs.remove(_kPrefTokenBackup);
      await prefs.remove(_kPrefUserId);
    } catch (e) {
      debugPrint("UserStorage: Error clearing backup: $e");
    }
  }

  Future<void> savePin(String pin) async {
    await _secureStorage.write(key: _kKeyPin, value: pin);
  }

  /// Retrieves the token, attempting SecureStorage first, then Backup.
  Future<String?> getToken() async {
    // 1. Try Secure Storage
    try {
      final token = await _secureStorage.read(key: _kKeyToken);
      if (token != null) return token;
    } catch (_) {}

    // 2. Fallback to Backup
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kPrefTokenBackup);
    } catch (_) {}

    return null;
  }
}
