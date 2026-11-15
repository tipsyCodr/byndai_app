import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/api_header_service.dart';
import 'package:http/http.dart' as http;

/// Communicates with the ByndAI backend AI chatbot endpoints.
///
/// Endpoints (Sanctum Bearer token):
///   GET    /api/ai/conversations       → list user's conversation sessions
///   GET    /api/ai/conversations/{id}  → get messages for a conversation
///   DELETE /api/ai/conversations/{id}  → delete conversation
///   POST   /api/ai/chat                → non-streaming chat
///   POST   /api/ai/chat/stream         → SSE stream chat
class AiChatbotService {
  static const String _baseUrl = AppConfig.apiBaseUrl;

  static Future<Map<String, String>> _headers() async {
    return await ApiHeaderService.getHeaders();
  }

  // ── Conversation Management ────────────────────────────────────────────────

  /// Fetches all conversations of the authenticated user.
  static Future<List<Map<String, dynamic>>> fetchConversations() async {
    final uri = Uri.parse('$_baseUrl/ai/conversations');
    try {
      final response = await http
          .get(uri, headers: await _headers())
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = data['conversations'];
        if (list is List) {
          return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('🤖 Error fetching conversations: $e');
      return [];
    }
  }

  /// Fetches all messages belonging to a conversation.
  static Future<List<Map<String, dynamic>>> fetchMessages(int conversationId) async {
    final uri = Uri.parse('$_baseUrl/ai/conversations/$conversationId');
    try {
      final response = await http
          .get(uri, headers: await _headers())
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = data['messages'];
        if (list is List) {
          return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('🤖 Error fetching messages for conversation $conversationId: $e');
      return [];
    }
  }

  /// Deletes a conversation and its messages.
  static Future<bool> deleteConversation(int conversationId) async {
    final uri = Uri.parse('$_baseUrl/ai/conversations/$conversationId');
    try {
      final response = await http
          .delete(uri, headers: await _headers())
          .timeout(const Duration(seconds: 15));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('🤖 Error deleting conversation $conversationId: $e');
      return false;
    }
  }

  // ── Non-streaming Chat ─────────────────────────────────────────────────────

  /// Sends [message] and returns assistant response with conversation info.
  static Future<Map<String, dynamic>> sendMessage(
    String message, {
    int? conversationId,
    List<Map<String, String>> history = const [],
  }) async {
    final uri = Uri.parse('$_baseUrl/ai/chat');
    try {
      final response = await http
          .post(
            uri,
            headers: await _headers(),
            body: jsonEncode({
              'message': message,
              'conversation_id': conversationId,
              'history': history,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'reply': data['reply']?.toString() ?? '',
          'conversation_id': data['conversation_id'],
          'conversation_title': data['conversation_title'],
        };
      } else {
        debugPrint('🤖 AI chat error ${response.statusCode}: ${response.body}');
        return {
          'reply': 'Error ${response.statusCode}. Please try again.',
          'is_error': true,
        };
      }
    } on TimeoutException {
      return {'reply': 'Request timed out. Please try again.', 'is_error': true};
    } catch (e) {
      debugPrint('🤖 AI chat exception: $e');
      return {'reply': 'Network error. Please check your connection.', 'is_error': true};
    }
  }

  // ── Streaming Chat ─────────────────────────────────────────────────────────

  /// Streams the AI reply token-by-token via SSE.
  /// [onMeta] is called as soon as conversation metadata arrives from server.
  static Stream<String> streamMessage(
    String message, {
    int? conversationId,
    List<Map<String, String>> history = const [],
    void Function(int conversationId, String title)? onMeta,
  }) async* {
    final uri = Uri.parse('$_baseUrl/ai/chat/stream');
    final headers = await _headers();

    final request = http.Request('POST', uri)
      ..headers.addAll(headers)
      ..body = jsonEncode({
        'message': message,
        'conversation_id': conversationId,
        'history': history,
      });

    try {
      final streamedResponse = await request
          .send()
          .timeout(const Duration(seconds: 12));

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

          // Meta event with conversation id/title
          if (data.containsKey('meta') && data['meta'] is Map) {
            final meta = data['meta'] as Map;
            final convId = meta['conversation_id'];
            final convTitle = meta['title']?.toString() ?? 'Chat';
            if (convId is int && onMeta != null) {
              onMeta(convId, convTitle);
            }
          }

          final content = data['content']?.toString();
          if (content != null && content.isNotEmpty) {
            yield content;
          }
        } catch (_) {
          // malformed or ping chunk
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
