import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:gridcard/features/profile/profile_page.dart';
import 'package:gridcard/widgets/top_alert.dart';
import 'package:http/http.dart' as http;

// import '../feature_map/feature_access_helper.dart';
// import '../feature_map/feature_mapper.dart';
// import '../home/SubscriptionPlans.dart';
import '../features/feature_map/feature_access_helper.dart';
import '../features/feature_map/feature_mapper.dart';
import '../features/home/SubscriptionPlans.dart';
import 'package:gridcard/core/services/auth_provider.dart';
import 'package:provider/provider.dart';

class DiscoverConnectionSuggest extends StatefulWidget {
  const DiscoverConnectionSuggest({super.key});

  @override
  State<DiscoverConnectionSuggest> createState() =>
      _DiscoverConnectionSuggestState();
}

class _DiscoverConnectionSuggestState extends State<DiscoverConnectionSuggest> {
  static const String _baseUrl = AppConfig.apiBaseUrl;

  // static const String _storageBaseUrl =
  //     "https://byndai.in/storage";

  static const String _storageBaseUrl = AppConfig.apiProfileImg;

  final ScrollController _scrollController = ScrollController();

  int? _userId;
  bool _isLoading = false;
  bool _isFetchingMore = false;
  bool _isFirstLoad = true;

  int _currentPage = 1;
  int _lastPage = 1;

  String _capitalize(String text) {
    if (text.isEmpty) return "";
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  final List<Map<String, dynamic>> _users = [];

  // ================= SEND CONNECTION REQUEST =================
  Future<String?> _sendConnectionRequest(int receiverId) async {
    final url = Uri.parse("$_baseUrl/connection-create");

    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          "receiver_id": receiverId,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.refreshSubscription();

        final auth = Provider.of<AuthProvider>(context, listen: false);

        int? featureId = FeatureMapper.getFeatureId('connection_request_send');

        bool canUse = FeatureAccessHelper.canUseFeature(
          featureId: featureId!,
          subscription: auth.subscriptionDetails,
        );

        debugPrint(
            "after api call  discover page connection_request_send: $canUse");
        return null;
      }

      if (response.statusCode == 422) {
        if (data["errors"] != null && data["errors"]["receiver_id"] != null) {
          return data["errors"]["receiver_id"][0];
        }
        return data["message"] ?? "Validation error";
      }

      return data["message"] ?? "Something went wrong";
    } catch (e) {
      return "Server error, try again";
    }
  }

  // ================= HEADERS =================
  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      "Content-Type": "application/json",
      "Accept": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  @override
  void initState() {
    super.initState();
    _initAndLoad();

    // _scrollController.addListener(() {
    //   if (_scrollController.position.pixels >=
    //           _scrollController.position.maxScrollExtent - 200 &&
    //       !_isLoading) {
    //     _loadNextPage();
    //   }
    // });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 50 &&
          !_isFetchingMore &&
          _currentPage < _lastPage) {
        _loadNextPage();
      }
    });
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

      debugPrint("🟢 DISCOVER VIEW PROFILE API: ${res.statusCode} => $data");

      // ✅ allow
      if (res.statusCode == 200 && data["message"] == "same") {
        return true;
      }

      if (res.statusCode == 200 && data["message"] == "not match") {
        return true;
      }

      // ❌ limit exceed
      if (res.statusCode == 403) {
        return false;
      }

      return false;
    } catch (e) {
      debugPrint("🔴 ERROR viewProfile API: $e");
      return false;
    }
  }

  Future<void> _initAndLoad() async {
    final session = await UserStorageService().loadSession();
    final userId = session.user?.id;
    if (userId == null) return;

    _userId = userId;
    await _fetchUsers(page: 1);
  }

  // ================= API CALL =================
//   Future<void> _fetchUsers({required int page}) async {
//     if (_userId == null) return;

//     try {
//       setState(() => _isLoading = true);

//       final uri = Uri.parse(
//           "$_baseUrl/users-with-business/list?page=$page&per_page=10");

//       final response = await http.post(
//         uri,
//         headers: await _getHeaders(),
//         body: jsonEncode({"userId": _userId}),
//       );

//       final jsonData = jsonDecode(response.body);

//       if (response.statusCode == 200 && jsonData["status"] == true) {
//         final List listUsers = jsonData["data"]?["users"] ?? [];

//         final pagination = jsonData["data"]?["pagination"] ?? {};
//         _currentPage = pagination["current_page"] ?? page;
//         _lastPage = pagination["last_page"] ?? page;

//         final newUsers =
//             listUsers.map((e) => Map<String, dynamic>.from(e)).toList();

//         if (page == 1) {
//           _users.clear();
//         }

//         final existingIds = _users.map((e) => e["id"]).toSet();

// for (final u in newUsers) {
//   if (!existingIds.contains(u["id"])) {
//     _users.add(u);
//     existingIds.add(u["id"]); // 🔥 IMPORTANT
//   }
// }

