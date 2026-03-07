import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:gridcard/core/services/user_storage_service.dart';
import './post_detailed_page.dart';
import './report_page.dart';
import '../business_feed/business_feed_page.dart';
import './industry_icon_mapper.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/widgets/top_alert.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import './full_screen_image_viewer.dart';

class HomePostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final Function(int, Map<String, dynamic>) onPostUpdated;

  const HomePostCard({
    super.key,
    required this.post,
    required this.onPostUpdated,
  });

  @override
  State<HomePostCard> createState() => _HomePostCardState();
}

class _HomePostCardState extends State<HomePostCard> {
  // static const String _baseUrl =
  //     "https://byndai.in/";

  static const String _baseUrl = AppConfig.imageBaseUrl;
  // static const String _baseUrl = AppConfig.imageBaseUrl;

  final bool _expandedDescription = false;
  final bool _showDebugInfo = false;
  bool _isLikeAnimating = false;
  bool _isDislikeAnimating = false;
  bool _isSaveAnimating = false;

  final PageController _imageController = PageController();

  // =========================
  // STATE VARIABLES FOR REACTIONS
  // =========================
  late Map<String, dynamic> _postData;
  late String _myReaction;
  late int _likesCount;
  late int _dislikesCount;
  late bool _isSaved;
  late int _savesCount;

