
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
//   final PageController _pageController = PageController(viewportFraction: .6);

//   static const String _baseUrl = AppConfig.apiBaseUrl;

//   int? _userId;

//   bool _isLoading = false;
//   bool _isFirstLoad = true;

//   int _currentPage = 1;
//   int _lastPage = 1;

//   final List<Map<String, dynamic>> _users = [];

//   @override
//   void initState() {
//     super.initState();
//     _initAndLoad();

//     _pageController.addListener(() {
//       final currentPage = _pageController.page ?? 0;
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

//   Future<void> _fetchUsers({required int page}) async {
//     if (_userId == null) return;

//     try {
//       setState(() {
//         _isLoading = true;
//       });

//       final uri = Uri.parse("$_baseUrl/users/filter-list?page=$page");

//       final response = await http.post(
//         uri,
//         headers: {
//           "Content-Type": "application/json",
//           "Accept": "application/json",
//         },
//         body: jsonEncode({
//           "user_id": _userId,
//         }),
//       );

//       final jsonData = jsonDecode(response.body);

//       if (response.statusCode == 200 && jsonData["status"] == true) {
//         final List data = jsonData["data"] ?? [];

//         final pagination = jsonData["pagination"] ?? {};
//         final int currentPage = pagination["current_page"] ?? page;
//         final int lastPage = pagination["last_page"] ?? page;

//         final newUsers = data.map((e) => Map<String, dynamic>.from(e)).toList();

//         setState(() {
//           if (page == 1) {
//             _users.clear();
//           }
//           _users.addAll(newUsers);

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

//   @override
//   Widget build(BuildContext context) {
//     final colorScheme = Theme.of(context).colorScheme;
//     final isDark = Theme.of(context).brightness == Brightness.dark;

//     if (_isFirstLoad) {
//       return const SizedBox(
//         height: 150,
//         child: Center(child: CircularProgressIndicator()),
//       );
//     }

//     if (_users.isEmpty) {
//       return const SizedBox(
//         height: 150,
//         child: Center(
//           child: Text("No suggestions found"),
//         ),
//       );
//     }

//     return SizedBox(
//       height: 150,
//       child: PageView.builder(
//         controller: _pageController,
//         itemCount: _users.length,
//         itemBuilder: (context, index) {
//           final user = _users[index];
//           final userName = user["fname"] ?? "Unknown";

