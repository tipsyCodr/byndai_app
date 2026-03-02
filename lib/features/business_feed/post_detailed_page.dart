import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:gridcard/config/app_config.dart';

class PostDetailsPage extends StatefulWidget {
  final int postId;
  final Map<String, dynamic>? initialPostData;

  const PostDetailsPage({
    super.key,
    required this.postId,
    this.initialPostData,
  });

  @override
  State<PostDetailsPage> createState() => _PostDetailsPageState();
}

class _PostDetailsPageState extends State<PostDetailsPage> {
  // static const String _baseUrl =
  //     "https://byndai.in/";

  static const String _baseUrl = AppConfig.imageBaseUrl;

  // =========================
  // STATE VARIABLES
  // =========================
  late Map<String, dynamic> _postData;
  bool _isLoading = true;
  bool _isLoadingComments = false;
  bool _isPostingComment = false;
  bool _expandedDescription = false;

  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final PageController _imageController = PageController();

  // Comments
  final List<Map<String, dynamic>> _comments = [];
  final List<Map<String, dynamic>> _replies = [];

  // Reply Modal State
  int? _replyingToCommentId;
  String _replyingToUserName = "";
  String _replyingToCommentText = "";
  bool _showReplyModal = false;

  @override
  void initState() {
    super.initState();
    _postData = widget.initialPostData ?? {};

    if (widget.initialPostData != null && widget.initialPostData!.isNotEmpty) {
      // If we have initial data, use it and fetch comments
      _isLoading = false;
      _fetchComments();
    } else {
      // Otherwise fetch post data first
      _fetchPostDetails();
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  // =========================
  // HEADERS FOR API
  // =========================
  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // =========================
  // FETCH POST DETAILS
  // =========================
  Future<void> _fetchPostDetails() async {
    setState(() => _isLoading = true);

    try {
      final headers = await _getHeaders();
      final uri = Uri.parse("$_baseUrl/posts/list?page=1");

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        if (jsonData["status"] == true) {
          final List<dynamic> postsList = jsonData["data"] ?? [];

          // Find our specific post
          final post = postsList.firstWhere(
            (p) => p["id"] == widget.postId,
            orElse: () => null,
          );

          if (post != null) {
            setState(() {
              _postData = Map<String, dynamic>.from(post);
            });

            // Now fetch comments
            _fetchComments();
          }
        }
      }
    } catch (e) {
      debugPrint("Fetch post details error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // =========================
  // FETCH COMMENTS
  // =========================
  Future<void> _fetchComments() async {
    if (_isLoadingComments) return;

    setState(() => _isLoadingComments = true);

    try {
      final headers = await _getHeaders();
      final uri =
          Uri.parse("$_baseUrl/api/posts/comments_list/${widget.postId}");

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        if (jsonData["status"] == true) {
          final List<dynamic> commentsList = jsonData["data"] ?? [];

          // Separate main comments and replies
          final List<Map<String, dynamic>> mainComments = [];
          final List<Map<String, dynamic>> allReplies = [];

          for (var comment in commentsList) {
            final commentMap = Map<String, dynamic>.from(comment);

            if (commentMap["parent_id"] == null) {
              mainComments.add(commentMap);
            } else {
              allReplies.add(commentMap);
            }
          }

          // Count replies for each comment
          for (var comment in mainComments) {
            final commentId = comment["id"];
            final replyCount = allReplies
                .where((reply) => reply["parent_id"] == commentId)
                .length;
            comment["reply_count"] = replyCount;
          }

          setState(() {
            _comments.clear();
            _comments.addAll(mainComments);
            _replies.clear();
            _replies.addAll(allReplies);
          });
        }
      }
    } catch (e) {
      debugPrint("Fetch comments error: $e");
    } finally {
      setState(() => _isLoadingComments = false);
    }
  }

  // =========================
  // POST COMMENT
  // =========================
  Future<void> _postComment() async {
    if (_isPostingComment) return;
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isPostingComment = true);

    try {
      final headers = await _getHeaders();
      final uri = Uri.parse("$_baseUrl/api/posts/comment");

      final body = {
        "post_id": widget.postId,
        "comment": _commentController.text.trim(),
        if (_replyingToCommentId != null) "parent_id": _replyingToCommentId,
      };

      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        if (jsonData["status"] == true) {
          // Clear and reset
          _commentController.clear();
          _closeReplyModal();

          // Refresh comments
          _fetchComments();

          // Scroll to top
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );

          // Show success snackbar
          _showSnackBar(
            _replyingToCommentId != null ? "Reply posted!" : "Comment posted!",
            Colors.green,
          );
        }
      }
    } catch (e) {
      debugPrint("Post comment error: $e");
      _showSnackBar("Failed to post comment", Colors.red);
    } finally {
      setState(() => _isPostingComment = false);
    }
  }

