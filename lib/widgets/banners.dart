import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class Banners extends StatelessWidget {
  const Banners({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        _buildPremiumBanner(
          context,
          colorScheme.primary,
          'AI Business Insights',
          'Unlock deep analytics for your card views.',
          CupertinoIcons.sparkles,
        ),
        const SizedBox(height: 16),
        _buildPremiumBanner(
          context,
          const Color(0xFF6B4EE6),
          'Expand Your Network',
          'Connect with 50+ industry leaders near you.',
          CupertinoIcons.person_3_fill,
        ),
        const SizedBox(height: 16),
        _buildPremiumBanner(
          context,
          const Color(0xFFE64E4E),
          'Secure Card Sharing',
          'End-to-end encrypted profile transfers.',
          CupertinoIcons.lock_shield_fill,
        ),
      ],
    );
  }

  Widget _buildPremiumBanner(BuildContext context, Color accentColor,
      String title, String subtitle, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHighest : Colors.grey[100],
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: colorScheme.onSurface.withOpacity(0.05), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: accentColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                      color:
                          isDark ? colorScheme.onSurface : colorScheme.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.5),
                      fontSize: 11,
                      height: 1.3),
                ),
              ],
            ),
          ),
          Icon(CupertinoIcons.chevron_right,
              color: colorScheme.onSurface.withOpacity(0.1), size: 14),
        ],
      ),
    );
  }
}
