import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:http/http.dart' as http;

import 'my_post_card.dart';

class MyPostsPage extends StatefulWidget {
  const MyPostsPage({super.key});

  @override
  State<MyPostsPage> createState() => _MyPostsPageState();
}

class _MyPostsPageState extends State<MyPostsPage> {
  static const String _baseUrl = AppConfig.apiBaseUrl;
  int? _selectedIndustryId;
  final List<Map<String, dynamic>> _posts = [];

  int _currentPage = 1;
  int _lastPage = 1;
  bool _isLoading = false;
  bool _isLoadingMore = false;

  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  final ScrollController _scrollController = ScrollController();

  int? _userId;

  @override
  void initState() {
    super.initState();
    _initialize();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 250) {
        _loadMore();
      }
    });
  }

  Future<void> _initialize() async {
    _userId = await UserStorageService().getUserId();
    _fetchPosts(page: 1);
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // MyPostsPage ke andar, _MyPostsPageState class mein ye method add karo
  void _handleBack() {
    if (_selectedIndustryId != null || _searchQuery.isNotEmpty) {
      // Filters clear karo
      setState(() {
        _selectedIndustryId = null;
        _searchQuery = "";
        _searchController.clear();
      });
      _fetchPosts(page: 1); // Unfiltered data load karo
    } else {
      // Navigator.pop(context); // Actual back navigation
      Navigator.pop(context, true);
    }
  }

  Future<void> _fetchPosts({required int page}) async {
    if (_isLoading || _userId == null) return;

    setState(() => _isLoading = true);

    // 🔥 IMPORTANT: Agar page 1 hai to turant posts clear kar do
    if (page == 1) {
      setState(() {
        _posts.clear();
      });
    }

    try {
      final headers = await _getHeaders();

      Map<String, String> queryParams = {
        "page": page.toString(),
      };

      if (_searchQuery.isNotEmpty) {
        queryParams["search"] = _searchQuery;
      }

      if (_selectedIndustryId != null) {
        queryParams["industry_id"] = _selectedIndustryId.toString();
      }

      final uri = Uri.parse("$_baseUrl/posts/user/$_userId")
          .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        final List<dynamic> dataList = jsonData["data"] ?? [];
        final pagination = jsonData["pagination"] ?? {};

        final List<Map<String, dynamic>> newPosts =
            dataList.map((e) => Map<String, dynamic>.from(e)).toList();

        setState(() {
          // Ab yahan posts clear nahi karna, kyunki upar clear kar chuke hain
          _posts.addAll(newPosts);

          _currentPage = pagination["current_page"] ?? page;
          _lastPage = pagination["last_page"] ?? 1;
        });
      } else {
        debugPrint("MyPosts fetch failed: ${response.body}");
      }
    } catch (e) {
      debugPrint("MyPosts fetch error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    if (_currentPage >= _lastPage) return;

    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _currentPage + 1;
      final headers = await _getHeaders();

      // final uri =
      //     Uri.parse("$_baseUrl/posts/user/$_userId?page=$nextPage");

      Map<String, String> queryParams = {
        "page": nextPage.toString(),
      };

      if (_searchQuery.isNotEmpty) {
        queryParams["search"] = _searchQuery;
      }

      if (_selectedIndustryId != null) {
        queryParams["industry_id"] = _selectedIndustryId.toString();
      }

      final uri = Uri.parse("$_baseUrl/posts/user/$_userId")
          .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        final List<dynamic> dataList = jsonData["data"] ?? [];
        final pagination = jsonData["pagination"] ?? {};

        final List<Map<String, dynamic>> newPosts =
            dataList.map((e) => Map<String, dynamic>.from(e)).toList();

        setState(() {
          _posts.addAll(newPosts);
          _currentPage = pagination["current_page"] ?? nextPage;
          _lastPage = pagination["last_page"] ?? _lastPage;
        });
      }
    } catch (e) {
      debugPrint("MyPosts load more error: $e");
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _onRefresh() async {
    await _fetchPosts(page: 1);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      // backgroundColor: const Color(0xFFF5F6FA),
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        // backgroundColor: Colors.white,
        backgroundColor: colorScheme.surface,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: _handleBack, // 🔥 Custom handler
        ),
        title: Text(
          "My Posts",
          style: TextStyle(
              color: colorScheme.onSurface, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                if (_debounce?.isActive ?? false) _debounce!.cancel();

                _debounce = Timer(const Duration(milliseconds: 500), () {
                  setState(() {
                    _searchQuery = value;
                  });
                  _fetchPosts(page: 1);
                });
              },
              decoration: InputDecoration(
                hintText: "Search posts...",
                hintStyle: TextStyle(
                    color: colorScheme.onSurface
                        .withOpacity(0.6)), // 👈 was Colors.grey
                filled: true,
                fillColor: colorScheme.surface,
                prefixIcon: Icon(Icons.search,
                    color: colorScheme.onSurface.withOpacity(0.6)),

                // 🔥 CLEAR BUTTON
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close,
                            color: colorScheme.onSurface.withOpacity(0.6)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = "";
                            _selectedIndustryId = null;
                          });
                          _fetchPosts(page: 1);
                        },
                      )
                    : null,

                // filled: true,
                // fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                // border: OutlineInputBorder(
                //   borderRadius: BorderRadius.circular(12),
                //   borderSide: BorderSide(
                //       color: colorScheme.onSurface.withOpacity(0.12),
                //       width: 0.2,
                //       ),

                // ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: colorScheme.primary,
                    width: 0.2,
                  ), // 👈 was Colors.grey.shade300
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: colorScheme.primary,
                    width: 0.8,
                  ), // 👈 was Colors.blueAccent
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading && _posts.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _posts.isEmpty
                    ? const Center(
                        child: Text(
                          "No posts found",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _onRefresh,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _posts.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _posts.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 18),
                                child:
                                    Center(child: CircularProgressIndicator()),
                              );
                            }

                            return MyPostCard(
                              key: ValueKey(_posts[index]["id"]),
                              post: _posts[index],
                              onPostUpdated: (postId, updatedPost) {
                                final postIndex =
                                    _posts.indexWhere((p) => p["id"] == postId);
                                if (postIndex != -1) {
                                  setState(() {
                                    _posts[postIndex] = updatedPost;
                                  });
                                }
                              },
                              onIndustryTap: (industryId) {
                                setState(() {
                                  _selectedIndustryId = industryId;
                                  _searchQuery = "";
                                  _searchController.clear();
                                });
                                _fetchPosts(page: 1);
                              },
                              // onPostDeleted: (postId) {
                              //   setState(() {
                              //     _posts.removeWhere((p) => p["id"] == postId);
                              //   });
                              // },
                              onPostDeleted: (postId) {
                                setState(() {
                                  _posts.removeWhere((p) => p["id"] == postId);
                                });

                                if (_posts.isEmpty) {
                                  _fetchPosts(page: 1);
                                }
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
