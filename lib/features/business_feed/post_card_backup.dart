
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:video_player/video_player.dart';
// import 'package:cached_network_image/cached_network_image.dart';

// class PostCard extends StatefulWidget {
//   final Map<String, dynamic> post;

//   const PostCard({
//     super.key,
//     required this.post,
//   });

//   @override
//   State<PostCard> createState() => _PostCardState();
// }

// class _PostCardState extends State<PostCard> {
//   static const String _baseUrl =
//       "https://powderblue-jellyfish-554082.hostingersite.com";

//   bool _expandedDescription = false;
//   bool _showDebugInfo = false; // For debugging

//   final PageController _imageController = PageController();
//   final PageController _videoController = PageController();

//   final Map<int, VideoPlayerController> _videoPlayers = {};
// //.................
//   @override
//   void dispose() {
//     _imageController.dispose();
//     _videoController.dispose();

//     for (final v in _videoPlayers.values) {
//       v.dispose();
//     }
//     super.dispose();
//   }

//   // ✅ Time format
//   String _formatTime(String? dateTimeStr) {
//     if (dateTimeStr == null || dateTimeStr.isEmpty) return "";
//     try {
//       final dt = DateTime.parse(dateTimeStr.replaceAll(" ", "T"));
//       return DateFormat("hh:mm a").format(dt);
//     } catch (_) {
//       return "";
//     }
//   }

//   // ✅ Complete URL - FIXED VERSION
//   String _fullUrl(String? path) {
//     if (path == null || path.isEmpty) return "";
//     if (path.startsWith("http")) return path;
    
//     // Remove leading slash if baseUrl already has it
//     String cleanPath = path;
//     if (cleanPath.startsWith("/") && _baseUrl.endsWith("/")) {
//       cleanPath = cleanPath.substring(1);
//     }
    
//     // Add slash if missing
//     if (!_baseUrl.endsWith("/") && !cleanPath.startsWith("/")) {
//       return "$_baseUrl/$cleanPath";
//     }
    
//     return "$_baseUrl$cleanPath";
//   }

//   // ✅ Get media list
//   List<Map<String, dynamic>> get _media {
//     final m = widget.post["media"];
//     if (m is List) {
//       return m.map((e) => Map<String, dynamic>.from(e)).toList();
//     }
//     return [];
//   }

//   List<Map<String, dynamic>> get _images {
//     return _media.where((m) => m["media_type"] == "image").toList();
//   }

//   List<Map<String, dynamic>> get _videos {
//     return _media.where((m) => m["media_type"] == "video").toList();
//   }

//   // ✅ Video controller
//   Future<VideoPlayerController> _getVideoController(int index) async {
//     if (_videoPlayers.containsKey(index)) return _videoPlayers[index]!;

//     final url = _fullUrl(_videos[index]["media_url"] ?? "");

//     final controller = VideoPlayerController.networkUrl(Uri.parse(url));
//     await controller.initialize();

//     controller.setLooping(true);

//     _videoPlayers[index] = controller;
//     return controller;
//   }

//   @override
//   Widget build(BuildContext context) {
//     final user = widget.post["user"] ?? {};
//     final fname = (user["fname"] ?? "User").toString();
//     final title = (widget.post["title"] ?? "").toString();
//     final description = (widget.post["description"] ?? "").toString();

//     final updatedAt = _formatTime(widget.post["updated_at"]?.toString());

//     return Card(
//       elevation: 2,
//       margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: Padding(
//         padding: const EdgeInsets.all(14),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Debug button (long press to show debug info)
//             GestureDetector(
//               onLongPress: () {
//                 setState(() {
//                   _showDebugInfo = !_showDebugInfo;
//                 });
//               },
//               child: Row(
//                 children: [
//                   // Default user avatar
//                   const CircleAvatar(
//                     radius: 18,
//                     backgroundImage: AssetImage("assets/images/default_user.png"),
//                   ),
//                   const SizedBox(width: 10),

