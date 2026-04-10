import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:gridcard/widgets/glass_box.dart';

class ReviewTab extends StatefulWidget {
  final Map<String, dynamic>? userDetails;
  final VoidCallback? onSaved;

  const ReviewTab({super.key, this.userDetails, this.onSaved});

  @override
  State<ReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends State<ReviewTab> {
  static const String _baseUrl = AppConfig.apiBaseUrl;

  bool isLoading = false;
  List reviews = [];

  // Static cache
  static List _cachedReviews = [];
  static int? _cachedUserId;
  static DateTime? _lastFetchTime;

  bool get _shouldRefresh {
    if (_cachedReviews.isEmpty || _lastFetchTime == null) return true;
    return DateTime.now().difference(_lastFetchTime!) > const Duration(minutes: 60);
  }

  // ================= HEADERS =================
  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ================= FETCH REVIEWS =================
  Future<void> _fetchReviews() async {
    if (isLoading) return;

    final userIdId = await UserStorageService().getUserId();
    if (!_shouldRefresh && _cachedReviews.isNotEmpty && _cachedUserId == userIdId) {
      if (mounted) setState(() => reviews = List.from(_cachedReviews));
      return;
    }

    setState(() => isLoading = true);

    try {
      final headers = await _getHeaders();
      final userId = userIdId;

      if (userId == null) {
        throw "User not logged in (userId null)";
      }

      final url = Uri.parse("$_baseUrl/user-reviews/$userId");

      final res = await http.get(url, headers: headers);

      final jsonData = jsonDecode(res.body);

      if (res.statusCode == 200 && jsonData["status"] == true) {
        final dataObj = jsonData["data"];

        if (dataObj != null && dataObj["data"] != null) {
          reviews = dataObj["data"] as List;
        } else {
          reviews = [];
        }
        _cachedReviews = List.from(reviews);
        _cachedUserId = userIdId;

        if (mounted) setState(() {});
      } else {
        throw (jsonData["message"] ?? "Reviews load failed");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          _lastFetchTime = DateTime.now();
        });
      }
    }
  }

  // ================= INIT =================
  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      // backgroundColor: Colors.grey.shade100,
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : reviews.isEmpty
              ? _emptyUI()
              : RefreshIndicator(
                  onRefresh: () async {
                    _lastFetchTime = null;
                    await _fetchReviews();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: reviews.length,
                    itemBuilder: (_, i) {
                      final r = reviews[i] as Map<String, dynamic>;

                      final fromUser = Map<String, dynamic>.from(r["from_user"] ?? {});
                      final username =
                          (fromUser["user_name"] ?? "Unknown User").toString();

                      final message = (r["message"] ?? "").toString();
                      final rating = int.tryParse(r["rating"].toString()) ?? 0;

                      return _reviewCard(
                        username: username,
                        rating: rating,
                        message: message,
                        createdAt: (r["created_at"] ?? "").toString(),
                      );
                    },
                  ),
                ),
    );
  }

  // ================= EMPTY UI =================
  Widget _emptyUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rate_review, size: 60, color: Theme.of(context).disabledColor.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              "No reviews yet",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              "Jab koi aapko review dega,\nyaha show hoga.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).disabledColor),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () {
                _lastFetchTime = null;
                _fetchReviews();
              },
              icon: const Icon(Icons.refresh),
              label: const Text("Reload"),
            ),
          ],
        ),
      ),
    );
  }

  // ================= REVIEW CARD =================
  Widget _reviewCard({
    required String username,
    required int rating,
    required String message,
    required String createdAt,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassBox(
        padding: const EdgeInsets.all(14),
        borderRadius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row (User + Rating)
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    username.isNotEmpty ? username[0].toUpperCase() : "U",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface),
                      ),
                      const SizedBox(height: 4),
                      _starsRow(rating, colorScheme),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Message
            if (message.trim().isNotEmpty)
              Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: colorScheme.onSurface,
                ),
              )
            else
              Text(
                "No message",
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            const SizedBox(height: 10),
            // Date (optional)
            Text(
              createdAt.isNotEmpty ? createdAt.split("T").first : "",
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
            ),
          ],
        ),
      ),
    );
  }

  // ================= STARS UI =================
  Widget _starsRow(int rating, ColorScheme colorScheme) {
    // rating 0-5 clamp
    int safeRating = rating;
    if (safeRating < 0) safeRating = 0;
    if (safeRating > 5) safeRating = 5;

    return Row(
      children: List.generate(5, (index) {
        final isFilled = index < safeRating;

        return Icon(
          Icons.star,
          size: 18,
          color: isFilled ? Colors.amber : colorScheme.onSurface.withOpacity(0.1),
          shadows: isFilled ? [
            Shadow(
              color: Colors.amber.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 0),
            )
          ] : null,
        );
      }),
    );
  }
}
