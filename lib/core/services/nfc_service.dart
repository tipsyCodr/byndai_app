import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';
import 'user_storage_service.dart';
import 'package:gridcard/features/profile/profile_page.dart';
import 'package:http/http.dart' as http;
import 'package:gridcard/config/app_config.dart';

enum NfcConnectionStatus {
  idle,
  scanning,
  completed,
  error,
}

class NfcService with ChangeNotifier {
  static final NfcService _instance = NfcService._internal();
  factory NfcService() => _instance;
  NfcService._internal();

  NfcConnectionStatus _status = NfcConnectionStatus.idle;
  bool _isNfcAvailable = false;
  bool _isListening = false;

  int? _lastScannedUserId;
  DateTime? _lastScanTime;

  NfcConnectionStatus get status => _status;
  bool get isNfcAvailable => _isNfcAvailable;
  bool get isListening => _isListening;

  // ===============================
  // Initialize NFC
  // ===============================

  Future<void> initialize({required BuildContext context}) async {
    try {
      _isNfcAvailable = await NfcManager.instance.isAvailable();

      if (_isNfcAvailable) {
        debugPrint("✅ NFC available");
        _startListening(context);
      } else {
        debugPrint("❌ NFC not available");
      }

      notifyListeners();
    } catch (e) {
      debugPrint("🔴 NFC init error: $e");
    }
  }

  // ===============================
  // Start NFC Listening
  // ===============================

  void _startListening(BuildContext context) {
    if (_isListening) return;

    _isListening = true;
    _status = NfcConnectionStatus.scanning;
    notifyListeners();

    NfcManager.instance.startSession(
      pollingOptions: const {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
        NfcPollingOption.iso18092,
      },
      onDiscovered: (NfcTag tag) async {
        try {
          await _handleNfcTag(context, tag);
        } catch (e) {
          debugPrint("🔴 NFC error $e");
        } finally {
          await NfcManager.instance.stopSession();
          _isListening = false;

          Future.delayed(const Duration(seconds: 1), () {
            _startListening(context);
          });
        }
      },
    );
  }

  // ===============================
  // Handle NFC Tag
  // ===============================

  Future<void> _handleNfcTag(BuildContext context, NfcTag tag) async {
    final storage = UserStorageService();
    final currentUserId = await storage.getUserId();

    if (currentUserId == null) {
      debugPrint("❌ User not logged in");
      return;
    }

    final ndef = Ndef.from(tag);

    if (ndef == null || ndef.cachedMessage == null) {
      debugPrint("❌ No NDEF found");
      return;
    }

    final records = ndef.cachedMessage!.records;

    if (records.isEmpty) return;

    final payload = utf8.decode(records.first.payload);
    final data = jsonDecode(payload);

    final otherUserId = data['user_id'] is int ? data['user_id'] : int.tryParse(data['user_id'].toString());

    if (otherUserId == null) {
      debugPrint("❌ Invalid NFC data");
      return;
    }

    if (otherUserId == currentUserId) {
      _showSnack(context, "You cannot connect with yourself");
      return;
    }

    // ===============================
    // Duplicate tap protection
    // ===============================

    if (_lastScannedUserId == otherUserId &&
        _lastScanTime != null &&
        DateTime.now().difference(_lastScanTime!) <
            const Duration(seconds: 5)) {
      debugPrint("⚠️ Duplicate NFC tap ignored");
      return;
    }

    _lastScannedUserId = otherUserId;
    _lastScanTime = DateTime.now();

    debugPrint("🎯 NFC Tap: $currentUserId -> $otherUserId");

    // Navigate profile
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProfilePage(
            userId: otherUserId,
            viewerUserId: currentUserId,
            fromSuggestion: true,
          ),
        ),
      );
    }

    await _sendConnectionRequest(context, otherUserId);
  }

  // ===============================
  // Send Connection Request
  // ===============================

  Future<void> _sendConnectionRequest(
      BuildContext context, int receiverId) async {
    try {
      final storage = UserStorageService();
      final token = await storage.getToken();

      if (token == null) return;

      final response = await http.post(
        Uri.parse("${AppConfig.apiBaseUrl}/connection-request"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "receiver_id": receiverId,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        _showSnack(context, "Connection request sent");
      } else if (data["message"] != null) {
        _showSnack(context, data["message"]);
      } else {
        _showSnack(context, "Connection request failed");
      }
    } catch (e) {
      debugPrint("🔴 Connection error $e");
      _showSnack(context, "Connection failed");
    }
  }

  // ===============================
  // NFC Write Message
  // ===============================

  Future<NdefMessage> generateNdefMessage() async {
    final storage = UserStorageService();
    final userId = await storage.getUserId();

    if (userId == null) {
      throw Exception("User not logged in");
    }

    final data = jsonEncode({
      "user_id": userId,
      "timestamp": DateTime.now().millisecondsSinceEpoch,
      "app": "byndai",
      "version": "1.0",
    });

    return NdefMessage(
      records: [
        NdefRecord(
          typeNameFormat: TypeNameFormat.media,
          type: Uint8List.fromList(
            utf8.encode("application/vnd.byndai.connection"),
          ),
          identifier: Uint8List(0),
          payload: Uint8List.fromList(utf8.encode(data)),
        ),
      ],
    );
  }

  // ===============================
  // Snack helper
  // ===============================

  void _showSnack(BuildContext context, String msg) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ===============================
  // Stop Listening
  // ===============================

  void stopListening() {
    if (_isListening) {
      NfcManager.instance.stopSession();
      _isListening = false;
      _status = NfcConnectionStatus.idle;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
