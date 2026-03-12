import 'dart:convert';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:gridcard/features/profile/profile_page.dart';
import 'package:http/http.dart' as http;
import 'package:gridcard/widgets/top_alert.dart';
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

  final int _pendingPerPage = 10;
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

  final int _perPage = 10;
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

  final int _sentPerPage = 10;
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

  Future<int?> _createChatAndGetChatId(int otherUserId) async {
    try {
      final uri = Uri.parse("$_baseUrl/chat/create-chat/$otherUserId");

      final response = await http.post(
        uri,
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        if (jsonData["status"] == true && jsonData["chat"] != null) {
          return int.tryParse(jsonData["chat"]["id"].toString());
        }
      }

      debugPrint("❌ createChat failed: ${response.body}");
      return null;
    } catch (e) {
      debugPrint("❌ _createChatAndGetChatId Exception: $e");
      return null;
    }
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

  Future<http.Response> _deleteRequest(
      String url, Map<String, dynamic> body) async {
    final request = http.Request('DELETE', Uri.parse(url));
    request.headers.addAll(await _getHeaders());
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode(body);
    final streamedResponse = await request.send();
    return await http.Response.fromStream(streamedResponse);
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
        TopAlert.show(context, json['message'], isSuccess: true);

        setState(() {
          pendingConnections.removeAt(index);
        });

        fetchAcceptedFriends(reset: true);
        fetchConnections(reset: true);
      } else {
        TopAlert.show(context, json['message'] ?? "Failed", isError: true);
      }
    } catch (_) {
      TopAlert.show(context, 'Network error', isError: true);
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
      } else if (fromTab == "accepted") {
        setState(() => acceptedLoading = true);
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
          } else if (fromTab == "accepted") {
            acceptedFriends.removeAt(index);
            _acceptedCount = (_acceptedCount - 1).clamp(0, 999999);
          } else {
            sentRequests.removeAt(index);
            _sentCount = (_sentCount - 1).clamp(0, 999999);
          }
        });

        TopAlert.show(context, message, isSuccess: true);

        fetchConnections(reset: true);
        fetchAcceptedFriends(reset: true);
        fetchSentRequests(reset: true); // ✅
      } else {
        TopAlert.show(context, message, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      TopAlert.show(context, "Network error", isError: true);
      debugPrint("❌ DELETE API Exception: $e");
    } finally {
      if (!mounted) return;
      if (fromTab == "pending") {
        setState(() => isLoading = false);
      } else if (fromTab == "accepted") {
        setState(() => acceptedLoading = false);
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
    TopAlert.show(context, "Export feature coming soon ✅");
  }

  // ================== EXPORT CLICK (PENDING) ==================
  void _onPendingExportClick() {
    TopAlert.show(context, "Pending export coming soon ✅");
  }

  // ================== EXPORT CLICK (SENT) ==================
  void _onSentExportClick() {
    TopAlert.show(context, "Sent export coming soon ✅");
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
    final colorScheme = Theme.of(context).colorScheme;

    final connectionTitle = "Connected ($_acceptedCount)";
    final pendingTitle = "Pending ($_pendingCount)";
    final sentTitle = "Sent ($_sentCount)"; // ✅

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        title:
            Text('Connections', style: TextStyle(color: colorScheme.onSurface)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.2), // or any color
            borderRadius: BorderRadius.circular(8), // optional
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurface.withOpacity(0.6),
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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (acceptedLoading) {
      return Center(
          child: CircularProgressIndicator(color: colorScheme.primary));
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
                    color: colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: colorScheme.primary.withOpacity(0.2)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: "Search connections...",
                      hintStyle: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.6)),
                      prefixIcon: Icon(Icons.search,
                          color: colorScheme.onSurface.withOpacity(0.6)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: colorScheme.primary.withOpacity(0.2)),
                ),
                child: IconButton(
                  onPressed: _onExportClick,
                  icon: Icon(Icons.download, color: colorScheme.onSurface),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: acceptedFriends.isEmpty
              ? Center(
                  child: Text(
                    'No connections found',
                    style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.6)),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await fetchAcceptedFriends(reset: true);
                  },
                  color: colorScheme.primary,
                  child: ListView.builder(
                    controller: _acceptedScrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: acceptedFriends.length +
                        (_acceptedIsPaginating ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_acceptedIsPaginating &&
                          index == acceptedFriends.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: colorScheme.primary)),
                        );
                      }

                      final item = acceptedFriends[index];
                      final friendId =
                          int.tryParse(item['friend_id'].toString());
                      if (friendId == null) return const SizedBox.shrink();

                      return GestureDetector(
                        onTap: () async {
                          final session =
                              await UserStorageService().loadSession();
                          final viewerId = session.user?.id;
                          if (viewerId == null) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfilePage(
                                userId: friendId,
                                viewerUserId: viewerId,
                                isConnected: true,
                              ),
                            ),
                          );
                        },
                        child: Card(
                          color: colorScheme.surface,
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color:
                                  isDark ? Colors.white : colorScheme.primary,
                              width: 0.2,
                            ),
                          ),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                /// Top User Info
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor:
                                          colorScheme.surfaceVariant,
                                      backgroundImage:
                                          item['profile_pic'] != null
                                              ? NetworkImage(
                                                  "${AppConfig.apiProfileImg}/${item['profile_pic']}",
                                                )
                                              : null,
                                      child: item['profile_pic'] == null
                                          ? Icon(
                                              Icons.person,
                                              color: colorScheme.onSurface
                                                  .withOpacity(0.6),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        item['fname'] ?? 'User',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                /// Bottom Buttons
                                Row(
                                  children: [
                                    /// Chat Button
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.chat_bubble_outline,
                                            size: 18),
                                        label: const Text("Chat"),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: colorScheme.primary,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        onPressed: () async {
                                          debugPrint(
                                              "✅ Accepted Friend Item: ${jsonEncode(item)}");

                                          final receiverId = int.tryParse(
                                              item['friend_id'].toString());

                                          if (receiverId == null) {
                                            debugPrint("❌ friend_id missing");
                                            return;
                                          }

                                          showDialog(
                                            context: context,
                                            barrierDismissible: false,
                                            builder: (_) => const Center(
                                                child:
                                                    CircularProgressIndicator()),
                                          );

                                          final chatId =
                                              await _createChatAndGetChatId(
                                                  receiverId);

                                          if (!mounted) return;
                                          Navigator.pop(context);

                                          if (chatId == null) {
                                            TopAlert.show(
                                              context,
                                              "Chat create nahi ho paya",
                                              isError: true,
                                            );
                                            return;
                                          }

                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ChatScreen(
                                                chatId: chatId,
                                                receiverId: receiverId,
                                                receiverName: item['fname'] ?? "User",
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: Icon(Icons.more_vert,
                                          color: colorScheme.onSurface
                                              .withOpacity(0.6)),
                                      onSelected: (value) async {
                                        if (value == 'view') {
                                          final session =
                                              await UserStorageService()
                                                  .loadSession();
                                          final viewerId = session.user?.id;
                                          if (!mounted) return;
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ProfilePage(
                                                userId: int.tryParse(
                                                    item['friend_id']
                                                        .toString()),
                                                viewerUserId: viewerId,
                                                isConnected: true,
                                              ),
                                            ),
                                          );
                                        } else if (value == 'delete') {
                                          final session =
                                              await UserStorageService()
                                                  .loadSession();
                                          final viewerId = session.user?.id;
                                          if (viewerId == null) return;

                                          final friendId = int.tryParse(
                                              item['friend_id'].toString());
                                          if (friendId == null) return;

                                          // status 2 means they are already connected
                                          await deleteConnectionRequest(
                                            senderId: viewerId,
                                            receiverId: friendId,
                                            status: 2,
                                            fromTab: "accepted",
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
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete,
                                                  color: Colors.redAccent),
                                              SizedBox(width: 8),
                                              Text('Delete'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isLoading && pendingConnections.isEmpty) {
      return Center(
          child: CircularProgressIndicator(color: colorScheme.primary));
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
                    color: colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: colorScheme.primary.withOpacity(0.2)),
                  ),
                  child: TextField(
                    controller: _pendingSearchController,
                    onChanged: _onPendingSearchChanged,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: "Search pending...",
                      hintStyle: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.6)),
                      prefixIcon: Icon(Icons.search,
                          color: colorScheme.onSurface.withOpacity(0.6)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: colorScheme.primary.withOpacity(0.2)),
                ),
                child: IconButton(
                  onPressed: _onPendingExportClick,
                  icon: Icon(Icons.download, color: colorScheme.onSurface),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: pendingConnections.isEmpty
              ? Center(
                  child: Text(
                    'No pending requests',
                    style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.6)),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await fetchConnections(reset: true);
                  },
                  color: colorScheme.primary,
                  child: ListView.builder(
                    controller: _pendingScrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: pendingConnections.length +
                        (_pendingIsPaginating ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_pendingIsPaginating &&
                          index == pendingConnections.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: colorScheme.primary)),
                        );
                      }

                      final item = pendingConnections[index];
                      final senderId =
                          int.tryParse(item['sender_id'].toString());

                      return GestureDetector(
                        onTap: () async {
                          final session =
                              await UserStorageService().loadSession();
                          final viewerId = session.user?.id;
                          if (viewerId == null || senderId == null) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfilePage(
                                userId: senderId,
                                viewerUserId: viewerId,
                                fromConnectionTab: 'pending',
                              ),
                            ),
                          );
                        },
                        child: Card(
                          color: colorScheme.surface,
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color:
                                  isDark ? Colors.white : colorScheme.primary,
                              width: 0.2,
                            ),
                          ),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                /// Top Section
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 26,
                                      backgroundColor:
                                          colorScheme.surfaceVariant,
                                      backgroundImage:
                                          item['profile_pic'] != null
                                              ? NetworkImage(
                                                  "${AppConfig.apiProfileImg}/${item['profile_pic']}",
                                                )
                                              : null,
                                      child: item['profile_pic'] == null
                                          ? Icon(Icons.person,
                                              color: colorScheme.onSurface
                                                  .withOpacity(0.6))
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['fname'] ?? '',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            item['user_name'] ?? '',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: colorScheme.onSurface
                                                  .withOpacity(0.6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                // Divider(
                                //   height: 1,
                                //   color: colorScheme.outline.withOpacity(0.2),
                                // ),

                                // const SizedBox(height: 12),

                                /// Bottom Buttons
                                Row(
                                  children: [
                                    /// Accept
                                    Expanded(
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: colorScheme.primary,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        onPressed: () async {
                                          final session =
                                              await UserStorageService()
                                                  .loadSession();
                                          final senderId = int.tryParse(
                                              item['sender_id'].toString());
                                          final receiverId = session.user?.id;

                                          if (senderId == null ||
                                              receiverId == null) return;
                                          // updateStatus(
                                          //   senderId: item['sender_id'],
                                          //   receiverId: session.user!.id!,
                                          //   status: 2,
                                          //   index: index,
                                          // );
                                          updateStatus(
                                            senderId: senderId,
                                            receiverId: receiverId,
                                            status: 2,
                                            index: index,
                                          );
                                        },
                                        child: const Text("Accept"),
                                      ),
                                    ),

                                    const SizedBox(width: 10),

                                    /// Reject
                                    Expanded(
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                            color: colorScheme.outline,
                                            width: 0.2,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        onPressed: () async {
                                          final session =
                                              await UserStorageService()
                                                  .loadSession();

                                          final receiverId = session.user?.id;
                                          if (receiverId == null) return;

                                          // final senderId = item['sender_id'];
                                          // final status = item['status'];
                                          final senderId = int.tryParse(
                                              item['sender_id'].toString());
                                          final status = int.tryParse(
                                              item['status'].toString());
                                          if (senderId == null ||
                                              status == null) return;

                                          await deleteConnectionRequest(
                                            senderId: senderId,
                                            receiverId: receiverId,
                                            status: status,
                                            fromTab: "pending",
                                            index: index,
                                          );
                                        },
                                        child: const Text("Reject"),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (sentLoading && sentRequests.isEmpty) {
      return Center(
          child: CircularProgressIndicator(color: colorScheme.primary));
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
                    color: colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: colorScheme.primary.withOpacity(0.2)),
                  ),
                  child: TextField(
                    controller: _sentSearchController,
                    onChanged: _onSentSearchChanged,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: "Search sent...",
                      hintStyle: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.6)),
                      prefixIcon: Icon(Icons.search,
                          color: colorScheme.onSurface.withOpacity(0.6)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: colorScheme.primary.withOpacity(0.2)),
                ),
                child: IconButton(
                  onPressed: _onSentExportClick,
                  icon: Icon(Icons.download, color: colorScheme.onSurface),
                ),
              ),
            ],
          ),
        ),

        // list
        Expanded(
          child: sentRequests.isEmpty
              ? Center(
                  child: Text(
                    'No sent requests',
                    style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.6)),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await fetchSentRequests(reset: true);
                  },
                  color: colorScheme.primary,
                  child: ListView.builder(
                    controller: _sentScrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount:
                        sentRequests.length + (_sentIsPaginating ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_sentIsPaginating && index == sentRequests.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: colorScheme.primary)),
                        );
                      }

                      final item = sentRequests[index];

                      final fname = item['fname'] ?? 'User';
                      final userName = item['user_name'] ?? '';

                      return GestureDetector(
                        onTap: () async {
                          final session =
                              await UserStorageService().loadSession();
                          final viewerId = session.user?.id;
                          final profileUserId =
                              int.tryParse(item['receiver_id'].toString());
                          if (viewerId == null || profileUserId == null) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfilePage(
                                userId: profileUserId,
                                viewerUserId: viewerId,
                                fromConnectionTab: 'sent',
                              ),
                            ),
                          );
                        },
                        child: Card(
                          color: colorScheme.surface,
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color:
                                  isDark ? Colors.white : colorScheme.primary,
                              width: 0.2,
                            ),
                          ),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                /// Top User Info
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 26,
                                      backgroundColor:
                                          colorScheme.surfaceVariant,
                                      backgroundImage:
                                          item['profile_pic'] != null
                                              ? NetworkImage(
                                                  "${AppConfig.apiProfileImg}/${item['profile_pic']}",
                                                )
                                              : null,
                                      child: item['profile_pic'] == null
                                          ? Icon(
                                              Icons.person,
                                              color: colorScheme.onSurface
                                                  .withOpacity(0.6),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            fname,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                          // const SizedBox(height: 2),
                                          // Text(
                                          //   userName,
                                          //   style: TextStyle(
                                          //     fontSize: 13,
                                          //     color: colorScheme.onSurface
                                          //         .withOpacity(0.6),
                                          //   ),
                                          // ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                // Divider(
                                //   color: colorScheme.outline.withOpacity(0.2),
                                // ),

                                                  /// Bottom Buttons
                                Row(
                                  children: [
                                    /// View Button
                                    Expanded(
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: colorScheme.primary,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        onPressed: () async {
                                          final session =
                                              await UserStorageService()
                                                  .loadSession();
                                          final senderId = session.user?.id;
                                          if (senderId == null) return;

                                          final receiverId =
                                              int.tryParse(item['receiver_id'].toString());
                                          if (receiverId == null) return;

                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ProfilePage(
                                                userId: receiverId,
                                                viewerUserId: senderId,
                                                fromConnectionTab: 'sent',
                                              ),
                                            ),
                                          );
                                        },
                                        child: const Text("View"),
                                      ),
                                    ),

                                    const SizedBox(width: 10),

                                    /// Remove Button
                                    Expanded(
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                            color: colorScheme.outline,
                                            width: 0.2,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        onPressed: () async {
                                          final session =
                                              await UserStorageService()
                                                  .loadSession();
                                          final senderId = session.user?.id;
                                          if (senderId == null) return;

                                          final receiverId = int.tryParse(
                                              item['receiver_id'].toString());
                                          final status = int.tryParse(
                                              item['status'].toString());

                                          if (receiverId == null ||
                                              status == null) return;

                                          await deleteConnectionRequest(
                                            senderId: senderId,
                                            receiverId: receiverId,
                                            status: status,
                                            fromTab: "sent",
                                            index: index,
                                          );
                                        },
                                        child: const Text("Remove"),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
