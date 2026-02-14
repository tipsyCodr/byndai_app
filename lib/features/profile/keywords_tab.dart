

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:http/http.dart' as http;

class KeywordsTab extends StatefulWidget {
  final Map<String, dynamic>? userDetails;
  const KeywordsTab({super.key, this.userDetails});

  @override
  State<KeywordsTab> createState() => _KeywordsTabState();
}

class _KeywordsTabState extends State<KeywordsTab> {
  static const String _baseUrl = AppConfig.apiBaseUrl;

  bool isLoading = false;

  List<Map<String, dynamic>> keywords = [];

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
    try {
      setState(() => isLoading = true);

      final headers = await _getHeaders();

      final userId = await UserStorageService().getUserId();
      if (userId == null) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User not found. Please login again.")),
        );
        return;
      }

      final url = Uri.parse("$_baseUrl/user-keywords/$userId");
      final response = await http.get(url, headers: headers);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data["status"] == true) {
        final List list = data["data"] ?? [];

        setState(() {
          keywords = list.map((e) => {
                "id": e["id"],
                "keywords": e["keywords"],
              }).toList();
        });
      } else {
        final msg = data["message"] ?? "Failed to fetch keywords";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => isLoading = false);
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );

        // refresh list
        await fetchKeywords();
      } else {
        final msg = data["message"] ?? "Something went wrong";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );

        await fetchKeywords();
      } else {
        final msg = data["message"] ?? "Update failed";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );

        // remove instantly from UI
        setState(() {
          keywords.removeWhere((item) => item["id"] == id);
        });
      } else {
        final msg = data["message"] ?? "Delete failed";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  // ================= ADD / EDIT MODAL =================
  void openKeywordModal({bool isEdit = false, Map<String, dynamic>? keyword}) {
    final TextEditingController keywordController = TextEditingController(
      text: isEdit ? (keyword?["keywords"] ?? "") : "",
    );

    bool saving = false;

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
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final title = keywordController.text.trim();

                          if (title.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("Please enter keyword")),
                            );
                            return;
                          }

                          setModalState(() => saving = true);

                          if (isEdit) {
                            // await updateKeyword(keyword["id"], title);
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
                      : Text(isEdit ? "Update" : "Save"),
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
