

import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';

class BusinessInfoDetailsPage extends StatelessWidget {
  final Map<String, dynamic> businessInfo;
  const BusinessInfoDetailsPage({super.key, required this.businessInfo});

  static const String _baseUrl = AppConfig.apiProfileImg;

  String _safe(dynamic v) {
    if (v == null) return "";
    return v.toString().trim();
  }

  // Modern Info Row with Icons (theme-aware)
  Widget _infoRow(
      BuildContext context, IconData icon, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface.withOpacity(0.6),
                        letterSpacing: 0.5,
                      ) ??
                      TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface.withOpacity(0.6),
                        letterSpacing: 0.5,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? "Not Available" : value,
                  style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ) ??
                      const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Professional Card Wrapper (theme-aware)
  Widget _sectionCard({
    required BuildContext context,
    required String title,
    required List<Widget> children,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 16, right: 16),
            child: Text(
              title.toUpperCase(),
              style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.primary,
                    letterSpacing: 1.1,
                  ) ??
                  TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.primary,
                    letterSpacing: 1.1,
                  ),
            ),
          ),
          Divider(
            height: 24,
            thickness: 0.8,
            color: colorScheme.outline.withOpacity(0.2),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    debugPrint("Business Info => $businessInfo");

    final qrPath = _safe(businessInfo["payment_qr"]);
    final qrUrl = qrPath.isEmpty ? "" : "$_baseUrl/$qrPath";

    return Scaffold(
      backgroundColor: colorScheme.surface, // was Color(0xFFF8FAFC)
      appBar: AppBar(
        title: Text(
          "Business Profile",
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // 🔷 Business Header Info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: colorScheme.primary,
                      child: Text(
                        _safe(businessInfo["legal_name"]).isNotEmpty
                            ? _safe(businessInfo["legal_name"])[0]
                            : "B",
                        style: textTheme.headlineSmall?.copyWith(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ) ??
                            const TextStyle(
                              fontSize: 32,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _safe(businessInfo["legal_name"]).isEmpty
                          ? "Business Name"
                          : _safe(businessInfo["legal_name"]),
                      textAlign: TextAlign.center,
                      style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: colorScheme.onSurface,
                          ) ??
                          const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
              ),

              // 🔷 QR Card (Professional Presentation)
              if (qrUrl.isNotEmpty)
                _sectionCard(
                  context: context,
                  title: "Payment QR Code",
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: colorScheme.outline.withOpacity(0.2),
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            qrUrl,
                            height: 200,
                            width: 200,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.qr_code_2,
                              size: 100,
                              color: colorScheme.onSurface.withOpacity(0.4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

              // 🔷 Registration Details
              _sectionCard(
                context: context,
                title: "Registration Details",
                children: [
                  _infoRow(context, Icons.business_center, "Legal Name",
                      _safe(businessInfo["legal_name"])),
                  _infoRow(context, Icons.category, "Industry ID",
                      _safe(businessInfo["industry_id"])),
                  _infoRow(context, Icons.receipt_long, "GST Number",
                      _safe(businessInfo["gst_no"])),
                ],
              ),

              // 🔷 Banking Information
              _sectionCard(
                context: context,
                title: "Banking & Payments",
                children: [
                  _infoRow(context, Icons.account_balance, "Bank Account",
                      _safe(businessInfo["bank_acc_no"])),
                  _infoRow(context, Icons.code, "IFSC Code",
                      _safe(businessInfo["ifsc_code"])),
                  _infoRow(context, Icons.location_city, "Branch Name",
                      _safe(businessInfo["branch_name"])),
                  _infoRow(context, Icons.payments, "UPI ID",
                      _safe(businessInfo["upi_id"])),
                ],
              ),

              // 🔷 Contact & Location
              _sectionCard(
                context: context,
                title: "Contact Details",
                children: [
                  _infoRow(context, Icons.email_outlined, "Email Address",
                      _safe(businessInfo["contact_email"])),
                  _infoRow(context, Icons.language, "Website",
                      _safe(businessInfo["website_url"])),
                  _infoRow(context, Icons.location_on_outlined,
                      "Business Address", _safe(businessInfo["address"])),
                ],
              ),

              // 🔷 About Business
              if (_safe(businessInfo["description"]).isNotEmpty)
                _sectionCard(
                  context: context,
                  title: "Description",
                  children: [
                    Text(
                      _safe(businessInfo["description"]),
                      style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.8),
                            height: 1.5,
                          ) ??
                          TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurface.withOpacity(0.8),
                            height: 1.5,
                          ),
                    ),
                  ],
                ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
