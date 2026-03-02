
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


import 'package:gridcard/core/services/leads_provider.dart';

import 'package:gridcard/models/lead_model.dart';
import './lead_details.dart';
import './lead_scanner.dart';
import './lead_chat_page.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:gridcard/config/app_config.dart';

class LeadsPage extends StatefulWidget {
  const LeadsPage({super.key});

  @override
  State<LeadsPage> createState() => _LeadsPageState();
}

class _LeadsPageState extends State<LeadsPage> {
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  // static const String _baseUrl =
  //     "https://powderblue-jellyfish-554082.hostingersite.com";

   static const String _baseUrl =  AppConfig.imageBaseUrl;
     

  int? _currentUserId; // Store user ID after fetching

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
                                    return SizedBox(
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
                          SizedBox(
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
      child: Row(
        children: [
          Expanded(
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
                  // 🔁 If search is needed, implement filter in provider
                  // For now, we can ignore or call a search method if exists
                  // provider.searchLeads(val);
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: _openAddLeadModal,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                CupertinoIcons.add,
                size: 20,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ],
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

  // 🔁 This function remains mostly unchanged; it still uses LeadProviders for saving
  void _openAddLeadModal() {
    final nameCtrl = TextEditingController();
    final companyCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final email2Ctrl = TextEditingController();
    final websiteCtrl = TextEditingController();

    final List<TextEditingController> mobileCtrls = [
      TextEditingController(),
    ];

    final nameFocus = FocusNode();
    final emailFocus = FocusNode();
    final email2Focus = FocusNode();
    final websiteFocus = FocusNode();
    final addressFocus = FocusNode();

    final List<FocusNode> mobileFocusNodes = [
      FocusNode(),
    ];

    bool showEmail2 = false;
    bool isSaving = false;

    Map<String, String?> errors = {};

    bool isValidMobile(String v) => RegExp(r'^[0-9]{10}$').hasMatch(v);
    bool isValidEmail(String v) =>
        RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(v);

    void validate(StateSetter setModalState, {bool submit = false}) {
      final Map<String, String?> newErrors = {};

      if (nameCtrl.text.trim().isEmpty) {
        newErrors['name'] = "Name is required";
      }

      final mob1 = mobileCtrls[0].text.trim();
      if (mob1.isEmpty) {
        newErrors['mobile0'] = "Mobile is required";
      } else if (!isValidMobile(mob1)) {
        newErrors['mobile0'] = "Enter valid 10 digit mobile";
      }

      for (int i = 1; i < mobileCtrls.length; i++) {
        final mob = mobileCtrls[i].text.trim();
        if (mob.isNotEmpty && !isValidMobile(mob)) {
          newErrors['mobile$i'] = "Invalid mobile";
        }
      }

      if (emailCtrl.text.trim().isEmpty) {
        newErrors['email'] = "Email is required";
      } else if (!isValidEmail(emailCtrl.text.trim())) {
        newErrors['email'] = "Invalid email format";
      }

      if (showEmail2 &&
          email2Ctrl.text.trim().isNotEmpty &&
          !isValidEmail(email2Ctrl.text.trim())) {
        newErrors['email2'] = "Invalid email format";
      }

      if (websiteCtrl.text.length > 25) {
        newErrors['website'] = "Max 25 characters";
      }

      if (addressCtrl.text.length > 120) {
        newErrors['address'] = "Max 120 characters";
      }

      setModalState(() => errors = newErrors);

      if (submit && newErrors.isNotEmpty) {
        if (newErrors.containsKey('name')) {
          nameFocus.requestFocus();
        } else if (newErrors.containsKey('mobile0'))
          mobileFocusNodes[0].requestFocus();
        else if (newErrors.containsKey('email'))
          emailFocus.requestFocus();
        else if (newErrors.containsKey('email2'))
          email2Focus.requestFocus();
        else if (newErrors.containsKey('website'))
          websiteFocus.requestFocus();
        else if (newErrors.containsKey('address')) addressFocus.requestFocus();
      }
    }

    void fillFormFromScannerData(
        Map<String, dynamic> formData, StateSetter setModalState) {
      if (formData['name'] != null && formData['name'].toString().isNotEmpty) {
        nameCtrl.text = formData['name'].toString();
      }
      if (formData['company'] != null &&
          formData['company'].toString().isNotEmpty) {
        companyCtrl.text = formData['company'].toString();
      }
      if (formData['mobile1'] != null &&
          formData['mobile1'].toString().isNotEmpty) {
        mobileCtrls[0].text = formData['mobile1'].toString();
        if (formData['mobile2'] != null &&
            formData['mobile2'].toString().isNotEmpty) {
          if (mobileCtrls.length < 2) {
            mobileCtrls.add(TextEditingController());
            mobileFocusNodes.add(FocusNode());
          }
          mobileCtrls[1].text = formData['mobile2'].toString();
        }
        if (formData['mobile3'] != null &&
            formData['mobile3'].toString().isNotEmpty) {
          if (mobileCtrls.length < 3) {
            mobileCtrls.add(TextEditingController());
            mobileFocusNodes.add(FocusNode());
          }
          mobileCtrls[2].text = formData['mobile3'].toString();
        }
      }
      if (formData['email1'] != null &&
          formData['email1'].toString().isNotEmpty) {
        emailCtrl.text = formData['email1'].toString();
      }
      if (formData['email2'] != null &&
          formData['email2'].toString().isNotEmpty) {
        showEmail2 = true;
        email2Ctrl.text = formData['email2'].toString();
      }
      if (formData['website'] != null &&
          formData['website'].toString().isNotEmpty) {
        websiteCtrl.text = formData['website'].toString();
      }
      if (formData['address'] != null &&
          formData['address'].toString().isNotEmpty) {
        addressCtrl.text = formData['address'].toString();
      }
      validate(setModalState);
    }

    showDialog(
      context: context,
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isDesktop = screenWidth > 800;

        return StatefulBuilder(builder: (context, setModalState) {
          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            insetPadding: EdgeInsets.symmetric(
              horizontal: isDesktop ? screenWidth * 0.35 : 16,
              vertical: 24,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Add New Lead",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),

                    _buildValidatedField("Name", nameCtrl, nameFocus,
                        error: errors['name'],
                        onChanged: (_) => validate(setModalState)),

                    Column(
                      children: List.generate(mobileCtrls.length, (i) {
                        return _buildValidatedField(
                          i == 0 ? "Mobile No" : "Mobile ${i + 1}",
                          mobileCtrls[i],
                          mobileFocusNodes[i],
                          keyboard: TextInputType.phone,
                          error: errors['mobile$i'],
                          onChanged: (_) => validate(setModalState),
                          suffix: i == 0 && mobileCtrls.length < 3
                              ? IconButton(
                                  icon: const Icon(CupertinoIcons.add_circled),
                                  onPressed: () {
                                    setModalState(() {
                                      mobileCtrls.add(TextEditingController());
                                      mobileFocusNodes.add(FocusNode());
                                    });
                                  },
                                )
                              : i > 0
                                  ? IconButton(
                                      icon: const Icon(CupertinoIcons.delete,
                                          color: Colors.red),
                                      onPressed: () {
                                        setModalState(() {
                                          mobileCtrls.removeAt(i);
                                          mobileFocusNodes.removeAt(i);
                                        });
                                      },
                                    )
                                  : null,
                        );
                      }),
                    ),

                    _buildValidatedField(
                        "Company Name", companyCtrl, FocusNode()),

                    _buildValidatedField(
                      "Email",
                      emailCtrl,
                      emailFocus,
                      keyboard: TextInputType.emailAddress,
                      error: errors['email'],
                      onChanged: (_) => validate(setModalState),
                      suffix: !showEmail2
                          ? IconButton(
                              icon: const Icon(CupertinoIcons.add_circled),
                              onPressed: () {
                                setModalState(() => showEmail2 = true);
                              },
                            )
                          : null,
                    ),

                    if (showEmail2)
                      _buildValidatedField(
                        "Email 2",
                        email2Ctrl,
                        email2Focus,
                        keyboard: TextInputType.emailAddress,
                        error: errors['email2'],
                        onChanged: (_) => validate(setModalState),
                        suffix: IconButton(
                          icon: const Icon(CupertinoIcons.delete,
                              color: Colors.red),
                          onPressed: () {
                            setModalState(() {
                              showEmail2 = false;
                              email2Ctrl.clear();
                            });
                          },
                        ),
                      ),

                    _buildValidatedField("Website", websiteCtrl, websiteFocus,
                        error: errors['website'],
                        onChanged: (_) => validate(setModalState)),

                    _buildValidatedField("Address", addressCtrl, addressFocus,
                        maxLines: 2,
                        error: errors['address'],
                        onChanged: (_) => validate(setModalState)),

                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Cancel")),
                        const SizedBox(width: 12),
                        if (!isDesktop) ...[
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => Dialog(
                                  insetPadding: EdgeInsets.zero,
                                  child: LeadsScannerPage(
                                    onDataExtracted:
                                        (Map<String, dynamic> formData) {
                                      fillFormFromScannerData(
                                          formData, setModalState);
                                    },
                                  ),
                                ),
                              ).then((_) {
                                setModalState(() {});
                              });
                            },
                            icon: const Icon(CupertinoIcons.qrcode_viewfinder),
                            label: const Text("Scan"),
                          ),
                        ],
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  validate(setModalState, submit: true);
                                  if (errors.isNotEmpty) return;

                                  setModalState(() => isSaving = true);

                                  final data = {
                                    "name": nameCtrl.text.trim(),
                                    "mobiles": mobileCtrls
                                        .map((e) => e.text.trim())
                                        .where((e) => e.isNotEmpty)
                                        .toList(),
                                    "company_name": companyCtrl.text.trim(),
                                    "email": emailCtrl.text.trim(),
                                    "email2": showEmail2
                                        ? email2Ctrl.text.trim()
                                        : null,
                                    "website": websiteCtrl.text.trim(),
                                    "address": addressCtrl.text.trim(),
                                  };

                                  // 🔁 Still using old provider for adding lead
                                  final provider =
                                      context.read<LeadProviders>();
                                  final success =
                                      await provider.addLeadRaw(data);

                                  if (success) {
                                    Navigator.pop(context);
                                    // Refresh scanned leads list
                                    if (_currentUserId != null) {
                                      context
                                          .read<LeadProviders>()
                                          .fetchLeadsByUserId(
                                            userId: _currentUserId!,
                                            reset: true,
                                          );
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text("✅ Lead Added Successfully"),
                                      ),
                                    );
                                  } else {
                                    setModalState(() => isSaving = false);
                                  }
                                },
                          child: isSaving
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text("Save"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }
}