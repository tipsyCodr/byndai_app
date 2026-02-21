import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:http/http.dart' as http;

import 'post_card.dart';
import 'post_creation_page.dart';

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
  Future<void> _fetchPosts({required int page}) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final headers = await _getHeaders();

      final uri = Uri.parse("$_baseUrl/posts/list?page=$page");

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        final List<dynamic> dataList = jsonData["data"] ?? [];
        final pagination = jsonData["pagination"] ?? {};

        final List<Map<String, dynamic>> newPosts =
            dataList.map((e) => Map<String, dynamic>.from(e)).toList();

        // setState(() {
        //   _posts.clear();
        //   _posts.addAll(newPosts);

        //   _currentPage = pagination["current_page"] ?? 1;
        //   _lastPage = pagination["last_page"] ?? 1;
        // });

        setState(() {
          _posts.clear();

          // 👇 If selectedPostId exists, bring it to top
          if (widget.selectedPostId != null) {
            final index =
                newPosts.indexWhere((p) => p["id"] == widget.selectedPostId);

            if (index != -1) {
              final selectedPost = newPosts.removeAt(index);
              newPosts.insert(0, selectedPost);
            }
          }

          _posts.addAll(newPosts);

          _currentPage = pagination["current_page"] ?? 1;
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        title:
            const Text("Business Feed", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _fetchPosts(page: 1),
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
      body: _isLoading && _posts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _onRefresh,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _posts.length + (_isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  // Loading more indicator
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
                      // Find and update the post in the list
                      final postIndex =
                          _posts.indexWhere((p) => p["id"] == postId);
                      if (postIndex != -1) {
                        setState(() {
                          _posts[postIndex] = updatedPost;
                        });
                      }
                    },
                  );
                },
              ),
            ),
    );
  }
}
