
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:http/http.dart' as http;

import '../../routes/route_names.dart';
import 'package:http_parser/http_parser.dart';

class QRScanViewProfile extends StatefulWidget {
  final String receiverId;
  final String name;
  final String email;
  final String mobile;
  final String senderId;
  final String senderName;

  const QRScanViewProfile({
    super.key,
    required this.receiverId,
    required this.name,
    required this.email,
    required this.mobile,
    required this.senderId,
    required this.senderName,
  });

  @override
  State<QRScanViewProfile> createState() => _QRScanViewProfileState();
}

class _QRScanViewProfileState extends State<QRScanViewProfile> {
  static const String _baseUrl = AppConfig.apiBaseUrl;
  static const _storage = FlutterSecureStorage();

  bool _isLoading = false;

  // ================= HEADERS =================
  static Future<Map<String, String>> _getHeaders(
      {bool isMultipart = false}) async {
    final token = await UserStorageService().getToken();
    return {
      if (!isMultipart) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ================= API CALL =================
  /// null = success
  /// String = error message
  Future<String?> _sendConnectionRequest(int receiverId) async {
    final url = Uri.parse('$_baseUrl/connection-create');

    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'receiver_id': receiverId,
        }),
      );

      debugPrint('📡 Status Code: ${response.statusCode}');
      debugPrint('📩 Response Body: ${response.body}');

      final data = jsonDecode(response.body);

      // ✅ SUCCESS
      if (response.statusCode == 200 || response.statusCode == 201) {
        return null;
      }

      // ❌ VALIDATION ERROR (422)
      if (response.statusCode == 422) {
        if (data['errors'] != null) {
          if (data['errors']['receiver_id'] != null) {
            return data['errors']['receiver_id'][0];
          }
        }
        return data['message'] ?? 'Validation error';
      }

      // ❌ OTHER SERVER ERRORS
      return data['message'] ?? 'Something went wrong';

    } catch (e) {
      debugPrint('🚨 API Exception: $e');
      return 'Server error, please try again';
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Profile Details'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _profileCard(),
              const SizedBox(height: 30),

              // ================= SEND BUTTON =================
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          try {
                            final receiverId =
                                int.parse(widget.receiverId);

                            setState(() => _isLoading = true);

                            final errorMessage =
                                await _sendConnectionRequest(receiverId);

                            setState(() => _isLoading = false);

                            if (!mounted) return;

                            // ✅ SUCCESS
                            if (errorMessage == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('✅ Connection request sent'),
                                  backgroundColor: Colors.green,
                                ),
                              );

                              // Navigator.popUntil(
                              //   context,
                              //   (route) =>
                              //       route.settings.name ==
                              //       RouteNames.profile_qr,
                              // );
                               Navigator.pop(context, true);
                            }
                            // ❌ ERROR FROM API
                            else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(errorMessage),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } catch (e) {
                            setState(() => _isLoading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('Invalid Receiver ID: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send, size: 20),
                            SizedBox(width: 10),
                            Text(
                              'Send Connection Request',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= PROFILE CARD =================
  Widget _profileCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.person, size: 80, color: Colors.blue),
          const SizedBox(height: 16),
          Text(
            widget.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(widget.email),
          Text(widget.mobile),
        ],
      ),
    );
  }
}
