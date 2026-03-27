import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:gridcard/core/services/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';

import '../features/feature_map/feature_access_helper.dart';
import '../features/feature_map/feature_mapper.dart';
import '../features/home/SubscriptionPlans.dart';
import 'package:gridcard/core/services/auth_provider.dart';
import 'package:provider/provider.dart';

class ShareProfileWidget extends StatefulWidget {
  const ShareProfileWidget({super.key});

  @override
  State<ShareProfileWidget> createState() => _ShareProfileWidgetState();
}

class _ShareProfileWidgetState extends State<ShareProfileWidget> {
  final TextEditingController _phoneController = TextEditingController();

  static const String _baseUrl = AppConfig.apiBaseUrl;

  // ================= HEADERS =================
  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Future<void> _sendToWhatsApp() async {
  //   final phone = _phoneController.text.trim();
  //   if (phone.isEmpty) return;

  //   final user = context.read<AuthProvider>().user;
  //   final profileId = user?.userName ?? user?.id?.toString() ?? 'me';
  //   final baseUrl = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/api$'), '');
  //   final profileUrl = "$baseUrl/u/$profileId";

  //   final message =
  //       "Hi, check out my Bynd AI digital business card here: $profileUrl";

  //   final encodedMessage = Uri.encodeComponent(message);

  //   String formattedPhone = phone;

  //   if (RegExp(r'^\d{10}$').hasMatch(phone)) {
  //     formattedPhone = "91$phone";
  //   }

  //   final whatsappUrl =
  //       Uri.parse("https://wa.me/$formattedPhone?text=$encodedMessage");

  //   await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
  // }

  Future<void> _sendToWhatsApp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;

    try {
      // 🔥 1. API CALL (Feature check)
      final headers = await _getHeaders();

      final response = await http.post(
        Uri.parse("$_baseUrl/show-mini-website"),
        headers: headers,
      );

      final data = jsonDecode(response.body);

      // ❌ LIMIT EXCEEDED
      if (response.statusCode == 403 || data['success'] == false) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const SubscriptionPlans(),
            ),
          );
        }
        return;
      }

      // ✅ SUCCESS → continue sharing
      final user = context.read<AuthProvider>().user;
      final profileId = user?.userName ?? user?.id?.toString() ?? 'me';
      final baseUrl = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/api$'), '');
      final profileUrl = "$baseUrl/u/$profileId";

      final message =
          "Hi, check out my Bynd AI digital business card here: $profileUrl";

      final encodedMessage = Uri.encodeComponent(message);

      String formattedPhone = phone;

      if (RegExp(r'^\d{10}$').hasMatch(phone)) {
        formattedPhone = "91$phone";
      }

      final whatsappUrl =
          Uri.parse("https://wa.me/$formattedPhone?text=$encodedMessage");

      await launchUrl(
        whatsappUrl,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      print("❌ Share Error: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Something went wrong")),
        );
      }
    }
  }

  Future<void> _shareNative() async {
    final user = context.read<AuthProvider>().user;
    final profileId = user?.userName ?? user?.id?.toString() ?? 'me';
    final baseUrl = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/api$'), '');
    final profileUrl = "$baseUrl/profile/$profileId";

    final message =
        "Hi, check out my bynd AI digital business card here: $profileUrl";

    await Share.share(message);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Share Profile",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "+91",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _phoneController,
                    style: TextStyle(color: colors.onSurface),
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? colors.surfaceContainerHighest
                          : Colors.grey[100],
                      hintText: "Enter Phone",
                      hintStyle:
                          TextStyle(color: colors.onSurface.withOpacity(0.3)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _sendToWhatsApp,
              icon: const Icon(Icons.share, size: 18),
              label: const Text("Share Your Profile Card"),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: colors.primary.withOpacity(0.2)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Cancel",
                style: TextStyle(color: colors.onSurface.withOpacity(0.5)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
