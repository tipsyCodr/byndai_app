// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
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
//   bool _showDebugInfo = false;

//   final PageController _imageController = PageController();

//   @override
//   void dispose() {
//     _imageController.dispose();

//     super.dispose();
//   }

//   // =========================
//   // TIME FORMAT
//   // =========================
//   String _formatTime(String? dateTimeStr) {
//     if (dateTimeStr == null || dateTimeStr.isEmpty) return "";
//     try {
//       final dt = DateTime.parse(dateTimeStr.replaceAll(" ", "T"));
//       return DateFormat("hh:mm a").format(dt);
//     } catch (_) {
//       return "";
//     }
//   }

//   // =========================
//   // COMPLETE URL
//   // =========================
//   String _fullUrl(String? path) {
//     if (path == null || path.isEmpty) return "";
//     if (path.startsWith("http")) return path;

//     String cleanPath = path;
//     if (cleanPath.startsWith("/") && _baseUrl.endsWith("/")) {
//       cleanPath = cleanPath.substring(1);
//     }

//     if (!_baseUrl.endsWith("/") && !cleanPath.startsWith("/")) {
//       return "$_baseUrl/$cleanPath";
//     }

//     return "$_baseUrl$cleanPath";
//   }

//   // =========================
//   // MEDIA LIST
//   // =========================
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

//   // =========================
//   // BUILD
//   // =========================
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
//             // =========================
//             // TOP HEADER
//             // =========================
//             GestureDetector(
//               onLongPress: () {
//                 setState(() => _showDebugInfo = !_showDebugInfo);
//               },
//               child: Row(
//                 children: [
//                   const CircleAvatar(
//                     radius: 18,
//                     backgroundImage: AssetImage("assets/images/default_user.png"),
//                   ),
//                   const SizedBox(width: 10),
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
//                   const CircleAvatar(
//                     radius: 14,
//                     backgroundImage: AssetImage("assets/images/default_logo.png"),
//                   ),
//                 ],
//               ),
//             ),

//             // =========================
//             // DEBUG INFO
//             // =========================
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
//                     Text("Post ID: ${widget.post["id"]}",
//                         style: const TextStyle(fontSize: 12)),
//                     Text("Images: ${_images.length}",
//                         style: const TextStyle(fontSize: 12)),

//                     if (_images.isNotEmpty)
//                       Text(
//                         "First Image URL: ${_fullUrl(_images[0]["media_url"])}",
//                         style: const TextStyle(fontSize: 10),
//                         overflow: TextOverflow.ellipsis,
//                       ),

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
//             // DESCRIPTION
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
//             // IMAGE CAROUSEL
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

//             const SizedBox(height: 14),

//             // =========================
//             // FOOTER
//             // =========================
//             _buildFooter(),
//           ],
//         ),
//       ),
//     );
//   }

//   // =========================
//   // SHORT DESC (25)
//   // =========================
//   String _shortDesc(String desc) {
//     if (desc.length <= 25) return desc;
//     return desc.substring(0, 25);
//   }

//   // =========================
//   // IMAGE CAROUSEL
//   // =========================
//   Widget _buildImageCarousel() {
//     return SizedBox(
//       height: 210,
//       child: PageView.builder(
//         controller: _imageController,
//         itemCount: _images.length,
//         itemBuilder: (context, index) {
//           final media = _images[index];
//           final url = _fullUrl(media["media_url"] ?? "");

//           return Padding(
//             padding: const EdgeInsets.all(4),
//             child: ClipRRect(
//               borderRadius: BorderRadius.circular(14),
//               child: CachedNetworkImage(
//                 imageUrl: url,
//                 fit: BoxFit.cover,
//                 width: double.infinity,
//                 placeholder: (context, url) => Container(
//                   color: Colors.grey[200],
//                   child: const Center(child: CircularProgressIndicator()),
//                 ),
//                 errorWidget: (context, url, error) {
//                   debugPrint("IMAGE ERROR: $error");
//                   debugPrint("URL: $url");

//                   return Container(
//                     color: Colors.grey.shade200,
//                     alignment: Alignment.center,
//                     child: const Text("Image load failed"),
//                   );
//                 },
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }

//   // =========================
//   // FOOTER
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
//             // TODO: Like API
//           },
//         ),
//         _footerBtn(
//           icon: Icons.thumb_down_alt_outlined,
//           label: dislikes.toString(),
//           active: myReaction == "dislike",
//           onTap: () {
//             // TODO: Dislike API
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
//             // TODO: Save API
//           },
//         ),
//         _footerBtn(
//           icon: Icons.flag_outlined,
//           label: "Report",
//           onTap: () {
//             // TODO: Report action
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

///==========================================================================================

// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:http/http.dart' as http;
// import 'package:gridcard/core/services/user_storage_service.dart';

// class PostCard extends StatefulWidget {
//   final Map<String, dynamic> post;
//   final Function(int, Map<String, dynamic>) onPostUpdated;

//   const PostCard({
//     super.key,
//     required this.post,
//     required this.onPostUpdated,
//   });

//   @override
//   State<PostCard> createState() => _PostCardState();
// }

// class _PostCardState extends State<PostCard> {
//   static const String _baseUrl =
//       "https://powderblue-jellyfish-554082.hostingersite.com";

//   bool _expandedDescription = false;
//   bool _showDebugInfo = false;
//   bool _isReacting = false;

//   final PageController _imageController = PageController();

//   // =========================
//   // STATE VARIABLES FOR REACTIONS
//   // =========================
//   late Map<String, dynamic> _postData;
//   late String _myReaction;
//   late int _likesCount;
//   late int _dislikesCount;

//   @override
//   void initState() {
//     super.initState();
//     _postData = Map<String, dynamic>.from(widget.post);
//     _myReaction = _postData["my"]?["reaction"] ?? "none";
//     _likesCount = _postData["counts"]?["likes"] ?? 0;
//     _dislikesCount = _postData["counts"]?["dislikes"] ?? 0;
//   }

//   @override
//   void dispose() {
//     _imageController.dispose();
//     super.dispose();
//   }

//   // =========================
//   // TIME FORMAT
//   // =========================
//   String _formatTime(String? dateTimeStr) {
//     if (dateTimeStr == null || dateTimeStr.isEmpty) return "";
//     try {
//       final dt = DateTime.parse(dateTimeStr.replaceAll(" ", "T"));
//       return DateFormat("hh:mm a").format(dt);
//     } catch (_) {
//       return "";
//     }
//   }

//   // =========================
//   // COMPLETE URL
//   // =========================
//   String _fullUrl(String? path) {
//     if (path == null || path.isEmpty) return "";
//     if (path.startsWith("http")) return path;

//     String cleanPath = path;
//     if (cleanPath.startsWith("/") && _baseUrl.endsWith("/")) {
//       cleanPath = cleanPath.substring(1);
//     }

//     if (!_baseUrl.endsWith("/") && !cleanPath.startsWith("/")) {
//       return "$_baseUrl/$cleanPath";
//     }

//     return "$_baseUrl$cleanPath";
//   }

//   // =========================
//   // MEDIA LIST
//   // =========================
//   List<Map<String, dynamic>> get _media {
//     final m = _postData["media"];
//     if (m is List) {
//       return m.map((e) => Map<String, dynamic>.from(e)).toList();
//     }
//     return [];
//   }

//   List<Map<String, dynamic>> get _images {
//     return _media.where((m) => m["media_type"] == "image").toList();
//   }

//   // =========================
//   // REACTION API CALL
//   // =========================
//   Future<void> _sendReaction(String reactionType) async {
//     if (_isReacting) return;

//     // यदि user पहले से same reaction दे चुका है, तो remove करें
//     if (_myReaction == reactionType) {
//       reactionType = "none";
//     }

//     setState(() {
//       _isReacting = true;
//     });

//     try {
//       final token = await UserStorageService().getToken();
//       if (token == null) return;

//       final postId = _postData["id"];

//       final headers = {
//         'Content-Type': 'application/json',
//         'Accept': 'application/json',
//         'Authorization': 'Bearer $token',
//       };

//       final body = {
//         "post_id": postId,
//         "reaction_type": reactionType,
//         "reaction": reactionType,
//       };

//       final response = await http.post(
//         Uri.parse("$_baseUrl/api/posts/react"),
//         headers: headers,
//         body: jsonEncode(body),
//       );

//       if (response.statusCode == 200) {
//         final responseData = jsonDecode(response.body);

//         if (responseData["status"] == true) {
//           // Update local state based on new reaction
//           final String newReaction = reactionType;
//           final String previousReaction = _myReaction;

//           // Calculate new counts
//           int newLikes = _likesCount;
//           int newDislikes = _dislikesCount;

//           // Remove previous reaction
//           if (previousReaction == "like") {
//             newLikes--;
//           } else if (previousReaction == "dislike") {
//             newDislikes--;
//           }

//           // Add new reaction
//           if (newReaction == "like") {
//             newLikes++;
//           } else if (newReaction == "dislike") {
//             newDislikes++;
//           }

//           // Update state
//           setState(() {
//             _myReaction = newReaction;
//             _likesCount = newLikes;
//             _dislikesCount = newDislikes;

