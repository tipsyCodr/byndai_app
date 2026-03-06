import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:gridcard/widgets/top_alert.dart';

import './add_business_info_page.dart';
import './business_info_details_page.dart';

class BusinessInfoTab extends StatefulWidget {
  final Map<String, dynamic>? userDetails;
  const BusinessInfoTab({super.key, this.userDetails});

  @override
  State<BusinessInfoTab> createState() => _BusinessInfoTabState();
}

class _BusinessInfoTabState extends State<BusinessInfoTab> {
  static const String _baseUrl = AppConfig.apiBaseUrl;

  bool isLoading = false;
  String? errorMessage;

  int? userId;
  List<dynamic> businessList = [];

  // ================= HEADERS =================
  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  @override
  void initState() {
    super.initState();
    _initAndFetch();
  }

  Future<void> _initAndFetch() async {
    await _loadUserId();
    if (userId != null) {
      await _fetchBusinessInfo();
    }
  }

  Future<void> _loadUserId() async {
    try {
      final id = await UserStorageService().getUserId();
      setState(() => userId = id);
    } catch (_) {
      setState(() => userId = null);
    }
  }

  // ================= GET API =================
  Future<void> _fetchBusinessInfo() async {
    if (userId == null) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final headers = await _getHeaders();
      final url = Uri.parse("$_baseUrl/business-info-by-user/$userId");

      final res = await http.get(url, headers: headers);
      final jsonData = jsonDecode(res.body);

      if (res.statusCode == 200 && jsonData["status"] == true) {
        setState(() {
          businessList = jsonData["data"] ?? [];
        });
      } else {
        setState(() {
          errorMessage = jsonData["message"] ?? "Failed to load business info";
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Error: $e";
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ================= DELETE API =================
  Future<void> _deleteBusinessInfo({
    required int businessId,
    required int listIndex,
  }) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse("$_baseUrl/business-info-delete/$businessId");

      final res = await http.delete(url, headers: headers);
      final jsonData = jsonDecode(res.body);

      if (res.statusCode == 200 && jsonData["status"] == true) {
        setState(() {
          businessList.removeAt(listIndex);
        });

        if (!mounted) return;
        TopAlert.show(context, jsonData["message"] ?? "Deleted successfully",
            isSuccess: true);
      } else {
        if (!mounted) return;
        TopAlert.show(context, jsonData["message"] ?? "Delete failed",
            isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      TopAlert.show(context, "Error: $e", isError: true);
    }
  }

  Future<void> _confirmDelete({
    required int businessId,
    required int listIndex,
    required String titleName,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return AlertDialog(
          title: const Text("Delete Business Info?"),
          content: Text("Are you sure you want to delete:\n\n$titleName"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );

    if (ok == true) {
      _deleteBusinessInfo(businessId: businessId, listIndex: listIndex);
    }
  }

  String _safeText(dynamic v) {
    if (v == null) return "";
    return v.toString().trim();
  }

  Widget _infoRow(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item, int index) {
    final legalName = _safeText(item["legal_name"]);
    final gstNo = _safeText(item["gst_no"]);
    final address = _safeText(item["address"]);
    final website = _safeText(item["website_url"]);
    final email = _safeText(item["contact_email"]);

    final businessId = int.tryParse(_safeText(item["id"])) ?? 0;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BusinessInfoDetailsPage(businessInfo: item),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top title
            Row(
              children: [
                Expanded(
                  child: Text(
                    legalName.isEmpty ? "Business" : legalName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // 3 dots
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, color: Colors.grey),
                  onSelected: (value) async {
                    if (value == "edit") {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddBusinessInfoPage(
                            isEdit: true,
                            businessInfo: item,
                          ),
                        ),
                      );

                      // ✅ update success -> refresh
                      if (result == true) {
                        _fetchBusinessInfo();
                      }
                    }

                    if (value == "delete") {
                      _confirmDelete(
                        businessId: businessId,
                        listIndex: index,
                        titleName: legalName.isEmpty ? "Business" : legalName,
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: "edit",
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 10),
                          Text("Edit"),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: "delete",
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 10),
                          Text("Delete"),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            _infoRow("GST No", gstNo),
            _infoRow("Address", address),
            _infoRow("Website", website),
            _infoRow("Email", email),

            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip("ID: ${_safeText(item["id"])}"),
                _chip("Industry: ${_safeText(item["industry_id"])}"),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchBusinessInfo,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 10),
              if (userId == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Text("User ID not found"),
                  ),
                )
              else if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 50),
                  child: Center(
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else if (businessList.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 70),
                  child: Center(
                    child: Text(
                      "No Business Info Found\nClick + to add new",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                )
              else
                ...businessList.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return _buildCard(item, index);
                }),
            ],
          ),
        ),
      ),

      // ✅ + => ADD MODE
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddBusinessInfoPage(),
            ),
          );

          if (result == true) {
            _fetchBusinessInfo();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
