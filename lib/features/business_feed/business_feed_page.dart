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

  // POSTS LIST
  final List<Map<String, dynamic>> _posts = [];

  // PAGINATION
  int _currentPage = 1;
  int _lastPage = 1;
  bool _isLoading = false;
  bool _isLoadingMore = false;

  final ScrollController _scrollController = ScrollController();

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
    super.dispose();
  }

  // ================= FETCH POSTS =================
  // Future<void> _fetchPosts({required int page}) async {
  //   if (_isLoading) return;

  //   setState(() => _isLoading = true);

  //   try {
  //     final headers = await _getHeaders();

  //     // final uri = Uri.parse("$_baseUrl/posts/list?page=$page");
  //     Map<String, String> queryParams = {
  //       "page": page.toString(),
  //     };

  //     if (_searchQuery.isNotEmpty) {
  //       queryParams["search"] = _searchQuery;
  //     }

  //     if (_selectedIndustryId != null) {
  //       queryParams["industry_id"] = _selectedIndustryId.toString();
  //     }

  //     final uri = Uri.parse("$_baseUrl/posts/list")
  //         .replace(queryParameters: queryParams);

  //     final response = await http.get(uri, headers: headers);

  //     if (response.statusCode == 200) {
  //       final jsonData = jsonDecode(response.body);

  //       final List<dynamic> dataList = jsonData["data"] ?? [];
  //       final pagination = jsonData["pagination"] ?? {};

  //       final List<Map<String, dynamic>> newPosts =
  //           dataList.map((e) => Map<String, dynamic>.from(e)).toList();

  //       setState(() {
  //         _posts.clear();

  //         // 👇 If selectedPostId exists, bring it to top
  //         if (widget.selectedPostId != null) {
  //           final index =
  //               newPosts.indexWhere((p) => p["id"] == widget.selectedPostId);

  //           if (index != -1) {
  //             final selectedPost = newPosts.removeAt(index);
  //             newPosts.insert(0, selectedPost);
  //           }
  //         }

  //         _posts.addAll(newPosts);

  //         _currentPage = pagination["current_page"] ?? 1;
  //         _lastPage = pagination["last_page"] ?? 1;
  //       });
  //     } else {
  //       debugPrint("Fetch posts failed: ${response.body}");
  //     }
  //   } catch (e) {
  //     debugPrint("Fetch posts exception: $e");
  //   } finally {
  //     setState(() => _isLoading = false);
  //   }
  // }

  Future<void> _fetchPosts({required int page}) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    // 🔥 Naya: Agar page 1 hai to turant posts clear kar do (loading indicator dikhane ke liye)
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
          // Ab yahan posts clear nahi karna, kyunki upar clear kar chuke hain
          // Agar page > 1 hai to previous posts already maujood hain, unme add karo
          if (page == 1) {
            // Refresh case: already cleared, bas newPosts add karo
            _posts.addAll(newPosts);
          } else {
            // Load more case: previous posts mein add karo
            _posts.addAll(newPosts);
          }

          // selectedPostId wala logic abhi bhi yahan rahega
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
        // Agar fail ho jaye to kuch error message dikha sakte ho
      }
    } catch (e) {
      debugPrint("Fetch posts exception: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // BusinessFeedPage ke andar, _BusinessFeedPageState class mein
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
      Navigator.pop(context); // Actual back navigation
    }
  }

  // ================= LOAD MORE =================
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

  // ================= REFRESH =================
  Future<void> _onRefresh() async {
    await _fetchPosts(page: 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: _handleBack,
        ),
        title: const Text(
          "Business Feed",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu, color: Colors.black87),
            onSelected: (value) {
              if (value == "my_posts") {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MyPostsPage(),
                  ),
                );
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PostCreationPage()),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // 🔎 SEARCH BAR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                hintText: "Search posts...",
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
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
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blueAccent),
                ),
              ),
              onChanged: (value) {
                if (_debounce?.isActive ?? false) _debounce!.cancel();

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
                ? const Center(child: CircularProgressIndicator())
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

                          // 👇 NEW CALLBACK
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
