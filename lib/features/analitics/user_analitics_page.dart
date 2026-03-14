import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class UserAnaliticsPage extends StatefulWidget {
  const UserAnaliticsPage({super.key});

  @override
  State<UserAnaliticsPage> createState() => _UserAnaliticsPageState();
}

class _UserAnaliticsPageState extends State<UserAnaliticsPage> {
  static const String _baseUrl = AppConfig.apiBaseUrl;

  // ================= HEADERS =================
  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ================= STATE =================
  bool _loading = true;
  String? _error;

  int? _userId;

  // Pagination
  int _viewersPage = 1;
  int _clickersPage = 1;

  bool _viewersHasNext = false;
  bool _clickersHasNext = false;

  bool _loadingMoreViewers = false;
  bool _loadingMoreClickers = false;

  // Data (store as list so we can append)
  int _totalViews = 0;
  int _totalTimeSeconds = 0;

  List<Map<String, dynamic>> _viewers = [];
  List<Map<String, dynamic>> _clickers = [];
  List<Map<String, dynamic>> _platformTotals = [];

  Map<String, dynamic>? _ratingData;

  // Controllers for horizontal lazy loading
  final ScrollController _viewersScroll = ScrollController();
  final ScrollController _clickersScroll = ScrollController();

  // ================= INIT =================
  @override
  void initState() {
    super.initState();
    _initLoad();

    _viewersScroll.addListener(_viewersScrollListener);
    _clickersScroll.addListener(_clickersScrollListener);
  }

  @override
  void dispose() {
    _viewersScroll.removeListener(_viewersScrollListener);
    _clickersScroll.removeListener(_clickersScrollListener);
    _viewersScroll.dispose();
    _clickersScroll.dispose();
    super.dispose();
  }

  Future<void> _initLoad() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final id = await UserStorageService().getUserId();

      if (id == null || id == 0) {
        setState(() {
          _loading = false;
          _error = "User session not found. Please login again.";
        });
        return;
      }

      _userId = id;

      // reset all
      _viewersPage = 1;
      _clickersPage = 1;

      _viewersHasNext = false;
      _clickersHasNext = false;

      _viewers.clear();
      _clickers.clear();
      _platformTotals.clear();

