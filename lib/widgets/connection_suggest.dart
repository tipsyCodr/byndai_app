// import 'dart:async';
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:gridcard/config/app_config.dart';
// import 'package:gridcard/core/services/user_storage_service.dart';
// import 'package:gridcard/features/profile/profile_page.dart';
// import 'package:http/http.dart' as http;

// class ConnectionSuggest extends StatefulWidget {
//   const ConnectionSuggest({super.key});

//   @override
//   State<ConnectionSuggest> createState() => _ConnectionSuggestState();
// }

// class _ConnectionSuggestState extends State<ConnectionSuggest> {
//   final PageController _pageController = PageController(viewportFraction: .78);

//   static const String _baseUrl = AppConfig.apiBaseUrl;

//   // Image base url (as you said)
//   // static const String _storageBaseUrl =
//   //     "https://byndai.in/storage";

//   static const String _storageBaseUrl = AppConfig.apiProfileImg;

//   int? _userId;

//   bool _isLoading = false;
//   bool _isFirstLoad = true;

//   int _currentPage = 1;
//   int _lastPage = 1;

//   final List<Map<String, dynamic>> _users = [];

//   // ================= HEADERS =================
//   Future<Map<String, String>> _getHeaders() async {
//     final token = await UserStorageService().getToken();
//     return {
//       "Content-Type": "application/json",
//       "Accept": "application/json",
//       if (token != null) "Authorization": "Bearer $token",
//     };
//   }

//   @override
//   void initState() {
//     super.initState();
//     _initAndLoad();

//     _pageController.addListener(() {
//       final currentPage = _pageController.page ?? 0;

//       // last 2-3 cards ke paas aate hi load next
//       if (currentPage >= (_users.length - 3) && !_isLoading) {
//         _loadNextPage();
//       }
//     });
//   }

//   Future<void> _initAndLoad() async {
//     final session = await UserStorageService().loadSession();
//     final userId = session.user?.id;

//     if (userId == null) return;

//     setState(() {
//       _userId = userId;
//     });

//     await _fetchUsers(page: 1);
//   }

//   // ================= API CALL =================
//   Future<void> _fetchUsers({required int page}) async {
//     if (_userId == null) return;

//     try {
//       setState(() {
//         _isLoading = true;
//       });

//       // NEW API
//       final uri = Uri.parse("$_baseUrl/users-with-business/list?page=$page");

//       final headers = await _getHeaders();

//       final response = await http.post(
//         uri,
//         headers: headers,
//         body: jsonEncode({
//           "userId": _userId,
//         }),
//       );

//       final jsonData = jsonDecode(response.body);

//       if (response.statusCode == 200 && jsonData["status"] == true) {
//         final List listUsers = jsonData["data"]?["users"] ?? [];

//         final pagination = jsonData["data"]?["pagination"] ?? {};
//         final int currentPage = pagination["current_page"] ?? page;
//         final int lastPage = pagination["last_page"] ?? page;

//         final newUsers =
//             listUsers.map((e) => Map<String, dynamic>.from(e)).toList();

//         setState(() {
//           if (page == 1) {
//             _users.clear();
//           }

//           // avoid duplicates
//           final existingIds = _users.map((e) => e["id"]).toSet();
//           for (final u in newUsers) {
//             if (!existingIds.contains(u["id"])) {
//               _users.add(u);
//             }
//           }

//           _currentPage = currentPage;
//           _lastPage = lastPage;

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

//   Future<void> _loadNextPage() async {
//     if (_isLoading) return;
//     if (_currentPage >= _lastPage) return;
//     await _fetchUsers(page: _currentPage + 1);
//   }

//   @override
//   void dispose() {
//     _pageController.dispose();
//     super.dispose();
//   }

//   // ================= HELPERS =================
//   String? _fullStorageUrl(String? path) {
//     if (path == null) return null;
//     final p = path.trim();
//     if (p.isEmpty) return null;
//     return "$_storageBaseUrl/$p";
//   }

//   String _safeText(dynamic v) {
//     if (v == null) return "";
//     return v.toString().trim();
//   }

