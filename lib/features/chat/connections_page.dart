
import 'dart:convert';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:http/http.dart' as http;
import './chat_screen.dart';

class ConnectionsPage extends StatefulWidget {
  /// 0 = Connections
  /// 1 = Pending
  /// 2 = Sent
  final int initialTabIndex;

  const ConnectionsPage({
    super.key,
    this.initialTabIndex = 1, // ✅ default = Pending
  });

  @override
  State<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends State<ConnectionsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const String _baseUrl = AppConfig.apiBaseUrl;

  // ================== PENDING ==================
  List<dynamic> pendingConnections = [];
  bool isLoading = true;

  final TextEditingController _pendingSearchController =
      TextEditingController();
  Timer? _pendingDebounce;
  final ScrollController _pendingScrollController = ScrollController();

  int _pendingCount = 0;
  int _pendingCurrentPage = 1;
  int _pendingLastPage = 1;
  bool _pendingIsPaginating = false;
  bool _pendingHasMore = true;

  String _pendingSearchQuery = "";

  int _pendingPerPage = 10;
  final List<int> _pendingPerPageOptions = [5, 10, 15, 20];

  // ================== ACCEPTED (Connections) ==================
  List<dynamic> acceptedFriends = [];
  bool acceptedLoading = true;

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  final ScrollController _acceptedScrollController = ScrollController();

  int _acceptedCount = 0;

  int _acceptedCurrentPage = 1;
  int _acceptedLastPage = 1;

  bool _acceptedIsPaginating = false;
  bool _acceptedHasMore = true;

  String _searchQuery = "";

  int _perPage = 10;
  final List<int> _perPageOptions = [5, 10, 15, 20];

  // ================== SENT (UPDATED) ==================
  List<dynamic> sentRequests = [];
  bool sentLoading = true;

  final TextEditingController _sentSearchController = TextEditingController();
  Timer? _sentDebounce;
  final ScrollController _sentScrollController = ScrollController();

  int _sentCount = 0;
  int _sentCurrentPage = 1;
  int _sentLastPage = 1;

  bool _sentIsPaginating = false;
  bool _sentHasMore = true;

  String _sentSearchQuery = "";

