import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:gridcard/widgets/top_alert.dart';
import 'package:gridcard/core/utils/error_formatter.dart';

class KeywordsTab extends StatefulWidget {
  final Map<String, dynamic>? userDetails;
  final VoidCallback? onSaved;
  const KeywordsTab({super.key, this.userDetails, this.onSaved});

  @override
  State<KeywordsTab> createState() => _KeywordsTabState();
}

class _KeywordsTabState extends State<KeywordsTab> {
  static const String _baseUrl = AppConfig.apiBaseUrl;

  bool isLoading = false;

  List<Map<String, dynamic>> keywords = [];

  // Static cache for keywords
  static List<Map<String, dynamic>> _cachedKeywords = [];
  static int? _cachedUserId;
  static DateTime? _lastFetchTime;

  bool get _shouldRefresh {
    if (_cachedKeywords.isEmpty || _lastFetchTime == null) return true;
    return DateTime.now().difference(_lastFetchTime!) > const Duration(minutes: 60);
  }

  // ================= HEADERS =================
  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ================= GET KEYWORDS =================
  Future<void> fetchKeywords() async {
    final userIdId = await UserStorageService().getUserId();
    if (userIdId == null) {
      TopAlert.show(context, "User not found. Please login again.",
          isError: true);
      return;
    }

    if (!_shouldRefresh && _cachedKeywords.isNotEmpty && _cachedUserId == userIdId) {
      if (mounted) setState(() => keywords = List.from(_cachedKeywords));
      return;
    }

    try {
      setState(() => isLoading = true);

      final headers = await _getHeaders();
      final userId = userIdId;

      final url = Uri.parse("$_baseUrl/user-keywords/$userId");
      final response = await http.get(url, headers: headers);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data["status"] == true) {
        final List list = data["data"] ?? [];

        setState(() {
          keywords = list
              .map((e) => {
                    "id": e["id"],
                    "keywords": e["keywords"],
                  })
              .toList();
          _cachedKeywords = List.from(keywords);
          _cachedUserId = userIdId;
        });
      } else {
        final msg = data["message"] ?? "Failed to fetch keywords";
        TopAlert.show(context, msg, isError: true);
      }
    } catch (e) {
      TopAlert.show(context, ErrorFormatter.format(e), isError: true);
    } finally {
      setState(() {
        isLoading = false;
        _lastFetchTime = DateTime.now();
      });
    }
  }

  // ================= CREATE KEYWORD =================
  Future<void> createKeyword(String title) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse("$_baseUrl/master-user-keywords");

      final body = jsonEncode({
        "title": title,
      });

      final response = await http.post(url, headers: headers, body: body);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final msg = data["message"] ?? "Keyword saved successfully";

        TopAlert.show(context, msg, isSuccess: true);

        // refresh list
        _lastFetchTime = null;
        await fetchKeywords();
        widget.onSaved?.call();
      } else {
        final msg = data["message"] ?? "Something went wrong";
        TopAlert.show(context, msg, isError: true);
      }
    } catch (e) {
      TopAlert.show(context, ErrorFormatter.format(e), isError: true);
    }
  }

  // ================= UPDATE KEYWORD =================
  Future<void> updateKeyword(int id, String title) async {
    try {
      final headers = await _getHeaders();

      // ✅ if your backend uses PUT/PATCH
      final url = Uri.parse("$_baseUrl/updated-user-keywords/$id");

      final body = jsonEncode({
        "title": title,
      });

      // Laravel me mostly PUT/PATCH hota hai
      final response = await http.put(url, headers: headers, body: body);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final msg = data["message"] ?? "Keyword updated successfully";

        TopAlert.show(context, msg, isSuccess: true);

        _lastFetchTime = null;
        await fetchKeywords();
        widget.onSaved?.call();
      } else {
        final msg = data["message"] ?? "Update failed";
        TopAlert.show(context, msg, isError: true);
      }
    } catch (e) {
      TopAlert.show(context, ErrorFormatter.format(e), isError: true);
    }
  }

  // ================= DELETE KEYWORD =================
  Future<void> deleteKeyword(int id) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse("$_baseUrl/master-user-keywords/$id");

      final response = await http.delete(url, headers: headers);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final msg = data["message"] ?? "Keyword deleted successfully";

        TopAlert.show(context, msg, isSuccess: true);

        // remove instantly from UI
        setState(() {
          keywords.removeWhere((item) => item["id"] == id);
          _cachedKeywords = List.from(keywords);
        });
        widget.onSaved?.call();
      } else {
        final msg = data["message"] ?? "Delete failed";
        TopAlert.show(context, msg, isError: true);
      }
    } catch (e) {
      TopAlert.show(context, ErrorFormatter.format(e), isError: true);
    }
  }

  // ================= ADD / EDIT MODAL =================
  void openKeywordModal({bool isEdit = false, Map<String, dynamic>? keyword}) {
    final TextEditingController keywordController = TextEditingController(
      text: isEdit ? (keyword?["keywords"] ?? "") : "",
    );

    bool saving = false;

    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: !saving,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(isEdit ? "Edit Keyword" : "Add Keyword"),
              content: TextField(
                controller: keywordController,
                enabled: !saving,
                decoration: InputDecoration(
                  hintText: "Enter keyword",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              actions: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    side: BorderSide.none, // ✅ border remove
                  ),
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                // ElevatedButton(
                //   onPressed: saving
                //       ? null
                //       : () async {
                //           final title = keywordController.text.trim();

                //           if (title.isEmpty) {
                //             ScaffoldMessenger.of(context).showSnackBar(
                //               const SnackBar(
                //                   content: Text("Please enter keyword")),
                //             );
                //             return;
                //           }

                //           setModalState(() => saving = true);

                //           if (isEdit) {
                //             // await updateKeyword(keyword["id"], title);
                //             await updateKeyword(keyword!["id"], title);
                //           } else {
                //             await createKeyword(title);
                //           }

                //           setModalState(() => saving = false);

                //           Navigator.pop(context);
                //         },
                //   child: saving
                //       ? const SizedBox(
                //           height: 20,
                //           width: 20,
                //           child: CircularProgressIndicator(
                //             strokeWidth: 2.5,
                //             color: Colors.white,
                //           ),
                //         )
                //       : Text(isEdit ? "Update" : "Save"),
                // ),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                          final title = keywordController.text.trim();

                          if (title.isEmpty) {
                            TopAlert.show(context, "Please enter keyword",
                                isError: true);
                            return;
                          }

                          setModalState(() => saving = true);

                          if (isEdit) {
                            await updateKeyword(keyword!["id"], title);
                          } else {
                            await createKeyword(title);
                          }

                          setModalState(() => saving = false);

                          Navigator.pop(context);
                        },
                  child: saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(isEdit ? "Save" : "Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ================= DELETE CONFIRM =================
  void confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Confirm Delete"),
          content: const Text("Are you sure you want to delete this keyword?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await deleteKeyword(id);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  // ================= INIT =================
  @override
  void initState() {
    super.initState();
    fetchKeywords();
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : keywords.isEmpty
              ? const Center(
                  child: Text(
                    "No keywords added",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: keywords.length,
                  itemBuilder: (context, index) {
                    final item = keywords[index];

                    return Card(
                      // shape: RoundedRectangleBorder(
                      //   borderRadius: BorderRadius.circular(14),
                      // ),
                      elevation: 0,
                      color: isDark
                          ? colorScheme.surfaceContainerHighest
                          : colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        title: Text(item["keywords"] ?? ""),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == "edit") {
                              openKeywordModal(isEdit: true, keyword: item);
                            } else if (value == "delete") {
                              confirmDelete(item["id"]);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: "edit",
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 18),
                                  SizedBox(width: 8),
                                  Text("Edit"),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: "delete",
                              child: Row(
                                children: [
                                  Icon(Icons.delete,
                                      size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text("Delete"),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

      // ✅ Bottom Right Add Button
      floatingActionButton: FloatingActionButton(
        onPressed: () => openKeywordModal(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
