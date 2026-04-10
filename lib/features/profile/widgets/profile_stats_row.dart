import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ProfileStatsRow extends StatelessWidget {
  final int connectionsCount;
  final int viewsCount;
  final int linksCount;
  final double rating;
  final int totalReviews;

  const ProfileStatsRow({
    super.key,
    this.connectionsCount = 0,
    this.viewsCount = 0,
    this.linksCount = 0,
    this.rating = 0.0,
    this.totalReviews = 0,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildStatChip(
            context,
            icon: Icons.people_outline,
            label: "$connectionsCount Connections",
          ),
          const SizedBox(width: 8),
          _buildStatChip(
            context,
            icon: Icons.visibility_outlined,
            label: "$viewsCount Views",
          ),
          const SizedBox(width: 8),
          _buildStatChip(
            context,
            icon: Icons.link,
            label: "$linksCount Links",
          ),
          const SizedBox(width: 8),
          _buildStatChip(
            context,
            icon: Icons.star_outline,
            label: "${rating.toStringAsFixed(1)} ($totalReviews Reviews)",
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(BuildContext context,
      {required IconData icon, required String label}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white12 : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white24 : Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
