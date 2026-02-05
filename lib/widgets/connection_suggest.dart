


import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:http/http.dart' as http;

class ConnectionSuggest extends StatefulWidget {
  const ConnectionSuggest({super.key});

  @override
  State<ConnectionSuggest> createState() => _ConnectionSuggestState();
}

class _ConnectionSuggestState extends State<ConnectionSuggest> {
  final PageController _pageController = PageController(viewportFraction: .6);

  static const String _baseUrl = AppConfig.apiBaseUrl;

  int? _userId;

  bool _isLoading = false;
  bool _isFirstLoad = true;

  int _currentPage = 1;
  int _lastPage = 1;

  final List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _initAndLoad();

    _pageController.addListener(() {
      // Jab user end ke paas aajaye tab next page load karo
      final currentPage = _pageController.page ?? 0;

      // last item ke close aate hi load
      if (currentPage >= (_users.length - 3) && !_isLoading) {
        _loadNextPage();
      }
    });
  }

  Future<void> _initAndLoad() async {
    final session = await UserStorageService().loadSession();
    final userId = session.user?.id;

    if (userId == null) return;

    setState(() {
      _userId = userId;
    });

    await _fetchUsers(page: 1);
  }

  Future<void> _fetchUsers({required int page}) async {
    if (_userId == null) return;

    try {
      setState(() {
        _isLoading = true;
      });

      final uri = Uri.parse("$_baseUrl/users/filter-list?page=$page");

      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "user_id": _userId,
        }),
      );

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 && jsonData["status"] == true) {
        final List data = jsonData["data"] ?? [];

        final pagination = jsonData["pagination"] ?? {};
        final int currentPage = pagination["current_page"] ?? page;
        final int lastPage = pagination["last_page"] ?? page;

        final newUsers = data.map((e) => Map<String, dynamic>.from(e)).toList();

        setState(() {
          if (page == 1) {
            _users.clear();
          }
          _users.addAll(newUsers);

          _currentPage = currentPage;
          _lastPage = lastPage;

          _isFirstLoad = false;
        });
      } else {
        setState(() => _isFirstLoad = false);
      }
    } catch (e) {
      setState(() => _isFirstLoad = false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoading) return;
    if (_currentPage >= _lastPage) return;

    await _fetchUsers(page: _currentPage + 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // First loading
    if (_isFirstLoad) {
      return const SizedBox(
        height: 150,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // No data
    if (_users.isEmpty) {
      return const SizedBox(
        height: 150,
        child: Center(
          child: Text("No suggestions found"),
        ),
      );
    }

    return SizedBox(
      height: 150,
      child: PageView.builder(
        controller: _pageController,
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          final userName = user["fname"] ?? "Unknown";

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surfaceContainerHighest
                  : Colors.grey[100],
              border: Border.all(
                color: colorScheme.onSurface.withOpacity(0.05),
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_circle,
                  size: 60,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 8),

                // ✅ Name -> user_name
                Text(
                  userName.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? colorScheme.onSurface : colorScheme.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                Text(
                  'Occupation',
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),

                // Optional: loading indicator at end (agar next page load ho raha ho)
                if (_isLoading && index == _users.length - 1)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