//                   // fname + time
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           fname,
//                           style: const TextStyle(
//                             fontSize: 15,
//                             fontWeight: FontWeight.w700,
//                           ),
//                         ),
//                         const SizedBox(height: 2),
//                         Text(
//                           updatedAt,
//                           style: TextStyle(
//                             fontSize: 12,
//                             color: Colors.grey.shade600,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),

//                   // Top right logo
//                   const CircleAvatar(
//                     radius: 14,
//                     backgroundImage: AssetImage("assets/images/default_logo.png"),
//                   ),
//                 ],
//               ),
//             ),

//             // Debug Info
//             if (_showDebugInfo)
//               Container(
//                 padding: const EdgeInsets.all(8),
//                 margin: const EdgeInsets.symmetric(vertical: 8),
//                 decoration: BoxDecoration(
//                   color: Colors.grey[100],
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       "Post ID: ${widget.post["id"]}",
//                       style: const TextStyle(fontSize: 12),
//                     ),
//                     Text(
//                       "Images: ${_images.length}",
//                       style: const TextStyle(fontSize: 12),
//                     ),
//                     if (_images.isNotEmpty)
//                       Text(
//                         "Image URL: ${_fullUrl(_images[0]["media_url"])}",
//                         style: const TextStyle(fontSize: 10),
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     Text(
//                       "Videos: ${_videos.length}",
//                       style: const TextStyle(fontSize: 12),
//                     ),
//                   ],
//                 ),
//               ),

//             const SizedBox(height: 12),

//             // =========================
//             // TITLE
//             // =========================
//             if (title.isNotEmpty)
//               Text(
//                 title,
//                 style: const TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w800,
//                 ),
//               ),

//             const SizedBox(height: 8),

//             // =========================
//             // DESCRIPTION + STAR ICON + READ MORE
//             // =========================
//             if (description.isNotEmpty)
//               Row(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Icon(Icons.star, size: 18),
//                   const SizedBox(width: 6),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           _expandedDescription
//                               ? description
//                               : _shortDesc(description),
//                           style: const TextStyle(fontSize: 14, height: 1.35),
//                         ),
//                         if (description.length > 25)
//                           GestureDetector(
//                             onTap: () {
//                               setState(() {
//                                 _expandedDescription = !_expandedDescription;
//                               });
//                             },
//                             child: Padding(
//                               padding: const EdgeInsets.only(top: 4),
//                               child: Text(
//                                 _expandedDescription
//                                     ? "Read less"
//                                     : "...Read more",
//                                 style: const TextStyle(
//                                   fontSize: 13,
//                                   fontWeight: FontWeight.w700,
//                                   color: Colors.blue,
//                                 ),
//                               ),
//                             ),
//                           ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),

//             // =========================
//             // IMAGE CAROUSEL - UPDATED WITH CACHED NETWORK IMAGE
//             // =========================
//             if (_images.isNotEmpty) ...[
//               const SizedBox(height: 14),
//               Text(
//                 "Images (${_images.length})",
//                 style: const TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//               const SizedBox(height: 8),
//               _buildImageCarousel(),
//             ],

//             // =========================
//             // VIDEO CAROUSEL
//             // =========================
//             if (_videos.isNotEmpty) ...[
//               const SizedBox(height: 14),
//               Text(
//                 "Videos (${_videos.length})",
//                 style: const TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//               const SizedBox(height: 8),
//               _buildVideoCarousel(),
//             ],

//             const SizedBox(height: 14),

//             // =========================
//             // FOOTER ACTIONS
//             // =========================
//             _buildFooter(),
//           ],
//         ),
//       ),
//     );
//   }

//   // ✅ 25 length short description
//   String _shortDesc(String desc) {
//     if (desc.length <= 25) return desc;
//     return desc.substring(0, 25);
//   }

//   // =========================
//   // IMAGE CAROUSEL WIDGET - IMPROVED VERSION
//   // =========================
//   Widget _buildImageCarousel() {
//     return Column(
//       children: [
//         SizedBox(
//           height: 210,
//           child: PageView.builder(
//             controller: _imageController,
//             itemCount: _images.length,
//             itemBuilder: (context, index) {
//               final media = _images[index];
//               final url = _fullUrl(media["media_url"] ?? "");
              
//               print("Image URL: $url"); // Debug print
              
//               return Padding(
//                 padding: const EdgeInsets.all(4.0),
//                 child: ClipRRect(
//                   borderRadius: BorderRadius.circular(14),
//                   child: CachedNetworkImage(
//                     imageUrl: url,
//                     fit: BoxFit.cover,
//                     width: double.infinity,
//                     placeholder: (context, url) => Container(
//                       color: Colors.grey[200],
//                       child: const Center(
//                         child: CircularProgressIndicator(),
//                       ),
//                     ),
//                     errorWidget: (context, url, error) {
//                       print("Image Error: $error"); // Debug print
//                       return Container(
//                         color: Colors.grey[200],
//                         alignment: Alignment.center,
//                         child: Column(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             const Icon(Icons.broken_image, size: 40, color: Colors.grey),
//                             const SizedBox(height: 8),
//                             Text(
//                               "Failed to load image",
//                               style: TextStyle(
//                                 fontSize: 12,
//                                 color: Colors.grey[600],
//                               ),
//                             ),
//                             const SizedBox(height: 4),
//                             Text(
//                               "URL: ${media["media_url"]}",
//                               style: const TextStyle(fontSize: 10),
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                           ],
//                         ),
//                       );
//                     },
//                   ),
//                 ),
//               );
//             },
//           ),
//         ),
//         if (_images.length > 1)
//           Padding(
//             padding: const EdgeInsets.only(top: 8),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: List.generate(
//                 _images.length,
//                 (index) => Container(
//                   width: 8,
//                   height: 8,
//                   margin: const EdgeInsets.symmetric(horizontal: 4),
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     color: _imageController.hasClients &&
//                             (_imageController.page?.round() ?? 0) == index
//                         ? Colors.blue
//                         : Colors.grey[300],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//       ],
//     );
//   }

