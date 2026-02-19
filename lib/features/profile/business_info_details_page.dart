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

  Widget _detailRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? "-" : value,
              style: const TextStyle(fontSize: 13),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qrPath = _safe(businessInfo["payment_qr"]);
    final qrUrl = qrPath.isEmpty ? "" : "$_baseUrl/$qrPath";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Business Details"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _safe(businessInfo["legal_name"]).isEmpty
                          ? "Business"
                          : _safe(businessInfo["legal_name"]),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Business ID: ${_safe(businessInfo["id"])}",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // QR
              if (qrUrl.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Payment QR",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          qrUrl,
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return Container(
                              height: 220,
                              alignment: Alignment.center,
                              child: const Text("QR image load failed"),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Details list
              _detailRow("Legal Name", _safe(businessInfo["legal_name"])),
              _detailRow("Industry ID", _safe(businessInfo["industry_id"])),
              _detailRow("GST No", _safe(businessInfo["gst_no"])),
              _detailRow("Address", _safe(businessInfo["address"])),
              _detailRow("Description", _safe(businessInfo["description"])),
              _detailRow("Bank Acc No", _safe(businessInfo["bank_acc_no"])),
              _detailRow("IFSC Code", _safe(businessInfo["ifsc_code"])),
              _detailRow("Branch Name", _safe(businessInfo["branch_name"])),
              _detailRow("Website", _safe(businessInfo["website_url"])),
              _detailRow("Email", _safe(businessInfo["contact_email"])),
              _detailRow("UPI ID", _safe(businessInfo["upi_id"])),
              _detailRow("Created At", _safe(businessInfo["created_at"])),
              _detailRow("Updated At", _safe(businessInfo["updated_at"])),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
