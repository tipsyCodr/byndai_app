import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:http/http.dart' as http;

/// Communicates with the ByndAI backend AI chatbot endpoints.
///
/// Endpoints (all require Sanctum Bearer token):
///   POST /api/ai/chat          → non-streaming, returns {"reply":"..."}
///   POST /api/ai/chat/stream   → SSE stream, chunks: data: {"content":"..."}
class AiChatbotService {
  static const String _baseUrl = AppConfig.apiBaseUrl;
  static const _storage = FlutterSecureStorage();

  static Future<Map<String, String>> _headers() async {
    final token = await _storage.read(key: 'token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Non-streaming ──────────────────────────────────────────────────────────

  /// Sends [message] with optional [history] and returns the assistant reply.
  /// [history] is a list of `{"role": "user"|"assistant", "content": "..."}`.
  static Future<String> sendMessage(
    String message, {
    List<Map<String, String>> history = const [],
  }) async {
    final uri = Uri.parse('$_baseUrl/ai/chat');
    try {
      final response = await http
          .post(
            uri,
            headers: await _headers(),
            body: jsonEncode({'message': message, 'history': history}),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['reply']?.toString() ?? '';
      } else {
        debugPrint('🤖 AI chat error ${response.statusCode}: ${response.body}');
        return 'Error ${response.statusCode}. Please try again.';
      }
    } on TimeoutException {
      return 'Request timed out. Please try again.';
    } catch (e) {
      debugPrint('🤖 AI chat exception: $e');
      return 'Network error. Please check your connection.';
    }
  }

  // ── Streaming ──────────────────────────────────────────────────────────────

  /// Streams the AI reply token-by-token via SSE.
  ///
  /// Each emitted [String] is a partial content chunk.
  /// The stream closes when the server sends `data: [DONE]` or the connection
  /// ends. Errors are emitted as `StreamError` events.
  static Stream<String> streamMessage(
    String message, {
    List<Map<String, String>> history = const [],
  }) async* {
    final uri = Uri.parse('$_baseUrl/ai/chat/stream');
    final headers = await _headers();

    final request = http.Request('POST', uri)
      ..headers.addAll(headers)
      ..body = jsonEncode({'message': message, 'history': history});

    try {
      final streamedResponse = await request
          .send()
          .timeout(const Duration(seconds: 10)); // connect timeout only

      if (streamedResponse.statusCode != 200) {
        final body = await streamedResponse.stream.bytesToString();
        debugPrint('🤖 AI stream error ${streamedResponse.statusCode}: $body');
        yield 'Error ${streamedResponse.statusCode}. Please try again.';
        return;
      }

      await for (final chunk in streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (!chunk.startsWith('data:')) continue;
        final raw = chunk.substring(5).trim();
        if (raw == '[DONE]') break;
        try {
          final data = jsonDecode(raw) as Map<String, dynamic>;
          final content = data['content']?.toString();
          if (content != null && content.isNotEmpty) yield content;
        } catch (_) {
          // malformed chunk — skip
        }
      }
    } on TimeoutException {
      yield 'Connection timed out. Please try again.';
    } catch (e) {
      debugPrint('🤖 AI stream exception: $e');
      yield 'Network error. Please check your connection.';
    }
  }
}

