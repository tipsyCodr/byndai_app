import 'dart:convert';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/firestore_chat_service.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:gridcard/widgets/shimmer_box.dart';
import 'package:gridcard/features/profile/profile_page.dart';
import 'package:http/http.dart' as http;
import 'package:gridcard/widgets/top_alert.dart';
import './chat_screen.dart';

import 'package:gridcard/core/services/notification_service.dart';

import '../feature_map/feature_access_helper.dart';
import '../feature_map/feature_mapper.dart';
import '../home/SubscriptionPlans.dart';
import 'package:gridcard/core/services/auth_provider.dart';
import 'package:provider/provider.dart';

class ConnectionsPage extends StatefulWidget {
  /// 0 = Chats
  /// 1 = Connected
  /// 2 = Pending
  /// 3 = Sent
  final int initialTabIndex;

  const ConnectionsPage({
    super.key,
    this.initialTabIndex = 0, // ✅ default = Connected
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
  StreamSubscription? _notificationSubscription;

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

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _chatsSubscription;
  final Map<int, Map<String, dynamic>> _liveChatsByFriendId = {};

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
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );

    // fetch all
    fetchConnections(reset: true); // pending
    fetchAcceptedFriends(reset: true); // accepted
    fetchSentRequests(reset: true); // ✅ sent updated

    // lazy load listeners
    _acceptedScrollController.addListener(_acceptedScrollListener);
    _pendingScrollController.addListener(_pendingScrollListener);
    _sentScrollController.addListener(_sentScrollListener); // ✅
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        authProvider.refreshSubscription();
      }
    });

    // 🔔 Event-driven refresh on incoming push notification
    _notificationSubscription =
        NotificationService.onNotificationReceived.listen((message) {
      if (mounted) {
        fetchAcceptedFriends(silent: true);
      }
    });

    _initLiveChatsListener();
  }

  Future<void> _initLiveChatsListener() async {
    final session = await UserStorageService().loadSession();
    final userId = session.user?.id;
    if (userId == null || !mounted) return;

    _chatsSubscription =
        FirestoreChatService.getUserChatsStream(userId).listen((snapshot) {
      if (!mounted) return;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final participants = (data['participants'] as List?)
                ?.map((e) => int.tryParse(e.toString()))
                .whereType<int>()
                .toList() ??
            [];
        final otherId = participants.firstWhere(
          (id) => id != userId,
          orElse: () => -1,
        );
        if (otherId <= 0) continue;

        final ts = data['last_message_at'];
        String iso = data['last_message_iso']?.toString() ?? '';
        String formatted = '';
        int liveMs = 0;
        if (ts is Timestamp) {
          final dt = ts.toDate().toLocal();
          liveMs = dt.millisecondsSinceEpoch;
          iso = dt.toIso8601String();
          final h12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
          final min = dt.minute.toString().padLeft(2, '0');
          final ampm = dt.hour >= 12 ? 'PM' : 'AM';
          formatted = '${h12.toString().padLeft(2, '0')}:$min $ampm';
        } else if (iso.isNotEmpty) {
          final dt = DateTime.tryParse(iso)?.toLocal();
          if (dt != null) {
            liveMs = dt.millisecondsSinceEpoch;
            final h12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
            final min = dt.minute.toString().padLeft(2, '0');
            final ampm = dt.hour >= 12 ? 'PM' : 'AM';
            formatted = '${h12.toString().padLeft(2, '0')}:$min $ampm';
          }
        }

        _liveChatsByFriendId[otherId] = {
          'last_message': data['last_message']?.toString() ?? '',
          'last_message_at': iso,
          '_live_ms': liveMs,
          if (formatted.isNotEmpty) 'updated_at_formatted': formatted,
          'unread_count': data['unread_$userId'] ?? 0,
        };
      }

      if (acceptedFriends.isNotEmpty) {
        setState(() {
          _mergeLiveChatsIntoAccepted();
          _sortAcceptedByLatest();
        });
      }
    });
  }

  void _mergeLiveChatsIntoAccepted() {
    if (_liveChatsByFriendId.isEmpty) return;
    for (final item in acceptedFriends) {
      if (item is! Map) continue;
      final friendId = int.tryParse(item['friend_id']?.toString() ?? '');
      if (friendId == null) continue;
      final live = _liveChatsByFriendId[friendId];
      if (live == null) continue;
      final liveMsg = live['last_message']?.toString() ?? '';
      if (liveMsg.isNotEmpty) {
        item['last_message'] = liveMsg;
      }
      final liveAt = live['last_message_at']?.toString() ?? '';
      if (liveAt.isNotEmpty) {
        item['last_message_at'] = liveAt;
      }
      if (live['_live_ms'] != null) {
        item['_live_ms'] = live['_live_ms'];
      }
      final liveFormatted = live['updated_at_formatted']?.toString() ?? '';
      if (liveFormatted.isNotEmpty) {
        item['updated_at_formatted'] = liveFormatted;
      }
      if (live.containsKey('unread_count')) {
        item['unread_count'] = live['unread_count'];
      }
    }
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _chatsSubscription?.cancel();
    _debounce?.cancel();
    _pendingDebounce?.cancel();
    _sentDebounce?.cancel();
    _searchController.dispose();
    _pendingSearchController.dispose();
    _sentSearchController.dispose();
    _acceptedScrollController.dispose();
    _pendingScrollController.dispose();
    _sentScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<bool> _viewProfileApi(int profileId) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse("$_baseUrl/view-profile");

      final res = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          "profile_id": profileId,
        }),
      );

      final data = jsonDecode(res.body);

      debugPrint("🟢 VIEW PROFILE API: ${res.statusCode} => $data");

      if (res.statusCode == 200 && data["message"] == "same") {
        return true;
      }

      if (res.statusCode == 200 && data["message"] == "not match") {
        return true;
      }

      if (res.statusCode == 403) {
        return false;
      }

      return false;
    } catch (e) {
      debugPrint("🔴 ERROR viewProfile API: $e");
      return false;
    }
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
  DateTime? _parseFriendTimestamp(dynamic item) {
    if (item is! Map) return null;
    for (final key in [
      'last_message_at',
      'last_message_time',
      'updated_at',
      'created_at',
    ]) {
      final raw = item[key]?.toString();
      if (raw != null && raw.trim().isNotEmpty) {
        final dt = DateTime.tryParse(raw.trim());
        if (dt != null) return dt;
      }
    }
    return null;
  }

  void _sortAcceptedByLatest() {
    acceptedFriends.sort((a, b) {
      final aLiveMs = (a['_live_ms'] as int?) ?? 0;
      final bLiveMs = (b['_live_ms'] as int?) ?? 0;
      if (aLiveMs > 0 || bLiveMs > 0) {
        if (aLiveMs != bLiveMs) return bLiveMs.compareTo(aLiveMs);
      }

      final aUnread = int.tryParse((a['unread_count'] ??
                      a['unread_messages_count'] ??
                      a['unread'] ??
                      a['unread_count_sender'] ??
                      0)
                  .toString()) ??
              0;
      final bUnread = int.tryParse((b['unread_count'] ??
                      b['unread_messages_count'] ??
                      b['unread'] ??
                      b['unread_count_sender'] ??
                      0)
                  .toString()) ??
              0;
      if ((aUnread > 0) != (bUnread > 0)) {
        return bUnread > 0 ? 1 : -1;
      }

      final aHasMsg = (a['last_message'] ??
              a['message'] ??
              a['latest_message'] ??
              a['last_msg'] ??
              '')
          .toString()
          .trim()
          .isNotEmpty;
      final bHasMsg = (b['last_message'] ??
              b['message'] ??
              b['latest_message'] ??
              b['last_msg'] ??
              '')
          .toString()
          .trim()
          .isNotEmpty;
      if (aHasMsg != bHasMsg) return bHasMsg ? 1 : -1;

      final aDt = _parseFriendTimestamp(a);
      final bDt = _parseFriendTimestamp(b);
      if (aDt != null && bDt != null) return bDt.compareTo(aDt);
      if (bDt != null) return 1;
      if (aDt != null) return -1;
      return 0;
    });
    for (final item in acceptedFriends.take(5)) {
      debugPrint(
          '📋 SORTED: ${item['fname']} | liveMs=${item['_live_ms']} | unread=${item['unread_count'] ?? item['unread_messages_count'] ?? item['unread'] ?? item['unread_count_sender']} | updated_at=${item['updated_at']} | last_msg_at=${item['last_message_at']}');
    }
  }

  Future<void> fetchAcceptedFriends({
    bool reset = false,
    bool loadMore = false,
    bool silent = false,
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
    if (reset && !silent) {
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
      "sort_by": "updated_at",
      "order": "desc",
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

          _mergeLiveChatsIntoAccepted();
          _sortAcceptedByLatest();

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

        // 🔄 Refresh subscription details after accepting
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.refreshSubscription();

        final auth = Provider.of<AuthProvider>(context, listen: false);

        int? featureId =
            FeatureMapper.getFeatureId('connection_request_accept');

        bool canUse = FeatureAccessHelper.canUseFeature(
          featureId: featureId!,
          subscription: auth.subscriptionDetails,
        );

        debugPrint("after api call  connection_request_accept: $canUse");
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final activeChats = _getActiveChats();
    final chatsTitle = "Chats (${activeChats.length})";
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
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicator: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurface.withValues(alpha: 0.6),
          tabs: [
            Tab(text: chatsTitle),
            Tab(text: connectionTitle),
            Tab(text: pendingTitle),
            Tab(text: sentTitle),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChatsList(activeChats),
          _buildAcceptedList(),
          _buildPendingListUpdated(),
          _buildSentListUpdated(), // ✅ updated
        ],
      ),
    );
  }

  List<dynamic> _getActiveChats() {
    return acceptedFriends.where((item) {
      if (item is! Map) return false;
      final friendId = int.tryParse(item['friend_id']?.toString() ?? '');
      final msg = (item['last_message'] ??
              item['message'] ??
              item['latest_message'] ??
              item['excerpt'] ??
              item['last_msg'] ??
              '')
          .toString()
          .trim();
      final hasLive =
          friendId != null && _liveChatsByFriendId.containsKey(friendId);
      return msg.isNotEmpty || hasLive;
    }).toList();
  }

  Future<void> _deleteChatOnly(dynamic item, int friendId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Chat'),
        content: Text(
            'Delete chat history with ${item['fname'] ?? 'User'}? Your connection will remain.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final chatId = await _createChatAndGetChatId(friendId);
    if (chatId != null) {
      await FirestoreChatService.deleteChat(chatId);
    }
    if (!mounted) return;
    setState(() {
      _liveChatsByFriendId.remove(friendId);
      item['last_message'] = '';
      item['message'] = '';
      item['latest_message'] = '';
      item['last_msg'] = '';
      item['_live_ms'] = 0;
      item['unread_count'] = 0;
      item['unread_messages_count'] = 0;
    });
    TopAlert.show(context, 'Chat deleted');
  }

  Widget _buildPresenceAvatar({
    required int userId,
    required String? profilePic,
    required String name,
    bool hasUnread = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U';

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreChatService.getUserPresenceStream(userId),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final isOnline = data?['is_online'] == true;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: EdgeInsets.all(hasUnread ? 2 : 0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: hasUnread
                    ? Border.all(
                        color: const Color(0xFF25D366),
                        width: 2,
                      )
                    : null,
              ),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
                backgroundImage: profilePic != null
                    ? NetworkImage('${AppConfig.apiProfileImg}/$profilePic')
                    : null,
                child: profilePic == null
                    ? Text(
                        initial,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                      )
                    : null,
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: isOnline
                      ? const Color(0xFF22C55E)
                      : Colors.grey.shade400,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.surface,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildListShimmer() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: 6,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            ShimmerBox(width: 52, height: 52, borderRadius: 26),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 140, height: 14, borderRadius: 7),
                  SizedBox(height: 8),
                  ShimmerBox(width: 210, height: 12, borderRadius: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatsList(List<dynamic> chats) {
    final colorScheme = Theme.of(context).colorScheme;

    if (acceptedLoading) {
      return _buildListShimmer();
    }

    if (chats.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 48,
              color: colorScheme.onSurface.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 12),
            Text(
              'No active chats yet',
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.65),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => _tabController.animateTo(1),
              child: const Text('Message a connection'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await fetchAcceptedFriends(reset: true);
      },
      color: colorScheme.primary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 6, 0, 16),
        itemCount: chats.length,
        itemBuilder: (context, index) {
          final item = chats[index];
          final friendId = int.tryParse(item['friend_id'].toString());
          if (friendId == null) return const SizedBox.shrink();

          final rawUnread = item['unread_count'] ??
              item['unread_messages_count'] ??
              item['unread'] ??
              item['unread_count_sender'] ??
              0;
          final unreadCount = int.tryParse(rawUnread.toString()) ?? 0;
          final hasUnread = unreadCount > 0;
          final timeStr =
              item['updated_at_formatted'] ?? item['time'] ?? '';
          final messageContent = (item['last_message'] ??
                  item['message'] ??
                  item['latest_message'] ??
                  item['excerpt'] ??
                  item['last_msg'] ??
                  '')
              .toString()
              .trim();

          return InkWell(
            onLongPress: () => _deleteChatOnly(item, friendId),
            onTap: () async {
              setState(() {
                item['unread_count'] = 0;
                item['unread_messages_count'] = 0;
              });

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    const Center(child: CircularProgressIndicator()),
              );

              final chatId = await _createChatAndGetChatId(friendId);
              if (!mounted) return;
              Navigator.pop(context);

              if (chatId == null) {
                TopAlert.show(context, 'Unable to open chat', isError: true);
                return;
              }

              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    chatId: chatId,
                    receiverId: friendId,
                    receiverName: item['fname'] ?? 'User',
                    receiverPic: item['profile_pic']?.toString(),
                  ),
                ),
              );

              if (mounted) {
                fetchAcceptedFriends(silent: true);
              }
            },
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      _buildPresenceAvatar(
                        userId: friendId,
                        profilePic: item['profile_pic']?.toString(),
                        name: (item['fname'] ?? 'U').toString(),
                        hasUnread: hasUnread,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item['fname'] ?? 'User',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: hasUnread
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                if (timeStr.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    timeStr,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: hasUnread
                                          ? const Color(0xFF25D366)
                                          : colorScheme.onSurface
                                              .withValues(alpha: 0.48),
                                      fontWeight: hasUnread
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    messageContent.isNotEmpty
                                        ? messageContent
                                        : 'Tap to chat',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: hasUnread
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: hasUnread
                                          ? colorScheme.onSurface
                                              .withValues(alpha: 0.88)
                                          : colorScheme.onSurface
                                              .withValues(alpha: 0.55),
                                    ),
                                  ),
                                ),
                                if (hasUnread)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2.5,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 22,
                                      minHeight: 22,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF25D366),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        unreadCount > 99
                                            ? '99+'
                                            : '$unreadCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  indent: 82,
                  endIndent: 16,
                  color: colorScheme.outline.withValues(alpha: 0.08),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ================= ACCEPTED UI =================

  Widget _buildAcceptedList() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (acceptedLoading) {
      return _buildListShimmer();
    }

    return Column(
      children: [
        /// 🔍 Search + Export
        // Padding(
        //   padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        //   child: Row(
        //     children: [
        //       Expanded(
        //         child: Container(
        //           height: 44,
        //           decoration: BoxDecoration(
        //             color: colorScheme.surfaceVariant,
        //             borderRadius: BorderRadius.circular(12),
        //             border:
        //                 Border.all(color: colorScheme.primary.withOpacity(0.2)),
        //           ),
        //           child: TextField(
        //             controller: _searchController,
        //             onChanged: _onSearchChanged,
        //             style: TextStyle(color: colorScheme.onSurface),
        //             decoration: InputDecoration(
        //               hintText: "Search connections...",
        //               hintStyle: TextStyle(
        //                   color: colorScheme.onSurface.withOpacity(0.6)),
        //               prefixIcon: Icon(Icons.search,
        //                   color: colorScheme.onSurface.withOpacity(0.6)),
        //               border: InputBorder.none,
        //               contentPadding: const EdgeInsets.symmetric(vertical: 12),
        //             ),
        //           ),
        //         ),
        //       ),
        //       const SizedBox(width: 10),
        //       Container(
        //         height: 44,
        //         width: 44,
        //         decoration: BoxDecoration(
        //           color: colorScheme.surfaceVariant,
        //           borderRadius: BorderRadius.circular(12),
        //           border:
        //               Border.all(color: colorScheme.primary.withOpacity(0.2)),
        //         ),
        //         child: IconButton(
        //           onPressed: _onExportClick,
        //           icon: Icon(Icons.download, color: colorScheme.onSurface),
        //         ),
        //       ),
        //     ],
        //   ),
        // ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark
                        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.14),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: TextStyle(color: colorScheme.onSurface, fontSize: 15),
                    decoration: InputDecoration(
                      filled: false,
                      hintText: "Search connections...",
                      hintStyle: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.45),
                        fontSize: 14.5,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 20,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.close,
                                size: 20,
                                color: colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged("");
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 11,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _onExportClick,
                icon: Icon(
                  Icons.download_rounded,
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),

        /// 📋 List
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
                    padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
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

                      final designation = (item['designation'] ??
                              item['job_title'] ??
                              item['role'] ??
                              '')
                          .toString()
                          .trim();
                      final company = (item['legal_name'] ??
                              item['business_name'] ??
                              item['company_name'] ??
                              item['company'] ??
                              '')
                          .toString()
                          .trim();
                      final subtitleText = [
                        if (designation.isNotEmpty) designation,
                        if (company.isNotEmpty) company,
                      ].join(' • ');

                      Future<void> openProfile() async {
                        final session =
                            await UserStorageService().loadSession();
                        final viewerId = session.user?.id;
                        if (viewerId == null || !mounted) return;
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
                      }

                      return InkWell(
                        onTap: openProfile,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 11,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  /// 👤 Avatar with live presence dot
                                  _buildPresenceAvatar(
                                    userId: friendId,
                                    profilePic: item['profile_pic']?.toString(),
                                    name: (item['fname'] ?? 'U').toString(),
                                  ),

                                  const SizedBox(width: 14),

                                  /// 🧑 Name + Designation / Company
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['fname'] ?? 'User',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          subtitleText.isNotEmpty
                                              ? subtitleText
                                              : 'Connected',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.58),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(width: 10),

                                  /// Red Unfollow / Remove Connection icon button
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent
                                          .withValues(alpha: 0.10),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      tooltip: 'Remove Connection',
                                      icon: const Icon(
                                        Icons.person_remove_outlined,
                                        color: Colors.redAccent,
                                        size: 20,
                                      ),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title:
                                                const Text('Remove Connection'),
                                            content: Text(
                                                'Remove ${item['fname'] ?? 'this user'} from your connections?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, false),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, true),
                                                child: const Text(
                                                  'Remove',
                                                  style: TextStyle(
                                                      color: Colors.redAccent),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm != true || !mounted) return;

                                        final session =
                                            await UserStorageService()
                                                .loadSession();
                                        final viewerId = session.user?.id ?? 0;
                                        final sId = int.tryParse(
                                                (item['sender_id'] ?? viewerId)
                                                    .toString()) ??
                                            viewerId;
                                        final rId = int.tryParse(
                                                (item['receiver_id'] ??
                                                        friendId)
                                                    .toString()) ??
                                            friendId;
                                        final st = int.tryParse(
                                                (item['status'] ?? 1)
                                                    .toString()) ??
                                            1;

                                        await deleteConnectionRequest(
                                          senderId: sId,
                                          receiverId: rId,
                                          status: st,
                                          fromTab: 'accepted',
                                          index: index,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Divider(
                              height: 1,
                              indent: 82,
                              endIndent: 16,
                              color:
                                  colorScheme.outline.withValues(alpha: 0.08),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  // ================= PENDING UI (UPDATED) ==========================================
  Widget _buildPendingListUpdated() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isLoading && pendingConnections.isEmpty) {
      return Center(
          child: CircularProgressIndicator(color: colorScheme.primary));
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);

    int? featureId = FeatureMapper.getFeatureId('connection_request_accept');

    bool canUse = FeatureAccessHelper.canUseFeature(
      featureId: featureId!,
      subscription: auth.subscriptionDetails,
    );

    debugPrint("Can use connection_request_accept: $canUse");

    return Column(
      children: [
        // Padding(
        //   padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        //   child: Row(
        //     children: [
        //       Expanded(
        //         child: Container(
        //           height: 44,
        //           decoration: BoxDecoration(
        //             color: colorScheme.surfaceVariant,
        //             borderRadius: BorderRadius.circular(12),
        //             border:
        //                 Border.all(color: colorScheme.primary.withOpacity(0.2)),
        //           ),
        //           child: TextField(
        //             controller: _pendingSearchController,
        //             onChanged: _onPendingSearchChanged,
        //             style: TextStyle(color: colorScheme.onSurface),
        //             decoration: InputDecoration(
        //               hintText: "Search pending...",
        //               hintStyle: TextStyle(
        //                   color: colorScheme.onSurface.withOpacity(0.6)),
        //               prefixIcon: Icon(Icons.search,
        //                   color: colorScheme.onSurface.withOpacity(0.6)),
        //               border: InputBorder.none,
        //               contentPadding: const EdgeInsets.symmetric(vertical: 12),
        //             ),
        //           ),
        //         ),
        //       ),
        //       const SizedBox(width: 10),
        //       Container(
        //         height: 44,
        //         width: 44,
        //         decoration: BoxDecoration(
        //           color: colorScheme.surfaceVariant,
        //           borderRadius: BorderRadius.circular(12),
        //           border:
        //               Border.all(color: colorScheme.primary.withOpacity(0.2)),
        //         ),
        //         child: IconButton(
        //           onPressed: _onPendingExportClick,
        //           icon: Icon(Icons.download, color: colorScheme.onSurface),
        //         ),
        //       ),
        //     ],
        //   ),
        // ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pendingSearchController,
                  onChanged: _onPendingSearchChanged,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: "Search pending...",
                    hintStyle: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),

                    // ✅ same business feed style
                    filled: true,
                    fillColor: colorScheme.surface,

                    prefixIcon: Icon(
                      Icons.search,
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),

                    // ✅ clear button
                    suffixIcon: _pendingSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.close,
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                            onPressed: () {
                              _pendingSearchController.clear();
                              _onPendingSearchChanged(""); // function same
                            },
                          )
                        : null,

                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),

                    // ✅ borders same as business feed
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 0.2,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 0.8,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // ✅ Export button styled same
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.primary,
                    width: 0.2,
                  ),
                ),
                child: IconButton(
                  onPressed: _onPendingExportClick,
                  icon: Icon(
                    Icons.download,
                    color: colorScheme.onSurface,
                  ),
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

                          bool canView = await _viewProfileApi(senderId);

                          if (canView) {
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
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SubscriptionPlans(),
                              ),
                            );
                          }
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

                                          if (canUse == true) {
                                            // ✅ Allowed → API call
                                            updateStatus(
                                              senderId: senderId,
                                              receiverId: receiverId,
                                              status: 2,
                                              index: index,
                                            );
                                          } else {
                                            // ❌ Limit reached → Subscription page
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const SubscriptionPlans(),
                                              ),
                                            );

                                            TopAlert.show(
                                              context,
                                              'Limit reached, upgrade plan 🚀',
                                              isError: true,
                                            );
                                          }
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
        // Padding(
        //   padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        //   child: Row(
        //     children: [
        //       Expanded(
        //         child: Container(
        //           height: 44,
        //           decoration: BoxDecoration(
        //             color: colorScheme.surfaceVariant,
        //             borderRadius: BorderRadius.circular(12),
        //             border:
        //                 Border.all(color: colorScheme.primary.withOpacity(0.2)),
        //           ),
        //           child: TextField(
        //             controller: _sentSearchController,
        //             onChanged: _onSentSearchChanged,
        //             style: TextStyle(color: colorScheme.onSurface),
        //             decoration: InputDecoration(
        //               hintText: "Search sent...",
        //               hintStyle: TextStyle(
        //                   color: colorScheme.onSurface.withOpacity(0.6)),
        //               prefixIcon: Icon(Icons.search,
        //                   color: colorScheme.onSurface.withOpacity(0.6)),
        //               border: InputBorder.none,
        //               contentPadding: const EdgeInsets.symmetric(vertical: 12),
        //             ),
        //           ),
        //         ),
        //       ),
        //       const SizedBox(width: 10),
        //       Container(
        //         height: 44,
        //         width: 44,
        //         decoration: BoxDecoration(
        //           color: colorScheme.surfaceVariant,
        //           borderRadius: BorderRadius.circular(12),
        //           border:
        //               Border.all(color: colorScheme.primary.withOpacity(0.2)),
        //         ),
        //         child: IconButton(
        //           onPressed: _onSentExportClick,
        //           icon: Icon(Icons.download, color: colorScheme.onSurface),
        //         ),
        //       ),
        //     ],
        //   ),
        // ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _sentSearchController,
                  onChanged: _onSentSearchChanged,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: "Search sent...",
                    hintStyle: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),

                    // ✅ business feed style
                    filled: true,
                    fillColor: colorScheme.surface,

                    prefixIcon: Icon(
                      Icons.search,
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),

                    // ✅ clear button
                    suffixIcon: _sentSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.close,
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                            onPressed: () {
                              _sentSearchController.clear();
                              _onSentSearchChanged(""); // function same
                            },
                          )
                        : null,

                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),

                    // ✅ borders same as business feed
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 0.2,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 0.8,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // ✅ Export button same style
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.primary,
                    width: 0.2,
                  ),
                ),
                child: IconButton(
                  onPressed: _onSentExportClick,
                  icon: Icon(
                    Icons.download,
                    color: colorScheme.onSurface,
                  ),
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

                          bool canView = await _viewProfileApi(profileUserId);

                          if (canView) {
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
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SubscriptionPlans(),
                              ),
                            );
                          }
                        },
                        child: Card(
                          color: colorScheme.surface,
                          elevation: 2,
                          shadowColor: isDark
                              ? Colors.black
                              : Colors.grey.withOpacity(0.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: colorScheme.outline.withOpacity(0.2),
                              width: 0.6,
                            ),
                          ),
                          margin: const EdgeInsets.only(bottom: 14),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            child: Column(
                              children: [
                                /// 👤 USER INFO
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
                                              size: 26,
                                              color: colorScheme.onSurface
                                                  .withOpacity(0.6),
                                            )
                                          : null,
                                    ),

                                    const SizedBox(width: 14),

                                    /// Name + Username
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            fname,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                          if (userName.isNotEmpty)
                                            Text(
                                              userName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
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

                                /// Divider (subtle)
                                Divider(
                                  height: 1,
                                  color: colorScheme.outline.withOpacity(0.15),
                                ),

                                const SizedBox(height: 10),

                                /// 🔘 ACTION BUTTON
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        icon: const Icon(
                                            Icons.person_remove_alt_1,
                                            size: 18),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                            color: colorScheme.outline,
                                            width: 0.5,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
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
                                        label: const Text("Remove"),
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
