import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'post_card.dart';
import 'post_creation_page.dart';
import 'my_posts_page.dart';

class BusinessFeedPage extends StatefulWidget {
  final String industryType;
  final int? selectedPostId;
  const BusinessFeedPage({
    super.key,
    this.industryType = 'All',
    this.selectedPostId,
  });

  @override
  State<BusinessFeedPage> createState() => _BusinessFeedPageState();
}

class _BusinessFeedPageState extends State<BusinessFeedPage> {
  static const String _baseUrl = AppConfig.apiBaseUrl;

  String _searchQuery = "";
  int? _selectedIndustryId;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  final List<Map<String, dynamic>> _posts = [];

  int _currentPage = 1;
  int _lastPage = 1;
  bool _isLoading = false;
  bool _isLoadingMore = false;

  final ScrollController _scrollController = ScrollController();

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
    _fetchPosts(page: 1);
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 250) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchPosts({required int page}) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    if (page == 1) {
      setState(() => _posts.clear());
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

      final uri = Uri.parse("$_baseUrl/posts/list")
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

          if (widget.selectedPostId != null && page == 1) {
            final index =
                _posts.indexWhere((p) => p["id"] == widget.selectedPostId);
            if (index != -1) {
              final selectedPost = _posts.removeAt(index);
              _posts.insert(0, selectedPost);
            }
          }

          _currentPage = pagination["current_page"] ?? page;
          _lastPage = pagination["last_page"] ?? 1;
        });
      } else {
        debugPrint("Fetch posts failed: ${response.body}");
      }
    } catch (e) {
      debugPrint("Fetch posts exception: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _handleBack() {
    if (_selectedIndustryId != null || _searchQuery.isNotEmpty) {
      setState(() {
        _selectedIndustryId = null;
        _searchQuery = "";
        _searchController.clear();
      });
      _fetchPosts(page: 1);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    if (_currentPage >= _lastPage) return;

    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _currentPage + 1;

      final headers = await _getHeaders();
      final uri = Uri.parse("$_baseUrl/posts/list?page=$nextPage");

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
      } else {
        debugPrint("Load more failed: ${response.body}");
      }
    } catch (e) {
      debugPrint("Load more exception: $e");
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
      backgroundColor: colorScheme.surface, // 👈 was const Color(0xFFF5F6FA)
      appBar: AppBar(
        backgroundColor: colorScheme.surface, // 👈 was Colors.white
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: colorScheme.onSurface), // 👈 was Colors.black87
          onPressed: _handleBack,
        ),
        title: Text(
          "Business Feed",
          style: TextStyle(
            color: colorScheme.onSurface, // 👈 was Colors.black87
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.menu,
                color: colorScheme.onSurface), // 👈 was Colors.black87
            onSelected: (value) async {
              if (value == "my_posts") {
                // Navigator.push(
                //   context,
                //   MaterialPageRoute(builder: (_) => const MyPostsPage()),
                // );

                final shouldRefresh = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyPostsPage()),
                );

                if (shouldRefresh == true) {
                  _fetchPosts(page: 1);
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: "my_posts",
                child: Text("My Posts"),
              ),
            ],
          ),
        ],
      ),
      // floatingActionButton: FloatingActionButton(
      //   backgroundColor: colorScheme.primary, // 👈 was Colors.blueAccent
      //   onPressed: () {
      //     Navigator.push(
      //       context,
      //       MaterialPageRoute(builder: (_) => PostCreationPage()),
      //     );
      //   },
      //   child: Icon(Icons.add,
      //       color: colorScheme.onPrimary), // 👈 was Colors.white
      // ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: colorScheme.primary,
        onPressed: () async {
          // await Navigator.push(
          //   context,
          //   MaterialPageRoute(builder: (_) => PostCreationPage()),
          // );

          // // 🔄 Page par wapas aate hi latest posts fetch
          // _fetchPosts(page: 1);

          final createdPostId = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PostCreationPage()),
          );

          await _fetchPosts(page: 1);

          if (createdPostId != null) {
            final index = _posts.indexWhere((p) => p["id"] == createdPostId);

            if (index > 0) {
              final newPost = _posts.removeAt(index);
              _posts.insert(0, newPost);
              setState(() {});
            }
          }
        },
        child: Icon(Icons.add, color: colorScheme.onPrimary),
      ),
      body: Column(
        children: [
          // 🔎 SEARCH BAR
          Padding(
            // padding: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.only(
              left: 10,
              right: 10,
              top: 10,
            ),
            child: TextField(
              controller: _searchController,
              // style: TextStyle(
              //     color: colorScheme.onSurface), // 👈 was Colors.black87
              decoration: InputDecoration(
                hintText: "Search posts...",
                hintStyle: TextStyle(
                    color: colorScheme.onSurface
                        .withOpacity(0.6)), // 👈 was Colors.grey
                filled: true,
                fillColor: colorScheme.surface, // 👈 was Colors.white
                prefixIcon: Icon(Icons.search,
                    color: colorScheme.onSurface
                        .withOpacity(0.6)), // 👈 was Colors.grey
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close,
                            color: colorScheme.onSurface
                                .withOpacity(0.6)), // 👈 was Colors.grey
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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              onChanged: (value) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 500), () {
                  setState(() {
                    _searchQuery = value;
                    _selectedIndustryId = null;
                  });
                  _fetchPosts(page: 1);
                });
              },
            ),
          ),

          // 📃 POSTS LIST
          Expanded(
            child: _isLoading && _posts.isEmpty
                ? Center(child: CircularProgressIndicator())
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
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final post = _posts[index];

                        return PostCard(
                          post: post,
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