  int _sentPerPage = 10;
  final List<int> _sentPerPageOptions = [5, 10, 15, 20];

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

    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );

    // fetch all
    fetchConnections(reset: true); // pending
    fetchAcceptedFriends(reset: true); // accepted
    fetchSentRequests(reset: true); // ✅ sent updated

    // lazy load listeners
    _acceptedScrollController.addListener(_acceptedScrollListener);
    _pendingScrollController.addListener(_pendingScrollListener);
    _sentScrollController.addListener(_sentScrollListener); // ✅
  }

  // ================== CONNECTIONS TAB LAZY LOAD LISTENER ==================
  void _acceptedScrollListener() {
    if (_acceptedScrollController.position.pixels >=
        _acceptedScrollController.position.maxScrollExtent - 200) {
      if (!_acceptedIsPaginating &&
          _acceptedHasMore &&
          !acceptedLoading &&
          _tabController.index == 0) {
        fetchAcceptedFriends(loadMore: true);
      }
    }
  }

  // ================== PENDING TAB LAZY LOAD LISTENER ==================
  void _pendingScrollListener() {
    if (_pendingScrollController.position.pixels >=
        _pendingScrollController.position.maxScrollExtent - 200) {
      if (!_pendingIsPaginating &&
          _pendingHasMore &&
          !isLoading &&
          _tabController.index == 1) {
        fetchConnections(loadMore: true);
      }
    }
  }

  // ================== SENT TAB LAZY LOAD LISTENER (NEW) ==================
  void _sentScrollListener() {
    if (_sentScrollController.position.pixels >=
        _sentScrollController.position.maxScrollExtent - 200) {
      if (!_sentIsPaginating &&
          _sentHasMore &&
          !sentLoading &&
          _tabController.index == 2) {
        fetchSentRequests(loadMore: true);
      }
    }
  }

  // ================= FETCH PENDING (UPDATED WITH SEARCH/SORT/PAGINATION) =================
  Future<void> fetchConnections({
    bool reset = false,
    bool loadMore = false,
  }) async {
    final session = await UserStorageService().loadSession();
    final userId = session.user?.id;

    if (userId == null) {
      setState(() {
        pendingConnections = [];
        isLoading = false;
        _pendingCount = 0;
      });
      return;
    }

    // reset logic
    if (reset) {
      setState(() {
        isLoading = true;
        pendingConnections = [];
        _pendingCurrentPage = 1;
        _pendingLastPage = 1;
        _pendingHasMore = true;
        _pendingIsPaginating = false;
        _pendingCount = 0;
      });
    }

    // loadMore logic
    if (loadMore) {
      if (_pendingCurrentPage >= _pendingLastPage) {
        setState(() => _pendingHasMore = false);
        return;
      }
      setState(() => _pendingIsPaginating = true);
      _pendingCurrentPage += 1;
    }

    final queryParams = <String, String>{
      "per_page": _pendingPerPage.toString(),
      "page": _pendingCurrentPage.toString(),
      if (_pendingSearchQuery.trim().isNotEmpty)
        "search": _pendingSearchQuery.trim(),
      "sort_by": "fname",
      "order": "asc",
    };

    final uri =
        Uri.parse("$_baseUrl/connection-receiver-senders/$userId").replace(
      queryParameters: queryParams,
    );

    try {
      final response = await http.get(uri, headers: await _getHeaders());

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        final List data = json['data'] ?? [];

        final pagination = json['pagination'] ?? {};
        final int currentPage = pagination['current_page'] ?? 1;
        final int lastPage = pagination['last_page'] ?? 1;

        final filtered = data.where((e) => e['status'] == 0).toList();

        setState(() {
          _pendingCount = filtered.length;

          _pendingCurrentPage = currentPage;
          _pendingLastPage = lastPage;

          if (loadMore) {
            pendingConnections.addAll(filtered);
          } else {
            pendingConnections = filtered;
          }

          _pendingHasMore = _pendingCurrentPage < _pendingLastPage;
        });
      } else {
        debugPrint("❌ Pending API Error: ${response.statusCode}");
        debugPrint("❌ Body: ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ Pending API Exception: $e");
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        _pendingIsPaginating = false;
      });
    }
  }

  // ================= FETCH ACCEPTED (UPDATED WITH SEARCH/SORT/PAGINATION) =================
  Future<void> fetchAcceptedFriends({
    bool reset = false,
    bool loadMore = false,
  }) async {
    final session = await UserStorageService().loadSession();
    final userId = session.user?.id;

    if (userId == null) {
      setState(() {
        acceptedFriends = [];
        acceptedLoading = false;
        _acceptedCount = 0;
      });
      return;
    }

    // reset logic
    if (reset) {
      setState(() {
        acceptedLoading = true;
        acceptedFriends = [];
        _acceptedCurrentPage = 1;
        _acceptedLastPage = 1;
        _acceptedHasMore = true;
        _acceptedIsPaginating = false;
        _acceptedCount = 0;
      });
    }

    // loadMore logic
    if (loadMore) {
      if (_acceptedCurrentPage >= _acceptedLastPage) {
        setState(() => _acceptedHasMore = false);
        return;
      }
      setState(() => _acceptedIsPaginating = true);
      _acceptedCurrentPage += 1;
    }

    final queryParams = <String, String>{
      "per_page": _perPage.toString(),
      "page": _acceptedCurrentPage.toString(),
      if (_searchQuery.trim().isNotEmpty) "search": _searchQuery.trim(),
      "sort_by": "fname",
      "order": "asc",
    };

    final uri = Uri.parse("$_baseUrl/friends/$userId").replace(
      queryParameters: queryParams,
    );

    try {
      final response = await http.get(uri, headers: await _getHeaders());

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        final List data = json['data'] ?? [];
        final int count = json['count'] ?? 0;

        final pagination = json['pagination'] ?? {};
        final int currentPage = pagination['current_page'] ?? 1;
        final int lastPage = pagination['last_page'] ?? 1;

        setState(() {
          _acceptedCount = count;
          _acceptedCurrentPage = currentPage;
          _acceptedLastPage = lastPage;

          if (loadMore) {
            acceptedFriends.addAll(data);
          } else {
            acceptedFriends = data;
          }

          _acceptedHasMore = _acceptedCurrentPage < _acceptedLastPage;
        });
      }
    } catch (e) {
      debugPrint("❌ Accepted API Exception: $e");
    } finally {
      if (!mounted) return;
      setState(() {
        acceptedLoading = false;
        _acceptedIsPaginating = false;
      });
    }
  }

  // ================= FETCH SENT (FULL UPDATED) =================
  Future<void> fetchSentRequests({
    bool reset = false,
    bool loadMore = false,
  }) async {
    final session = await UserStorageService().loadSession();
    final userId = session.user?.id;

    if (userId == null) {
      setState(() {
        sentRequests = [];
        sentLoading = false;
        _sentCount = 0;
      });
      return;
    }

    // reset logic
    if (reset) {
      setState(() {
        sentLoading = true;
        sentRequests = [];
        _sentCurrentPage = 1;
        _sentLastPage = 1;
        _sentHasMore = true;
        _sentIsPaginating = false;
        _sentCount = 0;
      });
    }

    // loadMore logic
    if (loadMore) {
      if (_sentCurrentPage >= _sentLastPage) {
        setState(() => _sentHasMore = false);
        return;
      }
      setState(() => _sentIsPaginating = true);
      _sentCurrentPage += 1;
    }

    final queryParams = <String, String>{
      "per_page": _sentPerPage.toString(),
      "page": _sentCurrentPage.toString(),
      if (_sentSearchQuery.trim().isNotEmpty) "search": _sentSearchQuery.trim(),
      "sort_by": "fname",
      "order": "asc",
    };

    final uri = Uri.parse("$_baseUrl/connection-senders-receiver/$userId")
        .replace(queryParameters: queryParams);

    try {
      final response = await http.get(uri, headers: await _getHeaders());

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        final List data = json['data'] ?? [];
        final int count = json['count'] ?? 0;

        final pagination = json['pagination'] ?? {};
        final int currentPage = pagination['current_page'] ?? 1;
        final int lastPage = pagination['last_page'] ?? 1;

        setState(() {
          _sentCount = count;
          _sentCurrentPage = currentPage;
          _sentLastPage = lastPage;

          if (loadMore) {
            sentRequests.addAll(data);
          } else {
            sentRequests = data;
          }

          _sentHasMore = _sentCurrentPage < _sentLastPage;
        });
      } else {
        debugPrint("❌ Sent API Error: ${response.statusCode}");
        debugPrint("❌ Body: ${response.body}");

        if (!loadMore) {
          setState(() {
            sentRequests = [];
            _sentCount = 0;
          });
        }
      }
    } catch (e) {
      debugPrint("❌ Sent API Exception: $e");
      if (!loadMore) {
        setState(() {
          sentRequests = [];
          _sentCount = 0;
        });
      }
    } finally {
      if (!mounted) return;
      setState(() {
        sentLoading = false;
        _sentIsPaginating = false;
      });
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

        fetchAcceptedFriends(reset: true);
        fetchConnections(reset: true);
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(json['message'] ?? "Failed")));
      }
    } catch (_) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Network error')));
    }
  }

  // ================= DELETE REQUEST (PENDING / SENT) =================
  Future<void> deleteConnectionRequest({
    required int senderId,
    required int receiverId,
    required int status,
    required String fromTab, // "pending" or "sent"
    required int index,
  }) async {
    final url = Uri.parse("$_baseUrl/connection-request/delete");

    final payload = {
      "sender_id": senderId,
      "receiver_id": receiverId,
      "status": status,
    };

    debugPrint("🗑 DELETE API CALL ($fromTab):");
    debugPrint(jsonEncode(payload));

    try {
      if (fromTab == "pending") {
        setState(() => isLoading = true);
      } else {
        setState(() => sentLoading = true);
      }

      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode(payload),
      );

      final jsonData = jsonDecode(response.body);

      if (!mounted) return;

      final message = jsonData['message'] ?? "Done";

      if (response.statusCode == 200 && jsonData['status'] == true) {
        setState(() {
          if (fromTab == "pending") {
            pendingConnections.removeAt(index);
          } else {
            sentRequests.removeAt(index);
            _sentCount = (_sentCount - 1).clamp(0, 999999);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );

        fetchConnections(reset: true);
        fetchAcceptedFriends(reset: true);
        fetchSentRequests(reset: true); // ✅
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Network error")),
      );
      debugPrint("❌ DELETE API Exception: $e");
    } finally {
      if (!mounted) return;
      if (fromTab == "pending") {
        setState(() => isLoading = false);
      } else {
        setState(() => sentLoading = false);
      }
    }
  }

  // ================== SEARCH DEBOUNCE (ACCEPTED) ==================
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() => _searchQuery = value);
      fetchAcceptedFriends(reset: true);
    });
  }

  // ================== SEARCH DEBOUNCE (PENDING) ==================
  void _onPendingSearchChanged(String value) {
    _pendingDebounce?.cancel();
    _pendingDebounce = Timer(const Duration(milliseconds: 500), () {
      setState(() => _pendingSearchQuery = value);
      fetchConnections(reset: true);
    });
  }

  // ================== SEARCH DEBOUNCE (SENT) ==================
  void _onSentSearchChanged(String value) {
    _sentDebounce?.cancel();
    _sentDebounce = Timer(const Duration(milliseconds: 500), () {
      setState(() => _sentSearchQuery = value);
      fetchSentRequests(reset: true);
    });
  }

  // ================== EXPORT CLICK ==================
  void _onExportClick() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Export feature coming soon ✅")),
    );
  }

  // ================== EXPORT CLICK (PENDING) ==================
  void _onPendingExportClick() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Pending export coming soon ✅")),
    );
  }

  // ================== EXPORT CLICK (SENT) ==================
  void _onSentExportClick() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Sent export coming soon ✅")),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();

    _acceptedScrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();

    _pendingScrollController.dispose();
    _pendingSearchController.dispose();
    _pendingDebounce?.cancel();

    _sentScrollController.dispose();
    _sentSearchController.dispose();
    _sentDebounce?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectionTitle = "Connect ($_acceptedCount)";
    final pendingTitle = "Pending ($_pendingCount)";
    final sentTitle = "Sent ($_sentCount)"; // ✅

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
          tabs: [
            Tab(text: connectionTitle),
            Tab(text: pendingTitle),
            Tab(text: sentTitle),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAcceptedList(),
          _buildPendingListUpdated(),
          _buildSentListUpdated(), // ✅ updated
        ],
      ),
    );
  }

  // ================= ACCEPTED UI =================
  Widget _buildAcceptedList() {
    if (acceptedLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "Search connections...",
                      hintStyle: TextStyle(color: Colors.white38),
                      prefixIcon: Icon(Icons.search, color: Colors.white54),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: IconButton(
                  onPressed: _onExportClick,
                  icon: const Icon(Icons.download, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: acceptedFriends.isEmpty
              ? const Center(
                  child: Text(
                    'No connections found',
                    style: TextStyle(color: Colors.white38),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await fetchAcceptedFriends(reset: true);
                  },
                  child: ListView.builder(
                    controller: _acceptedScrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: acceptedFriends.length +
                        (_acceptedIsPaginating ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_acceptedIsPaginating &&
                          index == acceptedFriends.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final item = acceptedFriends[index];

                      return Card(
                        color: const Color(0xFF1E1E1E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        
                        child: ListTile(
                          onTap: () async {
                            debugPrint(
                                "✅ Accepted Friend Item: ${jsonEncode(item)}");

                            // receiverId = friend_id
                            final receiverId =
                                int.tryParse(item['friend_id'].toString());

                            if (receiverId == null) {
                              debugPrint("❌ friend_id missing");
                              return;
                            }

                            // senderId = logged in user id
                            final session =
                                await UserStorageService().loadSession();
                            final senderId = session.user?.id;

                            if (senderId == null) {
                              debugPrint("❌ senderId (myId) null");
                              return;
                            }

                            debugPrint(
                                "📌 senderId=$senderId receiverId=$receiverId");

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  receiverId: receiverId,
                                  receiverName: item['fname'] ??
                                      "User", // ✅ header me kavita show hoga
                                  receiverUserName: item['user_name'],
                                ),
                              ),
                            );
                          },
                          leading: const CircleAvatar(
                            backgroundImage:
                                AssetImage('assets/images/default_avatar.png'),
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
                            icon: const Icon(Icons.more_vert,
                                color: Colors.white),
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
                  ),
                ),
        ),
      ],
    );
  }

  // ================= PENDING UI (UPDATED) =================
  Widget _buildPendingListUpdated() {
    if (isLoading && pendingConnections.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: TextField(
                    controller: _pendingSearchController,
                    onChanged: _onPendingSearchChanged,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "Search pending...",
                      hintStyle: TextStyle(color: Colors.white38),
                      prefixIcon: Icon(Icons.search, color: Colors.white54),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: IconButton(
                  onPressed: _onPendingExportClick,
                  icon: const Icon(Icons.download, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: pendingConnections.isEmpty
              ? const Center(
                  child: Text(
                    'No pending requests',
                    style: TextStyle(color: Colors.white38),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await fetchConnections(reset: true);
                  },
                  child: ListView.builder(
                    controller: _pendingScrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: pendingConnections.length +
                        (_pendingIsPaginating ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_pendingIsPaginating &&
                          index == pendingConnections.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final item = pendingConnections[index];
                      final senderId = item['sender_id'];

                      return Card(
                        color: const Color(0xFF1E1E1E),
                        child: ListTile(
                          leading:
                              const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(
                            item['fname'] ?? '',
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            item['user_name'] ?? '',
                            style: const TextStyle(color: Colors.white38),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check_circle,
                                    color: Colors.greenAccent),
                                onPressed: () async {
                                  final session =
                                      await UserStorageService().loadSession();
                                  updateStatus(
                                    senderId: senderId,
                                    receiverId: session.user!.id!,
                                    status: 2,
                                    index: index,
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.cancel,
                                    color: Colors.redAccent),
                                onPressed: () async {
                                  final session =
                                      await UserStorageService().loadSession();

                                  final receiverId = session.user?.id;
                                  if (receiverId == null) return;

                                  final senderId = item['sender_id'];
                                  final status = item['status'];

                                  await deleteConnectionRequest(
                                    senderId: senderId,
                                    receiverId: receiverId,
                                    status: status,
                                    fromTab: "pending",
                                    index: index,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  // ================= SENT UI (FULL UPDATED LIKE PENDING) ====================
  Widget _buildSentListUpdated() {
    if (sentLoading && sentRequests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // 🔥 Search + Export
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: TextField(
                    controller: _sentSearchController,
                    onChanged: _onSentSearchChanged,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "Search sent...",
                      hintStyle: TextStyle(color: Colors.white38),
                      prefixIcon: Icon(Icons.search, color: Colors.white54),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: IconButton(
                  onPressed: _onSentExportClick,
                  icon: const Icon(Icons.download, color: Colors.white),
                ),
              ),
            ],
          ),
        ),

        // list
        Expanded(
          child: sentRequests.isEmpty
              ? const Center(
                  child: Text(
                    'No sent requests',
                    style: TextStyle(color: Colors.white38),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await fetchSentRequests(reset: true);
                  },
                  child: ListView.builder(
                    controller: _sentScrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount:
                        sentRequests.length + (_sentIsPaginating ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_sentIsPaginating && index == sentRequests.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final item = sentRequests[index];

                      final fname = item['fname'] ?? 'User';
                      final userName = item['user_name'] ?? '';

                      return Card(
                        color: const Color(0xFF1E1E1E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundImage:
                                AssetImage('assets/images/default_avatar.png'),
                          ),
                          title: Text(
                            fname,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            "$userName",
                            style: const TextStyle(color: Colors.white38),
                          ),
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert,
                                color: Colors.white),
                            onSelected: (value) async {
                              final session =
                                  await UserStorageService().loadSession();
                              final senderId = session.user?.id;

                              if (senderId == null) return;

                              final receiverId = item['receiver_id'];
                              final status = item['status'];

                              if (value == "view") {
                                debugPrint("👁 SENT VIEW CLICK:");
                                debugPrint(jsonEncode({
                                  "sender_id": senderId,
                                  "receiver_id": receiverId,
                                  "status": status,
                                }));
                              }

                              if (value == "cancel") {
                                await deleteConnectionRequest(
                                  senderId: senderId,
                                  receiverId: receiverId,
                                  status: status,
                                  fromTab: "sent",
                                  index: index,
                                );
                              }
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
                                value: 'cancel',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.redAccent),
                                    SizedBox(width: 8),
                                    Text('cancel'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
