import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gridcard/core/theme/app_theme.dart';
import 'package:gridcard/features/business_feed/business_feed_page.dart';
import '../features/chat/connections_page.dart';
import '../features/business_event/business_event_page.dart';
import '../features/analitics/user_analitics_page.dart';
import 'package:gridcard/widgets/glass_box.dart';

class ActionDock extends StatelessWidget {
  const ActionDock({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final palette = theme.extension<AppThemeColors>();

    return GlassBox(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      borderRadius: 24,
      opacity: isDark ? 0.22 : 0.5,
      gradientColors: [
        (palette?.glassTop ?? theme.colorScheme.surface)
            .withValues(alpha: isDark ? 0.88 : 0.75),
        (palette?.glassBottom ?? theme.colorScheme.surface)
            .withValues(alpha: isDark ? 0.82 : 0.55),
      ],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionItem(FontAwesomeIcons.newspaper, 'Feed', context,
              const BusinessFeedPage()),
          _buildActionItem(FontAwesomeIcons.calendarDays, 'Events', context,
              const BusinessEventPage()),
          _buildActionItem(FontAwesomeIcons.chartLine, 'Analytics', context,
              const UserAnaliticsPage()),
          _buildActionItem(
            FontAwesomeIcons.userGroup, 'Connects', context,
            // const ConnectionsPage()
            const ConnectionsPage(initialTabIndex: 0),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(
      IconData icon, String label, BuildContext context, Widget page) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final palette = theme.extension<AppThemeColors>();
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => page),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: (isDark
                        ? Colors.white
                        : (palette?.neonAccent ?? colorScheme.primary))
                    .withValues(alpha: 0.2),
                width: 0.8,
              ),
            ),
            child: Icon(
              icon,
              size: 24,
              color: isDark ? colorScheme.onSurface : colorScheme.primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.72),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}

