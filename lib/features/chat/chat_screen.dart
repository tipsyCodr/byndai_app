
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';

// class ChatScreen extends StatefulWidget {
//   final int receiverId;
//   final String receiverName;
//   final String? receiverUserName;

//   const ChatScreen({
//     super.key,
//     required this.receiverId,
//     required this.receiverName,
//     this.receiverUserName,
//   });

//   @override
//   State<ChatScreen> createState() => _ChatScreenState();
// }

// class _ChatScreenState extends State<ChatScreen> {
//   final TextEditingController _msgController = TextEditingController();
//   final ScrollController _scrollController = ScrollController();

//   // ✅ Messages list (local demo)
//   final List<Map<String, dynamic>> _messages = [];

//   @override
//   void dispose() {
//     _msgController.dispose();
//     _scrollController.dispose();
//     super.dispose();
//   }

//   // ✅ Send message function
//   void _sendMessage() {
//     final text = _msgController.text.trim();

//     if (text.isEmpty) return;

//     setState(() {
//       _messages.add({
//         "text": text,
//         "time": DateTime.now(),
//         "isMe": true,
//       });
//     });

//     _msgController.clear();

//     // ✅ scroll to bottom
//     Future.delayed(const Duration(milliseconds: 100), () {
//       if (_scrollController.hasClients) {
//         _scrollController.animateTo(
//           _scrollController.position.maxScrollExtent,
//           duration: const Duration(milliseconds: 300),
//           curve: Curves.easeOut,
//         );
//       }
//     });
//   }

//   // ✅ Date Label like Today / Yesterday / dd MMM yyyy
//   String _getDateLabel(DateTime date) {
//     final now = DateTime.now();

//     final today = DateTime(now.year, now.month, now.day);
//     final msgDay = DateTime(date.year, date.month, date.day);

//     final diff = today.difference(msgDay).inDays;

//     if (diff == 0) return "Today";
//     if (diff == 1) return "Yesterday";

//     return DateFormat("dd MMM yyyy").format(date);
//   }

//   // ✅ Time format like 11:30 AM
//   String _formatTime(DateTime time) {
//     return DateFormat("hh:mm a").format(time);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,

//       appBar: AppBar(
//         backgroundColor: Colors.black,
//         leading: IconButton(
//           icon: const Icon(CupertinoIcons.back, color: Colors.white),
//           onPressed: () => Navigator.pop(context),
//         ),
//         titleSpacing: 0,
//         title: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               widget.receiverName,
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 16,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//             const SizedBox(height: 2),
//             Text(
//               widget.receiverUserName ?? "Offline",
//               style: const TextStyle(
//                 color: Colors.white54,
//                 fontSize: 12,
//               ),
//             ),
//           ],
//         ),
//       ),

//       body: Column(
//         children: [
//           // ✅ Messages Area
//           Expanded(
//             child: _messages.isEmpty
//                 ? Center(
//                     child: Text(
//                       "Start chat with ${widget.receiverName}",
//                       style: const TextStyle(color: Colors.white38),
//                     ),
//                   )
//                 : ListView.builder(
//                     controller: _scrollController,
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 12,
//                       vertical: 12,
//                     ),
//                     itemCount: _messages.length,
//                     itemBuilder: (context, index) {
//                       final msg = _messages[index];
//                       final msgTime = msg["time"] as DateTime;

//                       // Date separator logic
//                       bool showDateSeparator = false;

//                       if (index == 0) {
//                         showDateSeparator = true;
//                       } else {
//                         final prevMsg = _messages[index - 1];
//                         final prevTime = prevMsg["time"] as DateTime;

//                         final prevDay =
//                             DateTime(prevTime.year, prevTime.month, prevTime.day);
//                         final currentDay =
//                             DateTime(msgTime.year, msgTime.month, msgTime.day);

//                         if (prevDay != currentDay) {
//                           showDateSeparator = true;
//                         }
//                       }

//                       return Column(
//                         children: [
//                           if (showDateSeparator)
//                             Padding(
//                               padding: const EdgeInsets.symmetric(vertical: 10),
//                               child: Container(
//                                 padding: const EdgeInsets.symmetric(
//                                   horizontal: 12,
//                                   vertical: 6,
//                                 ),
//                                 decoration: BoxDecoration(
//                                   color: const Color(0xFF1E1E1E),
//                                   borderRadius: BorderRadius.circular(14),
//                                   border: Border.all(color: Colors.white12),
//                                 ),
//                                 child: Text(
//                                   _getDateLabel(msgTime),
//                                   style: const TextStyle(
//                                     color: Colors.white70,
//                                     fontSize: 12,
//                                     fontWeight: FontWeight.w500,
//                                   ),
//                                 ),
//                               ),
//                             ),

