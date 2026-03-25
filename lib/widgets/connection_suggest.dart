import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:gridcard/features/profile/profile_page.dart';
import 'package:http/http.dart' as http;

import '../features/feature_map/feature_access_helper.dart';
import '../features/feature_map/feature_mapper.dart';
import '../features/home/SubscriptionPlans.dart';
import 'package:gridcard/core/services/auth_provider.dart';
import 'package:provider/provider.dart';

class ConnectionSuggest extends StatefulWidget {
  final int viewerUserId;

  const ConnectionSuggest({super.key, required this.viewerUserId});

  @override
  State<ConnectionSuggest> createState() =>
      ConnectionSuggestState(); // public state class
}

class ConnectionSuggestState extends State<ConnectionSuggest> {
  final PageController _pageController = PageController(viewportFraction: .78);

  static const String _baseUrl = AppConfig.apiBaseUrl;
  static const String _storageBaseUrl = AppConfig.apiProfileImg;

  bool _isLoading = false;
  bool _isFirstLoad = true;
  bool canView = true;

  int _currentPage = 1;
  int _lastPage = 1;

  final List<Map<String, dynamic>> _users = [];

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
    _fetchUsers(page: 1);

    _pageController.addListener(() {
      final currentPage = _pageController.page ?? 0;
      if (currentPage >= (_users.length - 3) && !_isLoading) {
        _loadNextPage();
      }
    });
  }

  // ================= API CALL =================
  Future<void> _fetchUsers({required int page}) async {
    try {
      setState(() => _isLoading = true);

      final uri = Uri.parse("$_baseUrl/users-with-business/list?page=$page");
      final headers = await _getHeaders();

      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({
          "userId": widget.viewerUserId,
        }),
      );

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 && jsonData["status"] == true) {
        final List listUsers = jsonData["data"]?["users"] ?? [];
        final pagination = jsonData["data"]?["pagination"] ?? {};
        final int currentPage = pagination["current_page"] ?? page;
        final int lastPage = pagination["last_page"] ?? page;

        final newUsers =
            listUsers.map((e) => Map<String, dynamic>.from(e)).toList();

        setState(() {
          if (page == 1) _users.clear();

          final existingIds = _users.map((e) => e["id"]).toSet();
          for (final u in newUsers) {
            if (!existingIds.contains(u["id"])) {
              _users.add(u);
            }
          }

          _currentPage = currentPage;
          _lastPage = lastPage;
          _isFirstLoad = false;
        });
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
    if (_isLoading) return;
    if (_currentPage >= _lastPage) return;
    await _fetchUsers(page: _currentPage + 1);
  }

  // ================= PUBLIC REFRESH METHOD =================
  void refresh() {
    setState(() {
      _users.clear();
      _currentPage = 1;
      _lastPage = 1;
      _isFirstLoad = true;
    });
    _fetchUsers(page: 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ================= HELPERS =================
  String? _fullStorageUrl(String? path) {
    if (path == null) return null;
    final p = path.trim();
    if (p.isEmpty) return null;
    return "$_storageBaseUrl/$p";
  }

  String _safeText(dynamic v) {
    if (v == null) return "";
    return v.toString().trim();
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

      // ✅ अगर same है → allow
      if (res.statusCode == 200 && data["message"] == "same") {
        return true;
      }

      // ✅ अगर not match है → allow
      if (res.statusCode == 200 && data["message"] == "not match") {
        return true;
      }

      // ❌ अगर limit exceed (403)
      if (res.statusCode == 403) {
        return false;
      }

      return false;
    } catch (e) {
      debugPrint("🔴 ERROR viewProfile API: $e");
      return false;
    }
  }

  // ================= CARD UI =================
  Widget _userCard(Map<String, dynamic> user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fname = _safeText(user["fname"]);
    final userName = _safeText(user["user_name"]);
    final profilePic = _fullStorageUrl(user["profile_pic"]);
    final industryTitle = _safeText(user["business"]?["industry"]?["title"]);

    final showName =
        fname.isNotEmpty ? fname : (userName.isNotEmpty ? userName : "Unknown");

    return GestureDetector(
      

      onTap: () async {
        final profileId = user["id"];

        bool canView = await _viewProfileApi(profileId);

        if (canView) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfilePage(
                userId: profileId,
                viewerUserId: widget.viewerUserId,
                fromSuggestion: true,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SubscriptionPlans(),
            ),
          );
        }
      },

      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              blurRadius: 14,
              offset: const Offset(0, 10),
              color: Colors.black.withOpacity(0.07),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              Positioned.fill(
                child: profilePic == null
                    ? Container(
                        color: isDark
                            ? Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                            : Colors.grey.shade300,
                        child: Icon(
                          Icons.account_circle,
                          size: 80,
                          color: isDark ? Colors.grey.shade600 : null,
                        ),
                      )
                    : Image.network(
                        profilePic,
                        fit: BoxFit.cover,
                      ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 60,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.65),
                        Colors.black.withOpacity(0.45),
                        Colors.black.withOpacity(0.25),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 0.8, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      showName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (industryTitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        industryTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isFirstLoad) {
      return const SizedBox(
        height: 320,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_users.isEmpty) {
      return const SizedBox(
        height: 320,
        child: Center(
          child: Text("No suggestions found"),
        ),
      );
    }

    return SizedBox(
      height: 280,
      child: PageView.builder(
        controller: _pageController,
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          return _userCard(user);
        },
      ),
    );
  }
}
