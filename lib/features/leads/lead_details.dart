

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gridcard/core/services/leads_provider.dart';
import 'package:gridcard/models/lead_model.dart';

class LeadDetailsPage extends StatefulWidget {
  final LeadModel lead;

  const LeadDetailsPage({super.key, required this.lead});

  @override
  State<LeadDetailsPage> createState() => _LeadDetailsPageState();
}

class _LeadDetailsPageState extends State<LeadDetailsPage> {
  late TextEditingController nameCtrl;
  late TextEditingController companyCtrl;
  late TextEditingController addressCtrl;
  late TextEditingController websiteCtrl;

  final List<TextEditingController> mobileCtrls = [];
  final List<TextEditingController> emailCtrls = [];

  final Map<String, String?> errors = {};
  bool isSaving = false;

  bool isValidMobile(String v) => RegExp(r'^[0-9]{10}$').hasMatch(v);
  bool isValidEmail(String v) =>
      RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(v);

  @override
  void initState() {
    super.initState();

    final lead = widget.lead;

    nameCtrl = TextEditingController(text: lead.name ?? "");
    companyCtrl = TextEditingController(text: lead.company_name ?? "");
    addressCtrl = TextEditingController(text: lead.address ?? "");
    websiteCtrl = TextEditingController(text: lead.website ?? "");

    if ((lead.mobile_no_1 ?? "").isNotEmpty) {
      mobileCtrls.add(TextEditingController(text: lead.mobile_no_1!));
    }
    if ((lead.mobile_no_2 ?? "").isNotEmpty) {
      mobileCtrls.add(TextEditingController(text: lead.mobile_no_2!));
    }
    if ((lead.mobile_no_3 ?? "").isNotEmpty) {
      mobileCtrls.add(TextEditingController(text: lead.mobile_no_3!));
    }
    if (mobileCtrls.isEmpty) mobileCtrls.add(TextEditingController());

    if ((lead.email ?? "").isNotEmpty) {
      emailCtrls.add(TextEditingController(text: lead.email!));
    }
    if ((lead.email2 ?? "").isNotEmpty) {
      emailCtrls.add(TextEditingController(text: lead.email2!));
    }
    if (emailCtrls.isEmpty) emailCtrls.add(TextEditingController());
  }

  void validate() {
    errors.clear();

    if (nameCtrl.text.trim().isEmpty) {
      errors['name'] = "Name required";
    }

    for (int i = 0; i < mobileCtrls.length; i++) {
      final v = mobileCtrls[i].text.trim();
      if (v.isEmpty) {
        errors['mobile$i'] = "Required";
      } else if (!isValidMobile(v)) {
        errors['mobile$i'] = "Invalid mobile";
      }
    }

    for (int i = 0; i < emailCtrls.length; i++) {
      final v = emailCtrls[i].text.trim();
      if (v.isNotEmpty && !isValidEmail(v)) {
        errors['email$i'] = "Invalid email";
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        title: const Text("Edit Lead"),
        centerTitle: true,
      ),
      bottomNavigationBar: isDesktop
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: isSaving ? null : _submit,
                    icon: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: const Text("Save Changes"),
                  ),
                ),
              ),
            ),
      body: Center(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: isDesktop ? 650 : double.infinity),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionCard(children: [
                  _input("Name", nameCtrl, error: errors['name']),
                  ..._buildMobiles(),
                ]),
                _sectionCard(children: [
                  _input("Company", companyCtrl),
                  ..._buildEmails(),
                ]),
                _sectionCard(children: [
                  _input("Website", websiteCtrl),
                  _input("Address", addressCtrl, maxLines: 3),
                ]),
                if (isDesktop)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: isSaving ? null : _submit,
                        icon: isSaving
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Icon(Icons.check),
                        label: const Text("Save Changes"),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0.8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 2),
        child: Column(children: children),
      ),
    );
  }

  List<Widget> _buildMobiles() {
    return List.generate(mobileCtrls.length, (i) {
      return _input(
        i == 0 ? "Mobile" : "Mobile ${i + 1}",
        mobileCtrls[i],
        keyboard: TextInputType.phone,
        error: errors['mobile$i'],
        suffix: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (i == 0 && mobileCtrls.length < 3)
              IconButton(
                icon: const Icon(CupertinoIcons.add_circled),
                onPressed: () =>
                    setState(() => mobileCtrls.add(TextEditingController())),
              ),
            if (i > 0)
              IconButton(
                icon: const Icon(CupertinoIcons.delete, color: Colors.red),
                onPressed: () => setState(() => mobileCtrls.removeAt(i)),
              ),
          ],
        ),
      );
    });
  }

  List<Widget> _buildEmails() {
    return List.generate(emailCtrls.length, (i) {
      return _input(
        i == 0 ? "Email" : "Email ${i + 1}",
        emailCtrls[i],
        keyboard: TextInputType.emailAddress,
        error: errors['email$i'],
        suffix: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (i == 0 && emailCtrls.length < 2)
              IconButton(
                icon: const Icon(CupertinoIcons.add_circled),
                onPressed: () =>
                    setState(() => emailCtrls.add(TextEditingController())),
              ),
            if (i > 0)
              IconButton(
                icon: const Icon(CupertinoIcons.delete, color: Colors.red),
                onPressed: () => setState(() => emailCtrls.removeAt(i)),
              ),
          ],
        ),
      );
    });
  }

  Widget _input(
    String label,
    TextEditingController ctrl, {
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
    String? error,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          errorText: error,
          suffixIcon: suffix,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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

  Future<void> _submit() async {
    validate();

    if (errors.isNotEmpty) {
      setState(() {});
      return;
    }

    final mobiles = mobileCtrls
        .map((e) => e.text.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final emails = emailCtrls
        .map((e) => e.text.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final payload = {
      "name": nameCtrl.text.trim(),
      "company_name": companyCtrl.text.trim(),
      "address": addressCtrl.text.trim(),
      "website": websiteCtrl.text.trim(),
      "mobile_no_1": mobiles.isNotEmpty ? mobiles[0] : "",
      "mobile_no_2": mobiles.length > 1 ? mobiles[1] : null,
      "mobile_no_3": mobiles.length > 2 ? mobiles[2] : null,
      "email": emails.isNotEmpty ? emails[0] : null,
      "email2": emails.length > 1 ? emails[1] : null,
    };

    setState(() => isSaving = true);

    final provider = context.read<LeadProviders>();
    final success = await provider.updateLead(widget.lead.id!, payload);

    setState(() => isSaving = false);

    if (success) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Lead Updated Successfully")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Update Failed")),
      );
    }
  }
}
