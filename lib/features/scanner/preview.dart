import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gridcard/core/services/lead_provider.dart';
import 'package:gridcard/models/customer_master_model.dart';
import 'package:provider/provider.dart';

class Preview extends StatefulWidget {
  final String imagePath;
  final String? recognizedText;

  const Preview({super.key, required this.imagePath, this.recognizedText});

  @override
  State<Preview> createState() => _PreviewState();
}

// ====== Text Classification Helpers ======

bool isPossibleOwnerName(String text) {
  final words = text.trim().split(RegExp(r'\s+'));
  // if (words.length < 1 || words.length > 3) return false;
  if (words.isEmpty) {
    // check this code use the above one if this gives issues.
    return false;
  }
  final nameRegex = RegExp(r"^[A-Z][a-z]+$");
  return words.every((word) => nameRegex.hasMatch(word));
}

bool isPossibleCompanyName(String text) {
  final textLower = text.toLowerCase();
  final companyKeywords = [
    'ltd',
    'private',
    'pvt',
    'inc',
    'llp',
    'enterprise',
    'enterprises',
    'industries',
    'corp',
    'corporation',
    'solutions',
    'group',
    'traders',
    'exports',
    'co.',
    'company',
    'tech',
    'systems',
    'services'
  ];

  // Avoid if too many digits (likely a phone number)
  final digitRatio = RegExp(r'\d').allMatches(text).length / text.length;
  if (digitRatio > 0.3) return false;

  // Rule 1: Contains company-related keywords
  if (companyKeywords.any((k) => textLower.contains(k))) return true;

  // Rule 2: All words in uppercase, more than one word (avoids owner's short initials)
  if (text == text.toUpperCase() && text.split(' ').length > 1) return true;

  // Rule 3: Has symbols/digits often seen in business names
  final businessStyleRegex = RegExp(r'[0-9&@\-.,]');
  if (businessStyleRegex.hasMatch(text)) return true;

  return false;
}

bool isEmail(String text) {
  return RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(text);
}

bool isPhone(String text) {
  final cleaned = text.replaceAll(RegExp(r'[^\d+]'), '');
  return RegExp(r'^\+?\d{10,15}$').hasMatch(cleaned);
}

bool isLikelyAddress(String text) {
  // Heuristics: contains numbers, street/road/avenue, or common address words
  final addressKeywords = [
    'street',
    'st.',
    'road',
    'rd.',
    'avenue',
    'ave',
    'block',
    'sector',
    'lane',
    'ln.',
    'colony',
    'district',
    'city',
    'village',
    'p.o.',
    'po',
    'zip',
    'pin',
    'suite',
    'apt',
    'floor',
    'building',
    'bldg',
    'near',
    'opposite',
    'behind',
    'area',
    'locality',
    'state',
    'country'
  ];

  final textLower = text.toLowerCase();

  // Rule 1: Contains address keywords
  if (addressKeywords.any((k) => textLower.contains(k))) return true;

  // Rule 2: Contains both digits and letters (e.g., "123 Main St")
  final hasDigits = RegExp(r'\d').hasMatch(text);
  final hasLetters = RegExp(r'[a-zA-Z]').hasMatch(text);
  if (hasDigits && hasLetters) return true;

  // Rule 3: Is long enough and contains commas (common in addresses)
  if (text.length > 15 && text.contains(',')) return true;

  return false;
}

bool isWebsite(String text) {
  return RegExp(
          r'^(https?:\/\/)?(www\.)?[a-zA-Z0-9\-]+\.[a-z]{2,}([\/\w\-.?=&]*)?$')
      .hasMatch(text);
}

class _PreviewState extends State<Preview> {
  final nameController = TextEditingController();
  final companyController = TextEditingController();
  final phoneController = TextEditingController();

  List<TextEditingController> emailControllers = [];
  List<TextEditingController> websiteControllers = [];
  List<TextEditingController> addressControllers = [];
  List<TextEditingController> otherDetailControllers = [];

