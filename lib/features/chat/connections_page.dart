import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:http/http.dart' as http;

class ConnectionsPage extends StatefulWidget {
  const ConnectionsPage({super.key});

  @override
  State<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends State<ConnectionsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 🔹 Pending
  List<dynamic> pendingConnections = [];
  bool isLoading = true;

  // 🔹 Accepted
  List<dynamic> acceptedFriends = [];
  bool acceptedLoading = true;

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

  @override
  void initState() {
    super.initState();
    // _tabController = TabController(length: 2, vsync: this);
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: 1, // ✅ Pending tab by default
    );

    fetchConnections(); // 🔸 pending (existing)
    fetchAcceptedFriends(); // 🔸 accepted (new)
  }

  // ================= FETCH PENDING =================
  Future<void> fetchConnections() async {
    setState(() => isLoading = true);

    final session = await UserStorageService().loadSession();
    final userId = session.user?.id;

    if (userId == null) {
      setState(() => isLoading = false);
      return;
    }

    final url = Uri.parse("$_baseUrl/connection-receiver-senders/$userId");

    try {
      final response = await http.get(url, headers: await _getHeaders());

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final List data = jsonData['data'] ?? [];

        setState(() {
          pendingConnections = data.where((e) => e['status'] == 0).toList();
          isLoading = false;
        });
      } else {
        isLoading = false;
      }
    } catch (_) {
      isLoading = false;
    }
  }

  // ================= FETCH ACCEPTED =================
  Future<void> fetchAcceptedFriends() async {
    setState(() => acceptedLoading = true);

    final session = await UserStorageService().loadSession();
    final userId = session.user?.id;

    if (userId == null) {
      setState(() => acceptedLoading = false);
      return;
    }

    final url = Uri.parse("$_baseUrl/friends/$userId");

    try {
      final response = await http.get(url, headers: await _getHeaders());

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        setState(() {
          acceptedFriends = json['data'] ?? [];
          acceptedLoading = false;
        });
      } else {
        acceptedLoading = false;
      }
    } catch (_) {
      acceptedLoading = false;
    }
  }

  // ================= ACCEPT / REJECT =================
  Future<void> updateStatus({
    required int senderId,
    required int receiverId,
    required int status,
    required int index,
  }) async {
    final url = Uri.parse("$_baseUrl/connection-request/update-status");

    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          "sender_id": senderId,
          "receiver_id": receiverId,
          "status": status,
        }),
      );

      final json = jsonDecode(response.body);

      if (response.statusCode == 200 && json['status'] == true) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(json['message'])));

        setState(() {
          pendingConnections.removeAt(index);
        });

        // accepted tab refresh
        fetchAcceptedFriends();
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(json['message'])));
      }
    } catch (_) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Network error')));
    }
  }

  @override
  Widget build(BuildContext context) {
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
          indicatorColor: Colors.blueAccent,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.white54,
          // tabs: const [
          //   Tab(text: 'Accepted'),
          //   Tab(text: 'Pending'),
          // ],

          tabs: const [
            Tab(text: 'Connections'), // ✅ renamed
            Tab(text: 'Pending'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAcceptedList(), // ✅ new
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildPendingList(),
        ],
      ),
    );
  }

  // ================= ACCEPTED UI =================
  Widget _buildAcceptedList() {
    if (acceptedLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (acceptedFriends.isEmpty) {
      return const Center(
        child: Text(
          'No connections found',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: acceptedFriends.length,
      itemBuilder: (context, index) {
        final item = acceptedFriends[index];

        return Card(
          color: const Color(0xFF1E1E1E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundImage: AssetImage('assets/images/default_avatar.png'),
            ),
            title: Text(
              item['fname'] ?? 'User',
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              item['user_name'] ?? '',
              style: const TextStyle(color: Colors.white38),
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                debugPrint('ACTION: $value');
                debugPrint('USER DATA: ${jsonEncode(item)}');
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'view',
                  child: Row(
                    children: [
                      Icon(Icons.visibility),
                      SizedBox(width: 8),
                      Text('View'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.redAccent),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ================= PENDING UI (UNCHANGED) =================
  Widget _buildPendingList() {
    if (pendingConnections.isEmpty) {
      return const Center(
        child: Text('No pending requests',
            style: TextStyle(color: Colors.white38)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pendingConnections.length,
      itemBuilder: (context, index) {
        final item = pendingConnections[index];
        final senderId = item['sender_id'];

        return Card(
          color: const Color(0xFF1E1E1E),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(item['fname'] ?? '',
                style: const TextStyle(color: Colors.white)),
            subtitle: Text(item['user_name'] ?? '',
                style: const TextStyle(color: Colors.white38)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon:
                      const Icon(Icons.check_circle, color: Colors.greenAccent),
                  onPressed: () async {
                    final session = await UserStorageService().loadSession();
                    updateStatus(
                      senderId: senderId,
                      receiverId: session.user!.id!,
                      status: 2,
                      index: index,
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.redAccent),
                  onPressed: () async {
                    final session = await UserStorageService().loadSession();
                    updateStatus(
                      senderId: senderId,
                      receiverId: session.user!.id!,
                      status: 1,
                      index: index,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