  // =========================
  // REPLY FUNCTIONS
  // =========================
  void _openReplyModal(int commentId, String userName, String commentText) {
    setState(() {
      _replyingToCommentId = commentId;
      _replyingToUserName = userName;
      _replyingToCommentText = commentText;
      _showReplyModal = true;
    });

    // Focus on comment field
    Future.delayed(const Duration(milliseconds: 100), () {
      FocusScope.of(context).requestFocus(FocusNode());
    });
  }

  void _closeReplyModal() {
    setState(() {
      _showReplyModal = false;
      _replyingToCommentId = null;
      _replyingToUserName = "";
      _replyingToCommentText = "";
    });
  }

  // =========================
  // SHOW REPLIES FUNCTION
  // =========================
  void _showRepliesModal(int commentId, String userName) {
    final replies =
        _replies.where((reply) => reply["parent_id"] == commentId).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return RepliesModal(
          userName: userName,
          replies: replies,
          onReplyPressed: () {
            Navigator.pop(context);
            final comment = _comments.firstWhere(
              (c) => c["id"] == commentId,
              orElse: () => {},
            );
            if (comment.isNotEmpty) {
              _openReplyModal(
                commentId,
                comment["user"]?["fname"] ?? "User",
                comment["comment"] ?? "",
              );
            }
          },
        );
      },
    );
  }

  // =========================
  // SHOW SNACKBAR
  // =========================
  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // =========================
  // FORMAT TIME
  // =========================
  String _formatTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return "";
    try {
      final dt = DateTime.parse(dateTimeStr.replaceAll(" ", "T"));
      return DateFormat("hh:mm a").format(dt);
    } catch (_) {
      return "";
    }
  }

  String _formatHumanTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return "";

    try {
      final dt = DateTime.parse(dateTimeStr.replaceAll(" ", "T"));
      final now = DateTime.now();
      final difference = now.difference(dt);

      if (difference.inSeconds < 60) return "Just now";
      if (difference.inMinutes < 60) return "${difference.inMinutes}m ago";
      if (difference.inHours < 24) return "${difference.inHours}h ago";
      if (difference.inDays < 30) return "${difference.inDays}d ago";

      return "${difference.inDays ~/ 30}mo ago";
    } catch (_) {
      return "";
    }
  }

  // =========================
  // COMPLETE URL
  // =========================
  String _fullUrl(String? path) {
    if (path == null || path.isEmpty) return "";
    if (path.startsWith("http")) return path;

    String cleanPath = path;
    if (cleanPath.startsWith("/") && _baseUrl.endsWith("/")) {
      cleanPath = cleanPath.substring(1);
    }

    if (!_baseUrl.endsWith("/") && !cleanPath.startsWith("/")) {
      return "$_baseUrl/$cleanPath";
    }

    return "$_baseUrl$cleanPath";
  }

  // =========================
  // MEDIA LIST
  // =========================
  List<Map<String, dynamic>> get _media {
    final m = _postData["media"];
    if (m is List) {
      return m.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  List<Map<String, dynamic>> get _images {
    return _media.where((m) => m["media_type"] == "image").toList();
  }

  // =========================
  // BUILD
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title:
            const Text("Post Details", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // =========================
                    // POST CONTENT SECTION
                    // =========================
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        child: Column(
                          children: [
                            // Post Card
                            _buildPostCard(),

                            // Comments Section Header
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  const Text(
                                    "Comments",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "(${_comments.length})",
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Comments List
                            if (_isLoadingComments)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child:
                                    Center(child: CircularProgressIndicator()),
                              )
                            else if (_comments.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 40),
                                child: Text(
                                  "No comments yet. Be the first to comment!",
                                  style: TextStyle(color: Colors.white60),
                                ),
                              )
                            else
                              ..._comments
                                  .map((comment) => _buildCommentItem(comment)),

                            const SizedBox(
                                height: 100), // Space for bottom input
                          ],
                        ),
                      ),
                    ),

                    // =========================
                    // COMMENT INPUT SECTION
                    // =========================
                    _buildCommentInput(),
                  ],
                ),

          // Reply Modal
          if (_showReplyModal)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.black.withOpacity(0.8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),

                    // Modal Header
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.grey[900],
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: _closeReplyModal,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            "Replying to",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Original Comment
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.grey[900],
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.grey[700],
                            child: Text(
                              _replyingToUserName.isNotEmpty
                                  ? _replyingToUserName[0].toUpperCase()
                                  : "U",
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _replyingToUserName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _replyingToCommentText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Reply Input in Modal
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: "Write a reply...",
                                hintStyle:
                                    const TextStyle(color: Colors.white60),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.grey[800],
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                suffixIcon: _isPostingComment
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      )
                                    : null,
                              ),
                              maxLines: null,
                              keyboardType: TextInputType.multiline,
                              autofocus: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!_isPostingComment)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: IconButton(
                                icon:
                                    const Icon(Icons.send, color: Colors.white),
                                onPressed: _postComment,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // const Spacer(),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // =========================
  // POST CARD WIDGET
  // =========================
  Widget _buildPostCard() {
    final user = _postData["user"] ?? {};
    final fname = (user["fname"] ?? "User").toString();
    final title = (_postData["title"] ?? "").toString();
    final description = (_postData["description"] ?? "").toString();
    final updatedAt = _formatTime(_postData["updated_at"]?.toString());

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Header
            Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundImage: AssetImage("assets/images/default_user.png"),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fname,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        updatedAt,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const CircleAvatar(
                  radius: 14,
                  backgroundImage: AssetImage("assets/images/default_logo.png"),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Title
            if (title.isNotEmpty)
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),

            const SizedBox(height: 8),

            // Description
            if (description.isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.star, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _expandedDescription
                              ? description
                              : (description.length > 100
                                  ? "${description.substring(0, 100)}..."
                                  : description),
                          style: const TextStyle(fontSize: 14, height: 1.35),
                        ),
                        if (description.length > 100)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _expandedDescription = !_expandedDescription;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _expandedDescription
                                    ? "Read less"
                                    : "...Read more",
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

            // Images Carousel
            if (_images.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                "Images (${_images.length})",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _buildImageCarousel(),
            ],
          ],
        ),
      ),
    );
  }

  // =========================
  // IMAGE CAROUSEL
  // =========================
  Widget _buildImageCarousel() {
    return SizedBox(
      height: 210,
      child: PageView.builder(
        controller: _imageController,
        itemCount: _images.length,
        itemBuilder: (context, index) {
          final media = _images[index];
          final url = _fullUrl(media["media_url"] ?? "");

          return Padding(
            padding: const EdgeInsets.all(4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) {
                  debugPrint("IMAGE ERROR: $error");
                  debugPrint("URL: $url");

                  return Container(
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: const Text("Image load failed"),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // =========================
  // COMMENT ITEM WIDGET
  // =========================
  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final user = comment["user"] ?? {};
    final fname = (user["fname"] ?? "User").toString();
    final userName = (user["user_name"] ?? "").toString();
    final replyCount = comment["reply_count"] ?? 0;
    final commentId = comment["id"];
    final commentText = comment["comment"] ?? "";
    final createdAtHuman = comment["created_at_human"] ??
        _formatHumanTime(comment["created_at"]?.toString());

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Comment Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey[700],
                child: Text(
                  fname.isNotEmpty ? fname[0].toUpperCase() : "U",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fname,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "@$userName • $createdAtHuman",
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Comment Text
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 42), // Align with avatar
            child: Text(
              commentText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),

          // Reply Button
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 42),
            child: Row(
              children: [
                // Reply Icon Button (YouTube Style)
                InkWell(
                  onTap: () => _openReplyModal(commentId, fname, commentText),
                  child: Row(
                    children: [
                      Icon(
                        Icons.reply,
                        size: 18,
                        color: Colors.blue[400],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Reply",
                        style: TextStyle(
                          color: Colors.blue[400],
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // View Replies Button (if replies exist)
                if (replyCount > 0)
                  InkWell(
                    onTap: () => _showRepliesModal(commentId, fname),
                    child: Row(
                      children: [
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Colors.white60,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "$replyCount ${replyCount == 1 ? 'reply' : 'replies'}",
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // COMMENT INPUT WIDGET
  // =========================
  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey[900],
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Add a comment...",
                    hintStyle: const TextStyle(color: Colors.white60),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[800],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    suffixIcon: _isPostingComment
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                ),
              ),
              const SizedBox(width: 10),
              if (!_isPostingComment)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _postComment,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// =========================
// REPLIES MODAL WIDGET
// =========================
class RepliesModal extends StatelessWidget {
  final String userName;
  final List<Map<String, dynamic>> replies;
  final VoidCallback onReplyPressed;

  const RepliesModal({
    super.key,
    required this.userName,
    required this.replies,
    required this.onReplyPressed,
  });

  String _formatHumanTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return "";

    try {
      final dt = DateTime.parse(dateTimeStr.replaceAll(" ", "T"));
      final now = DateTime.now();
      final difference = now.difference(dt);

      if (difference.inSeconds < 60) return "Just now";
      if (difference.inMinutes < 60) return "${difference.inMinutes}m ago";
      if (difference.inHours < 24) return "${difference.inHours}h ago";
      if (difference.inDays < 30) return "${difference.inDays}d ago";

      return "${difference.inDays ~/ 30}mo ago";
    } catch (_) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Modal Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "Replies to $userName",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.reply, color: Colors.blue),
                      onPressed: onReplyPressed,
                    ),
                  ],
                ),
              ),

              // Replies List
              Expanded(
                child: replies.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.comment_outlined,
                              color: Colors.white60,
                              size: 50,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "No replies yet",
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: onReplyPressed,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Text(
                                "Be the first to reply",
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: replies.length,
                        itemBuilder: (context, index) {
                          final reply = replies[index];
                          final user = reply["user"] ?? {};
                          final fname = (user["fname"] ?? "User").toString();
                          final userName = (user["user_name"] ?? "").toString();
                          final replyText = reply["comment"] ?? "";
                          final createdAtHuman = reply["created_at_human"] ??
                              _formatHumanTime(reply["created_at"]?.toString());

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Reply Header
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: Colors.grey[700],
                                      child: Text(
                                        fname.isNotEmpty
                                            ? fname[0].toUpperCase()
                                            : "U",
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 12),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            fname,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "@$userName • $createdAtHuman",
                                            style: const TextStyle(
                                              color: Colors.white60,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                // Reply Text
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 36), // Align with avatar
                                  child: Text(
                                    replyText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
