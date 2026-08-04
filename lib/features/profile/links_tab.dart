import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:gridcard/widgets/top_alert.dart';
import 'package:gridcard/widgets/glass_box.dart';
import 'package:gridcard/core/utils/error_formatter.dart';

class LinksTab extends StatefulWidget {
  final Map<String, dynamic>? userDetails;
  final VoidCallback? onSaved;
  const LinksTab({super.key, this.userDetails, this.onSaved});

  @override
  State<LinksTab> createState() => _LinksTabState();
}

class _LinksTabState extends State<LinksTab> {
  static const String _baseUrl = AppConfig.apiBaseUrl;

  // ================= HEADERS =================
  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  final List<Map<String, String>> socialOptions = [
    {"label": "Website", "value": "website"},
    {"label": "Store", "value": "store"},
    {"label": "JustDial", "value": "justdial"},
    {"label": "Google Review", "value": "google_review"},
    {"label": "IndiaMart", "value": "indiamart"},
    {"label": "Facebook", "value": "facebook"},
    {"label": "Instagram", "value": "instagram"},
    {"label": "Twitter", "value": "twitter"},
    {"label": "LinkedIn", "value": "linkedin"},
    {"label": "YouTube", "value": "youtube"},
    {"label": "WhatsApp", "value": "whatsapp"},
    {"label": "Telegram", "value": "telegram"},
    {"label": "Snapchat", "value": "snapchat"},
    {"label": "Other", "value": "other"},
  ];

  List<Map<String, dynamic>> savedLinks = [];
  static List<Map<String, dynamic>> _cachedLinks = [];
  static DateTime? _lastFetchTime;

  bool get _shouldRefresh {
    if (_cachedLinks.isEmpty || _lastFetchTime == null) return true;
    return DateTime.now().difference(_lastFetchTime!) > const Duration(minutes: 60);
  }

