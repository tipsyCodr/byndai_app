import 'dart:convert';
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:gridcard/core/theme/app_theme.dart'; // ✅ Added for AppThemeColors
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:gridcard/widgets/top_alert.dart';
import 'package:gridcard/widgets/glass_box.dart'; // ✅ GlassBox for consistent styling

class ChatScreen extends StatefulWidget {
  final int chatId;
  final int receiverId;
  final String receiverName;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final String _baseUrl = AppConfig.apiBaseUrl;

  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isSending = false;

  int? _myUserId;

  // API messages list
  List<dynamic> _messages = [];

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ===========================
  // Helpers
  // ===========================

  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();

    return {
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  Future<void> _initChat() async {
    try {
      final session = await UserStorageService().loadSession();
      _myUserId = session.user?.id;

      await _loadMessages();
      await _markAsRead();
      _scrollToBottom();
    } catch (e) {
      debugPrint("❌ _initChat error: $e");
    }
  }

  Future<void> _loadMessages() async {
    try {
      setState(() => _isLoading = true);

      final uri = Uri.parse("$_baseUrl/chat/get-message/${widget.chatId}");

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        if (jsonData["status"] == true) {
          final msgs = jsonData["messages"] ?? [];

          setState(() {
            _messages = msgs;
            _isLoading = false;
          });

          Future.delayed(const Duration(milliseconds: 200), () {
            _scrollToBottom();
          });
          return;
        }
      }

      debugPrint("❌ get-message failed: ${response.body}");

      setState(() {
        _messages = [];
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("❌ _loadMessages Exception: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead() async {
    try {
      final uri = Uri.parse("$_baseUrl/chat/mark-read/${widget.chatId}");

      final response = await http.post(
        uri,
        headers: await _getHeaders(),
      );

      debugPrint("✅ mark-read: ${response.body}");
    } catch (e) {
      debugPrint("❌ _markAsRead Exception: $e");
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    if (_isSending) return;

    try {
      setState(() => _isSending = true);

      final uri = Uri.parse("$_baseUrl/chat/send-message");

      final request = http.MultipartRequest("POST", uri);
      request.headers.addAll(await _getHeaders());

      request.fields["chat_id"] = widget.chatId.toString();
      request.fields["message"] = text;

      final streamed = await request.send();
      final responseBody = await streamed.stream.bytesToString();

      if (streamed.statusCode == 200) {
        final jsonData = jsonDecode(responseBody);

        if (jsonData["status"] == true) {
          final newMsg = jsonData["data"];

          setState(() {
            _messages.add(newMsg);
          });

          _msgController.clear();

          Future.delayed(const Duration(milliseconds: 100), () {
            _scrollToBottom();
          });

          return;
        }
      }

      debugPrint("❌ send-message failed: $responseBody");

      if (!mounted) return;
      TopAlert.show(context, "Message send nahi hua", isError: true);
    } catch (e) {
      debugPrint("❌ _sendMessage Exception: $e");
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;

    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  // ===========================
  // Date & Time
  // ===========================

  String _getDateLabel(DateTime date) {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(date.year, date.month, date.day);

    final diff = today.difference(msgDay).inDays;

    if (diff == 0) return "Today";
    if (diff == 1) return "Yesterday";

    return DateFormat("dd MMM yyyy").format(date);
  }

  String _formatTime(DateTime time) {
    return DateFormat("hh:mm a").format(time);
  }

  DateTime _parseMessageTime(dynamic msg) {
    try {
      final createdAt = msg["created_at"];
      if (createdAt == null) return DateTime.now();
      return DateTime.parse(createdAt).toLocal();
    } catch (_) {
      return DateTime.now();
    }
  }

  bool _isMe(dynamic msg) {
    final senderId = int.tryParse(msg["sender_id"].toString());
    if (_myUserId == null) return true;
    return senderId == _myUserId;
  }

  String _getMessageText(dynamic msg) {
    final text = msg["message"];
    if (text == null) return "";
    return text.toString();
  }

  // ===========================
  // UI – Light / Dark mode aware
  // ===========================

  Widget _buildLightModePattern(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -150,
            right: -120,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.16),
                    colorScheme.primary.withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: -180,
            child: Container(
              width: 520,
              height: 320,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(240),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.secondary.withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            right: -120,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colorScheme.secondary.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDarkModePattern(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -110,
            right: -140,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colorScheme.secondary.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 140,
            left: -150,
            child: Container(
              width: 420,
              height: 280,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(220),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -180,
            left: 20,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.09),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = Theme.of(context).extension<AppThemeColors>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface, // Let gradient show through
      appBar: AppBar(
     backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            CupertinoIcons.back,
            color: colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.receiverName,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            // Optional: show chat ID if needed (currently hidden)
          ],
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await _loadMessages();
            },
            icon: Icon(Icons.refresh, color: colorScheme.onSurface),
          ),
        ],
      ),
      body: _buildBackground(
        context: context,
        child: Column(
          children: [
            // ✅ Messages Area
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : _messages.isEmpty
                      ? Center(
                          child: Text(
                            "Start chat with ${widget.receiverName}",
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final msgTime = _parseMessageTime(msg);

                            // Date separator logic
                            bool showDateSeparator = false;

                            if (index == 0) {
                              showDateSeparator = true;
                            } else {
                              final prevMsg = _messages[index - 1];
                              final prevTime = _parseMessageTime(prevMsg);

                              final prevDay = DateTime(
                                prevTime.year,
                                prevTime.month,
                                prevTime.day,
                              );

                              final currentDay = DateTime(
                                msgTime.year,
                                msgTime.month,
                                msgTime.day,
                              );

                              if (prevDay != currentDay) {
                                showDateSeparator = true;
                              }
                            }

                            return Column(
                              children: [
                                if (showDateSeparator)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: palette?.glassTop
                                                ?.withValues(alpha: 0.5) ??
                                            colorScheme.surfaceContainerHighest
                                                .withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: colorScheme.outlineVariant
                                              .withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Text(
                                        _getDateLabel(msgTime),
                                        style: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                _MessageBubble(
                                  text: _getMessageText(msg),
                                  time: _formatTime(msgTime),
                                  isMe: _isMe(msg),
                                ),
                              ],
                            );
                          },
                        ),
            ),

            // ✅ Bottom Input Box – Glass style
            Container(
              margin: const EdgeInsets.only(bottom: 8, left: 12, right: 12),
              child: GlassBox(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                borderRadius: 32,
                blur: 15,
                opacity: isDark ? 0.2 : 0.12,
                gradientColors: [
                  (palette?.glassTop ?? colorScheme.surface)
                      .withValues(alpha: isDark ? 0.7 : 0.8),
                  (palette?.glassBottom ?? colorScheme.surface)
                      .withValues(alpha: isDark ? 0.58 : 0.7),
                ],
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgController,
                        style: TextStyle(color: colorScheme.onSurface),
                        maxLines: 4,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: "Type message...",
                          hintStyle: TextStyle(
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 46,
                      width: 46,
                      decoration: BoxDecoration(
                        color: _isSending
                            ? colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.3)
                            : colorScheme.primary,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: IconButton(
                        icon: _isSending
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.onPrimary,
                                ),
                              )
                            : Icon(Icons.send, color: colorScheme.onPrimary),
                        onPressed: _isSending ? null : _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to embed the background under the content
  Widget _buildBackground(
      {required BuildContext context, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).extension<AppThemeColors>()?.backgroundStart ??
                Theme.of(context).colorScheme.surface,
            Theme.of(context).extension<AppThemeColors>()?.backgroundMid ??
                Theme.of(context).colorScheme.surface,
            Theme.of(context).extension<AppThemeColors>()?.backgroundEnd ??
                Theme.of(context).colorScheme.surface,
          ],
        ),
      ),
      child: Stack(
        children: [
          if (Theme.of(context).brightness == Brightness.dark)
            _buildDarkModePattern(context),
          if (Theme.of(context).brightness != Brightness.dark)
            _buildLightModePattern(context),
          child,
        ],
      ),
    );
  }
}

// ===========================
// Message Bubble
// ===========================
class _MessageBubble extends StatelessWidget {
  final String text;
  final String time;
  final bool isMe;

  const _MessageBubble({
    required this.text,
    required this.time,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? colorScheme.primary
              : isDark
                  ? const Color(0xFF1E1E1E)
                  : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isMe ? colorScheme.onPrimary : colorScheme.onSurface,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                color: isMe
                    ? colorScheme.onPrimary.withValues(alpha: 0.8)
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
