import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';

class ManageCategoryPage extends StatefulWidget {
  const ManageCategoryPage({super.key});

  @override
  State<ManageCategoryPage> createState() => _ManageCategoryPageState();
}

class _ManageCategoryPageState extends State<ManageCategoryPage> {
  static const String _baseUrl = AppConfig.apiBaseUrl;

  List<dynamic> _categories = [];
  bool _isLoading = true;

  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    setState(() => _isLoading = true);

    try {
      final userId = await UserStorageService().getUserId();

      final response = await http.get(
        Uri.parse("$_baseUrl/lead-category-user/$userId"),
        headers: await _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (data["status"] == true) {
        _categories = data["data"];
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
    }

    setState(() => _isLoading = false);
  }

  // ================= DELETE =================
  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text("Delete Category"),
        content: const Text("Are you sure you want to delete this category?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context);

              await http.delete(
                Uri.parse("$_baseUrl/lead-category-delete/$id"),
                headers: await _getHeaders(),
              );

              _fetchCategories();
            },
            child: const Text("Delete"),
          )
        ],
      ),
    );
  }

  // ================= EDIT =================
  void _showEditModal(int id, String oldCategory) {
    final TextEditingController controller =
        TextEditingController(text: oldCategory);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text("Edit Category"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: "Category",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await http.put(
                Uri.parse("$_baseUrl/lead-category-update/$id"),
                headers: await _getHeaders(),
                body: jsonEncode({
                  "category": controller.text.trim(),
                }),
              );

              Navigator.pop(context);
              _fetchCategories();
            },
            child: const Text("Update"),
          )
        ],
      ),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Manage Categories",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? const Center(
                  child: Text(
                    "No categories found",
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchCategories,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final item = _categories[index];
                      final id = item["id"];
                      final category = item["category"];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.blue.shade50,
                            child: Text(
                              "${index + 1}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue),
                            ),
                          ),
                          title: Text(
                            category,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(
                              CupertinoIcons.ellipsis_vertical,
                              size: 18,
                            ),
                            onSelected: (value) {
                              if (value == "edit") {
                                _showEditModal(id, category);
                              }
                              if (value == "delete") {
                                _confirmDelete(id);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: "edit",
                                child: Row(
                                  children: [
                                    Icon(CupertinoIcons.pencil, size: 16),
                                    SizedBox(width: 8),
                                    Text("Edit"),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: "delete",
                                child: Row(
                                  children: [
                                    Icon(CupertinoIcons.delete,
                                        size: 16, color: Colors.red),
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
                ),
    );
  }
}
