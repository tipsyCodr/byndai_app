import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:gridcard/features/profile/profile_page.dart';
import 'package:gridcard/widgets/top_alert.dart';
import 'package:http/http.dart' as http;

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

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading) {
        _loadNextPage();
      }
    });
  }

  Future<void> _initAndLoad() async {
    final session = await UserStorageService().loadSession();
    final userId = session.user?.id;
    if (userId == null) return;

    _userId = userId;
    await _fetchUsers(page: 1);
  }

  // ================= API CALL =================
  Future<void> _fetchUsers({required int page}) async {
    if (_userId == null) return;

    try {
      setState(() => _isLoading = true);

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

        if (page == 1) _users.clear();

        final existingIds = _users.map((e) => e["id"]).toSet();
        for (final u in newUsers) {
          if (!existingIds.contains(u["id"])) {
            _users.add(u);
          }
        }

        setState(() => _isFirstLoad = false);
      } else {
        setState(() => _isFirstLoad = false);
      }
    } catch (e) {
      setState(() => _isFirstLoad = false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadNextPage() async {
    if (_currentPage >= _lastPage) return;
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

  // ================= CARD =================
  Widget _userCard(Map<String, dynamic> user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profilePic = _fullStorageUrl(user["profile_pic"]);
    final fname = user["fname"] ?? "";
    final friendCount = user["friend_count"] ?? 0;

    final business = user["business"];
    final legalName = business?["legal_name"] ?? "";
    final description = business?["description"] ?? "";

    return GestureDetector(
      onTap: () {
        if (_userId == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfilePage(
              userId: user["id"],
              viewerUserId: _userId,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        height: 360,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          image: profilePic != null
              ? DecorationImage(
                  image: NetworkImage(profilePic),
                  fit: BoxFit.cover,
                )
              : null,
          color: profilePic == null
              ? (isDark
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : Colors.grey.shade300)
              : null,
        ),
        child: Stack(
          children: [
            // Icon behind image if no image
            if (profilePic == null)
              Positioned.fill(
                child: Center(
                  child: Icon(
                    Icons.account_circle,
                    size: 80,
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                  ),
                ),
              ),
            // Gradient

            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 200, // 👈 sirf content jitna
              child: Container(
                decoration: const BoxDecoration(
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(20)),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black, // solid bottom
                      Colors.black, // keep solid till fname
                      Colors.black87, // slight fade
                      Colors.black54, // soft fade
                      Colors.transparent // completely clear
                    ],
                    stops: [
                      0.0,
                      0.55, // 👈 yaha tak full dark (fname tak)
                      0.75,
                      0.9,
                      1.0,
                    ],
                  ),
                ),
              ),
            ),

            // Content
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _capitalize(fname),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color.fromARGB(255, 247, 247, 250),
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 🔹 Legal Name (Left Side)
                      Expanded(
                        child: legalName.isNotEmpty
                            ? Text(
                                legalName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color.fromARGB(255, 249, 249, 252),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              )
                            : const SizedBox(),
                      ),

                      const SizedBox(width: 8),

                      // 🔹 Connect Count (Right Side)
                      Text(
                        "$friendCount Connects",
                        style: const TextStyle(
                          color: Color.fromARGB(255, 249, 248, 252),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (description.isNotEmpty)
                    Text(
                      _truncate(description),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white),
                          ),
                          onPressed: () {
                            if (_userId == null) return;

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProfilePage(
                                  userId: user["id"], // card wala user
                                  viewerUserId: _userId, // login user
                                  isConnected: user["is_connected"] == true,
                                ),
                              ),
                            );
                          },
                          child: const Text("View"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (_userId == null) return;

                            final receiverId = user["id"];

                            final errorMessage =
                                await _sendConnectionRequest(receiverId);

                            if (!mounted) return;

                            if (errorMessage == null) {
                              TopAlert.show(context, "Connection request sent",
                                  isSuccess: true);

                              // Optional: Button ko disable karne ke liye
                              setState(() {
                                user["is_connected"] = true;
                              });
                            } else {
                              TopAlert.show(context, errorMessage,
                                  isError: true);
                            }
                          },
                          child: Text(
                            user["is_connected"] == true
                                ? "Requested"
                                : "Connect",
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            )
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