//           return GestureDetector(
//             onTap: () {
//               // 👇 Navigate to that user's profile
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (context) => ProfilePage(
//                     userId: user['id'], // assuming 'id' exists
//                     viewerUserId: _userId, // ✅ add this
//                   ),
//                 ),
//               );
//             },
//             child: Container(
//               margin: const EdgeInsets.symmetric(horizontal: 8),
//               decoration: BoxDecoration(
//                 color: isDark
//                     ? colorScheme.surfaceContainerHighest
//                     : Colors.grey[100],
//                 border: Border.all(
//                   color: colorScheme.onSurface.withOpacity(0.05),
//                 ),
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(
//                     Icons.account_circle,
//                     size: 60,
//                     color: colorScheme.primary,
//                   ),
//                   const SizedBox(height: 8),
//                   Text(
//                     userName.toString(),
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       color: isDark ? colorScheme.onSurface : colorScheme.primary,
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   Text(
//                     'Occupation', // You may replace with actual field like user["occupation"]
//                     style: TextStyle(
//                       color: colorScheme.onSurface.withOpacity(0.5),
//                       fontSize: 12,
//                     ),
//                   ),
//                   if (_isLoading && index == _users.length - 1)
//                     const Padding(
//                       padding: EdgeInsets.only(top: 8),
//                       child: SizedBox(
//                         height: 18,
//                         width: 18,
//                         child: CircularProgressIndicator(strokeWidth: 2),
//                       ),
//                     ),
//                 ],
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }

//=================================================================================


import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:gridcard/features/profile/profile_page.dart';
import 'package:http/http.dart' as http;

class ConnectionSuggest extends StatefulWidget {
  const ConnectionSuggest({super.key});

  @override
  State<ConnectionSuggest> createState() => _ConnectionSuggestState();
}

class _ConnectionSuggestState extends State<ConnectionSuggest> {
  final PageController _pageController = PageController(viewportFraction: .78);

  static const String _baseUrl = AppConfig.apiBaseUrl;

  // Image base url (as you said)
  static const String _storageBaseUrl =
      "https://powderblue-jellyfish-554082.hostingersite.com/storage";

  int? _userId;

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
    _initAndLoad();

    _pageController.addListener(() {
      final currentPage = _pageController.page ?? 0;

      // last 2-3 cards ke paas aate hi load next
      if (currentPage >= (_users.length - 3) && !_isLoading) {
        _loadNextPage();
      }
    });
  }

  Future<void> _initAndLoad() async {
    final session = await UserStorageService().loadSession();
    final userId = session.user?.id;

    if (userId == null) return;

    setState(() {
      _userId = userId;
    });

    await _fetchUsers(page: 1);
  }

  // ================= API CALL =================
  Future<void> _fetchUsers({required int page}) async {
    if (_userId == null) return;

    try {
      setState(() {
        _isLoading = true;
      });

      // NEW API
      final uri = Uri.parse("$_baseUrl/users-with-business/list?page=$page");

      final headers = await _getHeaders();

      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({
          "userId": _userId,
        }),
      );

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 && jsonData["status"] == true) {
        final List listUsers = jsonData["data"]?["users"] ?? [];

        final pagination = jsonData["data"]?["pagination"] ?? {};
        final int currentPage = pagination["current_page"] ?? page;
        final int lastPage = pagination["last_page"] ?? page;

        final newUsers = listUsers.map((e) => Map<String, dynamic>.from(e)).toList();

        setState(() {
          if (page == 1) {
            _users.clear();
          }

          // avoid duplicates
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

  Widget _infoRow({
    required IconData icon,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade700),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ================= CARD UI =================
  // Widget _userCard(Map<String, dynamic> user) {
  //   final colorScheme = Theme.of(context).colorScheme;
  //   final isDark = Theme.of(context).brightness == Brightness.dark;

  //   final fname = _safeText(user["fname"]);
  //   final userName = _safeText(user["user_name"]);

  //   final address = _safeText(user["address"]);

  //   final stateName = _safeText(user["state"]?["state_name"]);

  //   final profilePic = _fullStorageUrl(user["profile_pic"]);
  //   final profileLogo = _fullStorageUrl(user["profile_logo"]);

  //   final business = user["business"];
  //   final legalName = _safeText(business?["legal_name"]);
  //   final gstNo = _safeText(business?["gst_no"]);
  //   final description = _safeText(business?["description"]);
  //   final industryTitle = _safeText(business?["industry"]?["title"]);

  //   final showName = fname.isNotEmpty ? fname : (userName.isNotEmpty ? userName : "Unknown");

  //   return GestureDetector(
  //     onTap: () {
  //       if (_userId == null) return;

  //       Navigator.push(
  //         context,
  //         MaterialPageRoute(
  //           builder: (context) => ProfilePage(
  //             userId: user["id"],
  //             viewerUserId: _userId,
  //           ),
  //         ),
  //       );
  //     },
  //     child: Container(
  //       margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
  //       decoration: BoxDecoration(
  //         color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
  //         borderRadius: BorderRadius.circular(22),
  //         border: Border.all(
  //           color: colorScheme.onSurface.withOpacity(0.06),
  //         ),
  //         boxShadow: [
  //           BoxShadow(
  //             blurRadius: 14,
  //             spreadRadius: 0,
  //             offset: const Offset(0, 10),
  //             color: Colors.black.withOpacity(0.07),
  //           ),
  //         ],
  //       ),
  //       child: ClipRRect(
  //         borderRadius: BorderRadius.circular(22),
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             // ================= IMAGE HEADER =================
  //             SizedBox(
  //               height: 135,
  //               width: double.infinity,
  //               child: Stack(
  //                 children: [
  //                   Positioned.fill(
  //                     child: profilePic == null
  //                         ? Container(
  //                             color: Colors.grey.shade200,
  //                             child: Icon(
  //                               Icons.account_circle,
  //                               size: 70,
  //                               color: Colors.grey.shade500,
  //                             ),
  //                           )
  //                         : Image.network(
  //                             profilePic,
  //                             fit: BoxFit.cover,
  //                             errorBuilder: (context, error, stackTrace) {
  //                               return Container(
  //                                 color: Colors.grey.shade200,
  //                                 child: Icon(
  //                                   Icons.account_circle,
  //                                   size: 70,
  //                                   color: Colors.grey.shade500,
  //                                 ),
  //                               );
  //                             },
  //                             loadingBuilder: (context, child, progress) {
  //                               if (progress == null) return child;
  //                               return Container(
  //                                 color: Colors.grey.shade200,
  //                                 child: const Center(
  //                                   child: SizedBox(
  //                                     height: 22,
  //                                     width: 22,
  //                                     child: CircularProgressIndicator(strokeWidth: 2),
  //                                   ),
  //                                 ),
  //                               );
  //                             },
  //                           ),
  //                   ),

  //                   // bottom gradient
  //                   Positioned(
  //                     left: 0,
  //                     right: 0,
  //                     bottom: 0,
  //                     height: 60,
  //                     child: Container(
  //                       decoration: BoxDecoration(
  //                         gradient: LinearGradient(
  //                           begin: Alignment.topCenter,
  //                           end: Alignment.bottomCenter,
  //                           colors: [
  //                             Colors.black.withOpacity(0.0),
  //                             Colors.black.withOpacity(0.55),
  //                           ],
  //                         ),
  //                       ),
  //                     ),
  //                   ),

  //                   // name on image bottom-left
  //                   Positioned(
  //                     left: 12,
  //                     bottom: 10,
  //                     right: 60,
  //                     child: Text(
  //                       showName,
  //                       maxLines: 1,
  //                       overflow: TextOverflow.ellipsis,
  //                       style: const TextStyle(
  //                         fontSize: 15,
  //                         fontWeight: FontWeight.w900,
  //                         color: Colors.white,
  //                       ),
  //                     ),
  //                   ),

  //                   // logo bottom-right (small circle)
  //                   Positioned(
  //                     right: 12,
  //                     bottom: 10,
  //                     child: Container(
  //                       height: 42,
  //                       width: 42,
  //                       decoration: BoxDecoration(
  //                         color: Colors.white,
  //                         shape: BoxShape.circle,
  //                         border: Border.all(color: Colors.white, width: 2),
  //                         boxShadow: [
  //                           BoxShadow(
  //                             blurRadius: 10,
  //                             offset: const Offset(0, 6),
  //                             color: Colors.black.withOpacity(0.25),
  //                           ),
  //                         ],
  //                       ),
  //                       child: ClipOval(
  //                         child: profileLogo == null
  //                             ? Icon(
  //                                 Icons.business,
  //                                 size: 22,
  //                                 color: Colors.grey.shade700,
  //                               )
  //                             : Image.network(
  //                                 profileLogo,
  //                                 fit: BoxFit.cover,
  //                                 errorBuilder: (context, error, stackTrace) {
  //                                   return Icon(
  //                                     Icons.business,
  //                                     size: 22,
  //                                     color: Colors.grey.shade700,
  //                                   );
  //                                 },
  //                               ),
  //                       ),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),

  //             // ================= DETAILS =================
  //             Expanded(
  //               child: Padding(
  //                 padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
  //                 child: Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     // fname (again) + username
  //                     Text(
  //                       showName,
  //                       maxLines: 1,
  //                       overflow: TextOverflow.ellipsis,
  //                       style: TextStyle(
  //                         fontSize: 15,
  //                         fontWeight: FontWeight.w900,
  //                         color: isDark ? colorScheme.onSurface : Colors.black,
  //                       ),
  //                     ),
  //                     if (userName.isNotEmpty) ...[
  //                       const SizedBox(height: 2),
  //                       Text(
  //                         "@$userName",
  //                         maxLines: 1,
  //                         overflow: TextOverflow.ellipsis,
  //                         style: TextStyle(
  //                           fontSize: 12,
  //                           color: Colors.grey.shade600,
  //                           fontWeight: FontWeight.w600,
  //                         ),
  //                       ),
  //                     ],

  //                     const SizedBox(height: 10),

  //                     // address + state
  //                     if (address.isNotEmpty || stateName.isNotEmpty) ...[
  //                       _infoRow(
  //                         icon: Icons.location_on,
  //                         text: [
  //                           if (address.isNotEmpty) address,
  //                           if (stateName.isNotEmpty) stateName,
  //                         ].join(" • "),
  //                       ),
  //                       const SizedBox(height: 8),
  //                     ],

  //                     // business legal name
  //                     if (legalName.isNotEmpty) ...[
  //                       _infoRow(
  //                         icon: Icons.storefront,
  //                         text: legalName,
  //                       ),
  //                       const SizedBox(height: 8),
  //                     ],

  //                     // gst
  //                     if (gstNo.isNotEmpty) ...[
  //                       _infoRow(
  //                         icon: Icons.receipt_long,
  //                         text: "GST: $gstNo",
  //                       ),
  //                       const SizedBox(height: 8),
  //                     ],

  //                     // industry
  //                     if (industryTitle.isNotEmpty) ...[
  //                       _infoRow(
  //                         icon: Icons.category,
  //                         text: "Industry: $industryTitle",
  //                       ),
  //                       const SizedBox(height: 8),
  //                     ],

  //                     // description
  //                     if (description.isNotEmpty) ...[
  //                       Expanded(
  //                         child: Container(
  //                           width: double.infinity,
  //                           padding: const EdgeInsets.all(10),
  //                           decoration: BoxDecoration(
  //                             color: isDark
  //                                 ? colorScheme.surface.withOpacity(0.5)
  //                                 : Colors.grey.shade50,
  //                             borderRadius: BorderRadius.circular(14),
  //                             border: Border.all(
  //                               color: colorScheme.onSurface.withOpacity(0.05),
  //                             ),
  //                           ),
  //                           child: Text(
  //                             description,
  //                             maxLines: 4,
  //                             overflow: TextOverflow.ellipsis,
  //                             style: TextStyle(
  //                               fontSize: 12,
  //                               color: Colors.grey.shade800,
  //                               fontWeight: FontWeight.w600,
  //                               height: 1.2,
  //                             ),
  //                           ),
  //                         ),
  //                       ),
  //                     ] else ...[
  //                       const Spacer(),
  //                     ],

  //                     // loader (only on last card)
  //                     if (_isLoading && _users.isNotEmpty && user["id"] == _users.last["id"])
  //                       const Padding(
  //                         padding: EdgeInsets.only(top: 10),
  //                         child: Center(
  //                           child: SizedBox(
  //                             height: 18,
  //                             width: 18,
  //                             child: CircularProgressIndicator(strokeWidth: 2),
  //                           ),
  //                         ),
  //                       ),
  //                   ],
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Widget _userCard(Map<String, dynamic> user) {
  final colorScheme = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  final fname = _safeText(user["fname"]);
  final userName = _safeText(user["user_name"]);

  final address = _safeText(user["address"]);
  final stateName = _safeText(user["state"]?["state_name"]);

  final profilePic = _fullStorageUrl(user["profile_pic"]);
  final profileLogo = _fullStorageUrl(user["profile_logo"]);

  final business = user["business"];
  final legalName = _safeText(business?["legal_name"]);
  final gstNo = _safeText(business?["gst_no"]);
  final description = _safeText(business?["description"]);
  final industryTitle = _safeText(business?["industry"]?["title"]);

  final showName =
      fname.isNotEmpty ? fname : (userName.isNotEmpty ? userName : "Unknown");

  return GestureDetector(
    onTap: () {
      if (_userId == null) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfilePage(
            userId: user["id"],
            viewerUserId: _userId,
          ),
        ),
      );
    },
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.onSurface.withOpacity(0.06),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            spreadRadius: 0,
            offset: const Offset(0, 10),
            color: Colors.black.withOpacity(0.07),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          children: [
            // ================= IMAGE HEADER =================
            SizedBox(
              height: 135,
              width: double.infinity,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: profilePic == null
                        ? Container(
                            color: Colors.grey.shade200,
                            child: Icon(
                              Icons.account_circle,
                              size: 70,
                              color: Colors.grey.shade500,
                            ),
                          )
                        : Image.network(
                            profilePic,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey.shade200,
                                child: Icon(
                                  Icons.account_circle,
                                  size: 70,
                                  color: Colors.grey.shade500,
                                ),
                              );
                            },
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  // bottom gradient
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 60,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.0),
                            Colors.black.withOpacity(0.55),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // name on image bottom-left
                  Positioned(
                    left: 12,
                    bottom: 10,
                    right: 60,
                    child: Text(
                      showName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  // logo bottom-right (small circle)
                  Positioned(
                    right: 12,
                    bottom: 10,
                    child: Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 10,
                            offset: const Offset(0, 6),
                            color: Colors.black.withOpacity(0.25),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: profileLogo == null
                            ? Icon(
                                Icons.business,
                                size: 22,
                                color: Colors.grey.shade700,
                              )
                            : Image.network(
                                profileLogo,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.business,
                                    size: 22,
                                    color: Colors.grey.shade700,
                                  );
                                },
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ================= DETAILS (SCROLLABLE) =================
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // fname + username
                      Text(
                        showName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: isDark ? colorScheme.onSurface : Colors.black,
                        ),
                      ),
                      if (userName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          "@$userName",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],

                      const SizedBox(height: 10),

                      if (address.isNotEmpty || stateName.isNotEmpty) ...[
                        _infoRow(
                          icon: Icons.location_on,
                          text: [
                            if (address.isNotEmpty) address,
                            if (stateName.isNotEmpty) stateName,
                          ].join(" • "),
                        ),
                        const SizedBox(height: 8),
                      ],

                      if (legalName.isNotEmpty) ...[
                        _infoRow(
                          icon: Icons.storefront,
                          text: legalName,
                        ),
                        const SizedBox(height: 8),
                      ],

                      if (gstNo.isNotEmpty) ...[
                        _infoRow(
                          icon: Icons.receipt_long,
                          text: "GST: $gstNo",
                        ),
                        const SizedBox(height: 8),
                      ],

                      if (industryTitle.isNotEmpty) ...[
                        _infoRow(
                          icon: Icons.category,
                          text: "Industry: $industryTitle",
                        ),
                        const SizedBox(height: 8),
                      ],

                      if (description.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? colorScheme.surface.withOpacity(0.5)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: colorScheme.onSurface.withOpacity(0.05),
                            ),
                          ),
                          child: Text(
                            description,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade800,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],

                      if (_isLoading &&
                          _users.isNotEmpty &&
                          user["id"] == _users.last["id"])
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Center(
                            child: SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}


  // ================= BUILD =================
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
      height: 330,
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
