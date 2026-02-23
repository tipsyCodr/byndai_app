import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gridcard/core/services/leads_provider.dart';

import 'package:gridcard/models/lead_model.dart';
import './lead_details.dart';
import './lead_chat_page.dart';
import 'package:gridcard/core/services/user_storage_service.dart';

class LeadsPage extends StatefulWidget {
  const LeadsPage({super.key});

  @override
  State<LeadsPage> createState() => _LeadsPageState();
}

class _LeadsPageState extends State<LeadsPage> {
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  static const String _baseUrl =
      "https://powderblue-jellyfish-554082.hostingersite.com";

  int? _currentUserId; // Store user ID after fetching.....

  @override
  void initState() {
    super.initState();
    _loadUserIdAndFetchLeads();
    _scrollCtrl.addListener(_onScroll);
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
                    color: Colors.white,
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
                                color: Colors.grey.shade100,
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
                                    return Container(
                                      height: 300,
                                      width: double.infinity,
                                      child: _buildNoImagePlaceholder(),
                                    );
                                  },
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            height: 300,
                            width: double.infinity,
                            child: _buildNoImagePlaceholder(),
                          ),
                        if (lead.imageFilename != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              "File: ${lead.imageFilename}",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
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
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(
                        Icons.close,
                        size: 20,
                        color: Colors.black87,
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

  Widget _buildNoImagePlaceholder() {
    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade200,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 60,
            color: Colors.grey,
          ),
          SizedBox(height: 12),
          Text(
            "No Image Available",
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "This lead doesn't have an image",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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

  Widget _buildTopBar(LeadProviders provider) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        height: 42,
        child: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            prefixIcon: const Icon(CupertinoIcons.search, size: 18),
            hintText: "Search lead...",
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lead.name ?? "",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        if ((lead.company_name ?? "").isNotEmpty)
                          Text(
                            lead.company_name!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(CupertinoIcons.phone,
                                size: 13, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              lead.mobile_no_1 ?? "",
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        if ((lead.email ?? "").isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(CupertinoIcons.mail,
                                  size: 13, color: Colors.grey),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  lead.email!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (lead.leadImage != null || lead.imageUrl != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.image_outlined,
                                    size: 12, color: Colors.green),
                                const SizedBox(width: 4),
                                Text(
                                  "Has Image",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (lead.leadImage != null || lead.imageUrl != null)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.remove_red_eye_outlined,
                            size: 18,
                            color: Colors.blue,
                          ),
                          onPressed: () => _showImagePreview(context, lead),
                        ),
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          CupertinoIcons.ellipsis_vertical,
                          size: 18,
                          color: Colors.grey,
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
                          if (value == 'chat') {
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
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(CupertinoIcons.pencil, size: 16),
                                SizedBox(width: 8),
                                Text("Edit"),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(CupertinoIcons.delete,
                                    size: 16, color: Colors.red),
                                SizedBox(width: 8),
                                Text("Delete"),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'chat',
                            child: Row(
                              children: [
                                Icon(Icons.chat_bubble_outline,
                                    size: 16, color: Colors.green),
                                SizedBox(width: 8),
                                Text("Chat"),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
            borderSide: BorderSide(color: Colors.grey.shade300),
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
            borderSide: const BorderSide(color: Colors.red, width: 1.4),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1.6),
          ),
        ),
      ),
    );
  }

  
}
