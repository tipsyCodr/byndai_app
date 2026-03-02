import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gridcard/core/services/leads_provider.dart';

import 'package:gridcard/models/lead_model.dart';
import './lead_details.dart';
import './lead_chat_page.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import './manage_category_page.dart';

class LeadsPage extends StatefulWidget {
  const LeadsPage({super.key});

  @override
  State<LeadsPage> createState() => _LeadsPageState();
}

class _LeadsPageState extends State<LeadsPage> {
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  static const String _baseUrl = AppConfig.apiBaseUrl;
  String _selectedCategory = "All";
  // List<String> _categories = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isCategoryLoading = false;

  int? _currentUserId; // Store user ID after fetching.....

  // ================= HEADERS =================
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
    _loadUserIdAndFetchLeads();
    _fetchLeadCategories();
    _scrollCtrl.addListener(_onScroll);
  }

  Future<void> _fetchLeadCategories() async {
    setState(() => _isCategoryLoading = true);

    try {
      final userId = await UserStorageService().getUserId();

      if (userId == null) return;

      final response = await http.get(
        Uri.parse("$_baseUrl/lead-category-user/$userId"),
        headers: await _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (data["status"] == true) {
        final List list = data["data"];
        // setState(() {
        //   _categories = list.map((e) => e["category"].toString()).toList();
        // });

        setState(() {
          _categories = list
              .map((e) => {
                    "id": e["id"],
                    "name": e["category"],
                  })
              .toList();
        });
      }
    } catch (e) {
      debugPrint("Category Fetch Error: $e");
    } finally {
      setState(() => _isCategoryLoading = false);
    }
  }

  void _showAddCategoryModal() {
    final TextEditingController categoryCtrl = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final colorScheme = Theme.of(context).colorScheme;
            return Dialog(
              backgroundColor: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Add Category",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: categoryCtrl,
                      decoration: const InputDecoration(
                        labelText: "Category",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        setModalState(() {});
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Cancel"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: categoryCtrl.text.trim().isEmpty ||
                                    isLoading
                                ? null
                                : () async {
                                    setModalState(() => isLoading = true);

                                    try {
                                      final userId = await UserStorageService()
                                          .getUserId();

                                      if (userId == null) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  "User not found. Login again")),
                                        );
                                        return;
                                      }

                                      final response = await http.post(
                                        Uri.parse(
                                            "$_baseUrl/lead-category-create"),
                                        headers: await _getHeaders(),
                                        body: jsonEncode({
                                          "user_id": userId,
                                          "category": categoryCtrl.text.trim(),
                                        }),
                                      );

                                      final data = jsonDecode(response.body);

                                      if (!context.mounted) return;
                                      Navigator.pop(context);

                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(data["message"] ??
                                              "Something went wrong"),
                                        ),
                                      );

                                      if (data["status"] == true) {
                                        _fetchLeadCategories();
                                      }
                                    } catch (e) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(content: Text("Error: $e")),
                                      );
                                    }
                                  },
                            child: isLoading
                                ? SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colorScheme.onPrimary,
                                    ),
                                  )
                                : const Text("Add"),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 🔁 New method to get user ID and fetch leads
  Future<void> _loadUserIdAndFetchLeads() async {
    final userId = await UserStorageService().getUserId();
    if (userId != null) {
      setState(() => _currentUserId = userId);
      if (mounted) {
        context.read<LeadProviders>().fetchLeadsByUserId(
              userId: userId,
              perPage: 10,
              reset: true,
            );
      }
    } else {
      // Handle no user – maybe show error or redirect to login
      debugPrint("No user ID found");
    }
  }

  void _onScroll() {
    final provider = context.read<LeadProviders>();

    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 100 &&
        !provider.isPaginating) {
      provider.loadNextPage(); // 🔁 Now uses new provider's pagination
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    // 🔁 Replace Consumer<LeadProviders> with Consumer<ScannedLeadProvider>
    return Consumer<LeadProviders>(
      builder: (context, provider, _) {
        return Column(
          children: [
            _buildTopBar(provider),
            _buildCategoryRow(),
            Expanded(
              child: isDesktop
                  ? _buildDesktopTable(provider)
                  : _buildMobileCards(provider),
            ),
            if (provider.isPaginating)
              const Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              )
          ],
        );
      },
    );
  }

  void _showImagePreview(BuildContext context, LeadModel lead) {
    final imageUrl = lead.imageUrl;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;
        final screenWidth = MediaQuery.of(context).size.width;
        final colorScheme = Theme.of(context).colorScheme;

        final maxImageHeight = screenHeight * 0.6;
        final maxImageWidth = screenWidth * 0.8;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: screenHeight * 0.8,
              maxWidth: screenWidth * 0.9,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            "${lead.name}",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (imageUrl != null)
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: maxImageHeight,
                              maxWidth: maxImageWidth,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: colorScheme.surfaceContainerHighest,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  imageUrl,
                                  fit: BoxFit.contain,
                                  headers: {
                                    'Access-Control-Allow-Origin': '*',
                                  },
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    print('Image Error: $error');
                                    return SizedBox(
                                      height: 300,
                                      width: double.infinity,
                                      child: _buildNoImagePlaceholder(context),
                                    );
                                  },
                                ),
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            height: 300,
                            width: double.infinity,
                            child: _buildNoImagePlaceholder(context),
                          ),
                        if (lead.imageFilename != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              "File: ${lead.imageFilename}",
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.close,
                        size: 20,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoImagePlaceholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.surfaceContainerHighest,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 60,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            "No Image Available",
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "This lead doesn't have an image",
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(int leadId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Lead"),
        content: const Text(
          "Are you sure you want to permanently delete this lead?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            icon: const Icon(Icons.delete),
            label: const Text("Delete"),
            onPressed: () async {
              Navigator.pop(context);

              // 🔁 Use old LeadProviders for delete (if it supports delete)
              final provider = context.read<LeadProviders>();
              final success = await provider.deleteLead(leadId);

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("🗑 Lead deleted successfully")),
                );
                // Refresh scanned leads list
                if (_currentUserId != null) {
                  context.read<LeadProviders>().fetchLeadsByUserId(
                        userId: _currentUserId!,
                        reset: true,
                      );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("❌ Delete failed")),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // ================= TOP BAR =================

  Widget _buildCategoryRow() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // ================= ALL BUTTON =================
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = "All";
              });

              if (_currentUserId != null) {
                context.read<LeadProviders>().setCategory(
                      null, // 🔥 null = ALL
                      _currentUserId!,
                    );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _selectedCategory == "All"
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "All",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _selectedCategory == "All"
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // ================= CATEGORY CHIPS =================
          Expanded(
            child: SizedBox(
              height: 32,
              child: _isCategoryLoading
                  ? const Center(
                      child: SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        // final category = _categories[index];

                        final category = _categories[index];
                        final categoryName = category["name"];
                        final categoryId = category["id"];
                        final isSelected =
                            _selectedCategory == categoryId.toString();

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategory = categoryId.toString();
                            });

                            if (_currentUserId != null) {
                              context.read<LeadProviders>().setCategory(
                                    categoryId.toString(), // 🔥 ID PASS KARO
                                    _currentUserId!,
                                  );
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.outlineVariant,
                              ),
                            ),
                            child: Text(
                              categoryName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),

          const SizedBox(width: 6),

          // ================= ADD BUTTON =================
          GestureDetector(
            onTap: _showAddCategoryModal,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Icon(Icons.add, size: 18, color: colorScheme.onSurface),
            ),
          ),

          const SizedBox(width: 6),

          // ================= MENU =================
          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            icon: const Icon(
              CupertinoIcons.ellipsis_vertical,
              size: 18,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),

            // 👇 YAHAN ADD KARNA HAI
            onSelected: (value) async {
              if (value == "manage_category") {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ManageCategoryPage(),
                  ),
                ).then((_) {
                  _fetchLeadCategories(); // 🔁 refresh after back
                });
              }

              if (value == "sort") {
                // future me sorting logic
              }
            },

            itemBuilder: (context) => const [
              PopupMenuItem(
                value: "manage_category",
                child: Text("Manage Categories"),
              ),
              PopupMenuItem(
                value: "sort",
                child: Text("Sort Leads"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(LeadProviders provider) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        height: 42,
        child: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            prefixIcon: Icon(CupertinoIcons.search,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            hintText: "Search lead...",
            hintStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant),
            ),
            filled: true,
            fillColor: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withOpacity(0.3),
          ),
          onChanged: (val) {
            // agar future me search implement karna ho
            // provider.searchLeads(val);
          },
        ),
      ),
    );
  }

  // ================= MOBILE VIEW =================
  Widget _buildMobileCards(LeadProviders provider) {
    if (provider.isLoading && provider.leads.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!provider.isLoading && provider.leads.isEmpty) {
      return const Center(
        child: Text(
          "No Data Found",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.only(bottom: 110),
      itemCount: provider.leads.length,
      itemBuilder: (_, i) {
        final lead = provider.leads[i];

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LeadDetailsPage(lead: lead),
              ),
            );
          },
          child: Card(
            elevation: 1.2,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            // child: Padding(
            //   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            //   child: Row(
            //     crossAxisAlignment: CrossAxisAlignment.start,
            //     children: [
            //       Expanded(
            //         child: Column(
            //           crossAxisAlignment: CrossAxisAlignment.start,
            //           children: [
            //             // Text(
            //             //   lead.name ?? "",
            //             //   maxLines: 1,
            //             //   overflow: TextOverflow.ellipsis,
            //             //   style: const TextStyle(
            //             //       fontSize: 14.5, fontWeight: FontWeight.w600),
            //             // ),
            //             Row(
            //               crossAxisAlignment: CrossAxisAlignment.start,
            //               children: [
            //                 // ✅ LEFT SIDE — NAME
            //                 Expanded(
            //                   child: Text(
            //                     lead.name ?? "",
            //                     style: const TextStyle(
            //                       fontSize: 16,
            //                       fontWeight: FontWeight.w600,
            //                     ),
            //                     overflow: TextOverflow.ellipsis,
            //                   ),
            //                 ),

            //                 // ✅ RIGHT SIDE — CHAT + MENU
            //                 Row(
            //                   mainAxisSize: MainAxisSize.min,
            //                   children: [
            //                     // CHAT ICON
            //                     IconButton(
            //                       visualDensity: VisualDensity.compact,
            //                       padding: EdgeInsets.zero,
            //                       constraints: const BoxConstraints(),
            //                       icon: const Icon(
            //                         Icons.chat_bubble_outline,
            //                         size: 18,
            //                         color: Colors.green,
            //                       ),
            //                       onPressed: () async {
            //                         final session = await UserStorageService()
            //                             .loadSession();
            //                         final viewerUserId = session.user?.id;

            //                         Navigator.push(
            //                           context,
            //                           MaterialPageRoute(
            //                             builder: (_) => LeadChatPage(
            //                               lead: lead,
            //                               viewerUserId: viewerUserId,
            //                             ),
            //                           ),
            //                         );
            //                       },
            //                     ),

            //                     // POPUP MENU
            //                     PopupMenuButton<String>(
            //                       padding: EdgeInsets.zero,
            //                       icon: const Icon(
            //                         CupertinoIcons.ellipsis_vertical,
            //                         size: 18,
            //                         color: Colors.grey,
            //                       ),
            //                       shape: RoundedRectangleBorder(
            //                         borderRadius: BorderRadius.circular(12),
            //                       ),
            //                       onSelected: (value) async {
            //                         if (value == 'edit') {
            //                           Navigator.push(
            //                             context,
            //                             MaterialPageRoute(
            //                               builder: (_) =>
            //                                   LeadDetailsPage(lead: lead),
            //                             ),
            //                           );
            //                         }
            //                         if (value == 'delete') {
            //                           _confirmDelete(lead.id!);
            //                         }
            //                       },
            //                       itemBuilder: (context) => const [
            //                         PopupMenuItem(
            //                           value: 'edit',
            //                           child: Row(
            //                             children: [
            //                               Icon(CupertinoIcons.pencil, size: 16),
            //                               SizedBox(width: 8),
            //                               Text("Edit"),
            //                             ],
            //                           ),
            //                         ),
            //                         PopupMenuItem(
            //                           value: 'delete',
            //                           child: Row(
            //                             children: [
            //                               Icon(CupertinoIcons.delete,
            //                                   size: 16, color: Colors.red),
            //                               SizedBox(width: 8),
            //                               Text("Delete"),
            //                             ],
            //                           ),
            //                         ),
            //                       ],
            //                     ),
            //                   ],
            //                 ),
            //               ],
            //             ),
            //             const SizedBox(height: 2),
            //             if ((lead.company_name ?? "").isNotEmpty)
            //               Text(
            //                 lead.company_name!,
            //                 maxLines: 1,
            //                 overflow: TextOverflow.ellipsis,
            //                 style: TextStyle(
            //                     fontSize: 12, color: Colors.grey.shade600),
            //               ),
            //             const SizedBox(height: 4),
            //             Row(
            //               children: [
            //                 const Icon(CupertinoIcons.phone,
            //                     size: 13, color: Colors.grey),
            //                 const SizedBox(width: 4),
            //                 Text(
            //                   lead.mobile_no_1 ?? "",
            //                   style: const TextStyle(fontSize: 12),
            //                 ),
            //               ],
            //             ),
            //             if ((lead.email ?? "").isNotEmpty) ...[
            //               const SizedBox(height: 2),
            //               Row(
            //                 children: [
            //                   const Icon(CupertinoIcons.mail,
            //                       size: 13, color: Colors.grey),
            //                   const SizedBox(width: 4),
            //                   Expanded(
            //                     child: Text(
            //                       lead.email!,
            //                       maxLines: 1,
            //                       overflow: TextOverflow.ellipsis,
            //                       style: const TextStyle(fontSize: 12),
            //                     ),
            //                   ),
            //                 ],
            //               ),
            //             ],
            //           ],
            //         ),
            //       ),
            //       // Row(
            //       //   mainAxisSize: MainAxisSize.min,
            //       //   children: [

            //       //     PopupMenuButton<String>(
            //       //       padding: EdgeInsets.zero,
            //       //       icon: const Icon(
            //       //         CupertinoIcons.ellipsis_vertical,
            //       //         size: 18,
            //       //         color: Colors.grey,
            //       //       ),
            //       //       shape: RoundedRectangleBorder(
            //       //         borderRadius: BorderRadius.circular(12),
            //       //       ),
            //       //       onSelected: (value) async {
            //       //         if (value == 'edit') {
            //       //           Navigator.push(
            //       //             context,
            //       //             MaterialPageRoute(
            //       //               builder: (_) => LeadDetailsPage(lead: lead),
            //       //             ),
            //       //           );
            //       //         }
            //       //         if (value == 'delete') {
            //       //           _confirmDelete(lead.id!);
            //       //         }
            //       //         if (value == 'chat') {
            //       //           final session =
            //       //               await UserStorageService().loadSession();
            //       //           final viewerUserId = session.user?.id;
            //       //           Navigator.push(
            //       //             context,
            //       //             MaterialPageRoute(
            //       //               builder: (_) => LeadChatPage(
            //       //                 lead: lead,
            //       //                 viewerUserId: viewerUserId,
            //       //               ),
            //       //             ),
            //       //           );
            //       //         }
            //       //       },
            //       //       itemBuilder: (context) => [
            //       //         const PopupMenuItem(
            //       //           value: 'edit',
            //       //           child: Row(
            //       //             children: [
            //       //               Icon(CupertinoIcons.pencil, size: 16),
            //       //               SizedBox(width: 8),
            //       //               Text("Edit"),
            //       //             ],
            //       //           ),
            //       //         ),
            //       //         const PopupMenuItem(
            //       //           value: 'delete',
            //       //           child: Row(
            //       //             children: [
            //       //               Icon(CupertinoIcons.delete,
            //       //                   size: 16, color: Colors.red),
            //       //               SizedBox(width: 8),
            //       //               Text("Delete"),
            //       //             ],
            //       //           ),
            //       //         ),
            //       //         const PopupMenuItem(
            //       //           value: 'chat',
            //       //           child: Row(
            //       //             children: [
            //       //               Icon(Icons.chat_bubble_outline,
            //       //                   size: 16, color: Colors.green),
            //       //               SizedBox(width: 8),
            //       //               Text("Chat"),
            //       //             ],
            //       //           ),
            //       //         ),
            //       //       ],
            //       //     ),
            //       //   ],
            //       // ),

            //       // Row(
            //       //   mainAxisSize: MainAxisSize.min,
            //       //   children: [
            //       //     // ✅ DIRECT CHAT ICON
            //       //     IconButton(
            //       //       visualDensity: VisualDensity.compact,
            //       //       padding: EdgeInsets.zero,
            //       //       constraints: const BoxConstraints(),
            //       //       icon: const Icon(
            //       //         Icons.chat_bubble_outline,
            //       //         size: 18,
            //       //         color: Colors.green,
            //       //       ),
            //       //       onPressed: () async {
            //       //         final session =
            //       //             await UserStorageService().loadSession();
            //       //         final viewerUserId = session.user?.id;

            //       //         Navigator.push(
            //       //           context,
            //       //           MaterialPageRoute(
            //       //             builder: (_) => LeadChatPage(
            //       //               lead: lead,
            //       //               viewerUserId: viewerUserId,
            //       //             ),
            //       //           ),
            //       //         );
            //       //       },
            //       //     ),

            //       //     // ✅ POPUP MENU (Edit + Delete Only)
            //       //     PopupMenuButton<String>(
            //       //       padding: EdgeInsets.zero,
            //       //       icon: const Icon(
            //       //         CupertinoIcons.ellipsis_vertical,
            //       //         size: 18,
            //       //         color: Colors.grey,
            //       //       ),
            //       //       shape: RoundedRectangleBorder(
            //       //         borderRadius: BorderRadius.circular(12),
            //       //       ),
            //       //       onSelected: (value) async {
            //       //         if (value == 'edit') {
            //       //           Navigator.push(
            //       //             context,
            //       //             MaterialPageRoute(
            //       //               builder: (_) => LeadDetailsPage(lead: lead),
            //       //             ),
            //       //           );
            //       //         }
            //       //         if (value == 'delete') {
            //       //           _confirmDelete(lead.id!);
            //       //         }
            //       //       },
            //       //       itemBuilder: (context) => [
            //       //         const PopupMenuItem(
            //       //           value: 'edit',
            //       //           child: Row(
            //       //             children: [
            //       //               Icon(CupertinoIcons.pencil, size: 16),
            //       //               SizedBox(width: 8),
            //       //               Text("Edit"),
            //       //             ],
            //       //           ),
            //       //         ),
            //       //         const PopupMenuItem(
            //       //           value: 'delete',
            //       //           child: Row(
            //       //             children: [
            //       //               Icon(CupertinoIcons.delete,
            //       //                   size: 16, color: Colors.red),
            //       //               SizedBox(width: 8),
            //       //               Text("Delete"),
            //       //             ],
            //       //           ),
            //       //         ),
            //       //       ],
            //       //     ),
            //       //   ],
            //       // ),
            //     ],
            //   ),
            // ),

            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// 🔥 TOP ROW — NAME + ACTIONS
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      /// NAME (LEFT)
                      Expanded(
                        child: Text(
                          lead.name ?? "",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      /// CHAT ICON
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.chat_bubble_outline,
                          size: 19,
                          color: Colors.green,
                        ),
                        onPressed: () async {
                          final session =
                              await UserStorageService().loadSession();
                          final viewerUserId = session.user?.id;

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LeadChatPage(
                                lead: lead,
                                viewerUserId: viewerUserId,
                              ),
                            ),
                          );
                        },
                      ),

                      /// POPUP MENU
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          CupertinoIcons.ellipsis_vertical,
                          size: 19,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (value) async {
                          if (value == 'edit') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LeadDetailsPage(lead: lead),
                              ),
                            );
                          }
                          if (value == 'delete') {
                            _confirmDelete(lead.id!);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text("Edit"),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              "Delete",
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  /// 🔥 SMALL GAP (Reduced)
                  const SizedBox(height: 4),

                  /// COMPANY NAME
                  if ((lead.company_name ?? "").isNotEmpty)
                    Text(
                      lead.company_name!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),

                  const SizedBox(height: 6),

                  /// PHONE
                  Row(
                    children: [
                      Icon(CupertinoIcons.phone,
                          size: 13,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        lead.mobile_no_1 ?? "",
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ],
                  ),

                  /// EMAIL
                  if ((lead.email ?? "").isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(CupertinoIcons.mail,
                            size: 13,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            lead.email!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ================= DESKTOP VIEW =================
  Widget _buildDesktopTable(LeadProviders provider) {
    if (provider.isLoading && provider.leads.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      controller: _scrollCtrl,
      child: DataTable(
        columns: const [
          DataColumn(label: Text("ID")),
          DataColumn(label: Text("Name")),
          DataColumn(label: Text("Company")),
          DataColumn(label: Text("Mobile")),
          DataColumn(label: Text("Email")),
          DataColumn(label: Text("Address")),
        ],
        rows: provider.leads.map((lead) {
          return DataRow(cells: [
            DataCell(Text("${lead.id}")),
            DataCell(Text(lead.name ?? "")),
            DataCell(Text(lead.company_name ?? "")),
            DataCell(Text(lead.mobile_no_1 ?? "")),
            DataCell(Text(lead.email ?? "")),
            DataCell(Text(lead.address ?? "")),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildValidatedField(
    String label,
    TextEditingController controller,
    FocusNode focusNode, {
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
    String? error,
    Widget? suffix,
    Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboard,
        maxLines: maxLines,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          errorText: error,
          suffixIcon: suffix,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 1.6,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: Theme.of(context).colorScheme.error, width: 1.4),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: Theme.of(context).colorScheme.error, width: 1.6),
          ),
        ),
      ),
    );
  }
}