//   Widget _infoRow({
//     required IconData icon,
//     required String text,
//   }) {
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Icon(icon, size: 14, color: Colors.grey.shade700),
//         const SizedBox(width: 6),
//         Expanded(
//           child: Text(
//             text,
//             maxLines: 2,
//             overflow: TextOverflow.ellipsis,
//             style: TextStyle(
//               fontSize: 12,
//               color: Colors.grey.shade800,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   // ================= CARD UI =================

//   Widget _userCard(Map<String, dynamic> user) {
//     final isDark = Theme.of(context).brightness == Brightness.dark;

//     final fname = _safeText(user["fname"]);
//     final userName = _safeText(user["user_name"]);
//     final profilePic = _fullStorageUrl(user["profile_pic"]);
//     final industryTitle = _safeText(user["business"]?["industry"]?["title"]);

//     final showName =
//         fname.isNotEmpty ? fname : (userName.isNotEmpty ? userName : "Unknown");

//     return GestureDetector(
//       onTap: () {
//         if (_userId == null) return;

//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (context) => ProfilePage(
//               userId: user["id"],
//               viewerUserId: _userId,
//             ),
//           ),
//         );
//       },
//       child: Container(
//         margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(22),
//           boxShadow: [
//             BoxShadow(
//               blurRadius: 14,
//               offset: const Offset(0, 10),
//               color: Colors.black.withOpacity(0.07),
//             ),
//           ],
//         ),
//         child: ClipRRect(
//           borderRadius: BorderRadius.circular(22),
//           child: Stack(
//             children: [
//               // ================= FULL IMAGE =================
//               Positioned.fill(
//                 child: profilePic == null
//                     ? Container(
//                         color: isDark
//                             ? Theme.of(context)
//                                 .colorScheme
//                                 .surfaceContainerHighest
//                             : Colors.grey.shade300,
//                         child: Icon(
//                           Icons.account_circle,
//                           size: 80,
//                           color: isDark ? Colors.grey.shade600 : null,
//                         ),
//                       )
//                     : Image.network(
//                         profilePic,
//                         fit: BoxFit.cover, // 🔥 Full card cover
//                       ),
//               ),

//               // ================= BOTTOM GRADIENT OVERLAY =================
//               Positioned(
//                 left: 0,
//                 right: 0,
//                 bottom: 0,
//                 height: 60,
//                 child: Container(
//                   decoration: BoxDecoration(
//                     gradient: LinearGradient(
//                       begin: Alignment.bottomCenter,
//                       end: Alignment.topCenter,
//                       colors: [
//                         Colors.black.withOpacity(0.65), // 🔥 softer dark
//                         Colors.black.withOpacity(0.45),
//                         Colors.black.withOpacity(0.25),
//                         Colors.transparent,
//                       ],
//                       stops: const [0.0, 0.5, 0.8, 1.0],
//                     ),
//                   ),
//                 ),
//               ),

//               // ================= TEXT INSIDE GREY AREA =================
//               Positioned(
//                 left: 0,
//                 right: 0,
//                 bottom: 8,
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Text(
//                       showName,
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       textAlign: TextAlign.center,
//                       style: const TextStyle(
//                         fontSize: 20,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.white,
//                       ),
//                     ),
//                     if (industryTitle.isNotEmpty) ...[
//                       const SizedBox(height: 2),
//                       Text(
//                         industryTitle,
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                         textAlign: TextAlign.center,
//                         style: const TextStyle(
//                           fontSize: 12,
//                           fontWeight: FontWeight.w500,
//                           color: Colors.white,
//                         ),
//                       ),
//                     ],
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   // ================= BUILD =================
//   @override
//   Widget build(BuildContext context) {
//     if (_isFirstLoad) {
//       return const SizedBox(
//         height: 320,
//         child: Center(child: CircularProgressIndicator()),
//       );
//     }

//     if (_users.isEmpty) {
//       return const SizedBox(
//         height: 320,
//         child: Center(
//           child: Text("No suggestions found"),
//         ),
//       );
//     }

//     return SizedBox(
//       height: 280,
//       child: PageView.builder(
//         controller: _pageController,
//         itemCount: _users.length,
//         itemBuilder: (context, index) {
//           final user = _users[index];
//           return _userCard(user);
//         },
//       ),
//     );
//   }
// }

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:gridcard/features/profile/profile_page.dart';
import 'package:http/http.dart' as http;

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
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfilePage(
              userId: user["id"],
              viewerUserId: widget.viewerUserId,
            ),
          ),
        );
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
