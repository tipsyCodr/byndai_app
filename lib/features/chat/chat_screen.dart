import 'dart:convert';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/firestore_chat_service.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:gridcard/core/theme/app_theme.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:gridcard/widgets/top_alert.dart';

class ChatScreen extends StatefulWidget {
  final int chatId;
  final int receiverId;
  final String receiverName;
  final String? receiverPic;
  final bool initialBlockedByMe;
  final bool initialBlockedByOther;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.receiverId,
    required this.receiverName,
    this.receiverPic,
    this.initialBlockedByMe = false,
    this.initialBlockedByOther = false,
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
  bool _blockedByMe = false;
  bool _blockedByOther = false;

  int? _myUserId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _chatDocSub;

  @override
  void initState() {
    super.initState();
    _blockedByMe = widget.initialBlockedByMe;
    _blockedByOther = widget.initialBlockedByOther;
    _initChat();
  }

  @override
  void dispose() {
    _chatDocSub?.cancel();
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
      if (_myUserId != null) {
        _chatDocSub =
            FirestoreChatService.getChatDocStream(widget.chatId).listen((doc) {
          if (!mounted) return;
          if (doc.data()?.containsKey('blocked_by') != true) return;
          final blockedBy = (doc.data()?['blocked_by'] as List?)
                  ?.map((e) => int.tryParse(e.toString()))
                  .whereType<int>()
                  .toList() ??
              [];
          setState(() {
            _blockedByMe = blockedBy.contains(_myUserId);
            _blockedByOther = blockedBy.contains(widget.receiverId);
          });
        });
        await FirestoreChatService.markChatRead(
          chatId: widget.chatId,
          userId: _myUserId!,
        );
      }
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
          final msgs = List<dynamic>.from(jsonData["messages"] ?? []);

          // Seed Firestore with backend history (only if Firestore is empty)
          await FirestoreChatService.seedMessagesIfEmpty(
            chatId: widget.chatId,
            messages: msgs,
          );

          setState(() => _isLoading = false);

          Future.delayed(const Duration(milliseconds: 200), () {
            _scrollToBottom();
          });
          return;
        }
      }

      debugPrint("❌ get-message failed: ${response.body}");
      setState(() => _isLoading = false);
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

  Future<bool> _setBlockStatus(bool willBlock) async {
    if (_myUserId == null) return false;
    try {
      final endpoint = willBlock ? 'block' : 'unblock';
      final uri = Uri.parse("$_baseUrl/chat/$endpoint");
      final headers = await _getHeaders();
      headers["Content-Type"] = "application/json";

      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({"blocked_id": widget.receiverId}),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData["status"] == true) {
          await FirestoreChatService.setChatBlocked(
            chatId: widget.chatId,
            userId: _myUserId!,
            isBlocked: willBlock,
          );
          return true;
        }
      }
      debugPrint("❌ $endpoint failed: ${response.statusCode} ${response.body}");
    } catch (e) {
      debugPrint("❌ _setBlockStatus Exception: $e");
    }
    return false;
  }

  Future<void> _sendMessage() async {
    if (_blockedByMe || _blockedByOther) return;
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    if (_isSending) return;
    HapticFeedback.lightImpact();

    // Optimistically clear input immediately
    _msgController.clear();

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
          final createdAt = newMsg?["created_at"]?.toString();

          // Sync to Firestore → triggers realtime stream on receiver's device
          await FirestoreChatService.syncMessageToFirestore(
            chatId: widget.chatId,
            senderId: _myUserId ?? 0,
            receiverId: widget.receiverId,
            message: text,
            createdAt: createdAt,
          );

          return;
        }
      }

      debugPrint("❌ send-message failed: $responseBody");

      if (!mounted) return;
      if (streamed.statusCode == 403) {
        String msg = "Cannot send message. User is blocked.";
        try {
          final decoded = jsonDecode(responseBody);
          if (decoded["message"] != null) {
            msg = decoded["message"].toString();
          }
        } catch (_) {}
        TopAlert.show(context, msg, isError: true);
      } else {
        TopAlert.show(context, "Message send nahi hua", isError: true);
      }
    } catch (e) {
      debugPrint("❌ _sendMessage Exception: $e");
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;

    _scrollController.animateTo(
      0.0,
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

    return DateFormat("dd MMMM yyyy").format(date);
  }

  String _formatTime(DateTime time) {
    return DateFormat("hh:mm a").format(time);
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
        leadingWidth: 40,
        leading: IconButton(
          icon: Icon(
            CupertinoIcons.back,
            color: colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colorScheme.surfaceContainerHighest,
              backgroundImage: widget.receiverPic != null &&
                      widget.receiverPic!.isNotEmpty
                  ? NetworkImage(
                      "${AppConfig.apiProfileImg}/${widget.receiverPic}",
                    )
                  : null,
              child: widget.receiverPic == null || widget.receiverPic!.isEmpty
                  ? Icon(
                      Icons.person,
                      size: 20,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.receiverName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: colorScheme.onSurface),
            onSelected: (value) async {
              if (value == 'delete_chat') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Delete Chat"),
                    content: const Text(
                        "Are you sure you want to delete this chat history?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          "Delete",
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirm == true && context.mounted) {
                  await FirestoreChatService.deleteChat(widget.chatId);
                  if (context.mounted) {
                    TopAlert.show(context, "Chat deleted");
                    Navigator.pop(context);
                  }
                }
              } else if (value == 'block') {
                final willBlock = !_blockedByMe;
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(willBlock ? "Block User" : "Unblock User"),
                    content: Text(willBlock
                        ? "Are you sure you want to block ${widget.receiverName}?"
                        : "Unblock ${widget.receiverName} to resume messaging?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(
                          willBlock ? "Block" : "Unblock",
                          style: TextStyle(
                            color: willBlock
                                ? Colors.redAccent
                                : colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirm == true && _myUserId != null && context.mounted) {
                  final ok = await _setBlockStatus(willBlock);
                  if (!context.mounted) return;
                  if (ok) {
                    setState(() => _blockedByMe = willBlock);
                    TopAlert.show(
                      context,
                      willBlock
                          ? "${widget.receiverName} blocked"
                          : "${widget.receiverName} unblocked",
                    );
                  } else {
                    TopAlert.show(
                      context,
                      "Failed to update block status",
                      isError: true,
                    );
                  }
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'delete_chat',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Delete Chat',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'block',
                child: Row(
                  children: [
                    Icon(
                      _blockedByMe ? Icons.lock_open_rounded : Icons.block,
                      color:
                          _blockedByMe ? colorScheme.primary : Colors.redAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _blockedByMe ? 'Unblock' : 'Block',
                      style: TextStyle(
                        color: _blockedByMe
                            ? colorScheme.primary
                            : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBackground(
        context: context,
        child: Column(
          children: [
            // ✅ Messages Area – realtime via Firestore stream
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirestoreChatService.getMessagesStream(
                          widget.chatId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        if (!snapshot.hasData ||
                            snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Text(
                              "Start chat with ${widget.receiverName}",
                              style: TextStyle(
                                  color: colorScheme.onSurfaceVariant),
                            ),
                          );
                        }

                        final docs = snapshot.data!.docs.reversed.toList();

                        return ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final data = docs[index].data();

                            // Parse timestamp from Firestore
                            DateTime msgTime;
                            final ts = data['timestamp'];
                            if (ts is Timestamp) {
                              msgTime = ts.toDate().toLocal();
                            } else {
                              try {
                                msgTime = DateTime.parse(
                                        data['created_at']?.toString() ?? '')
                                    .toLocal();
                              } catch (_) {
                                msgTime = DateTime.now();
                              }
                            }

                            final senderId =
                                int.tryParse(data['sender_id'].toString());
                            final isMe = _myUserId != null &&
                                (senderId == _myUserId ||
                                    data['sender_id'].toString() ==
                                        _myUserId.toString());
                            final text =
                                data['message']?.toString() ?? '';

                            // Date separator logic for inverted list (index 0 is newest, last index is oldest)
                            bool showDateSeparator = false;
                            if (index == docs.length - 1) {
                              showDateSeparator = true;
                            } else {
                              final nextData = docs[index + 1].data();
                              DateTime nextTime;
                              final nts = nextData['timestamp'];
                              if (nts is Timestamp) {
                                nextTime = nts.toDate().toLocal();
                              } else {
                                try {
                                  nextTime = DateTime.parse(
                                          nextData['created_at']?.toString() ??
                                              '')
                                      .toLocal();
                                } catch (_) {
                                  nextTime = DateTime.now();
                                }
                              }

                              final nextDay = DateTime(
                                  nextTime.year, nextTime.month, nextTime.day);
                              final currDay = DateTime(
                                  msgTime.year, msgTime.month, msgTime.day);
                              if (nextDay != currDay) showDateSeparator = true;
                            }

                            return Column(
                              children: [
                                if (showDateSeparator)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: (palette?.glassTop
                                                .withValues(alpha: 0.5)) ??
                                            colorScheme
                                                .surfaceContainerHighest
                                                .withValues(alpha: 0.5),
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        border: Border.all(
                                          color: colorScheme.outlineVariant
                                              .withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Text(
                                        _getDateLabel(msgTime),
                                        style: TextStyle(
                                          color:
                                              colorScheme.onSurfaceVariant,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                _MessageBubble(
                                  docId: docs[index].id,
                                  text: text,
                                  time: _formatTime(msgTime),
                                  isMe: isMe,
                                  onEdit: (docId, oldText) {
                                    final editController =
                                        TextEditingController(text: oldText);
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text("Edit Message"),
                                        content: TextField(
                                          controller: editController,
                                          autofocus: true,
                                          decoration: const InputDecoration(
                                            hintText: "Enter updated message",
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text("Cancel"),
                                          ),
                                          TextButton(
                                            onPressed: () async {
                                              final updatedText =
                                                  editController.text.trim();
                                              if (updatedText.isNotEmpty) {
                                                await FirestoreChatService
                                                    .updateMessage(
                                                  chatId: widget.chatId,
                                                  docId: docId,
                                                  newMessage: updatedText,
                                                );
                                              }
                                              if (ctx.mounted) {
                                                Navigator.pop(ctx);
                                              }
                                            },
                                            child: const Text("Save"),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  onDelete: (docId) async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text("Delete Message"),
                                        content: const Text(
                                            "Are you sure you want to delete this message?"),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text("Cancel"),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text(
                                              "Delete",
                                              style: TextStyle(
                                                  color: Colors.redAccent),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      await FirestoreChatService.deleteMessage(
                                        chatId: widget.chatId,
                                        docId: docId,
                                      );
                                    }
                                  },
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
            ),
            // ✅ Bottom Input Box – Clean Minimal Composer or Blocked Banner
            SafeArea(
              top: false,
              child: (_blockedByMe || _blockedByOther)
                  ? Container(
                      margin: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color:
                            isDark ? const Color(0xFF1A1D28) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.block,
                            size: 18,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _blockedByMe
                                  ? 'You blocked ${widget.receiverName}'
                                  : 'You cannot reply to this conversation',
                              style: TextStyle(
                                fontSize: 13.5,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (_blockedByMe && _myUserId != null)
                            TextButton(
                              onPressed: () async {
                                final ok = await _setBlockStatus(false);
                                if (ok && mounted) {
                                  setState(() => _blockedByMe = false);
                                }
                              },
                              child: const Text('Unblock'),
                            ),
                        ],
                      ),
                    )
                  : Container(
                      margin: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1D28) : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : colorScheme.primary.withValues(alpha: 0.10),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.30 : 0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgController,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 15,
                        ),
                        maxLines: 4,
                        minLines: 1,
                        textInputAction: TextInputAction.send,
                        decoration: InputDecoration(
                          filled: false,
                          hintText: "Message...",
                          hintStyle: TextStyle(
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.55),
                            fontSize: 14.5,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _isSending ? null : _sendMessage,
                      child: Container(
                        height: 38,
                        width: 38,
                        decoration: BoxDecoration(
                          color: _isSending
                              ? colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.3)
                              : colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: _isSending
                              ? SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colorScheme.onPrimary,
                                  ),
                                )
                              : Icon(
                                  Icons.arrow_upward_rounded,
                                  color: colorScheme.onPrimary,
                                  size: 20,
                                ),
                        ),
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
  final String docId;
  final String text;
  final String time;
  final bool isMe;
  final void Function(String docId, String oldText)? onEdit;
  final void Function(String docId)? onDelete;

  const _MessageBubble({
    required this.docId,
    required this.text,
    required this.time,
    required this.isMe,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: () {
            showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (ctx) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isMe)
                      ListTile(
                        leading: const Icon(Icons.edit),
                        title: const Text("Edit Message"),
                        onTap: () {
                          Navigator.pop(ctx);
                          onEdit?.call(docId, text);
                        },
                      ),
                    ListTile(
                      leading:
                          const Icon(Icons.delete, color: Colors.redAccent),
                      title: Text(
                        isMe ? "Delete Message" : "Delete for me",
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        onDelete?.call(docId);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(13, 9, 11, 7),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.76,
            ),
            decoration: BoxDecoration(
              color: isMe
                  ? colorScheme.primary
                  : isDark
                      ? const Color(0xFF1C2133)
                      : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMe ? 18 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 18),
              ),
              border: isMe
                  ? null
                  : Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : colorScheme.primary.withValues(alpha: 0.08),
                    ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 8,
              runSpacing: 2,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    color:
                        isMe ? colorScheme.onPrimary : colorScheme.onSurface,
                    fontSize: 14.5,
                    height: 1.35,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        color: isMe
                            ? colorScheme.onPrimary.withValues(alpha: 0.72)
                            : colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.7),
                        fontSize: 10.5,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 3),
                      Icon(
                        Icons.done_all_rounded,
                        size: 13.5,
                        color: colorScheme.onPrimary.withValues(alpha: 0.75),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
