import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gridcard/widgets/top_alert.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:gridcard/core/services/user_storage_service.dart';
import './post_detailed_page.dart';
import './report_page.dart';
import './industry_icon_mapper.dart';
import 'package:gridcard/config/app_config.dart';
import 'full_screen_image_viewer.dart';

class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final Function(int industryId)? onIndustryTap;
  final Function(int, Map<String, dynamic>) onPostUpdated;

  const PostCard({
    super.key,
    required this.post,
    this.onIndustryTap,
    required this.onPostUpdated,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  // static const String _baseUrl =
  //     "https://powderblue-jellyfish-554082.hostingersite.com";

  static const String _baseUrl = AppConfig.imageBaseUrl;

  bool _expandedDescription = false;
  bool _showDebugInfo = false;
  bool _isLikeAnimating = false;
  bool _isDislikeAnimating = false;
  bool _isSaveAnimating = false;

  final PageController _imageController = PageController();

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
  }

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }

  String _formatTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return "";
    try {
      final dt = DateTime.parse(dateTimeStr.replaceAll(" ", "T"));
      return DateFormat("hh:mm a").format(dt);
    } catch (_) {
      return "";
    }
  }

  void _openPostDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailsPage(
          postId: _postData["id"],
          initialPostData: _postData,
        ),
      ),
    );
  }

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

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    final isError = backgroundColor == Colors.red;
    final isSuccess = backgroundColor == Colors.green;
    TopAlert.show(context, message, isError: isError, isSuccess: isSuccess);
  }

  // ========== SAVE API ==========
  Future<void> _toggleSave() async {
    final bool previousSaved = _isSaved;
    final int previousSavesCount = _savesCount;

    final bool newSaved = !_isSaved;
    int newSavesCount = _savesCount;
    if (newSaved) {
      newSavesCount++;
    } else {
      newSavesCount--;
    }

    setState(() {
      _isSaved = newSaved;
      _savesCount = newSavesCount;
      _isSaveAnimating = true;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _isSaveAnimating = false);
    });

    final message =
        newSaved ? "Post saved to playlist" : "Post removed from playlist";
    final color = newSaved ? Colors.green : Colors.orange;
    _showSnackBar(message, color);

    final updatedPostData = Map<String, dynamic>.from(_postData);
    updatedPostData["my"] = {
      "reaction": _myReaction,
      "saved": newSaved,
    };
    updatedPostData["counts"] = {
      ..._postData["counts"] ?? {},
      "saves": newSavesCount,
    };

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
      final body = {"post_id": postId};

      final response = await http.post(
        Uri.parse("$_baseUrl/api/posts/save"),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData["status"] == true) {
          widget.onPostUpdated(postId, updatedPostData);
        } else {
          _revertSaveState(previousSaved, previousSavesCount);
        }
      } else {
        _revertSaveState(previousSaved, previousSavesCount);
      }
    } catch (e) {
      debugPrint("Save API error: $e");
      _revertSaveState(previousSaved, previousSavesCount);
    }
  }

  void _revertSaveState(bool previousSaved, int previousSavesCount) {
    if (mounted) {
      setState(() {
        _isSaved = previousSaved;
        _savesCount = previousSavesCount;
        _postData["my"] = {"reaction": _myReaction, "saved": previousSaved};
        _postData["counts"] = {
          ..._postData["counts"] ?? {},
          "saves": previousSavesCount,
        };
      });
      _showSnackBar("Failed to update save status", Colors.red);
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

  // ========== REACTION API ==========
  Future<void> _sendReaction(String reactionType) async {
    final String previousReaction = _myReaction;
    int newLikes = _likesCount;
    int newDislikes = _dislikesCount;
    String newReaction = reactionType;

    if (previousReaction == reactionType) {
      newReaction = "none";
      if (reactionType == "like") newLikes--;
      if (reactionType == "dislike") newDislikes--;
    } else {
      if (previousReaction == "like") newLikes--;
      if (previousReaction == "dislike") newDislikes--;
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
      if (mounted)
        setState(() {
          _isLikeAnimating = false;
          _isDislikeAnimating = false;
        });
    });

    final updatedPostData = Map<String, dynamic>.from(_postData);
    updatedPostData["my"] = {"reaction": newReaction, "saved": _isSaved};
    updatedPostData["counts"] = {
      ..._postData["counts"] ?? {},
      "likes": newLikes,
      "dislikes": newDislikes,
    };

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
        "reaction_type": finalReaction,
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
        _postData = Map<String, dynamic>.from(widget.post);
      });
      widget.onPostUpdated(_postData["id"], widget.post);
    }
  }

  String _shortDesc(String desc) {
    if (desc.length <= 25) return desc;
    return desc.substring(0, 25);
  }

  // =========================
  // UPDATED IMAGE CAROUSEL (THEME AWARE)
  // =========================
  // Widget _buildImageCarousel() {
  //   final colorScheme = Theme.of(context).colorScheme;
  //   final isDark = Theme.of(context).brightness == Brightness.dark;

  //   // Placeholder color: grey200 in light, surfaceVariant in dark
  //   final placeholderColor =
  //       isDark ? colorScheme.surfaceVariant : Colors.grey[200];

  //   return SizedBox(
  //     height: 210,
  //     child: PageView.builder(
  //       controller: _imageController,
  //       itemCount: _images.length,
  //       itemBuilder: (context, index) {
  //         final media = _images[index];
  //         final url = _fullUrl(media["media_url"] ?? "");

  //         return Padding(
  //           padding: const EdgeInsets.all(4),
  //           child: ClipRRect(
  //             borderRadius: BorderRadius.circular(14),
  //             child: CachedNetworkImage(
  //               imageUrl: url,
  //               fit: BoxFit.cover,
  //               width: double.infinity,
  //               placeholder: (context, url) => Container(
  //                 color: placeholderColor,
  //                 child: const Center(child: CircularProgressIndicator()),
  //               ),
  //               errorWidget: (context, url, error) {
  //                 debugPrint("IMAGE ERROR: $error\nURL: $url");
  //                 return Container(
  //                   color: placeholderColor,
  //                   alignment: Alignment.center,
  //                   child: Text(
  //                     "Image load failed",
  //                     style: TextStyle(
  //                       color: isDark
  //                           ? colorScheme.onSurface.withOpacity(0.6)
  //                           : Colors.grey.shade700,
  //                     ),
  //                   ),
  //                 );
  //               },
  //             ),
  //           ),
  //         );
  //       },
  //     ),
  //   );
  // }

  Widget _buildImageCarousel() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final placeholderColor =
        isDark ? colorScheme.surfaceVariant : Colors.grey[200];

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
            child: GestureDetector(
              onTap: () {
                _openFullScreenImages(index);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (context, url) => Container(
                    color: placeholderColor,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  errorWidget: (context, url, error) {
                    return Container(
                      color: placeholderColor,
                      alignment: Alignment.center,
                      child: Text(
                        "Image load failed",
                        style: TextStyle(
                          color: isDark
                              ? colorScheme.onSurface.withOpacity(0.6)
                              : Colors.grey.shade700,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReportPage(postId: _postData["id"]),
                ),
              );
            },
            child: const Text("Report"),
          ),
        ],
      ),
    );
  }

  // =========================
  // UPDATED FOOTER HELPERS (THEME AWARE)
  // =========================
  Widget _buildFooter() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final comments = _postData["counts"]?["comments"] ?? 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _footerReactionBtn(
          icon: Icons.thumb_up_alt_outlined,
          label: _likesCount.toString(),
          active: _myReaction == "like",
          isAnimating: _isLikeAnimating,
          onTap: () => _sendReaction("like"),
        ),
        _footerReactionBtn(
          icon: Icons.thumb_down_alt_outlined,
          label: _dislikesCount.toString(),
          active: _myReaction == "dislike",
          isAnimating: _isDislikeAnimating,
          onTap: () => _sendReaction("dislike"),
        ),
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
        _footerSaveBtn(
          icon: _isSaved ? Icons.bookmark : Icons.bookmark_border,
          label: "",
          active: _isSaved,
          isAnimating: _isSaveAnimating,
          onTap: _toggleSave,
        ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final inactiveColor =
        isDark ? colorScheme.onSurface.withOpacity(0.6) : Colors.grey.shade700;
    final activeColor = colorScheme.primary;

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
              color: active ? activeColor : inactiveColor,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? activeColor : inactiveColor,
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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final inactiveColor =
        isDark ? colorScheme.onSurface.withOpacity(0.6) : Colors.grey.shade700;
    final activeColor = colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color:
              isAnimating ? activeColor.withOpacity(0.1) : Colors.transparent,
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
                color: active ? activeColor : inactiveColor,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? activeColor : inactiveColor,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final inactiveColor =
        isDark ? colorScheme.onSurface.withOpacity(0.6) : Colors.grey.shade700;
    final activeColor = colorScheme.secondary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color:
              isAnimating ? activeColor.withOpacity(0.1) : Colors.transparent,
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
                color: active ? activeColor : inactiveColor,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // MAIN BUILD (THEME AWARE)

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

    // final cardColor = isDark
    //     ? colorScheme.surfaceContainerHighest.withOpacity(0.5)
    //     : const Color(0xFFDCDEF7);

    final cardColor = isDark
        ? colorScheme.surfaceContainerHighest.withOpacity(0.5)
        : Colors.white;

    final avatarBgColor =
        isDark ? colorScheme.surfaceVariant : Colors.grey.shade200;

    final timeColor =
        isDark ? colorScheme.onSurface.withOpacity(0.6) : Colors.grey.shade600;

    final readMoreColor =
        isDark ? colorScheme.primary : const Color.fromARGB(255, 45, 47, 190);

    final industryIconColor =
        isDark ? colorScheme.primary : const Color.fromARGB(255, 45, 47, 190);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _openPostDetails,
      child: Card(
        color: cardColor,
        // elevation: 2,
        elevation: isDark ? 2 : 1,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        // shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isDark
              ? BorderSide.none
              : BorderSide(
                  color: colorScheme.primary,
                  width: 1,
                ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ================= HEADER =================
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: avatarBgColor,
                    child: ClipOval(
                      child: (profilePicUrl != null && profilePicUrl.isNotEmpty)
                          ? Image.network(
                              profilePicUrl,
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.person,
                                  size: 22,
                                  color: isDark
                                      ? colorScheme.onSurface.withOpacity(0.6)
                                      : Colors.grey,
                                );
                              },
                            )
                          : Icon(
                              Icons.person,
                              size: 22,
                              color: isDark
                                  ? colorScheme.onSurface.withOpacity(0.6)
                                  : Colors.grey,
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
                            color: isDark ? colorScheme.onSurface : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          updatedAt,
                          style: TextStyle(
                            fontSize: 12,
                            color: timeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: avatarBgColor,
                    child: Icon(
                      IndustryIconMapper.getIcon(_postData["industry_icon"]),
                      size: 16,
                      color: industryIconColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ================= TITLE =================
              if (title.isNotEmpty)
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? colorScheme.onSurface : null,
                  ),
                ),

              const SizedBox(height: 8),

              // ================= DESCRIPTION =================
              if (description.isNotEmpty)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.star,
                      size: 18,
                      color: isDark ? colorScheme.primary : null,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _expandedDescription
                                ? description
                                : _shortDesc(description),
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.35,
                              color: isDark ? colorScheme.onSurface : null,
                            ),
                          ),
                          if (description.length > 25)
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

              // ================= IMAGE CAROUSEL =================
              if (_images.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  "Images (${_images.length})",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? colorScheme.onSurface : null,
                  ),
                ),
                const SizedBox(height: 8),
                _buildImageCarousel(),
              ],

              const SizedBox(height: 14),

              // ================= FOOTER =================
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }
}