//                           _MessageBubble(
//                             text: msg["text"],
//                             time: _formatTime(msgTime),
//                             isMe: msg["isMe"] ?? true,
//                           ),
//                         ],
//                       );
//                     },
//                   ),
//           ),

//           // ✅ Bottom Input Box
//           Container(
//             padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
//             decoration: const BoxDecoration(
//               color: Colors.black,
//               border: Border(
//                 top: BorderSide(color: Colors.white12),
//               ),
//             ),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 14),
//                     decoration: BoxDecoration(
//                       color: const Color(0xFF1E1E1E),
//                       borderRadius: BorderRadius.circular(30),
//                       border: Border.all(color: Colors.white12),
//                     ),
//                     child: TextField(
//                       controller: _msgController,
//                       style: const TextStyle(color: Colors.white),
//                       maxLines: 4,
//                       minLines: 1,
//                       decoration: const InputDecoration(
//                         hintText: "Type message...",
//                         hintStyle: TextStyle(color: Colors.white38),
//                         border: InputBorder.none,
//                       ),
//                       onSubmitted: (_) => _sendMessage(),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 10),
//                 Container(
//                   height: 46,
//                   width: 46,
//                   decoration: BoxDecoration(
//                     color: Colors.blueAccent,
//                     borderRadius: BorderRadius.circular(30),
//                   ),
//                   child: IconButton(
//                     icon: const Icon(Icons.send, color: Colors.white),
//                     onPressed: _sendMessage,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _MessageBubble extends StatelessWidget {
//   final String text;
//   final String time;
//   final bool isMe;

//   const _MessageBubble({
//     required this.text,
//     required this.time,
//     required this.isMe,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Align(
//       alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
//       child: Container(
//         margin: const EdgeInsets.symmetric(vertical: 6),
//         padding: const EdgeInsets.fromLTRB(12, 10, 10, 6),
//         constraints: BoxConstraints(
//           maxWidth: MediaQuery.of(context).size.width * 0.78,
//         ),
//         decoration: BoxDecoration(
//           color: isMe ? const Color(0xFF0B5CFF) : const Color(0xFF1E1E1E),
//           borderRadius: BorderRadius.circular(16),
//         ),
//         child: Column(
//           crossAxisAlignment:
//               isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
//           children: [
//             Text(
//               text,
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 15,
//               ),
//             ),
//             const SizedBox(height: 4),
//             Text(
//               time,
//               style: const TextStyle(
//                 color: Colors.white70,
//                 fontSize: 11,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }


//=====================================================================================


import 'dart:convert';
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

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
      // my user id (from session)
      final session = await UserStorageService().loadSession();
      _myUserId = session.user?.id;

      await _loadMessages();

      // Mark read (optional but good)
      await _markAsRead();

      // Scroll bottom after load
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

          // scroll bottom
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

      // attachments future me add kar sakte hain

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

          // scroll bottom
          Future.delayed(const Duration(milliseconds: 100), () {
            _scrollToBottom();
          });

          return;
        }
      }

      debugPrint("❌ send-message failed: $responseBody");

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Message send nahi hua")),
      );
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
      // created_at example: "2026-02-05T10:30:00.000000Z"
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
  // UI
  // ===========================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.receiverName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "Chat ID: ${widget.chatId}",
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await _loadMessages();
            },
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),

      body: Column(
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
                          style: const TextStyle(color: Colors.white38),
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
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E1E1E),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child: Text(
                                      _getDateLabel(msgTime),
                                      style: const TextStyle(
                                        color: Colors.white70,
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

          // ✅ Bottom Input Box
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: const BoxDecoration(
              color: Colors.black,
              border: Border(
                top: BorderSide(color: Colors.white12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: TextField(
                      controller: _msgController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 4,
                      minLines: 1,
                      decoration: const InputDecoration(
                        hintText: "Type message...",
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    color: _isSending ? Colors.grey : Colors.blueAccent,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white),
                    onPressed: _isSending ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF0B5CFF) : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