//   // =========================
//   // VIDEO CAROUSEL WIDGET
//   // =========================
//   Widget _buildVideoCarousel() {
//     return SizedBox(
//       height: 230,
//       child: PageView.builder(
//         controller: _videoController,
//         itemCount: _videos.length,
//         itemBuilder: (context, index) {
//           return FutureBuilder(
//             future: _getVideoController(index),
//             builder: (context, snapshot) {
//               if (!snapshot.hasData) {
//                 return ClipRRect(
//                   borderRadius: BorderRadius.circular(14),
//                   child: Container(
//                     color: Colors.black12,
//                     alignment: Alignment.center,
//                     child: const CircularProgressIndicator(),
//                   ),
//                 );
//               }

//               final controller = snapshot.data as VideoPlayerController;

//               return ClipRRect(
//                 borderRadius: BorderRadius.circular(14),
//                 child: Stack(
//                   alignment: Alignment.center,
//                   children: [
//                     AspectRatio(
//                       aspectRatio: controller.value.aspectRatio,
//                       child: VideoPlayer(controller),
//                     ),

//                     // Play / Pause button
//                     GestureDetector(
//                       onTap: () {
//                         setState(() {
//                           if (controller.value.isPlaying) {
//                             controller.pause();
//                           } else {
//                             controller.play();
//                           }
//                         });
//                       },
//                       child: CircleAvatar(
//                         radius: 26,
//                         backgroundColor: Colors.black.withOpacity(0.55),
//                         child: Icon(
//                           controller.value.isPlaying
//                               ? Icons.pause
//                               : Icons.play_arrow,
//                           size: 32,
//                           color: Colors.white,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }

//   // =========================
//   // FOOTER BUTTONS
//   // =========================
//   Widget _buildFooter() {
//     final counts = widget.post["counts"] ?? {};
//     final likes = counts["likes"] ?? 0;
//     final dislikes = counts["dislikes"] ?? 0;
//     final comments = counts["comments"] ?? 0;