  bool isPageLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchMasterLinks();
  }

  // ================= API METHODS =================
  Future<void> _fetchMasterLinks() async {
    if (!_shouldRefresh && _cachedLinks.isNotEmpty) {
      if (mounted) setState(() => savedLinks = List.from(_cachedLinks));
      return;
    }

    try {
      setState(() => isPageLoading = true);
      final headers = await _getHeaders();
      final url = Uri.parse("$_baseUrl/master-links");
      final response = await http.get(url, headers: headers);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data["status"] == true) {
        final List list = data["data"] ?? [];
        setState(() {
          savedLinks = list.map((e) => Map<String, dynamic>.from(e)).toList();
          _cachedLinks = List.from(savedLinks);
        });
      }
    } catch (e) {
      debugPrint("Error fetching links: $e");
    } finally {
      if (mounted) setState(() => isPageLoading = false);
      _lastFetchTime = DateTime.now();
    }
  }

  Future<bool> _createMasterLink({required String name, required String link}) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse("$_baseUrl/master-links");
      final body = jsonEncode({"name": name, "link": link, "status": 1});
      final response = await http.post(url, headers: headers, body: body);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        TopAlert.show(context, data["message"] ?? "Link saved", isSuccess: true);
        if (data["data"] != null) {
          setState(() {
            savedLinks.insert(0, Map<String, dynamic>.from(data["data"]));
            _cachedLinks = List.from(savedLinks);
          });
          widget.onSaved?.call();
        }
        return true;
      }
    } catch (e) {
      TopAlert.show(context, ErrorFormatter.format(e), isError: true);
    }
    return false;
  }

  Future<bool> _updateMasterLink({required int id, required String name, required String link}) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse("$_baseUrl/master-links/$id");
      final body = jsonEncode({"name": name, "link": link, "status": 1});
      final response = await http.post(url, headers: headers, body: body);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        TopAlert.show(context, data["message"] ?? "Link updated", isSuccess: true);
        if (data["data"] != null) {
          final updated = Map<String, dynamic>.from(data["data"]);
          setState(() {
            final index = savedLinks.indexWhere((e) => e["id"] == id);
            if (index != -1) savedLinks[index] = updated;
            _cachedLinks = List.from(savedLinks);
          });
          widget.onSaved?.call();
        }
        return true;
      }
    } catch (e) {
      TopAlert.show(context, ErrorFormatter.format(e), isError: true);
    }
    return false;
  }

  Future<bool> _deleteMasterLink(int id) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse("$_baseUrl/master-links/$id");
      final response = await http.delete(url, headers: headers);
      if (response.statusCode == 200) {
        TopAlert.show(context, "Deleted successfully", isSuccess: true);
        setState(() {
          savedLinks.removeWhere((e) => e["id"] == id);
          _cachedLinks = List.from(savedLinks);
        });
        widget.onSaved?.call();
        return true;
      }
    } catch (e) {
      TopAlert.show(context, ErrorFormatter.format(e), isError: true);
    }
    return false;
  }

  String getLabelFromValue(String value) {
    final item = socialOptions.firstWhere(
      (e) => e["value"] == value,
      orElse: () => {"label": value, "value": value},
    );
    return item["label"] ?? value;
  }

  // ================= MODALS =================
  void openAddLinkModal() {
    _openLinkModal(isEdit: false);
  }

  void openActionButtonModal({bool isEdit = false, Map<String, dynamic>? linkItem}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    String initialLabel = "";
    if (isEdit && linkItem != null) {
      initialLabel = linkItem["name"]?.toString().replaceFirst("btn:", "") ?? "";
    }
    final labelController = TextEditingController(text: initialLabel);
    final linkController = TextEditingController(text: isEdit ? (linkItem?["link"]?.toString() ?? "") : "");
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassBox(
          padding: const EdgeInsets.all(24),
          child: StatefulBuilder(builder: (context, setModalState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isEdit ? "Edit Action Button" : "Add Action Button",
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: colorScheme.onSurface)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: labelController,
                  enabled: !isLoading,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: _inputDecoration("Button Label", "e.g. My Portfolio", colorScheme),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: linkController,
                  enabled: !isLoading,
                  style: TextStyle(color: colorScheme.onSurface),
                  keyboardType: TextInputType.url,
                  decoration: _inputDecoration("Link URL", "https://", colorScheme),
                ),
                const SizedBox(height: 24),
                _submitButton(
                  isLoading: isLoading,
                  colorScheme: colorScheme,
                  label: isEdit ? "Update Button" : "Save Button",
                  onPressed: () async {
                    final label = labelController.text.trim();
                    final url = linkController.text.trim();
                    if (label.isEmpty || url.isEmpty) {
                      TopAlert.show(context, "Fields cannot be empty", isError: true);
                      return;
                    }
                    setModalState(() => isLoading = true);
                    final ok = isEdit
                        ? await _updateMasterLink(id: int.parse(linkItem!["id"].toString()), name: "btn:$label", link: url)
                        : await _createMasterLink(name: "btn:$label", link: url);
                    if (mounted) setModalState(() => isLoading = false);
                    if (ok) Navigator.pop(context);
                  },
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Center(child: Text("Cancel", style: TextStyle(color: colorScheme.onSurfaceVariant))),
                )
              ],
            );
          }),
        ),
      ),
    );
  }

  void _openLinkModal({required bool isEdit, Map<String, dynamic>? linkItem}) {
    if (isEdit && linkItem != null && linkItem["name"]?.toString().startsWith("btn:") == true) {
      openActionButtonModal(isEdit: true, linkItem: linkItem);
      return;
    }
    String? selectedPlatform = isEdit ? (linkItem?["name"]?.toString()) : null;
    final linkController = TextEditingController(text: isEdit ? (linkItem?["link"]?.toString() ?? "") : "");
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassBox(
          padding: const EdgeInsets.all(24),
          child: StatefulBuilder(builder: (context, setModalState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isEdit ? "Edit Social Link" : "Add Social Link",
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: colorScheme.onSurface)),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: selectedPlatform,
                  dropdownColor: colorScheme.surfaceContainerHighest,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: _inputDecoration("Select Platform", "", colorScheme),
                  items: socialOptions.map((item) => DropdownMenuItem(value: item["value"], child: Text(item["label"] ?? ""))).toList(),
                  onChanged: isLoading ? null : (val) => setModalState(() => selectedPlatform = val),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: linkController,
                  enabled: !isLoading,
                  style: TextStyle(color: colorScheme.onSurface),
                  keyboardType: TextInputType.url,
                  decoration: _inputDecoration("Enter Link", "https://", colorScheme),
                ),
                const SizedBox(height: 24),
                _submitButton(
                  isLoading: isLoading,
                  colorScheme: colorScheme,
                  label: isEdit ? "Update Link" : "Save Link",
                  onPressed: () async {
                    String finalLink = linkController.text.trim();
                    if (selectedPlatform == 'whatsapp') {
                      // Remove any non-digit characters (like spaces, +, or dashes)
                      String digits = finalLink.replaceAll(RegExp(r'\D'), '');
                      // If exactly 10 digits, prepend 91 (India)
                      if (digits.length == 10) {
                        finalLink = '91$digits';
                      } else {
                        // Otherwise use the cleaned digits as the link
                        finalLink = digits;
                      }
                    }

                    setModalState(() => isLoading = true);
                    final ok = isEdit
                        ? await _updateMasterLink(id: int.parse(linkItem!["id"].toString()), name: selectedPlatform!, link: finalLink)
                        : await _createMasterLink(name: selectedPlatform!, link: finalLink);
                    if (mounted) setModalState(() => isLoading = false);
                    if (ok) Navigator.pop(context);
                  },
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Center(child: Text("Cancel", style: TextStyle(color: colorScheme.onSurfaceVariant))),
                )
              ],
            );
          }),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint, ColorScheme colorScheme) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  Widget _submitButton({required bool isLoading, required ColorScheme colorScheme, required String label, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 4,
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onPrimary))
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }

  void confirmDelete(Map<String, dynamic> linkItem) {
    final id = int.parse(linkItem["id"].toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text("Delete Link"),
        content: const Text("Are you sure you want to delete this link?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(onPressed: () async { Navigator.pop(context); await _deleteMasterLink(id); }, child: const Text("OK")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: isPageLoading
          ? const Center(child: CircularProgressIndicator())
          : savedLinks.isEmpty
              ? _emptyState(colorScheme, theme)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: savedLinks.length,
                  itemBuilder: (context, index) {
                    final item = savedLinks[index];
                    final String name = item["name"]?.toString() ?? "";
                    final String link = item["link"]?.toString() ?? "";
                    final bool isActionButton = name.startsWith("btn:");
                    final String displayLabel = isActionButton ? name.replaceFirst("btn:", "") : getLabelFromValue(name);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassBox(
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: _linkIcon(isActionButton, colorScheme),
                          title: Text(displayLabel, style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
                          subtitle: Text(link, maxLines: 1, overflow: TextOverflow.ellipsis, 
                              style: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.7), fontSize: 12)),
                          trailing: _popupMenu(item, isActionButton, colorScheme),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: _fab(colorScheme),
    );
  }

  Widget _emptyState(ColorScheme colorScheme, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.link_off, size: 64, color: colorScheme.onSurface.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text("No Links Added Yet", style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Add social profile or custom action buttons", style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant.withOpacity(0.7))),
        ],
      ),
    );
  }

  Widget _linkIcon(bool isActionButton, ColorScheme colorScheme) {
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: (isActionButton ? colorScheme.primary : colorScheme.secondary).withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(isActionButton ? Icons.ads_click : Icons.link, 
          color: isActionButton ? colorScheme.primary : colorScheme.secondary, size: 20),
    );
  }

  Widget _popupMenu(Map<String, dynamic> item, bool isActionButton, ColorScheme colorScheme) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant),
      onSelected: (val) {
        if (val == "edit") {
          isActionButton ? openActionButtonModal(isEdit: true, linkItem: item) : _openLinkModal(isEdit: true, linkItem: item);
        } else if (val == "delete") {
          confirmDelete(item);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: "edit", child: Row(children: [Icon(Icons.edit_outlined, size: 20, color: colorScheme.primary), const SizedBox(width: 12), const Text("Edit")])),
        PopupMenuItem(value: "delete", child: Row(children: [Icon(Icons.delete_outline, size: 20, color: colorScheme.error), const SizedBox(width: 12), Text("Delete", style: TextStyle(color: colorScheme.error))])),
      ],
    );
  }

  Widget _fab(ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.extended(
          heroTag: "btn_add_link",
          onPressed: openAddLinkModal,
          label: const Text("Social Link"),
          icon: const Icon(Icons.share),
        ),
        const SizedBox(height: 12),
        FloatingActionButton.extended(
          heroTag: "btn_add_action",
          backgroundColor: colorScheme.secondaryContainer,
          foregroundColor: colorScheme.onSecondaryContainer,
          onPressed: () => openActionButtonModal(),
          label: const Text("Action Button"),
          icon: const Icon(Icons.ads_click),
        ),
      ],
    );
  }
}