//             // Update postData for parent callback
//             _postData["my"] = {
//               "reaction": newReaction,
//               "saved": _postData["my"]?["saved"] ?? false,
//             };

//             _postData["counts"] = {
//               ..._postData["counts"] ?? {},
//               "likes": newLikes,
//               "dislikes": newDislikes,
//             };
//           });

//           // Notify parent about the update
//           widget.onPostUpdated(postId, _postData);
//         }
//       }
//     } catch (e) {
//       debugPrint("Reaction API error: $e");
//       // Revert to original state if API fails
//       setState(() {
//         _myReaction = _postData["my"]?["reaction"] ?? "none";
//         _likesCount = _postData["counts"]?["likes"] ?? 0;
//         _dislikesCount = _postData["counts"]?["dislikes"] ?? 0;
//       });
//     } finally {
//       setState(() {
//         _isReacting = false;
//       });
//     }
//   }

//   // =========================
//   // BUILD
//   // =========================
//   @override
//   Widget build(BuildContext context) {
//     final user = _postData["user"] ?? {};
//     final fname = (user["fname"] ?? "User").toString();

//     final title = (_postData["title"] ?? "").toString();
//     final description = (_postData["description"] ?? "").toString();

//     final updatedAt = _formatTime(_postData["updated_at"]?.toString());

//     return Card(
//       elevation: 2,
//       margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: Padding(
//         padding: const EdgeInsets.all(14),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // =========================
//             // TOP HEADER
//             // =========================
//             GestureDetector(
//               onLongPress: () {
//                 setState(() => _showDebugInfo = !_showDebugInfo);
//               },
//               child: Row(
//                 children: [
//                   const CircleAvatar(
//                     radius: 18,
//                     backgroundImage: AssetImage("assets/images/default_user.png"),
//                   ),
//                   const SizedBox(width: 10),
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
//                   const CircleAvatar(
//                     radius: 14,
//                     backgroundImage: AssetImage("assets/images/default_logo.png"),
//                   ),
//                 ],
//               ),
//             ),

//             // =========================
//             // DEBUG INFO
//             // =========================
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
//                     Text("Post ID: ${_postData["id"]}",
//                         style: const TextStyle(fontSize: 12)),
//                     Text("Images: ${_images.length}",
//                         style: const TextStyle(fontSize: 12)),
//                     Text("My Reaction: $_myReaction",
//                         style: const TextStyle(fontSize: 12)),
//                     Text("Likes: $_likesCount, Dislikes: $_dislikesCount",
//                         style: const TextStyle(fontSize: 12)),

//                     if (_images.isNotEmpty)
//                       Text(
//                         "First Image URL: ${_fullUrl(_images[0]["media_url"])}",
//                         style: const TextStyle(fontSize: 10),
//                         overflow: TextOverflow.ellipsis,
//                       ),
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
//             // DESCRIPTION
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
//             // IMAGE CAROUSEL
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

//             const SizedBox(height: 14),

//             // =========================
//             // FOOTER WITH REACTIONS
//             // =========================
//             _buildFooter(),
//           ],
//         ),
//       ),
//     );
//   }

//   // =========================
//   // SHORT DESC (25)
//   // =========================
//   String _shortDesc(String desc) {
//     if (desc.length <= 25) return desc;
//     return desc.substring(0, 25);
//   }

//   // =========================
//   // IMAGE CAROUSEL
//   // =========================
//   Widget _buildImageCarousel() {
//     return SizedBox(
//       height: 210,
//       child: PageView.builder(
//         controller: _imageController,
//         itemCount: _images.length,
//         itemBuilder: (context, index) {
//           final media = _images[index];
//           final url = _fullUrl(media["media_url"] ?? "");

//           return Padding(
//             padding: const EdgeInsets.all(4),
//             child: ClipRRect(
//               borderRadius: BorderRadius.circular(14),
//               child: CachedNetworkImage(
//                 imageUrl: url,
//                 fit: BoxFit.cover,
//                 width: double.infinity,
//                 placeholder: (context, url) => Container(
//                   color: Colors.grey[200],
//                   child: const Center(child: CircularProgressIndicator()),
//                 ),
//                 errorWidget: (context, url, error) {
//                   debugPrint("IMAGE ERROR: $error");
//                   debugPrint("URL: $url");

//                   return Container(
//                     color: Colors.grey.shade200,
//                     alignment: Alignment.center,
//                     child: const Text("Image load failed"),
//                   );
//                 },
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }

//   // =========================
//   // FOOTER
//   // =========================
//   Widget _buildFooter() {
//     final comments = _postData["counts"]?["comments"] ?? 0;
//     final saved = _postData["my"]?["saved"] ?? false;

