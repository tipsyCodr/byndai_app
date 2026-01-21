import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/core/services/chat_provider.dart';
import 'package:provider/provider.dart';

class ChatRoomPage extends StatefulWidget {
  final int connectionId;
  final String otherUserName;

  const ChatRoomPage({
    super.key,
    required this.connectionId,
    required this.otherUserName,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Assuming we fetch messages for this connection
    // provider.fetchMessages(widget.connectionId);
  }

  void _sendMessage() async {
    if (_messageController.text.isEmpty) return;

    final success = await context.read<ChatProvider>().sendMessage(
          widget.connectionId,
          _messageController.text,
        );

    if (success) {
      _messageController.clear();
      // Scroll to bottom or re-fetch
    }
  }

  @override
  Widget build(BuildContext context) {
    // final provider = context.watch<ChatProvider>();
    // final messages = provider.getMessages(widget.connectionId);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.otherUserName,
            style: const TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              reverse: true,
              itemCount: 0, // messages.length
              itemBuilder: (context, index) {
                // final msg = messages[index];
                // bool isMe = msg['sender_id'] == myId;
                return const SizedBox.shrink();
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: const Border(top: BorderSide(color: Colors.white10)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add, color: Colors.blueAccent),
              onPressed: () {},
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: const TextStyle(color: Colors.white24),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.black,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Colors.blueAccent),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}