//         // ✅ FIX
//         setState(() {
//           _isFirstLoad = false;
//         });
//       } else {
//         setState(() => _isFirstLoad = false);
//       }
//     } catch (e) {
//       setState(() => _isFirstLoad = false);
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

  Future<void> _fetchUsers({required int page}) async {
    if (_userId == null) return;

    try {
      // 🔥 Loader handling (separate for first load & pagination)
      if (page == 1) {
        _isLoading = true;
      } else {
        _isFetchingMore = true;
      }
      setState(() {});

      final uri = Uri.parse(
          "$_baseUrl/users-with-business/list?page=$page&per_page=10");

      final response = await http.post(
        uri,
        headers: await _getHeaders(),
        body: jsonEncode({"userId": _userId}),
      );

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 && jsonData["status"] == true) {
        final List listUsers = jsonData["data"]?["users"] ?? [];

        final pagination = jsonData["data"]?["pagination"] ?? {};
        _currentPage = pagination["current_page"] ?? page;
        _lastPage = pagination["last_page"] ?? page;

        final newUsers =
            listUsers.map((e) => Map<String, dynamic>.from(e)).toList();

        // 🔥 First page reset
        if (page == 1) {
          _users.clear();
        }

        // 🔥 Duplicate safe add (FIXED)
        final existingIds = _users.map((e) => e["id"]).toSet();

        for (final u in newUsers) {
          if (!existingIds.contains(u["id"])) {
            _users.add(u);
            existingIds.add(u["id"]); // 👈 MOST IMPORTANT
          }
        }

        // 🔥 DEBUG (optional but useful)
        debugPrint("PAGE: $_currentPage / $_lastPage");
        debugPrint("NEW USERS: ${newUsers.length}");
        debugPrint("TOTAL USERS: ${_users.length}");

        setState(() {
          _isFirstLoad = false;
        });
      } else {
        setState(() {
          _isFirstLoad = false;
        });
      }
    } catch (e) {
      debugPrint("❌ FETCH USERS ERROR: $e");
      setState(() {
        _isFirstLoad = false;
      });
    } finally {
      // 🔥 Reset loaders properly
      setState(() {
        _isLoading = false;
        _isFetchingMore = false;
      });
    }
  }

  // Future<void> _loadNextPage() async {
  //   if (_currentPage >= _lastPage) return;
  //   await _fetchUsers(page: _currentPage + 1);
  // }

  Future<void> _loadNextPage() async {
    if (_currentPage >= _lastPage) return;
    if (_isFetchingMore) return;

    await _fetchUsers(page: _currentPage + 1);
  }

  String? _fullStorageUrl(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    return "$_storageBaseUrl/$path";
  }

  String _truncate(String text, {int max = 90}) {
    if (text.length <= max) return text;
    return "${text.substring(0, max)}...";
  }

  // ================= UPDATED CARD UI =================
  Widget _userCard(Map<String, dynamic> user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profilePic = _fullStorageUrl(user["profile_pic"]);
    final fname = user["fname"] ?? "";
    final friendCount = user["friend_count"] ?? 0;

    final business = user["business"];
    final legalName = business?["legal_name"] ?? "";
    final description = business?["description"] ?? "";

    return GestureDetector(
      onTap: () async {
        if (_userId == null) return;
        final profileId = user["id"];
        bool canView = await _viewProfileApi(profileId);

        if (canView) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProfilePage(
                userId: profileId,
                viewerUserId: _userId,
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
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        height: 400, // Card height thodi badhayi hai design match karne ke liye
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28), // Rounded corners like image
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            )
          ],
          image: profilePic != null
              ? DecorationImage(
                  image: NetworkImage(profilePic),
                  fit: BoxFit.cover,
                )
              : null,
          color: profilePic == null
              ? (isDark ? Colors.grey.shade900 : Colors.grey.shade200)
              : null,
        ),
        child: Stack(
          children: [
            // Placeholder Icon (agar image nahi hai)
            if (profilePic == null)
              Center(
                child: Icon(
                  Icons.person,
                  size: 120,
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),

            // Design wala Gradient (Frosted/Blur effect look)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.0),
                      Colors.black.withOpacity(0.4),
                      Colors.black.withOpacity(0.85),
                      Colors.black,
                    ],
                    stops: const [0.0, 0.4, 0.6, 0.85, 1.0],
                  ),
                ),
              ),
            ),

            // Content
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // User Name
                  Text(
                    _capitalize(fname),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 26,
                      letterSpacing: 0.5,
                    ),
                  ),

                  // Business/Legal Name
                  if (legalName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        legalName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Connection Count Text
                  Text(
                    "($friendCount Connections)",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Connect Button (Matches the pill shape in image)
                  SizedBox(
                    width: 160,
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side:
                            const BorderSide(color: Colors.white60, width: 1.5),
                        shape: const StadiumBorder(),
                        backgroundColor: Colors.white.withOpacity(0.1),

                        // 👇 IMPORTANT FIX
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () async {
                        // --- Existing Functionality Logic ---
                        final authProvider =
                            Provider.of<AuthProvider>(context, listen: false);
                        await authProvider.refreshSubscription();
                        final auth =
                            Provider.of<AuthProvider>(context, listen: false);
                        int? featureId = FeatureMapper.getFeatureId(
                            'connection_request_send');
                        bool canUse = FeatureAccessHelper.canUseFeature(
                          featureId: featureId!,
                          subscription: auth.subscriptionDetails,
                        );

                        if (canUse) {
                          if (_userId == null) return;
                          final receiverId = user["id"];
                          final errorMessage =
                              await _sendConnectionRequest(receiverId);
                          if (!mounted) return;
                          if (errorMessage == null) {
                            TopAlert.show(context, "Connection request sent",
                                isSuccess: true);
                            setState(() {
                              user["is_connected"] = true;
                            });
                          } else {
                            TopAlert.show(context, errorMessage, isError: true);
                          }
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const SubscriptionPlans()),
                          );
                        }
                      },
                      child: Text(
                        user["is_connected"] == true ? "Requested" : "Connect",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    if (_isFirstLoad) {
      return const SizedBox(
          height: 300, child: Center(child: CircularProgressIndicator()));
    }

    if (_users.isEmpty) {
      return const SizedBox(
          height: 300, child: Center(child: Text("No suggestions found")));
    }

    return ListView.builder(
      controller: _scrollController,
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      itemCount: _users.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < _users.length) {
          return _userCard(_users[index]);
        } else {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
      },
    );
  }
}
