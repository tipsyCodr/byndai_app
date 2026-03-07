import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:gridcard/features/business_feed/business_feed_page.dart';
import '../features/chat/connections_page.dart';
import '../features/business_event/business_event_page.dart';
import '../features/analitics/user_analitics_page.dart';

class ActionDock extends StatelessWidget {
  const ActionDock({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainerHighest.withOpacity(0.5)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(24),
        // border: Border.all(
        //     color: colorScheme.onSurface.withOpacity(0.05), width: 0.5),
        border: isDark
            ? Border.all(
                color: colorScheme.onSurface.withOpacity(0.05), width: 0.5)
            : Border.all(
                color: colorScheme.primary,
                width: 1,
              ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionItem(CupertinoIcons.square_grid_2x2, 'Feed', context,
              const BusinessFeedPage()),
          _buildActionItem(CupertinoIcons.calendar, 'Events', context,
              const BusinessEventPage()),
          _buildActionItem(CupertinoIcons.graph_square, 'Analytics', context,
              const UserAnaliticsPage()),
          _buildActionItem(
            CupertinoIcons.person_2, 'Connects', context,
            // const ConnectionsPage()
            const ConnectionsPage(initialTabIndex: 0),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(
      IconData icon, String label, BuildContext context, Widget page) {
    final colorScheme = Theme.of(context).colorScheme;
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.05),
              shape: BoxShape.circle,
              border: Border.all(
                  color: colorScheme.primary.withOpacity(0.1), width: 0.5),
            ),
            child: Icon(
              icon,
              size: 26,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.6),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}
