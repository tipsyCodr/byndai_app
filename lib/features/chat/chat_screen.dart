// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';

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

//   @override
//   void dispose() {
//     _msgController.dispose();
//     super.dispose();
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
//           // Chat Messages Area (abhi placeholder)
//           Expanded(
//             child: Center(
//               child: Text(
//                 "Chat with ${widget.receiverName}",
//                 style: const TextStyle(color: Colors.white38),
//               ),
//             ),
//           ),

//           // Bottom Input Box
//           Container(
//             padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
//             decoration: BoxDecoration(
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
//                       decoration: const InputDecoration(
//                         hintText: "Type message...",
//                         hintStyle: TextStyle(color: Colors.white38),
//                         border: InputBorder.none,
//                       ),
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
//                     onPressed: () {
//                       // TODO: Send message API later
//                       _msgController.clear();
//                     },
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


import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final int receiverId;
  final String receiverName;
  final String? receiverUserName;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
    this.receiverUserName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // ✅ Messages list (local demo)
  final List<Map<String, dynamic>> _messages = [];

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ✅ Send message function
  void _sendMessage() {
    final text = _msgController.text.trim();

    if (text.isEmpty) return;

    setState(() {
      _messages.add({
        "text": text,
        "time": DateTime.now(),
        "isMe": true,
      });
    });

    _msgController.clear();

    // ✅ scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ✅ Date Label like Today / Yesterday / dd MMM yyyy
  String _getDateLabel(DateTime date) {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(date.year, date.month, date.day);

    final diff = today.difference(msgDay).inDays;

    if (diff == 0) return "Today";
    if (diff == 1) return "Yesterday";

    return DateFormat("dd MMM yyyy").format(date);
  }

  // ✅ Time format like 11:30 AM
  String _formatTime(DateTime time) {
    return DateFormat("hh:mm a").format(time);
  }

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
              widget.receiverUserName ?? "Offline",
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),

      body: Column(
        children: [
          // ✅ Messages Area
          Expanded(
            child: _messages.isEmpty
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
                      final msgTime = msg["time"] as DateTime;

                      // Date separator logic
                      bool showDateSeparator = false;

                      if (index == 0) {
                        showDateSeparator = true;
                      } else {
                        final prevMsg = _messages[index - 1];
                        final prevTime = prevMsg["time"] as DateTime;

                        final prevDay =
                            DateTime(prevTime.year, prevTime.month, prevTime.day);
                        final currentDay =
                            DateTime(msgTime.year, msgTime.month, msgTime.day);

                        if (prevDay != currentDay) {
                          showDateSeparator = true;
                        }
                      }

                      return Column(
                        children: [
                          if (showDateSeparator)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
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
                            text: msg["text"],
                            time: _formatTime(msgTime),
                            isMe: msg["isMe"] ?? true,
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
                    color: Colors.blueAccent,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
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