  @override
  void dispose() {
    nameController.dispose();
    companyController.dispose();
    phoneController.dispose();
    for (var c in emailControllers +
        websiteControllers +
        addressControllers +
        otherDetailControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _analyzeText();
  }

  void _analyzeText() {
    final lines = (widget.recognizedText ?? '').split('\n');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (isEmail(trimmed)) {
        emailControllers.add(TextEditingController(text: trimmed));
      } else if (isWebsite(trimmed)) {
        websiteControllers.add(TextEditingController(text: trimmed));
      } else if (isPossibleCompanyName(trimmed) &&
          companyController.text.isEmpty) {
        companyController.text = trimmed;
      } else if (isPhone(trimmed) && phoneController.text.isEmpty) {
        phoneController.text = trimmed;
      } else if (isPossibleOwnerName(trimmed) && nameController.text.isEmpty) {
        nameController.text = trimmed;
      } else if (isLikelyAddress(trimmed)) {
        addressControllers.add(TextEditingController(text: trimmed));
      } else {
        otherDetailControllers.add(TextEditingController(text: trimmed));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? colors.surface
          : Colors.grey[50],
      appBar: AppBar(
        title: const Text("Verify Details",
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Preview Card
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 1.75, // Card ratio
                  child: Image.file(
                    File(widget.imagePath),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

            if (widget.recognizedText != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Contact Info Section
                    _buildSectionCard(
                      context,
                      title: "Contact Information",
                      icon: Icons.person_outline,
                      children: [
                        _buildTextField(
                            controller: nameController,
                            label: "Full Name",
                            icon: Icons.person),
                        _buildTextField(
                            controller: phoneController,
                            label: "Phone Number",
                            icon: Icons.phone,
                            keyboardType: TextInputType.phone),
                        ...emailControllers.map((c) => _buildTextField(
                            controller: c,
                            label: "Email Address",
                            icon: Icons.email,
                            keyboardType: TextInputType.emailAddress)),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Business Info Section
                    _buildSectionCard(
                      context,
                      title: "Business Details",
                      icon: Icons.business_outlined,
                      children: [
                        _buildTextField(
                            controller: companyController,
                            label: "Company Name",
                            icon: Icons.business),
                        ...websiteControllers.map((c) => _buildTextField(
                            controller: c,
                            label: "Website",
                            icon: Icons.language)),
                        ...addressControllers.map((c) => _buildTextField(
                            controller: c,
                            label: "Address",
                            icon: Icons.location_on,
                            maxLines: 2)),
                      ],
                    ),

                    if (otherDetailControllers.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildSectionCard(
                        context,
                        title: "Other Scanned Details",
                        icon: Icons.more_horiz_outlined,
                        children: [
                          ...otherDetailControllers.map((c) => _buildTextField(
                              controller: c,
                              label: "Detail",
                              icon: Icons.notes)),
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Actions
                    FilledButton.icon(
                      onPressed: () => _saveLead(context),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text("Save to Leads",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextButton.icon(
                      onPressed: () => _showOCRDetails(context),
                      icon: const Icon(Icons.description_outlined, size: 18),
                      label: const Text("View Raw Scanned Text"),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.onSurface.withOpacity(0.6),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(BuildContext context,
      {required String title,
      required IconData icon,
      required List<Widget> children}) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: colors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          filled: true,
          fillColor: colors.surfaceContainerHighest.withOpacity(0.3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  void _showOCRDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Raw Scanned Text",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Text(widget.recognizedText ?? "",
                    style: const TextStyle(height: 1.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveLead(BuildContext context) async {
    final lead = CustomerMasterModel(
      name: nameController.text,
      companyName: companyController.text,
      phoneNo: phoneController.text,
      email: emailControllers.isNotEmpty ? emailControllers.first.text : null,
      website:
          websiteControllers.isNotEmpty ? websiteControllers.first.text : null,
      address:
          addressControllers.isNotEmpty ? addressControllers.first.text : null,
      otherDetails: otherDetailControllers.map((c) => c.text).join('\n'),
    );

    final success = await context.read<LeadProvider>().addLead(lead);

    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lead saved successfully!")),
        );
        Navigator.pop(context); // Go back to camera
        Navigator.pop(context); // Go back to home/feed
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Failed to save lead. Please try again.")),
        );
      }
    }
  }
}