//     final my = widget.post["my"] ?? {};
//     final myReaction = my["reaction"] ?? "none";
//     final saved = my["saved"] ?? false;

//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         _footerBtn(
//           icon: Icons.thumb_up_alt_outlined,
//           label: likes.toString(),
//           active: myReaction == "like",
//           onTap: () {
//             // TODO: call like api
//           },
//         ),
//         _footerBtn(
//           icon: Icons.thumb_down_alt_outlined,
//           label: dislikes.toString(),
//           active: myReaction == "dislike",
//           onTap: () {
//             // TODO: call dislike api
//           },
//         ),
//         _footerBtn(
//           icon: Icons.mode_comment_outlined,
//           label: comments.toString(),
//           onTap: () {
//             // TODO: open comments page
//           },
//         ),
//         _footerBtn(
//           icon: saved ? Icons.bookmark : Icons.bookmark_border,
//           label: "Save",
//           active: saved == true,
//           onTap: () {
//             // TODO: call save api
//           },
//         ),
//         _footerBtn(
//           icon: Icons.flag_outlined,
//           label: "Report",
//           onTap: () {
//             // TODO: report action
//           },
//         ),
//       ],
//     );
//   }

//   Widget _footerBtn({
//     required IconData icon,
//     required String label,
//     required VoidCallback onTap,
//     bool active = false,
//   }) {
//     return InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(10),
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
//         child: Row(
//           children: [
//             Icon(
//               icon,
//               size: 18,
//               color: active ? Colors.blue : Colors.grey.shade700,
//             ),
//             const SizedBox(width: 4),
//             Text(
//               label,
//               style: TextStyle(
//                 fontSize: 13,
//                 fontWeight: FontWeight.w600,
//                 color: active ? Colors.blue : Colors.grey.shade800,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;

  const PostCard({
    super.key,
    required this.post,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  static const String _baseUrl =
      "https://powderblue-jellyfish-554082.hostingersite.com";

  bool _expandedDescription = false;
  bool _showDebugInfo = false;

  final PageController _imageController = PageController();
  final PageController _videoController = PageController();

  // ✅ Video controllers
  final Map<int, VideoPlayerController> _videoPlayers = {};
  final Map<int, ChewieController> _chewiePlayers = {};

  @override
  void dispose() {
    _imageController.dispose();
    _videoController.dispose();

    for (final c in _chewiePlayers.values) {
      c.dispose();
    }
    for (final v in _videoPlayers.values) {
      v.dispose();
    }

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
    final m = widget.post["media"];
    if (m is List) {
      return m.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  List<Map<String, dynamic>> get _images {
    return _media.where((m) => m["media_type"] == "image").toList();
  }

  List<Map<String, dynamic>> get _videos {
    return _media.where((m) => m["media_type"] == "video").toList();
  }

  // =========================
  // GET CHEWIE CONTROLLER
  // =========================
  Future<ChewieController?> _getChewieController(int index) async {
    if (_chewiePlayers.containsKey(index)) return _chewiePlayers[index];

    final url = _fullUrl(_videos[index]["media_url"] ?? "");
    if (url.isEmpty) return null;

    try {
      final videoController = VideoPlayerController.networkUrl(Uri.parse(url));
      await videoController.initialize();

      final chewieController = ChewieController(
        videoPlayerController: videoController,
        autoPlay: false,
        looping: false,
        allowMuting: true,
        showControls: true,
        aspectRatio: videoController.value.aspectRatio == 0
            ? 16 / 9
            : videoController.value.aspectRatio,
      );

      _videoPlayers[index] = videoController;
      _chewiePlayers[index] = chewieController;

      return chewieController;
    } catch (e) {
      debugPrint("VIDEO INIT ERROR: $e");
      debugPrint("URL: $url");
      return null;
    }
  }

  // =========================
  // BUILD
  // =========================
  @override
  Widget build(BuildContext context) {
    final user = widget.post["user"] ?? {};
    final fname = (user["fname"] ?? "User").toString();

    final title = (widget.post["title"] ?? "").toString();
    final description = (widget.post["description"] ?? "").toString();

    final updatedAt = _formatTime(widget.post["updated_at"]?.toString());

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =========================
            // TOP HEADER
            // =========================
            GestureDetector(
              onLongPress: () {
                setState(() => _showDebugInfo = !_showDebugInfo);
              },
              child: Row(
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
            ),

            // =========================
            // DEBUG INFO
            // =========================
            if (_showDebugInfo)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Post ID: ${widget.post["id"]}",
                        style: const TextStyle(fontSize: 12)),
                    Text("Images: ${_images.length}",
                        style: const TextStyle(fontSize: 12)),
                    Text("Videos: ${_videos.length}",
                        style: const TextStyle(fontSize: 12)),
                    if (_images.isNotEmpty)
                      Text(
                        "First Image URL: ${_fullUrl(_images[0]["media_url"])}",
                        style: const TextStyle(fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (_videos.isNotEmpty)
                      Text(
                        "First Video URL: ${_fullUrl(_videos[0]["media_url"])}",
                        style: const TextStyle(fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // =========================
            // TITLE
            // =========================
            if (title.isNotEmpty)
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),

            const SizedBox(height: 8),

            // =========================
            // DESCRIPTION
            // =========================
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
                              : _shortDesc(description),
                          style: const TextStyle(fontSize: 14, height: 1.35),
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

            // =========================
            // IMAGE CAROUSEL
            // =========================
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

            // =========================
            // VIDEO CAROUSEL
            // =========================
            if (_videos.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                "Videos (${_videos.length})",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _buildVideoCarousel(),
            ],

            const SizedBox(height: 14),

            // =========================
            // FOOTER
            // =========================
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // =========================
  // SHORT DESC (25)
  // =========================
  String _shortDesc(String desc) {
    if (desc.length <= 25) return desc;
    return desc.substring(0, 25);
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
  // VIDEO CAROUSEL
  // =========================
  Widget _buildVideoCarousel() {
    return SizedBox(
      height: 230,
      child: PageView.builder(
        controller: _videoController,
        itemCount: _videos.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.all(4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: FutureBuilder<ChewieController?>(
                future: _getChewieController(index),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      color: Colors.black12,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(),
                    );
                  }

                  final chewie = snapshot.data;
                  if (chewie == null) {
                    return Container(
                      color: Colors.black12,
                      alignment: Alignment.center,
                      child: const Text("Video load failed"),
                    );
                  }

                  return Chewie(controller: chewie);
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // =========================
  // FOOTER
  // =========================
  Widget _buildFooter() {
    final counts = widget.post["counts"] ?? {};
    final likes = counts["likes"] ?? 0;
    final dislikes = counts["dislikes"] ?? 0;
    final comments = counts["comments"] ?? 0;

    final my = widget.post["my"] ?? {};
    final myReaction = my["reaction"] ?? "none";
    final saved = my["saved"] ?? false;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _footerBtn(
          icon: Icons.thumb_up_alt_outlined,
          label: likes.toString(),
          active: myReaction == "like",
          onTap: () {
            // TODO: Like API
          },
        ),
        _footerBtn(
          icon: Icons.thumb_down_alt_outlined,
          label: dislikes.toString(),
          active: myReaction == "dislike",
          onTap: () {
            // TODO: Dislike API
          },
        ),
        _footerBtn(
          icon: Icons.mode_comment_outlined,
          label: comments.toString(),
          onTap: () {
            // TODO: open comments page
          },
        ),
        _footerBtn(
          icon: saved ? Icons.bookmark : Icons.bookmark_border,
          label: "Save",
          active: saved == true,
          onTap: () {
            // TODO: Save API
          },
        ),
        _footerBtn(
          icon: Icons.flag_outlined,
          label: "Report",
          onTap: () {
            // TODO: Report action
          },
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
              color: active ? Colors.blue : Colors.grey.shade700,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? Colors.blue : Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
