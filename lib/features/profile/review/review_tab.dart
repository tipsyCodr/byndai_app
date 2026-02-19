// import 'package:flutter/material.dart';
// import 'package:gridcard/config/app_config.dart';
// import 'package:gridcard/core/services/user_storage_service.dart';
// import 'package:http/http.dart' as http;

// class ReviewTab extends StatefulWidget {
//   final Map<String, dynamic>? userDetails;

//   const ReviewTab({super.key, this.userDetails});

//   @override
//   State<ReviewTab> createState() => _ReviewTabState();
// }

// class _ReviewTabState extends State<ReviewTab> {
//   static const String _baseUrl = AppConfig.apiBaseUrl;
//   // ================= HEADERS =================
//   Future<Map<String, String>> _getHeaders() async {
//     final token = await UserStorageService().getToken();
//     return {
//       'Content-Type': 'application/json',
//       'Accept': 'application/json',
//       if (token != null) 'Authorization': 'Bearer $token',
//     };
//   }

//   @override
//   Widget build(BuildContext context) {
//     return const Center(
//       child: Text(
//         "Review Tab (Stateful)",
//         style: TextStyle(fontSize: 16),
//       ),
//     );
//   }
// }

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:http/http.dart' as http;

class ReviewTab extends StatefulWidget {
  final Map<String, dynamic>? userDetails;

  const ReviewTab({super.key, this.userDetails});

  @override
  State<ReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends State<ReviewTab> {
  static const String _baseUrl = AppConfig.apiBaseUrl;

  bool isLoading = false;
  List reviews = [];

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

    setState(() => isLoading = true);

    try {
      final headers = await _getHeaders();
      final userId = await UserStorageService().getUserId();

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
      if (mounted) setState(() => isLoading = false);
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
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : reviews.isEmpty
              ? _emptyUI()
              : RefreshIndicator(
                  onRefresh: _fetchReviews,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: reviews.length,
                    itemBuilder: (_, i) {
                      final r = reviews[i] as Map<String, dynamic>;

                      final fromUser =
                          (r["from_user"] ?? {}) as Map<String, dynamic>;
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
            Icon(Icons.rate_review, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              "No reviews yet",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              "Jab koi aapko review dega,\nyaha show hoga.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _fetchReviews,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row (User + Rating)
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.blue.shade50,
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : "U",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
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
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _starsRow(rating),
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
                color: Colors.grey.shade800,
              ),
            )
          else
            Text(
              "No message",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),

          const SizedBox(height: 10),

          // Date (optional)
          Text(
            createdAt.isNotEmpty ? createdAt.split("T").first : "",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  // ================= STARS UI =================
  Widget _starsRow(int rating) {
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
          color: isFilled ? Colors.amber : Colors.grey.shade400,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        );
      }),
    );
  }
}
