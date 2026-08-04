import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:gridcard/features/business_card_scan/domain/models/business_card.dart';

/// Sends the captured card image as multipart to `/gpt-ocr`.
///
/// The server (Laravel) requires `image` as a file upload — it does NOT
/// accept raw_text. GPT-4o-mini parses the image directly on the backend.
///
/// Server response keys:
///   name, company_name, email, email2, website, address,
///   mobile_no_1, mobile_no_2, mobile_no_3
class AIParsingService {
  static const String _endpoint = '${AppConfig.apiBaseUrl}/gpt-ocr';

  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Send [imagePath] as multipart image to the server.
  /// Returns a [BusinessCard] mapped from server response.
  Future<BusinessCard> parseCardImage(String imagePath) async {
    if (imagePath.isEmpty) {
      debugPrint('[AI] ⚠️ imagePath is empty, aborting');
      return const BusinessCard();
    }

    debugPrint('[AI] 🚀 Sending image to /gpt-ocr: $imagePath');

    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final request =
            http.MultipartRequest('POST', Uri.parse(_endpoint));

        final headers = await _getHeaders();
        request.headers.addAll(headers);

        final bytes = await File(imagePath).readAsBytes();
        debugPrint('[AI] 📦 Image size: ${(bytes.length / 1024).toStringAsFixed(1)} KB');

        request.files.add(http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: 'card_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ));

        debugPrint('[AI] 📤 attempt ${attempt + 1} — POST $_endpoint');
        final streamed = await request.send()
            .timeout(const Duration(seconds: 30));
        final body = await streamed.stream.bytesToString();

        debugPrint('[AI] 📥 HTTP ${streamed.statusCode}');
        debugPrint('[AI] 📋 Response body: $body');

        if (streamed.statusCode == 200) {
          final json = jsonDecode(body);
          if (json['success'] == true && json['data'] != null) {
            final card = BusinessCard.fromServerJson(
                Map<String, dynamic>.from(json['data']));
            debugPrint('[AI] ✅ Parsed card: name=${card.name}, company=${card.company}, mobile=${card.mobile}');
            return card;
          }
          debugPrint('[AI] ⚠️ success=false or data=null in response');
        } else {
          debugPrint('[AI] ❌ HTTP error ${streamed.statusCode}');
        }
      } catch (e) {
        debugPrint('[AI] ❌ attempt ${attempt + 1} exception: $e');
        if (attempt == 1) break;
      }
    }
    debugPrint('[AI] 🚫 All attempts failed, returning empty card');
    return const BusinessCard();
  }
}
