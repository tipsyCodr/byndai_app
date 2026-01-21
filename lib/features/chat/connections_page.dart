import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/core/services/chat_provider.dart';
import 'package:gridcard/features/chat/chat_room_page.dart';
import 'package:provider/provider.dart';

class ConnectionsPage extends StatefulWidget {
  const ConnectionsPage({super.key});

  @override
  State<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends State<ConnectionsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().fetchConnections();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final connections = provider.connections;
    // Assuming pending requests are separate or filtered from connections
    final pending = connections.where((c) => c['status'] == 'pending').toList();
    final accepted =
        connections.where((c) => c['status'] == 'accepted').toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Connections', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.blueAccent,
          tabs: const [
            Tab(text: 'Accepted'),
            Tab(text: 'Pending'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildConnectionList(accepted, isPending: false),
          _buildConnectionList(pending, isPending: true),
        ],
      ),
    );
  }

  Widget _buildConnectionList(List<dynamic> list, {required bool isPending}) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          isPending ? 'No pending requests' : 'No connections yet',
          style: const TextStyle(color: Colors.white38),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (context, index) =>
          const Divider(color: Colors.white10),
      itemBuilder: (context, index) {
        final item = list[index];
        final user = item['user'] ?? {};

        return ListTile(
          onTap: isPending
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatRoomPage(
                        connectionId: item['id'],
                        otherUserName: user['name'] ?? 'User',
                      ),
                    ),
                  );
                },
          leading: CircleAvatar(
            backgroundColor: Colors.grey[800],
            backgroundImage: user['profile_pic'] != null
                ? NetworkImage(user['profile_pic'])
                : null,
            child: user['profile_pic'] == null
                ? const Icon(Icons.person, color: Colors.white)
                : null,
          ),
          title: Text(user['name'] ?? 'Unknown User',
              style: const TextStyle(color: Colors.white)),
          subtitle: Text(user['designation'] ?? '',
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
          trailing: isPending
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle,
                          color: Colors.greenAccent),
                      onPressed: () {
                        // Accept request
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.redAccent),
                      onPressed: () {
                        // Reject request
                      },
                    ),
                  ],
                )
              : const Icon(CupertinoIcons.chevron_right,
                  color: Colors.white24, size: 16),
        );
      },
    );
  }
}
