import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gridcard/core/services/leads_provider.dart';
import 'package:gridcard/models/lead_model.dart';
import './lead_details.dart';
import './lead_scanner.dart';
import 'dart:ui';

class LeadsPage extends StatefulWidget {
  const LeadsPage({super.key});

  @override
  State<LeadsPage> createState() => _LeadsPageState();
}

class _LeadsPageState extends State<LeadsPage> {
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeadProviders>().fetchLeadsAdvanced(reset: true);
    });

    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    final provider = context.read<LeadProviders>();

    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 100 &&
        !provider.isPaginating) {
      provider.fetchLeadsAdvanced();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

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

              final provider = context.read<LeadProviders>();

              final success = await provider.deleteLead(leadId);

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("🗑 Lead deleted successfully")),
                );
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
              height: 42, // 👈 standard mobile height
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
                  provider.fetchLeadsAdvanced(
                    reset: true,
                    search: val,
                  );
                },
              ),
            ),
          ),

          const SizedBox(width: 10),
          // ================= ADD LEAD BUTTON =================

          InkWell(
            onTap: _openAddLeadModal,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 42, // 👈 reduced height
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

  Widget _buildInputWithIcon(
    String label,
    TextEditingController controller, {
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
    Widget? suffix,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: colorScheme.primary.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          suffixIcon: suffix,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: colorScheme.primary,
              width: 1.6,
            ),
          ),
          filled: true,
          fillColor: colorScheme.surface,
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
                  // LEFT INFO
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
                      ],
                    ),
                  ),

                  // RIGHT ACTION
                  // IconButton(
                  //   visualDensity: VisualDensity.compact,
                  //   padding: EdgeInsets.zero,
                  //   constraints: const BoxConstraints(),
                  //   icon: const Icon(
                  //     CupertinoIcons.delete_simple,
                  //     size: 18,
                  //     color: Colors.redAccent,
                  //   ),
                  //   onPressed: () => _confirmDelete(lead.id!),
                  // ),

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
                    onSelected: (value) {
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
        // decoration: InputDecoration(
        //   labelText: label,
        //   errorText: error,
        //   suffixIcon: suffix,
        //   border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        // ),

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

          // 🔥 MAIN FIX
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1.6),
          ),
        ),
      ),
    );
  }

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
        if (newErrors.containsKey('name'))
          nameFocus.requestFocus();
        else if (newErrors.containsKey('mobile0'))
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

                    // 🔥 EMAIL FIELD + ICON (RESTORED UX)
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

                    // 🔥 EMAIL 2 FIELD + DELETE ICON (RESTORED UX)
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
                        // 🔵 Scan (ONLY MOBILE)
                        if (!isDesktop) ...[
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () {
                              // TODO: future scan logic
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => const Dialog(
                                  insetPadding: EdgeInsets.zero,
                                  child: LeadsScannerPage(),
                                ),
                              );
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

                                  final provider =
                                      context.read<LeadProviders>();
                                  final success =
                                      await provider.addLeadRaw(data);

                                  if (success) {
                                    Navigator.pop(context);
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

  Widget _buildInput(
    String label,
    TextEditingController controller, {
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: colorScheme.primary.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),

          // 🟢 NORMAL BORDER
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
              width: 1,
            ),
          ),

          // 🔵 FOCUSED BORDER
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: colorScheme.primary,
              width: 1.6,
            ),
          ),

          // 🔴 ERROR BORDER (future validation ke liye)
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),

          filled: true,
          fillColor: colorScheme.surface,

          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
      ),
    );
  }
}
