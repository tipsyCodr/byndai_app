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
    final auth = context.watch<AuthProvider>();
    final subscription = auth.subscriptionDetails;
    final isPro = auth.isPro;
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

    final planName = subscription['plan_name'] ?? subscription['plan']?['name'] ?? 'Free';
    
    // Look for expires_at, end_date (from is-pro API), or fallback
    final rawExpiry = subscription['expires_at'] ?? subscription['end_date'] ?? subscription['active_subscription']?['end_date'];
    final expiresAt = rawExpiry != null 
        ? DateTime.tryParse(rawExpiry.toString())
        : null;

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
                      color: isPro ? colorScheme.secondary : colorScheme.onSurface.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isPro ? "PRO MEMBER" : "FREE MEMBER",
                      style: TextStyle(
                        color: isPro ? colorScheme.onSecondary : colorScheme.onSurface.withValues(alpha: 0.7),
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
                ],
              ),
            ),
            const SizedBox(height: 30),
            
            // Available Plans Carousel
            const SubscriptionPlans(isEmbedded: true),

            // Coming Next Section (Queued Plan)
            if (subscription['upcoming'] != null && subscription['upcoming']['has_upcoming'] == true) ...[
              const SizedBox(height: 40),
              Row(
                children: [
                  Text(
                    "Coming Next",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "QUEUED",
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GlassBox(
                borderRadius: 20,
                padding: const EdgeInsets.all(20),
                opacity: isDark ? 0.05 : 0.08,
                child: Column(
                  children: [
                    _buildDetailRow(
                      context,
                      CupertinoIcons.arrow_right_circle,
                      "Next Plan",
                      subscription['upcoming']['next_plan']['name'] ?? "Premium"
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      context,
                      CupertinoIcons.calendar_badge_plus,
                      "Starts After",
                      expiresAt != null ? DateFormat('MMM dd, yyyy').format(expiresAt) : "Expiry"
                    ),
                  ],
                ),
              ),
            ],
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
