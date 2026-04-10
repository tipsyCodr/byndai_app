import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gridcard/models/lead_model.dart';
import 'package:gridcard/core/services/leads_provider.dart';
import 'package:gridcard/widgets/app_network_image.dart';
import 'package:gridcard/widgets/glass_box.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import '../lead_details.dart';
import '../lead_chat_page.dart';

class LeadItemCard extends StatelessWidget {
  final int leadId;
  final VoidCallback onDelete;

  const LeadItemCard({
    super.key,
    required this.leadId,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<LeadProviders, LeadModel?>(
      selector: (_, provider) {
        try {
          return provider.leads.firstWhere((l) => l.id == leadId);
        } catch (_) {
          return null;
        }
      },
      builder: (context, lead, child) {
        if (lead == null) return const SizedBox.shrink();

        final colorScheme = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        final leadTitleColor = isDark
            ? Colors.white.withValues(alpha: 0.95)
            : colorScheme.onSurface;
        final leadSecondaryColor = isDark
            ? Colors.white.withValues(alpha: 0.84)
            : colorScheme.onSurfaceVariant;
        final leadContactColor = isDark
            ? Colors.white.withValues(alpha: 0.92)
            : colorScheme.onSurface;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: GlassBox(
            borderRadius: 20,
            padding: EdgeInsets.zero,
            opacity: isDark ? 0.08 : 0.05,
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.15),
              width: 1,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LeadDetailsPage(lead: lead),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// 🔥 TOP ROW — NAME + ACTIONS
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        /// IMAGE
                        Container(
                          margin: const EdgeInsets.only(right: 12),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: colorScheme.surfaceContainerHighest,
                            child: ClipOval(
                              child: AppNetworkImage(
                                imageUrl: lead.imageUrl,
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),

                        /// NAME (LEFT)
                        Expanded(
                          child: Text(
                            lead.name ?? "",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color: leadTitleColor,
                            ),
                          ),
                        ),

                        /// CHAT ICON
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.chat_bubble_outline,
                            size: 19,
                            color: Colors.green,
                          ),
                          onPressed: () async {
                            final session = await UserStorageService().loadSession();
                            final viewerUserId = session.user?.id;

                            if (!context.mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LeadChatPage(
                                  lead: lead,
                                  viewerUserId: viewerUserId,
                                ),
                              ),
                            );
                          },
                        ),

                        /// POPUP MENU
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            CupertinoIcons.ellipsis_vertical,
                            size: 19,
                            color: leadSecondaryColor,
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
                              onDelete();
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text("Edit"),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                "Delete",
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.error),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    /// COMPANY NAME
                    if ((lead.company_name ?? "").isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          lead.company_name!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: leadSecondaryColor.withValues(alpha: 0.8),
                          ),
                        ),
                      ),

                    /// CONTACT INFO CONTAINER
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          /// PHONE
                          Row(
                            children: [
                              Icon(CupertinoIcons.phone,
                                  size: 14, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                lead.mobile_no_1 ?? "",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: leadContactColor,
                                ),
                              ),
                            ],
                          ),

                          /// EMAIL
                          if ((lead.email ?? "").isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(CupertinoIcons.mail,
                                    size: 14, color: colorScheme.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    lead.email!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: leadContactColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
