import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import './event_card.dart';
import 'package:http/http.dart' as http;
import 'create_event_screen.dart';
import 'my_event.dart';

class BusinessEventPage extends StatefulWidget {
  final int? openEventId;
  const BusinessEventPage({super.key, this.openEventId});

  @override
  State<BusinessEventPage> createState() => _BusinessEventPageState();
}

class _BusinessEventPageState extends State<BusinessEventPage> {
  bool isLoading = false;
  List<dynamic> allEvents = []; // All events from API
  List<dynamic> filteredEvents = []; // Events after search filter
  String errorMessage = '';
  String searchQuery = '';
  Timer? _searchDebounce;

  static const String _baseUrl = AppConfig.apiBaseUrl;
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

  // ================= API CALL =================
  Future<void> _fetchEvents() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      final uri = Uri.parse("$_baseUrl/show-event");
      final headers = await _getHeaders();
      final loggedHeaders = Map<String, String>.from(headers);
      if (loggedHeaders['Authorization'] != null) {
        final auth = loggedHeaders['Authorization']!;
        loggedHeaders['Authorization'] =
            auth.length > 24 ? '${auth.substring(0, 16)}...${auth.substring(auth.length - 6)}' : 'Bearer ***';
      }

      final response = await http.get(
        uri,
        headers: headers,
      );

      debugPrint("========== SHOW EVENT API ==========");
      debugPrint("URL: $uri");
      debugPrint("HEADERS: $loggedHeaders");
      debugPrint("STATUS CODE: ${response.statusCode}");
      debugPrint("RAW RESPONSE BODY: ${response.body}");

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        if (jsonData['status'] == true) {
          setState(() {
            allEvents = jsonData['data'] ?? [];
            filteredEvents = List.from(allEvents);

            if (widget.openEventId != null) {
              final index =
                  allEvents.indexWhere((e) => e['id'] == widget.openEventId);

              if (index != -1) {
                final selectedEvent = allEvents[index];
                allEvents.removeAt(index);
                allEvents.insert(0, selectedEvent);

                filteredEvents = List.from(allEvents);
              }
            }
          });

          debugPrint("TOTAL EVENTS FETCHED: ${allEvents.length}");
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

        // Search in user name
        final userName =
            event['created_by_fname']?.toString().toLowerCase() ?? '';
        if (userName.contains(lowerCaseQuery)) return true;

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
    _fetchEvents(); // ✅ page open होते ही call
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ================= REFRESH =================
  void _refreshEvents() async {
    await _fetchEvents();
    // Reset search
    setState(() {
      searchQuery = '';
      filteredEvents = List.from(allEvents);
    });
  }

  // ================= CREATE EVENT BUTTON =================

  void _createEvent() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateEventScreen(
          onEventCreated: _refreshEvents,
        ),
      ),
    ).then((_) => _refreshEvents());
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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Business Events",
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.event, color: colorScheme.onSurface),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MyEventsScreen(),
                ),
              ).then((_) => _refreshEvents());
            },
            tooltip: 'My Events',
          ),
          IconButton(
            icon: isLoading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  )
                : Icon(Icons.refresh, color: colorScheme.onSurface),
            onPressed: isLoading ? null : _refreshEvents,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search/Filter Section
            // Padding(
            //   padding: const EdgeInsets.all(16),
            //   child: Container(
            //     padding: const EdgeInsets.symmetric(horizontal: 16),
            //     decoration: BoxDecoration(
            //       color: isDark
            //           ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
            //           : colorScheme.surfaceContainerHighest.withOpacity(0.1),
            //       borderRadius: BorderRadius.circular(12),
            //       border: Border.all(
            //         color: colorScheme.primary.withOpacity(0.2),
            //         width: 0.5,
            //       ),
            //     ),
            //     child: Row(
            //       children: [
            //         Icon(Icons.search,
            //             color: colorScheme.onSurface.withOpacity(0.6)),
            //         const SizedBox(width: 8),
            //         Expanded(
            //           child: TextField(
            //             controller: TextEditingController(text: searchQuery)
            //               ..selection = TextSelection.collapsed(
            //                 offset: searchQuery.length,
            //               ),
            //             style: TextStyle(color: colorScheme.onSurface),
            //             decoration: InputDecoration(
            //               hintText:
            //                   "Search...",
            //               hintStyle: TextStyle(
            //                   color: colorScheme.onSurface.withOpacity(0.5)),
            //               border: InputBorder.none,
            //               suffixIcon: searchQuery.isNotEmpty
            //                   ? IconButton(
            //                       icon: Icon(Icons.clear,
            //                           color: colorScheme.onSurface
            //                               .withOpacity(0.6)),
            //                       onPressed: _clearSearch,
            //                     )
            //                   : null,
            //             ),
            //             onChanged: _onSearchChanged,
            //           ),
            //         ),
            //       ],
            //     ),
            //   ),
            // ),

            Padding(
              padding: const EdgeInsets.only(
                left: 10,
                right: 10,
                top: 10,
              ),
              child: TextField(
                controller: TextEditingController(text: searchQuery)
                  ..selection = TextSelection.collapsed(
                    offset: searchQuery.length,
                  ),

                style: TextStyle(color: colorScheme.onSurface),

                decoration: InputDecoration(
                  hintText: "Search...",
                  hintStyle: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                  filled: true,
                  fillColor: colorScheme.surface,
                  prefixIcon: Icon(
                    Icons.search,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.close,
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                          onPressed: _clearSearch, // ✅ SAME FUNCTION
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 0.2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 0.8,
                    ),
                  ),
                ),

                onChanged: _onSearchChanged, // ✅ SAME FUNCTION
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
                        color: colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${filteredEvents.length} events found',
                      style: TextStyle(
                        color: colorScheme.primary,
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
              child: isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: colorScheme.primary,
                            strokeWidth: 2,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Loading events...",
                            style: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.6),
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
                              Icon(
                                Icons.error_outline,
                                color: colorScheme.error,
                                size: 60,
                              ),
                              const SizedBox(height: 16),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 32),
                                child: Text(
                                  errorMessage,
                                  style: TextStyle(
                                    color:
                                        colorScheme.onSurface.withOpacity(0.6),
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: _refreshEvents,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorScheme.primary,
                                  foregroundColor: colorScheme.onPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                                child: const Text("Try Again"),
                              ),
                            ],
                          ),
                        )
                      : filteredEvents.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    searchQuery.isNotEmpty
                                        ? Icons.search_off
                                        : Icons.event_busy,
                                    color:
                                        colorScheme.onSurface.withOpacity(0.3),
                                    size: 80,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    searchQuery.isNotEmpty
                                        ? 'No events found for "$searchQuery"'
                                        : 'No events available',
                                    style: TextStyle(
                                      color: colorScheme.onSurface
                                          .withOpacity(0.6),
                                      fontSize: 16,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  if (searchQuery.isNotEmpty)
                                    ElevatedButton(
                                      onPressed: _clearSearch,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            colorScheme.surfaceContainerHighest,
                                        foregroundColor: colorScheme.onSurface,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: const Text("Clear Search"),
                                    ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              color: colorScheme.primary,
                              backgroundColor: colorScheme.surface,
                              onRefresh: () async {
                                await _fetchEvents();
                                return;
                              },
                              child: ListView.builder(
                                padding: const EdgeInsets.only(bottom: 80),
                                itemCount: filteredEvents.length,
                                itemBuilder: (context, index) {
                                  return EventCard(
                                    event: filteredEvents[index],
                                    baseImageUrl: _imageBaseUrl,
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: FloatingActionButton(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          onPressed: _createEvent,
          tooltip: 'Create Event',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