  @override
  void initState() {
    super.initState();
    _postData = Map<String, dynamic>.from(widget.post);
    _myReaction = _postData["my"]?["reaction"] ?? "none";
    _likesCount = _postData["counts"]?["likes"] ?? 0;
    _dislikesCount = _postData["counts"]?["dislikes"] ?? 0;
    _isSaved = _postData["my"]?["saved"] ?? false;
    _savesCount = _postData["counts"]?["saves"] ?? 0;

    debugPrint("amit post data12: ${widget.post}");
  }

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }

  // =========================
  // TIME FORMAT
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
  // SHOW SNACKBAR
  // =========================
  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    final isError = backgroundColor == Colors.red ||
        backgroundColor == Theme.of(context).colorScheme.error;
    final isSuccess = backgroundColor == Colors.green;

    TopAlert.show(context, message, isError: isError, isSuccess: isSuccess);
  }

  // =========================
  // SAVE/UNSAVE API CALL
  // =========================
  Future<void> _toggleSave() async {
    // Store previous state
    final bool previousSaved = _isSaved;
    final int previousSavesCount = _savesCount;

    // Optimistic UI update
    final bool newSaved = !_isSaved;
    int newSavesCount = _savesCount;

    if (newSaved) {
      newSavesCount++;
    } else {
      newSavesCount--;
    }

    // Immediate UI update
    setState(() {
      _isSaved = newSaved;
      _savesCount = newSavesCount;
      _isSaveAnimating = true;
    });

    // Remove animation after delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isSaveAnimating = false;
        });
      }
    });

    // Show snackbar message
    final message =
        newSaved ? "Post saved to playlist" : "Post removed from playlist";
    final color = newSaved ? Colors.green : Theme.of(context).colorScheme.error;
    _showSnackBar(message, color);

    // Update postData
    final updatedPostData = Map<String, dynamic>.from(_postData);
    updatedPostData["my"] = {
      "reaction": _myReaction,
      "saved": newSaved,
    };

    updatedPostData["counts"] = {
      ..._postData["counts"] ?? {},
      "saves": newSavesCount,
    };

    // Call API in background
    _callSaveApi(updatedPostData, previousSaved, previousSavesCount);
  }

  Future<void> _callSaveApi(
    Map<String, dynamic> updatedPostData,
    bool previousSaved,
    int previousSavesCount,
  ) async {
    try {
      final token = await UserStorageService().getToken();
      if (token == null) return;

      final postId = _postData["id"];

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final body = {
        "post_id": postId,
      };

      debugPrint("Calling save API for post: $postId");

      final response = await http.post(
        Uri.parse("$_baseUrl/api/posts/save"),
        headers: headers,
        body: jsonEncode(body),
      );

      debugPrint("Save API Response: ${response.statusCode}");
      debugPrint("Save API Body: ${response.body}");

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData["status"] == true) {
          // API success - update parent with final data
          widget.onPostUpdated(postId, updatedPostData);
          debugPrint("Save API Success: ${responseData["message"]}");
        } else {
          // API failed, revert to original state
          debugPrint("Save API Failed: ${responseData["message"]}");
          _revertSaveState(previousSaved, previousSavesCount);
        }
      } else {
        // API failed, revert to original state
        debugPrint("Save API Error: ${response.statusCode}");
        _revertSaveState(previousSaved, previousSavesCount);
      }
    } catch (e) {
      debugPrint("Save API error: $e");
      // API failed, revert to original state
      _revertSaveState(previousSaved, previousSavesCount);
    }
  }

  void _revertSaveState(bool previousSaved, int previousSavesCount) {
    if (mounted) {
      setState(() {
        _isSaved = previousSaved;
        _savesCount = previousSavesCount;

        // Revert postData
        _postData["my"] = {
          "reaction": _myReaction,
          "saved": previousSaved,
        };

        _postData["counts"] = {
          ..._postData["counts"] ?? {},
          "saves": previousSavesCount,
        };
      });

      // Show error snackbar
      _showSnackBar(
          "Failed to update save status", Theme.of(context).colorScheme.error);

      // Notify parent to revert as well
      widget.onPostUpdated(_postData["id"], _postData);
    }
  }

  void _openFullScreenImages(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImageViewer(
          images: _images,
          initialIndex: initialIndex,
          baseUrl: _baseUrl,
        ),
      ),
    );
  }

  // =========================
  // REACTION API CALL
  // =========================
  Future<void> _sendReaction(String reactionType) async {
    final String previousReaction = _myReaction;

    int newLikes = _likesCount;
    int newDislikes = _dislikesCount;

    String newReaction = reactionType;

    if (previousReaction == reactionType) {
      // remove reaction
      newReaction = "none";
      if (reactionType == "like") newLikes--;
      if (reactionType == "dislike") newDislikes--;
    } else {
      // remove previous
      if (previousReaction == "like") newLikes--;
      if (previousReaction == "dislike") newDislikes--;

      // add new
      if (reactionType == "like") newLikes++;
      if (reactionType == "dislike") newDislikes++;

      newReaction = reactionType;
    }

    setState(() {
      _myReaction = newReaction;
      _likesCount = newLikes;
      _dislikesCount = newDislikes;

      if (reactionType == "like") _isLikeAnimating = true;
      if (reactionType == "dislike") _isDislikeAnimating = true;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _isLikeAnimating = false;
        _isDislikeAnimating = false;
      });
    });

    final updatedPostData = Map<String, dynamic>.from(_postData);
    updatedPostData["my"] = {
      "reaction": newReaction,
      "saved": _isSaved,
    };

    updatedPostData["counts"] = {
      ..._postData["counts"] ?? {},
      "likes": newLikes,
      "dislikes": newDislikes,
    };

    // ✅ IMPORTANT: API ko final reaction bhejo (like/dislike/none)
    _callReactionApi(newReaction, updatedPostData);
  }

  Future<void> _callReactionApi(
      String finalReaction, Map<String, dynamic> updatedPostData) async {
    try {
      final token = await UserStorageService().getToken();
      if (token == null) return;

      final postId = _postData["id"];

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final body = {
        "post_id": postId,
        "reaction_type": finalReaction, // like / dislike / none
        "reaction": finalReaction,
      };

      final response = await http.post(
        Uri.parse("$_baseUrl/api/posts/react"),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData["status"] == true) {
          widget.onPostUpdated(postId, updatedPostData);
        } else {
          _revertToOriginalState();
        }
      } else {
        _revertToOriginalState();
      }
    } catch (e) {
      debugPrint("Reaction API error: $e");
      _revertToOriginalState();
    }
  }

  void _revertToOriginalState() {
    if (mounted) {
      setState(() {
        _myReaction = widget.post["my"]?["reaction"] ?? "none";
        _likesCount = widget.post["counts"]?["likes"] ?? 0;
        _dislikesCount = widget.post["counts"]?["dislikes"] ?? 0;
        _isSaved = widget.post["my"]?["saved"] ?? false;
        _savesCount = widget.post["counts"]?["saves"] ?? 0;

        // Also update _postData
        _postData = Map<String, dynamic>.from(widget.post);
      });

      // Notify parent to revert as well
      widget.onPostUpdated(_postData["id"], widget.post);
    }
  }

  // =========================
  // NEW HELPER METHODS FOR DESCRIPTION
  // =========================
  String _getDisplayDescription(String desc) {
    if (_expandedDescription) return desc;

    final int charLimit = _images.isEmpty ? 550 : 25;
    if (desc.length <= charLimit) return desc;
    return '${desc.substring(0, charLimit)}...';
  }

  bool _shouldShowReadMore(String desc) {
    final int charLimit = _images.isEmpty ? 550 : 25;
    return desc.length > charLimit;
  }

  // =========================
  // BUILD
  // =========================
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final user = _postData["user"] ?? {};
    final fname = (user["fname"] ?? "User").toString();

    final profilePicPath = user["profile_pic"];
    final profilePicUrl =
        profilePicPath != null ? "$_baseUrl/storage/$profilePicPath" : null;

    final title = (_postData["title"] ?? "").toString();
    final description = (_postData["description"] ?? "").toString();

    final updatedAt = _formatTime(_postData["updated_at"]?.toString());

    final readMoreColor = isDark
        ? colorScheme.primary
        : const Color.fromARGB(255, 45, 47, 190); // original

    return SizedBox(
      height: 640,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        // decoration: BoxDecoration(
        //   color: isDark
        //       ? colorScheme.surfaceContainerHighest.withOpacity(0.5)
        //       : const Color.fromARGB(255, 170, 169, 248),
        //   borderRadius: BorderRadius.circular(20),
        //   border: isDark
        //       ? null
        //       : Border.all(color: colorScheme.primary.withOpacity(0.1)),
        //   boxShadow: isDark
        //       ? []
        //       : [
        //           BoxShadow(
        //             color: Colors.black.withOpacity(0.05),
        //             blurRadius: 10,
        //             offset: const Offset(0, 4),
        //           ),
        //         ],
        // ),

        decoration: BoxDecoration(
          color: isDark
              ? colorScheme.surfaceContainerHighest.withOpacity(0.5)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          // border: isDark
          //     ? null
          //     : Border.all(
          //         color: Colors.black.withOpacity(0.25),
          //         width: 1.2,
          //       ),
          border: isDark
              ? null
              : Border.all(
                  color: colorScheme.primary,
                  width: 1,
                ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),

        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// 👇 CARD CLICK AREA
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BusinessFeedPage(
                          selectedPostId: _postData["id"],
                        ),
                      ),
                    );
                  },
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// HEADER
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              // backgroundColor: colorScheme.surfaceVariant,
                              backgroundColor: isDark
                                  ? colorScheme.surfaceVariant
                                  : Colors.grey.shade200,
                              child: ClipOval(
                                child: (profilePicUrl != null &&
                                        profilePicUrl.isNotEmpty)
                                    ? Image.network(
                                        profilePicUrl,
                                        width: 36,
                                        height: 36,
                                        fit: BoxFit.cover,
                                      )
                                    : Icon(
                                        Icons.person,
                                        size: 22,
                                        color: colorScheme.onSurface
                                            .withOpacity(0.6),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fname,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    updatedAt,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurface
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            CircleAvatar(
                              radius: 14,
                              // backgroundColor: colorScheme.surfaceVariant,
                              backgroundColor: isDark
                                  ? colorScheme.surfaceVariant
                                  : Colors.grey.shade200,
                              child: Icon(
                                IndustryIconMapper.getIcon(
                                    _postData["industry_icon"]),
                                size: 16,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        /// TITLE
                        if (title.isNotEmpty)
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurface,
                            ),
                          ),

                        const SizedBox(height: 8),

                        /// DESCRIPTION
                        if (description.isNotEmpty)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.star,
                                  size: 18, color: colorScheme.primary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getDisplayDescription(description),
                                      style: TextStyle(
                                        fontSize: 14,
                                        height: 1.35,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    if (_shouldShowReadMore(description))
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => BusinessFeedPage(
                                                selectedPostId: _postData["id"],
                                              ),
                                            ),
                                          );
                                        },
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(
                                            "...Read more",
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: readMoreColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                        /// IMAGES
                        if (_images.isNotEmpty) ...[
                          const SizedBox(height: 14),

                          /// 👇 IMAGE CLICK DISABLED
                          GestureDetector(
                            onTap: () {},
                            child: _buildImageCarousel(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // const Divider(),

              /// FOOTER (no navigation)...
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // =========================
  // IMAGE CAROUSEL
  // =========================

  Widget _buildImageCarousel() {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 264,
      child: PageView.builder(
        controller: _imageController,
        itemCount: _images.length,
        itemBuilder: (context, index) {
          final media = _images[index];
          final url = _fullUrl(media["media_url"] ?? "");

          return Padding(
            padding: const EdgeInsets.all(4),
            child: GestureDetector(
              onTap: () {
                _openFullScreenImages(index);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  color: colorScheme.surfaceVariant, // background fill
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    errorWidget: (context, url, error) {
                      return Center(
                        child: Text(
                          "Image load failed",
                          style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // =========================
  // SHOW REPORT DIALOG
  // =========================
  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Report Post"),
          content: const Text("Do you want to report this post?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Report page open करें
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReportPage(
                      postId: _postData["id"],
                    ),
                  ),
                );
              },
              child: const Text("Report"),
            ),
          ],
        );
      },
    );
  }

  // =========================
  // FOOTER
  // =========================

  Widget _buildFooter() {
    final colorScheme = Theme.of(context).colorScheme;
    final comments = _postData["counts"]?["comments"] ?? 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // LIKE
        _footerReactionBtn(
          icon: Icons.thumb_up_alt_outlined,
          label: _likesCount.toString(),
          active: _myReaction == "like",
          isAnimating: _isLikeAnimating,
          onTap: () => _sendReaction("like"),
        ),

        // DISLIKE
        _footerReactionBtn(
          icon: Icons.thumb_down_alt_outlined,
          label: _dislikesCount.toString(),
          active: _myReaction == "dislike",
          isAnimating: _isDislikeAnimating,
          onTap: () => _sendReaction("dislike"),
        ),

        // COMMENT
        _footerBtn(
          icon: Icons.mode_comment_outlined,
          label: comments.toString(),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PostDetailsPage(
                  postId: _postData["id"],
                  initialPostData: _postData,
                ),
              ),
            );
          },
        ),

        // SAVE
        _footerSaveBtn(
          icon: _isSaved ? Icons.bookmark : Icons.bookmark_border,
          label: "",
          active: _isSaved,
          isAnimating: _isSaveAnimating,
          onTap: _toggleSave,
        ),

        // REPORT
        _footerBtn(
          icon: Icons.flag_outlined,
          label: "",
          onTap: _showReportDialog,
        ),
      ],
    );
  }

  Widget _footerBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    // final colorScheme = Theme.of(context).colorScheme;
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: active
                  ? colorScheme.primary
                  : colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active
                    ? colorScheme.primary
                    : colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footerReactionBtn({
    required IconData icon,
    required String label,
    required bool active,
    required bool isAnimating,
    required VoidCallback onTap,
  }) {
    // final colorScheme = Theme.of(context).colorScheme;
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isAnimating
              ? colorScheme.primary.withOpacity(0.1)
              : Colors.transparent,
          // color: isAnimating
          //     ? colorScheme.primary.withOpacity(0.1)
          //     : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                key: ValueKey<bool>(active),
                size: 18,
                color: active
                    ? colorScheme.primary
                    : colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active
                    ? colorScheme.primary
                    : colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footerSaveBtn({
    required IconData icon,
    required String label,
    required bool active,
    required bool isAnimating,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    // final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isAnimating
              ? colorScheme.secondary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                key: ValueKey<bool>(active),
                size: 18,
                color: active
                    ? colorScheme.secondary
                    : colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active
                    ? colorScheme.secondary
                    : colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