//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         // LIKE BUTTON
//         _footerReactionBtn(
//           icon: Icons.thumb_up_alt_outlined,
//           label: _likesCount.toString(),
//           active: _myReaction == "like",
//           isLoading: _isReacting,
//           onTap: () => _sendReaction("like"),
//         ),

//         // DISLIKE BUTTON
//         _footerReactionBtn(
//           icon: Icons.thumb_down_alt_outlined,
//           label: _dislikesCount.toString(),
//           active: _myReaction == "dislike",
//           isLoading: _isReacting,
//           onTap: () => _sendReaction("dislike"),
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
//             // TODO: Save API
//           },
//         ),
//         _footerBtn(
//           icon: Icons.flag_outlined,
//           label: "Report",
//           onTap: () {
//             // TODO: Report action
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

//   Widget _footerReactionBtn({
//     required IconData icon,
//     required String label,
//     required bool active,
//     required bool isLoading,
//     required VoidCallback onTap,
//   }) {
//     return InkWell(
//       onTap: isLoading ? null : onTap,
//       borderRadius: BorderRadius.circular(10),
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
//         child: Row(
//           children: [
//             if (isLoading)
//               SizedBox(
//                 width: 18,
//                 height: 18,
//                 child: CircularProgressIndicator(
//                   strokeWidth: 2,
//                   valueColor: AlwaysStoppedAnimation<Color>(
//                     active ? Colors.blue : Colors.grey.shade700,
//                   ),
//                 ),
//               )
//             else
//               Icon(
//                 icon,
//                 size: 18,
//                 color: active ? Colors.blue : Colors.grey.shade700,
//               ),
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

//=========================================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:gridcard/core/services/user_storage_service.dart';

class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final Function(int, Map<String, dynamic>) onPostUpdated;

  const PostCard({
    super.key,
    required this.post,
    required this.onPostUpdated,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  static const String _baseUrl =
      "https://powderblue-jellyfish-554082.hostingersite.com";

  bool _expandedDescription = false;
  bool _showDebugInfo = false;
  bool _isLikeAnimating = false;
  bool _isDislikeAnimating = false;

  final PageController _imageController = PageController();

  // =========================
  // STATE VARIABLES FOR REACTIONS
  // =========================
  late Map<String, dynamic> _postData;
  late String _myReaction;
  late int _likesCount;
  late int _dislikesCount;

  @override
  void initState() {
    super.initState();
    _postData = Map<String, dynamic>.from(widget.post);
    _myReaction = _postData["my"]?["reaction"] ?? "none";
    _likesCount = _postData["counts"]?["likes"] ?? 0;
    _dislikesCount = _postData["counts"]?["dislikes"] ?? 0;
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
      "saved": _postData["my"]?["saved"] ?? false,
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

        // Also update _postData
        _postData = Map<String, dynamic>.from(widget.post);
      });

      // Notify parent to revert as well
      widget.onPostUpdated(_postData["id"], widget.post);
    }
  }

  // =========================
  // BUILD
  // =========================
  @override
  Widget build(BuildContext context) {
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
                    backgroundImage:
                        AssetImage("assets/images/default_user.png"),
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
                    backgroundImage:
                        AssetImage("assets/images/default_logo.png"),
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
                    Text("Post ID: ${_postData["id"]}",
                        style: const TextStyle(fontSize: 12)),
                    Text("Images: ${_images.length}",
                        style: const TextStyle(fontSize: 12)),
                    Text("My Reaction: $_myReaction",
                        style: const TextStyle(fontSize: 12)),
                    Text("Likes: $_likesCount, Dislikes: $_dislikesCount",
                        style: const TextStyle(fontSize: 12)),
                    if (_images.isNotEmpty)
                      Text(
                        "First Image URL: ${_fullUrl(_images[0]["media_url"])}",
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

            const SizedBox(height: 14),

            // =========================
            // FOOTER WITH REACTIONS
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
  // FOOTER
  // =========================
  Widget _buildFooter() {
    final comments = _postData["counts"]?["comments"] ?? 0;
    final saved = _postData["my"]?["saved"] ?? false;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // LIKE BUTTON WITH ANIMATION
        _footerReactionBtn(
          icon: Icons.thumb_up_alt_outlined,
          label: _likesCount.toString(),
          active: _myReaction == "like",
          isAnimating: _isLikeAnimating,
          onTap: () => _sendReaction("like"),
        ),

        // DISLIKE BUTTON WITH ANIMATION
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

  Widget _footerReactionBtn({
    required IconData icon,
    required String label,
    required bool active,
    required bool isAnimating,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color:
              isAnimating ? Colors.blue.withOpacity(0.1) : Colors.transparent,
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
                color: active ? Colors.blue : Colors.grey.shade700,
              ),
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
