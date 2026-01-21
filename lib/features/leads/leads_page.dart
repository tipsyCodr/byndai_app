import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/core/services/lead_provider.dart';
import 'package:provider/provider.dart';

import 'package:gridcard/features/leads/lead_details_page.dart';
import 'package:gridcard/models/customer_master_model.dart';

class LeadsPage extends StatefulWidget {
  const LeadsPage({super.key});

  @override
  State<LeadsPage> createState() => _LeadsPageState();
}

class _LeadsPageState extends State<LeadsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeadProvider>().fetchLeads();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildSearchBar(),
        ),
        Expanded(
          child: Consumer<LeadProvider>(
            builder: (context, leadProvider, child) {
              if (leadProvider.isLoading && leadProvider.leads.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (leadProvider.errorMessage != null &&
                  leadProvider.leads.isEmpty) {
                return _buildErrorState(leadProvider.errorMessage!);
              }

              final filteredLeads = leadProvider.leads.where((lead) {
                final query = _searchQuery.toLowerCase();
                return (lead.name?.toLowerCase().contains(query) ?? false) ||
                    (lead.companyName?.toLowerCase().contains(query) ?? false);
              }).toList();

              if (filteredLeads.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.builder(
                itemCount: filteredLeads.length,
                padding: const EdgeInsets.only(bottom: 20),
                itemBuilder: (context, index) {
                  final lead = filteredLeads[index];
                  return _LeadTile(lead: lead);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.onSurface.withOpacity(0.05)),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: colorScheme.onSurface),
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          icon: Icon(CupertinoIcons.search,
              color: colorScheme.onSurface.withOpacity(0.4), size: 20),
          hintText: "Search leads by name or company...",
          hintStyle: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.3), fontSize: 13),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.cloud_download,
              color: colorScheme.primary, size: 60),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.6), fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.read<LeadProvider>().fetchLeads(),
            child: const Text("Retry Sync"),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(CupertinoIcons.doc_text_search,
            color: colorScheme.onSurface.withOpacity(0.1), size: 80),
        const SizedBox(height: 16),
        Text(
          _searchQuery.isEmpty
              ? "No Leads Yet"
              : "No results for '$_searchQuery'",
          style: TextStyle(color: colorScheme.primary, fontSize: 18),
        ),
        const SizedBox(height: 8),
        Text(
          _searchQuery.isEmpty
              ? "Scan business cards to see them here."
              : "Try a different search term.",
          style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.4), fontSize: 14),
        ),
      ],
    );
  }
}

class _LeadTile extends StatelessWidget {
  final CustomerMasterModel lead;
  const _LeadTile({required this.lead});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.onSurface.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(isDark ? 0.1 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              lead.name?[0].toUpperCase() ?? "?",
              style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
        title: Text(
          lead.name ?? "Unknown",
          style: TextStyle(
              color: isDark ? colorScheme.onSurface : colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (lead.companyName != null)
              Text(lead.companyName!,
                  style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 13)),
            if (lead.phoneNo != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.phone,
                        color: colorScheme.onSurface.withOpacity(0.3),
                        size: 12),
                    const SizedBox(width: 4),
                    Text(lead.phoneNo!,
                        style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.3),
                            fontSize: 12)),
                  ],
                ),
              ),
          ],
        ),
        trailing: Icon(CupertinoIcons.chevron_right,
            color: colorScheme.onSurface.withOpacity(0.1)),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LeadDetailsPage(lead: lead),
            ),
          );
        },
      ),
    );
  }
}
