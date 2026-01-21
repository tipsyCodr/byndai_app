import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/models/customer_master_model.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class LeadDetailsPage extends StatelessWidget {
  final CustomerMasterModel lead;

  const LeadDetailsPage({super.key, required this.lead});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title:
            Text("Lead Details", style: TextStyle(color: colorScheme.primary)),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: colorScheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(CupertinoIcons.pencil, color: colorScheme.primary),
            onPressed: () {
              // Future: Implement edit
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 32),
            _buildInfoSection(context),
            const SizedBox(height: 32),
            if (lead.otherDetails != null && lead.otherDetails!.isNotEmpty)
              _buildNotesSection(context),
            const SizedBox(height: 40),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              lead.name?[0].toUpperCase() ?? "?",
              style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lead.name ?? "Unknown Name",
                style: TextStyle(
                    color: isDark ? colorScheme.onSurface : colorScheme.primary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                lead.companyName ?? "Independent",
                style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 16),
              ),
              const SizedBox(height: 8),
              if (lead.createdAt != null)
                Text(
                  "Scanned on ${DateFormat('MMM dd, yyyy').format(lead.createdAt!)}",
                  style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.3),
                      fontSize: 12),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    return Column(
      children: [
        _buildInfoTile(
          context: context,
          icon: CupertinoIcons.phone,
          label: "Phone",
          value: lead.phoneNo ?? "Not provided",
          onTap: lead.phoneNo != null
              ? () => _launchURL("tel:${lead.phoneNo}")
              : null,
        ),
        _buildInfoTile(
          context: context,
          icon: CupertinoIcons.mail,
          label: "Email",
          value: lead.email ?? "Not provided",
          onTap: lead.email != null
              ? () => _launchURL("mailto:${lead.email}")
              : null,
        ),
        _buildInfoTile(
          context: context,
          icon: CupertinoIcons.location,
          label: "Address",
          value: lead.address ?? "Not provided",
          onTap: lead.address != null
              ? () => _launchURL(
                  "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(lead.address!)}")
              : null,
        ),
        _buildInfoTile(
          context: context,
          icon: CupertinoIcons.globe,
          label: "Website",
          value: lead.website ?? "Not provided",
          onTap: lead.website != null
              ? () => _launchURL(lead.website!.startsWith('http')
                  ? lead.website!
                  : 'https://${lead.website}')
              : null,
        ),
      ],
    );
  }

  Widget _buildInfoTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.4),
                          fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: TextStyle(
                          color: colorScheme.onSurface, fontSize: 15)),
                ],
              ),
            ),
            if (onTap != null)
              Icon(CupertinoIcons.chevron_right,
                  color: colorScheme.onSurface.withOpacity(0.1), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Additional Details",
            style: TextStyle(
                color: colorScheme.primary,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
                isDark ? colorScheme.surfaceContainerHighest : Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.onSurface.withOpacity(0.05)),
          ),
          child: Text(
            lead.otherDetails!,
            style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.7),
                fontSize: 14,
                height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              // Add to global contacts
            },
            icon: const Icon(CupertinoIcons.person_add_solid),
            label: const Text("Save to Contacts",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: colorScheme.primary.withOpacity(0.2)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              // Share lead
            },
            icon: Icon(CupertinoIcons.share, color: colorScheme.primary),
            label: Text("Share This Lead",
                style: TextStyle(color: colorScheme.primary)),
          ),
        ),
      ],
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
