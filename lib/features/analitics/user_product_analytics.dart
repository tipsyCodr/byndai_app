import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:http/http.dart' as http;

class UserProductAnalyticsWidget extends StatefulWidget {
  final int profileUserId;

  const UserProductAnalyticsWidget({
    super.key,
    required this.profileUserId,
  });

  @override
  State<UserProductAnalyticsWidget> createState() =>
      _UserProductAnalyticsWidgetState();
}

class _UserProductAnalyticsWidgetState
    extends State<UserProductAnalyticsWidget> {
  static const String _baseUrl = AppConfig.apiBaseUrl;

  List analyticsData = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAnalytics();
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> fetchAnalytics() async {
    try {
      final headers = await _getHeaders();

      final response = await http.post(
        Uri.parse("$_baseUrl/profile-product-clicks"),
        headers: headers,
        body: jsonEncode({
          "profile_user_id": widget.profileUserId,
        }),
      );

      final data = jsonDecode(response.body);

      if (data['status'] == true) {
        setState(() {
          analyticsData = data['data'];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (analyticsData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        child: Text("No product analytics found"),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          "Product Click Analytics",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        ListView.builder(
          itemCount: analyticsData.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final item = analyticsData[index];

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                leading: const Icon(Icons.shopping_bag),
                title: Text(
                  item['product_name'] ?? 'No Product',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  "Viewer: ${item['viewer_name'] ?? 'Unknown'}",
                ),
                trailing: Text(
                  "${item['click_count']} clicks",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
