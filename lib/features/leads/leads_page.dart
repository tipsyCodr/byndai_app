import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gridcard/core/services/leads-service.dart';
import 'package:gridcard/core/services/leads_provider.dart';
import 'package:gridcard/core/utils/file_exporter.dart';

import 'package:gridcard/models/lead_model.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import './manage_category_page.dart';
import 'package:gridcard/widgets/top_alert.dart';
import 'package:gridcard/core/utils/error_formatter.dart';
import 'package:intl/intl.dart';
import '../business_card_scan/presentation/google_lens_scanner.dart';
import './widgets/lead_item_card.dart';
import './widgets/lead_category_selector.dart';

class LeadsPage extends StatefulWidget {
  const LeadsPage({super.key});

  @override
  State<LeadsPage> createState() => _LeadsPageState();
}

class _LeadsPageState extends State<LeadsPage>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  static const String _baseUrl = AppConfig.apiBaseUrl;

  List<Map<String, dynamic>> _categories = [];
  bool _isCategoryLoading = false;
  bool _isExporting = false;

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

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  void _onSearchChanged(String query) {
    context.read<LeadProviders>().setSearchQuery(query);
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
                                        TopAlert.show(context,
                                            "User not found. Login again",
                                            isError: true);
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

                                      TopAlert.show(
                                        context,
                                        data["message"] ??
                                            "Something went wrong",
                                        isSuccess: data["status"] == true,
                                        isError: data["status"] != true,
                                      );

                                      if (data["status"] == true) {
                                        _fetchLeadCategories();
                                      }
                                    } catch (e) {
                                      Navigator.pop(context);
                                      TopAlert.show(context, ErrorFormatter.format(e),
                                          isError: true);
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

  Future<void> _loadUserIdAndFetchLeads() async {
    final userId = await UserStorageService().getUserId();
    if (userId != null) {
      if (mounted) setState(() => _currentUserId = userId);
      if (mounted) {
        final provider = context.read<LeadProviders>();
        if (provider.shouldRefresh) {
          provider.fetchLeadsByUserId(
            userId: userId,
            perPage: 10,
            reset: true,
          );
        }
      }
    } else {
      debugPrint("No user ID found");
    }
  }

  Future<void> _onRefresh() async {
    if (_currentUserId != null) {
      await context.read<LeadProviders>().fetchLeadsByUserId(
            userId: _currentUserId!,
            perPage: 10,
            reset: true,
          );
    }
    await _fetchLeadCategories();
  }

  void _onScroll() {
    final provider = context.read<LeadProviders>();

    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 100 &&
        !provider.isPaginating) {
      provider.loadNextPage();
    }
  }

  /// Escape a CSV field: wrap in quotes and escape inner quotes.
  String _csvField(String? value) {
    final s = (value ?? '').trim();
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  String _selectedCategoryName() {
    final selectedCategory = context.read<LeadProviders>().selectedCategory;
    if (selectedCategory == null || selectedCategory == 'All') return 'All';

    for (final category in _categories) {
      if (category['id']?.toString() == selectedCategory) {
        return category['name']?.toString() ?? 'Category';
      }
    }

    return 'Category';
  }

  Future<List<LeadModel>> _fetchAllLeadsForExport(
      LeadProviders provider) async {
    if (_currentUserId == null) return const [];

    final exportedLeads = <LeadModel>[];
    var page = 1;
    var lastPage = 1;

    do {
      final result = await LeadServices.fetchLeadsByUserId(
        userId: _currentUserId!,
        perPage: 100,
        page: page,
        category: provider.selectedCategory,
      );

      if (result == null) {
        throw Exception('Failed to fetch leads for export.');
      }

      final leads = result['leads'] as List<LeadModel>;
      final meta = result['meta'] as Map<String, dynamic>;

      exportedLeads.addAll(leads);
      lastPage = (meta['last_page'] as num?)?.toInt() ?? page;
      page++;
    } while (page <= lastPage);

    return exportedLeads;
  }

  Uint8List _buildCsvBytes(List<LeadModel> leads) {
    final now = DateTime.now();
    final categoryName = _selectedCategoryName();
    final buf = StringBuffer();

    // Header row
    buf.writeln(
        'ID,Name,Company,Mobile 1,Mobile 2,Mobile 3,Email 1,Email 2,Website,Address');

    // Data rows
    for (final lead in leads) {
      buf.writeln([
        _csvField(lead.id?.toString()),
        _csvField(lead.name),
        _csvField(lead.company_name),
        _csvField(lead.mobile_no_1),
        _csvField(lead.mobile_no_2),
        _csvField(lead.mobile_no_3),
        _csvField(lead.email),
        _csvField(lead.email2),
        _csvField(lead.website),
        _csvField(lead.address),
      ].join(','));
    }

    // Trailing summary
    buf.writeln();
    buf.writeln(
        'Exported At,${_csvField(DateFormat('dd MMM yyyy, hh:mm a').format(now))}');
    buf.writeln('Category,${_csvField(categoryName)}');
    buf.writeln('Lead Count,${leads.length}');

    // BOM so Excel/Numbers auto-detects UTF-8
    final bom = [0xEF, 0xBB, 0xBF];
    final content = utf8.encode(buf.toString());
    return Uint8List.fromList([...bom, ...content]);
  }

  Future<void> _exportLeadsToExcel(LeadProviders provider) async {
    if (_isExporting) return;
    if (_currentUserId == null) {
      TopAlert.show(context, 'User not found. Login again', isError: true);
      return;
    }

    setState(() => _isExporting = true);

    try {
      final leads = await _fetchAllLeadsForExport(provider);

      if (leads.isEmpty) {
        if (!mounted) return;
        TopAlert.show(context, 'No leads available to export', isError: true);
        return;
      }

      final bytes = _buildCsvBytes(leads);
      final fileName =
          'leads_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';

      await exportFileBytes(
        bytes: bytes,
        fileName: fileName,
        mimeType: 'text/csv',
        shareText: 'Leads export',
      );

      if (!mounted) return;
      TopAlert.show(context, 'CSV exported successfully', isSuccess: true);
    } catch (e) {
      if (!mounted) return;
      TopAlert.show(context, 'Export failed: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
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

              final provider = context.read<LeadProviders>();
              final success = await provider.deleteLead(leadId);

              if (success) {
                if (!mounted) return;
                TopAlert.show(context, "🗑 Lead deleted successfully",
                    isSuccess: true);
                if (_currentUserId != null) {
                  context.read<LeadProviders>().fetchLeadsByUserId(
                        userId: _currentUserId!,
                        reset: true,
                      );
                }
              } else {
                if (!mounted) return;
                TopAlert.show(context, "❌ Delete failed", isError: true);
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Consumer<LeadProviders>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'lens_scanner_fab',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GoogleLensScanner()),
            ),
            icon: const Icon(Icons.document_scanner_outlined),
            label: const Text('Scan Card'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
          body: RefreshIndicator(
            onRefresh: _onRefresh,
            color: Theme.of(context).colorScheme.primary,
            child: Column(
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
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(LeadProviders provider) {
    final searchField = SizedBox(
      height: 42,
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          prefixIcon: Icon(CupertinoIcons.search,
              size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon:
                      const Icon(CupertinoIcons.clear_circled_solid, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    _onSearchChanged("");
                    setState(() {});
                  },
                )
              : null,
          hintText: "Search lead...",
          hintStyle:
              TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          filled: true,
          fillColor: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withOpacity(0.3),
        ),
      ),
    );

    final exportButton = SizedBox(
      height: 48,
      child: FilledButton.tonalIcon(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
        onPressed: _isExporting ? null : () => _exportLeadsToExcel(provider),
        icon: _isExporting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.table_view_outlined, size: 18),
        label: const Text('Export CSV'),
      ),
    );

    final scanButton = SizedBox(
      height: 48,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GoogleLensScanner()),
        ),
        icon: const Icon(Icons.qr_code_scanner, size: 18),
        label: const Text('Scan Card'),
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 650) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchField,
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: scanButton),
                    const SizedBox(width: 8),
                    Expanded(child: exportButton),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: searchField),
              const SizedBox(width: 12),
              scanButton,
              const SizedBox(width: 12),
              exportButton,
            ],
          );
        },
      ),
    );
  }

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
          Selector<LeadProviders, String?>(
            selector: (_, p) => p.selectedCategory,
            builder: (context, selectedCategory, _) {
              final isAll =
                  selectedCategory == null || selectedCategory == "All";
              return GestureDetector(
                onTap: () {
                  if (_currentUserId != null) {
                    context.read<LeadProviders>().setCategory(
                          null,
                          _currentUserId!,
                        );
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isAll
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "All",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isAll
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 32,
              child: LeadCategorySelector(
                categories: _categories,
                isLoading: _isCategoryLoading,
                currentUserId: _currentUserId,
              ),
            ),
          ),
          const SizedBox(width: 6),
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
          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            icon: const Icon(
              CupertinoIcons.ellipsis_vertical,
              size: 18,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) async {
              if (value == "manage_category") {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ManageCategoryPage(),
                  ),
                ).then((_) {
                  _fetchLeadCategories();
                });
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

  Widget _buildDesktopTable(LeadProviders provider) {
    if (provider.isLoading && provider.leads.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
      ),
    );
  }

  Widget _buildMobileCards(LeadProviders provider) {
    if (provider.isLoading && provider.leads.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!provider.isLoading && provider.leads.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return RefreshIndicator(
            onRefresh: _onRefresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: const Center(
                  child: Text(
                    "No Data Found",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        controller: _scrollCtrl,
        padding: const EdgeInsets.only(bottom: 110),
        itemCount: provider.leads.length,
        itemBuilder: (_, i) {
          return LeadItemCard(
            leadId: provider.leads[i].id!,
            onDelete: () => _confirmDelete(provider.leads[i].id!),
          );
        },
      ),
    );
  }
}
