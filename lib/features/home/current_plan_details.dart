import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gridcard/core/services/auth_provider.dart';
import 'package:intl/intl.dart';
import 'package:gridcard/widgets/glass_box.dart';
import 'package:gridcard/features/home/SubscriptionPlans.dart';
import 'package:gridcard/core/theme/app_theme.dart';

class CurrentPlanDetails extends StatelessWidget {
  const CurrentPlanDetails({super.key});

  @override
  Widget build(BuildContext context) {
    final subscription = context.watch<AuthProvider>().subscriptionDetails;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final palette = Theme.of(context).extension<AppThemeColors>();

    if (subscription == null) {
      return Scaffold(
        backgroundColor: palette?.backgroundStart ?? colorScheme.surface,
        appBar: AppBar(
          title: const Text("Plan Details"),
          backgroundColor: Colors.transparent,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                palette?.backgroundStart ?? colorScheme.surface,
                palette?.backgroundMid ?? colorScheme.surface,
                palette?.backgroundEnd ?? colorScheme.surface,
              ],
            ),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final planName = subscription['plan_name'] ?? subscription['plan']?['name'] ?? 'Premium';
    
    // Look for expires_at, end_date (from is-pro API), or fallback
    final rawExpiry = subscription['expires_at'] ?? subscription['end_date'] ?? subscription['active_subscription']?['end_date'];
    final expiresAt = rawExpiry != null 
        ? DateTime.tryParse(rawExpiry.toString())
        : null;
        
    final daysLeft = subscription['days_left'] ?? 
        (expiresAt != null ? expiresAt.difference(DateTime.now()).inDays : 0);

    return Scaffold(
      backgroundColor: palette?.backgroundStart ?? colorScheme.surface,
      appBar: AppBar(
        title: const Text("Your Subscription"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: colorScheme.onSurface,
      ),
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              palette?.backgroundStart ?? colorScheme.surface,
              palette?.backgroundMid ?? colorScheme.surface,
              palette?.backgroundEnd ?? colorScheme.surface,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
            // Plan Card
            GlassBox(
              borderRadius: 24,
              padding: const EdgeInsets.all(24),
              opacity: isDark ? 0.05 : 0.08,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.secondary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "PRO MEMBER",
                      style: TextStyle(
                        color: colorScheme.onSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    planName,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Active Subscription",
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const Divider(height: 40),
                  _buildDetailRow(
                    context, 
                    CupertinoIcons.calendar, 
                    "Expires On", 
                    expiresAt != null ? DateFormat('MMM dd, yyyy').format(expiresAt) : "N/A"
                  ),
                  const SizedBox(height: 20),
                  _buildDetailRow(
                    context, 
                    CupertinoIcons.time, 
                    "Days Remaining", 
                    "$daysLeft Days"
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            
            // Manage Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SubscriptionPlans()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text("View All Plans / Upgrade"),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: colorScheme.primary),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