      await Future.wait([
        _fetchAnalytics(reset: true),
        _fetchAverageRating(),
      ]);
    } catch (e) {
      setState(() {
        _error = "Something went wrong: $e";
      });
    }

    setState(() {
      _loading = false;
    });
  }

  // ================= API: Analytics =================
  Future<void> _fetchAnalytics({bool reset = false}) async {
    if (_userId == null) return;

    final headers = await _getHeaders();
    final url = Uri.parse("$_baseUrl/user-analytics");

    final body = jsonEncode({
      "userId": _userId,
      "viewers_page": _viewersPage,
      "clickers_page": _clickersPage,
    });

    final res = await http.post(url, headers: headers, body: body);

    if (res.statusCode != 200) {
      throw Exception("Analytics API failed: ${res.body}");
    }

    final decoded = jsonDecode(res.body);

    if (decoded["status"] != true) {
      throw Exception(decoded["message"] ?? "Analytics load failed");
    }

    final data = decoded["data"];

    final profileViews = data["profile_views"];
    final platformClicks = data["platform_clicks"];

    // totals (same for all pages)
    _totalViews =
        int.tryParse(profileViews["total_view_count"].toString()) ?? 0;
    _totalTimeSeconds =
        int.tryParse(profileViews["total_time_seconds"].toString()) ?? 0;

    // platform totals (same for all pages)
    _platformTotals = List<Map<String, dynamic>>.from(
      (platformClicks["platform_totals"] ?? []) as List,
    );

    // pagination
    final viewersPagination = profileViews["pagination"];
    final clickersPagination = platformClicks["pagination"];

    _viewersHasNext = viewersPagination?["has_next"] == true;
    _clickersHasNext = clickersPagination?["has_next"] == true;

    // append viewers/clickers
    final newViewers = List<Map<String, dynamic>>.from(
      (profileViews["viewers"] ?? []) as List,
    );

    final newClickers = List<Map<String, dynamic>>.from(
      (platformClicks["clickers"] ?? []) as List,
    );

    // Reset vs append
    if (reset) {
      _viewers = newViewers;
      _clickers = newClickers;
    } else {
      // Avoid duplicates (if API gives same data)
      final existingViewerIds =
          _viewers.map((e) => e["viewer_user_id"]).toSet();
      for (final v in newViewers) {
        if (!existingViewerIds.contains(v["viewer_user_id"])) {
          _viewers.add(v);
        }
      }

      final existingClickerKey =
          _clickers.map((e) => "${e["viewer_id"]}_${e["platform"]}").toSet();
      for (final c in newClickers) {
        final key = "${c["viewer_id"]}_${c["platform"]}";
        if (!existingClickerKey.contains(key)) {
          _clickers.add(c);
        }
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  // ================= API: Average Rating =================
  Future<void> _fetchAverageRating() async {
    if (_userId == null) return;

    final headers = await _getHeaders();
    final url = Uri.parse("$_baseUrl/user-reviews/$_userId/average");

    final res = await http.get(url, headers: headers);

    if (res.statusCode != 200) {
      throw Exception("Rating API failed: ${res.body}");
    }

    final decoded = jsonDecode(res.body);

    if (decoded["status"] != true) {
      throw Exception(decoded["message"] ?? "Rating load failed");
    }

    setState(() {
      _ratingData = decoded["data"];
    });
  }

  // ================= LAZY LOAD LISTENERS =================
  void _viewersScrollListener() {
    if (_loadingMoreViewers) return;
    if (!_viewersHasNext) return;
    if (!_viewersScroll.hasClients) return;

    final maxScroll = _viewersScroll.position.maxScrollExtent;
    final current = _viewersScroll.position.pixels;

    // when user reaches 85% end -> load next
    if (current >= maxScroll * 0.85) {
      _loadMoreViewers();
    }
  }

  void _clickersScrollListener() {
    if (_loadingMoreClickers) return;
    if (!_clickersHasNext) return;
    if (!_clickersScroll.hasClients) return;

    final maxScroll = _clickersScroll.position.maxScrollExtent;
    final current = _clickersScroll.position.pixels;

    if (current >= maxScroll * 0.85) {
      _loadMoreClickers();
    }
  }

  Future<void> _loadMoreViewers() async {
    if (_loadingMoreViewers) return;
    if (!_viewersHasNext) return;

    setState(() => _loadingMoreViewers = true);

    try {
      _viewersPage += 1;
      await _fetchAnalytics(reset: false);
    } catch (_) {}

    if (mounted) {
      setState(() => _loadingMoreViewers = false);
    }
  }

  Future<void> _loadMoreClickers() async {
    if (_loadingMoreClickers) return;
    if (!_clickersHasNext) return;

    setState(() => _loadingMoreClickers = true);

    try {
      _clickersPage += 1;
      await _fetchAnalytics(reset: false);
    } catch (_) {}

    if (mounted) {
      setState(() => _loadingMoreClickers = false);
    }
  }

  // ================= UI HELPERS =================
  IconData _platformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case "instagram":
        return FontAwesomeIcons.instagram;
      case "facebook":
        return FontAwesomeIcons.facebook;
      case "youtube":
        return FontAwesomeIcons.youtube;
      case "whatsapp":
        return FontAwesomeIcons.whatsapp;
      case "twitter":
        return FontAwesomeIcons.twitter;
      case "telegram":
        return FontAwesomeIcons.telegram;
      case "snapchat":
        return FontAwesomeIcons.snapchat;
      case "linkedin":
        return FontAwesomeIcons.linkedin;
      default:
        return FontAwesomeIcons.link;
    }
  }

  String _formatSeconds(int seconds) {
    if (seconds <= 0) return "0s";
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m <= 0) return "${s}s";
    return "${m}m ${s}s";
  }

  Widget _sectionTitle(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  // Widget _statCard({
  //   required String title,
  //   required String value,
  //   required IconData icon,
  // }) {
  //   final cs = Theme.of(context).colorScheme;
  //   return Container(
  //     width: 170,
  //     padding: const EdgeInsets.all(14),
  //     margin: const EdgeInsets.only(right: 12),
  //     decoration: BoxDecoration(
  //       color: cs.surfaceContainerHighest.withOpacity(0.3),
  //       borderRadius: BorderRadius.circular(16),
  //       border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
  //       boxShadow: [
  //         BoxShadow(
  //           blurRadius: 10,
  //           spreadRadius: 0,
  //           offset: const Offset(0, 6),
  //           color: Colors.black.withOpacity(0.04),
  //         )
  //       ],
  //     ),
  //     child: Row(
  //       children: [
  //         Container(
  //           height: 44,
  //           width: 44,
  //           decoration: BoxDecoration(
  //             color: cs.primaryContainer,
  //             borderRadius: BorderRadius.circular(14),
  //           ),
  //           child: Icon(icon, size: 20, color: cs.onPrimaryContainer),
  //         ),
  //         const SizedBox(width: 12),
  //         Expanded(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text(
  //                 title,
  //                 maxLines: 1,
  //                 overflow: TextOverflow.ellipsis,
  //                 style: TextStyle(
  //                   fontSize: 12,
  //                   color: cs.onSurface.withOpacity(0.7),
  //                   fontWeight: FontWeight.w600,
  //                 ),
  //               ),
  //               const SizedBox(height: 4),
  //               Text(
  //                 value,
  //                 maxLines: 1,
  //                 overflow: TextOverflow.ellipsis,
  //                 style: const TextStyle(
  //                   fontSize: 18,
  //                   fontWeight: FontWeight.w800,
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity, // Take full width of parent
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 6),
            color: Colors.black.withOpacity(0.04),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 20, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyBox(String text) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: cs.onSurface.withOpacity(0.6),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _viewerCard(Map item) {
    final cs = Theme.of(context).colorScheme;
    final name = (item["viewer_fname"] ?? item["viewer_user_name"] ?? "Unknown")
        .toString();

    final viewCount = (item["view_count"] ?? 0).toString();
    final time = int.tryParse(item["total_time_seconds"].toString()) ?? 0;

    return Container(
      width: 240,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: cs.primaryContainer,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : "?",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.remove_red_eye,
                  size: 16, color: cs.onSurface.withOpacity(0.6)),
              const SizedBox(width: 6),
              Text(
                "$viewCount views",
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withOpacity(0.8),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.timer, size: 16, color: cs.onSurface.withOpacity(0.6)),
              const SizedBox(width: 6),
              Text(
                _formatSeconds(time),
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withOpacity(0.8),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Last: ${item["last_viewed_at"] ?? "-"}",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurface.withOpacity(0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _clickerCard(Map item) {
    final cs = Theme.of(context).colorScheme;
    final name = (item["viewer_fname"] ?? item["viewer_user_name"] ?? "Unknown")
        .toString();

    final platform = (item["platform"] ?? "-").toString();
    final clickCount = (item["click_count"] ?? 0).toString();

    return Container(
      width: 260,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: cs.primaryContainer,
                child: Icon(
                  _platformIcon(platform),
                  size: 16,
                  color: cs.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                platform.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withOpacity(0.8),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                "$clickCount clicks",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Last: ${item["last_clicked_at"] ?? "-"}",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurface.withOpacity(0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ================= BUILD =================
  // @override
  // Widget build(BuildContext context) {
  //   final cs = Theme.of(context).colorScheme;
  //   final avgRating = (_ratingData?["average_rating"] ?? 0).toString();
  //   final totalReviews = (_ratingData?["total_reviews"] ?? 0).toString();

  //   return Scaffold(
  //     backgroundColor: cs.surface,
  //     appBar: AppBar(
  //       backgroundColor: cs.surface,
  //       elevation: 0.6,
  //       leading: IconButton(
  //         icon: const Icon(Icons.arrow_back_ios_new, size: 18),
  //         onPressed: () => Navigator.pop(context),
  //       ),
  //       centerTitle: true,
  //       title: Text(
  //         "Analytics",
  //         style: TextStyle(
  //           fontSize: 18,
  //           fontWeight: FontWeight.w800,
  //           color: cs.onSurface,
  //         ),
  //       ),
  //       actions: [
  //         IconButton(
  //           onPressed: _initLoad,
  //           icon: const Icon(Icons.refresh),
  //         ),
  //       ],
  //     ),
  //     body: _loading
  //         ? const Center(child: CircularProgressIndicator())
  //         : _error != null
  //             ? Center(
  //                 child: Padding(
  //                   padding: const EdgeInsets.all(16),
  //                   child: Text(
  //                     _error!,
  //                     textAlign: TextAlign.center,
  //                     style: const TextStyle(
  //                       fontSize: 14,
  //                       fontWeight: FontWeight.w700,
  //                     ),
  //                   ),
  //                 ),
  //               )
  //             : RefreshIndicator(
  //                 onRefresh: _initLoad,
  //                 child: SingleChildScrollView(
  //                   physics: const AlwaysScrollableScrollPhysics(),
  //                   padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
  //                   child: Column(
  //                     crossAxisAlignment: CrossAxisAlignment.start,
  //                     children: [
  //                       // ================= TOP STATS =================
  //                       _sectionTitle("Overview"),
  //                       SizedBox(
  //                         height: 78,
  //                         child: ListView(
  //                           scrollDirection: Axis.horizontal,
  //                           children: [
  //                             _statCard(
  //                               title: "Total Views",
  //                               value: _totalViews.toString(),
  //                               icon: Icons.remove_red_eye,
  //                             ),
  //                             _statCard(
  //                               title: "Total Time",
  //                               value: _formatSeconds(_totalTimeSeconds),
  //                               icon: Icons.timer,
  //                             ),
  //                             _statCard(
  //                               title: "Rating",
  //                               value: avgRating,
  //                               icon: Icons.star,
  //                             ),
  //                             _statCard(
  //                               title: "Reviews",
  //                               value: totalReviews,
  //                               icon: Icons.reviews,
  //                             ),
  //                           ],
  //                         ),
  //                       ),

  //                       const SizedBox(height: 22),

  //                       // ================= PLATFORM TOTALS =================
  //                       _sectionTitle("Platform Clicks", subtitle: "Totals"),
  //                       if (_platformTotals.isEmpty)
  //                         _emptyBox("No platform click data found.")
  //                       else
  //                         SizedBox(
  //                           height: 110,
  //                           child: ListView.builder(
  //                             scrollDirection: Axis.horizontal,
  //                             itemCount: _platformTotals.length,
  //                             itemBuilder: (context, index) {
  //                               final item = _platformTotals[index];
  //                               final platform =
  //                                   (item["platform"] ?? "-").toString();
  //                               final clicks =
  //                                   (item["total_clicks"] ?? "0").toString();
  //                               final unique =
  //                                   (item["unique_users"] ?? 0).toString();

  //                               return Container(
  //                                 width: 160,
  //                                 padding: const EdgeInsets.all(14),
  //                                 margin: const EdgeInsets.only(right: 12),
  //                                 decoration: BoxDecoration(
  //                                   color: cs.surfaceContainerHighest
  //                                       .withOpacity(0.3),
  //                                   borderRadius: BorderRadius.circular(16),
  //                                   border: Border.all(
  //                                       color:
  //                                           cs.outlineVariant.withOpacity(0.5)),
  //                                 ),
  //                                 child: Column(
  //                                   crossAxisAlignment:
  //                                       CrossAxisAlignment.start,
  //                                   children: [
  //                                     Row(
  //                                       children: [
  //                                         Icon(
  //                                           _platformIcon(platform),
  //                                           size: 18,
  //                                           color:
  //                                               cs.onSurface.withOpacity(0.8),
  //                                         ),
  //                                         const SizedBox(width: 8),
  //                                         Expanded(
  //                                           child: Text(
  //                                             platform.toUpperCase(),
  //                                             maxLines: 1,
  //                                             overflow: TextOverflow.ellipsis,
  //                                             style: const TextStyle(
  //                                               fontSize: 13,
  //                                               fontWeight: FontWeight.w800,
  //                                             ),
  //                                           ),
  //                                         ),
  //                                       ],
  //                                     ),
  //                                     const SizedBox(height: 10),
  //                                     Text(
  //                                       "$clicks clicks",
  //                                       style: const TextStyle(
  //                                         fontSize: 16,
  //                                         fontWeight: FontWeight.w900,
  //                                       ),
  //                                     ),
  //                                     const SizedBox(height: 4),
  //                                     Text(
  //                                       "$unique unique users",
  //                                       style: TextStyle(
  //                                         fontSize: 12,
  //                                         color: cs.onSurface.withOpacity(0.7),
  //                                         fontWeight: FontWeight.w600,
  //                                       ),
  //                                     ),
  //                                   ],
  //                                 ),
  //                               );
  //                             },
  //                           ),
  //                         ),

  //                       const SizedBox(height: 22),

  //                       // ================= VIEWERS =================
  //                       _sectionTitle("Profile Viewers"),
  //                       if (_viewers.isEmpty)
  //                         _emptyBox("No viewers found.")
  //                       else
  //                         SizedBox(
  //                           height: 140,
  //                           child: ListView.builder(
  //                             controller: _viewersScroll,
  //                             scrollDirection: Axis.horizontal,
  //                             itemCount: _viewers.length + 1,
  //                             itemBuilder: (context, index) {
  //                               // loader card at end
  //                               if (index == _viewers.length) {
  //                                 if (_loadingMoreViewers) {
  //                                   return Container(
  //                                     width: 120,
  //                                     alignment: Alignment.center,
  //                                     child: const CircularProgressIndicator(),
  //                                   );
  //                                 }
  //                                 if (_viewersHasNext) {
  //                                   return Container(
  //                                     width: 140,
  //                                     alignment: Alignment.center,
  //                                     child: Text(
  //                                       "Scroll for more →",
  //                                       style: TextStyle(
  //                                         fontSize: 12,
  //                                         color: cs.onSurface.withOpacity(0.6),
  //                                         fontWeight: FontWeight.w700,
  //                                       ),
  //                                     ),
  //                                   );
  //                                 }
  //                                 return const SizedBox(width: 10);
  //                               }

  //                               return _viewerCard(_viewers[index]);
  //                             },
  //                           ),
  //                         ),

  //                       const SizedBox(height: 22),

  //                       // ================= CLICKERS =================
  //                       _sectionTitle("Platform Clickers"),
  //                       if (_clickers.isEmpty)
  //                         _emptyBox("No clickers found.")
  //                       else
  //                         SizedBox(
  //                           height: 150,
  //                           child: ListView.builder(
  //                             controller: _clickersScroll,
  //                             scrollDirection: Axis.horizontal,
  //                             itemCount: _clickers.length + 1,
  //                             itemBuilder: (context, index) {
  //                               if (index == _clickers.length) {
  //                                 if (_loadingMoreClickers) {
  //                                   return Container(
  //                                     width: 120,
  //                                     alignment: Alignment.center,
  //                                     child: const CircularProgressIndicator(),
  //                                   );
  //                                 }
  //                                 if (_clickersHasNext) {
  //                                   return Container(
  //                                     width: 140,
  //                                     alignment: Alignment.center,
  //                                     child: Text(
  //                                       "Scroll for more →",
  //                                       style: TextStyle(
  //                                         fontSize: 12,
  //                                         color: cs.onSurface.withOpacity(0.6),
  //                                         fontWeight: FontWeight.w700,
  //                                       ),
  //                                     ),
  //                                   );
  //                                 }
  //                                 return const SizedBox(width: 10);
  //                               }

  //                               return _clickerCard(_clickers[index]);
  //                             },
  //                           ),
  //                         ),

  //                       const SizedBox(height: 18),
  //                     ],
  //                   ),
  //                 ),
  //               ),
  //   );
  // }

  // ... (keep all imports and initial code until the BUILD method)

// ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final avgRating = (_ratingData?["average_rating"] ?? 0).toString();
    final totalReviews = (_ratingData?["total_reviews"] ?? 0).toString();

    // Get screen width for responsive grid
    final screenWidth = MediaQuery.of(context).size.width;
    // Calculate card width based on screen width with proper padding
    final cardWidth = (screenWidth - 32 - 12) /
        2; // 32 for horizontal padding, 12 for gap between cards

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0.6,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          "Analytics",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _initLoad,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _initLoad,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ================= TOP STATS - 2x2 GRID =================
                        _sectionTitle("Overview"),
                        Container(
                          margin: const EdgeInsets.only(bottom: 22),
                          child: Wrap(
                            spacing: 12, // horizontal gap between cards
                            runSpacing: 12, // vertical gap between rows
                            children: [
                              SizedBox(
                                width: cardWidth,
                                child: _statCard(
                                  title: "Total Views",
                                  value: _totalViews.toString(),
                                  icon: Icons.remove_red_eye,
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _statCard(
                                  title: "Total Time",
                                  value: _formatSeconds(_totalTimeSeconds),
                                  icon: Icons.timer,
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _statCard(
                                  title: "Rating",
                                  value: avgRating,
                                  icon: Icons.star,
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _statCard(
                                  title: "Reviews",
                                  value: totalReviews,
                                  icon: Icons.reviews,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ================= PLATFORM TOTALS =================
                        _sectionTitle("Platform Clicks", subtitle: "Totals"),
                        if (_platformTotals.isEmpty)
                          _emptyBox("No platform click data found.")
                        else
                          SizedBox(
                            height: 110,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _platformTotals.length,
                              itemBuilder: (context, index) {
                                final item = _platformTotals[index];
                                final platform =
                                    (item["platform"] ?? "-").toString();
                                final clicks =
                                    (item["total_clicks"] ?? "0").toString();
                                final unique =
                                    (item["unique_users"] ?? 0).toString();

                                return Container(
                                  width: 160,
                                  padding: const EdgeInsets.all(14),
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerHighest
                                        .withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color:
                                            cs.outlineVariant.withOpacity(0.5)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            _platformIcon(platform),
                                            size: 18,
                                            color:
                                                cs.onSurface.withOpacity(0.8),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              platform.toUpperCase(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        "$clicks clicks",
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "$unique unique users",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: cs.onSurface.withOpacity(0.7),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),

                        const SizedBox(height: 22),

                        // ================= VIEWERS =================
                        _sectionTitle("Profile Viewers"),
                        if (_viewers.isEmpty)
                          _emptyBox("No viewers found.")
                        else
                          SizedBox(
                            height: 140,
                            child: ListView.builder(
                              controller: _viewersScroll,
                              scrollDirection: Axis.horizontal,
                              itemCount: _viewers.length + 1,
                              itemBuilder: (context, index) {
                                // loader card at end
                                if (index == _viewers.length) {
                                  if (_loadingMoreViewers) {
                                    return Container(
                                      width: 120,
                                      alignment: Alignment.center,
                                      child: const CircularProgressIndicator(),
                                    );
                                  }
                                  if (_viewersHasNext) {
                                    return Container(
                                      width: 140,
                                      alignment: Alignment.center,
                                      child: Text(
                                        "Scroll for more →",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: cs.onSurface.withOpacity(0.6),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox(width: 10);
                                }

                                return _viewerCard(_viewers[index]);
                              },
                            ),
                          ),

                        const SizedBox(height: 22),

                        // ================= CLICKERS =================
                        _sectionTitle("Platform Clickers"),
                        if (_clickers.isEmpty)
                          _emptyBox("No clickers found.")
                        else
                          SizedBox(
                            height: 150,
                            child: ListView.builder(
                              controller: _clickersScroll,
                              scrollDirection: Axis.horizontal,
                              itemCount: _clickers.length + 1,
                              itemBuilder: (context, index) {
                                if (index == _clickers.length) {
                                  if (_loadingMoreClickers) {
                                    return Container(
                                      width: 120,
                                      alignment: Alignment.center,
                                      child: const CircularProgressIndicator(),
                                    );
                                  }
                                  if (_clickersHasNext) {
                                    return Container(
                                      width: 140,
                                      alignment: Alignment.center,
                                      child: Text(
                                        "Scroll for more →",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: cs.onSurface.withOpacity(0.6),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox(width: 10);
                                }

                                return _clickerCard(_clickers[index]);
                              },
                            ),
                          ),

                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
                ),
    );
  }
}
