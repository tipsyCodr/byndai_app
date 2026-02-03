import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:http/http.dart' as http;

import '../../routes/route_names.dart';

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

  // 🔹 Headers
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // 🔹 Direct API Call
  Future<bool> _sendConnectionRequest(int userId) async {
    final url = Uri.parse('$_baseUrl/connection-create');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'request_to': userId}),
      );

      debugPrint('📡 Status Code: ${response.statusCode}');
      debugPrint('📩 Response: ${response.body}');

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('🚨 Error creating connection: $e');
      return false;
    }
  }

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

              // 🔹 SEND CONNECTION REQUEST BUTTON
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

                            final success =
                                await _sendConnectionRequest(receiverId);

                            setState(() => _isLoading = false);

                            if (!mounted) return;

                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('✅ Connection request sent'),
                                  backgroundColor: Colors.green,
                                ),
                              );

                              Navigator.popUntil(
                                context,
                                (route) =>
                                    route.settings.name ==
                                    RouteNames.profile_qr,
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('❌ Failed to send request'),
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

  // ================= UI PART =================

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
