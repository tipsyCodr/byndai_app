import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'event_card.dart';
import 'package:http/http.dart' as http;

class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  bool isLoading = false;
  List<dynamic> allEvents = []; // All events from API
  List<dynamic> filteredEvents = []; // Events after search filter
  String errorMessage = '';
  String searchQuery = '';
  Timer? _searchDebounce;
  int? _currentUserId;

  static const String _baseUrl = AppConfig.apiBaseUrl;
  // static const String _imageBaseUrl =
  //     "https://byndai.in/";

  static const String _imageBaseUrl = AppConfig.imageBaseUrl;

  // ================= HEADERS =================
  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ================= GET USER ID =================
  Future<void> _getUserId() async {
    final userId = await UserStorageService().getUserId();
    setState(() {
      _currentUserId = userId;
    });
  }

  // ================= API CALL =================
  Future<void> _fetchUserEvents() async {
    if (_currentUserId == null) {
      await _getUserId();
    }

    if (_currentUserId == null) {
      setState(() {
        errorMessage = 'Unable to get user information';
        isLoading = false;
      });
      return;
    }

    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      final uri = Uri.parse("$_baseUrl/user-events/$_currentUserId");

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      debugPrint("========== USER EVENTS API ==========");
      debugPrint("URL: $uri");
      debugPrint("USER ID: $_currentUserId");
      debugPrint("STATUS CODE: ${response.statusCode}");

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        if (jsonData['status'] == true) {
          setState(() {
            allEvents = jsonData['data'] ?? [];
            filteredEvents = List.from(allEvents); // Initially show all events
          });
          debugPrint("TOTAL USER EVENTS FETCHED: ${allEvents.length}");
        } else {
          setState(() {
            errorMessage = jsonData['message'] ?? 'Failed to fetch events';
          });
          debugPrint("API ERROR: ${jsonData['message']}");
        }
      } else {
        try {
          final error = jsonDecode(response.body);
          setState(() {
            errorMessage = error['message'] ??
                'Failed to fetch events. Status: ${response.statusCode}';
          });
        } catch (e) {
          setState(() {
            errorMessage = 'Server error: ${response.statusCode}';
          });
        }
        debugPrint("API ERROR: ${response.body}");
      }

      debugPrint("====================================");
    } catch (e) {
      setState(() {
        errorMessage = 'Network error: $e';
      });
      debugPrint("EXCEPTION: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ================= SEARCH FUNCTION =================
  void _filterEvents(String query) {
    if (query.isEmpty) {
      setState(() {
        filteredEvents = List.from(allEvents);
      });
      return;
    }

    final lowerCaseQuery = query.toLowerCase();
    setState(() {
      filteredEvents = allEvents.where((event) {
        // Search in title
        final title = event['title']?.toString().toLowerCase() ?? '';
        if (title.contains(lowerCaseQuery)) return true;

        // Search in description
        final description =
            event['description']?.toString().toLowerCase() ?? '';
        if (description.contains(lowerCaseQuery)) return true;

        // Search in location
        final location = event['location']?.toString().toLowerCase() ?? '';
        if (location.contains(lowerCaseQuery)) return true;

        // Search in event type
        final eventType = event['event_type']?.toString().toLowerCase() ?? '';
        if (eventType.contains(lowerCaseQuery)) return true;

        // Search in industry
        final industryTitle =
            event['industry']?['title']?.toString().toLowerCase() ?? '';
        if (industryTitle.contains(lowerCaseQuery)) return true;

        return false;
      }).toList();
    });
  }

  // ================= DEBOUNCED SEARCH =================
  void _onSearchChanged(String value) {
    setState(() {
      searchQuery = value;
    });

    // Cancel previous timer
    if (_searchDebounce?.isActive ?? false) {
      _searchDebounce!.cancel();
    }

    // Start new timer for debouncing
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _filterEvents(value);
    });
  }

  // ================= INIT =================
  @override
  void initState() {
    super.initState();
    _getUserId().then((_) {
      _fetchUserEvents(); // ✅ user ID मिलने के बाद events fetch करें
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ================= REFRESH =================
  void _refreshEvents() async {
    await _fetchUserEvents();
    // Reset search
    setState(() {
      searchQuery = '';
      filteredEvents = List.from(allEvents);
    });
  }

  // ================= CLEAR SEARCH =================
  void _clearSearch() {
    setState(() {
      searchQuery = '';
    });
    _filterEvents('');
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "My Events",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh, color: Colors.white),
            onPressed: isLoading ? null : _refreshEvents,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: SizedBox(
          height: size.height,
          width: size.width,
          child: Column(
            children: [
              // Search/Filter Section
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(text: searchQuery)
                            ..selection = TextSelection.collapsed(
                              offset: searchQuery.length,
                            ),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Search my events...",
                            hintStyle: TextStyle(color: Colors.grey[500]),
                            border: InputBorder.none,
                            suffixIcon: searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear,
                                        color: Colors.grey),
                                    onPressed: _clearSearch,
                                  )
                                : null,
                          ),
                          onChanged: _onSearchChanged,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Search results info
              if (searchQuery.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Search results for "$searchQuery"',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${filteredEvents.length} events found',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 8),

              // Events List
              Expanded(
                child: _currentUserId == null
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              color: Colors.blue,
                              strokeWidth: 2,
                            ),
                            SizedBox(height: 16),
                            Text(
                              "Loading user information...",
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : isLoading
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  color: Colors.blue,
                                  strokeWidth: 2,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  "Loading your events...",
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : errorMessage.isNotEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: Colors.red,
                                      size: 60,
                                    ),
                                    const SizedBox(height: 16),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 32),
                                      child: Text(
                                        errorMessage,
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 16,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    ElevatedButton(
                                      onPressed: _refreshEvents,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 12,
                                        ),
                                      ),
                                      child: const Text(
                                        "Try Again",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : filteredEvents.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          searchQuery.isNotEmpty
                                              ? Icons.search_off
                                              : Icons.event_note,
                                          color: Colors.grey,
                                          size: 80,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          searchQuery.isNotEmpty
                                              ? 'No events found for "$searchQuery"'
                                              : 'You haven\'t created any events yet',
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 16,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 8),
                                        if (searchQuery.isNotEmpty)
                                          ElevatedButton(
                                            onPressed: _clearSearch,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.grey[800],
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: const Text(
                                              "Clear Search",
                                              style: TextStyle(
                                                  color: Colors.white),
                                            ),
                                          ),
                                        if (!searchQuery.isNotEmpty)
                                          const SizedBox(height: 16),
                                        if (!searchQuery.isNotEmpty)
                                          Text(
                                            'Create your first event from the main events page',
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 12,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                      ],
                                    ),
                                  )
                                : RefreshIndicator(
                                    color: Colors.blue,
                                    backgroundColor: Colors.black,
                                    onRefresh: () async {
                                      await _fetchUserEvents();
                                      return;
                                    },
                                    child: ListView.builder(
                                      padding:
                                          const EdgeInsets.only(bottom: 80),
                                      itemCount: filteredEvents.length,
                                      itemBuilder: (context, index) {
                                        return EventCard(
                                          event: filteredEvents[index],
                                          baseImageUrl: _imageBaseUrl,
                                          isMyEvent:
                                              true, // ✅ This enables the 3 dots menu
                                          onDeleted:
                                              _refreshEvents, // Refresh when deleted
                                          onUpdated:
                                              _refreshEvents, // ✅ New: Refresh when updated
                                        );
                                      },
                                    ),
                                  ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
