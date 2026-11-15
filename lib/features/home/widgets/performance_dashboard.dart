import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gridcard/core/services/user_stats_provider.dart';
import 'package:gridcard/widgets/glass_box.dart';
import 'package:gridcard/widgets/top_alert.dart';
import 'package:gridcard/core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../analitics/user_analitics_page.dart';

class PerformanceDashboard extends StatelessWidget {
  final VoidCallback onIncompleteMilestone;

  const PerformanceDashboard({
    super.key,
    required this.onIncompleteMilestone,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = Theme.of(context).extension<AppThemeColors>();

    return Selector<UserStatsProvider, bool>(
      selector: (_, p) => p.profileCompletionPercent < 100,
      builder: (context, isIncomplete, _) {
        return GestureDetector(
          onTap: () {
            if (isIncomplete) {
              onIncompleteMilestone();
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserAnaliticsPage()),
              );
            }
          },
          child: GlassBox(
            padding: EdgeInsets.zero,
            borderRadius: 24,
            border: Border(
              bottom: BorderSide(
                color: (palette?.neonAccent ?? colorScheme.secondary)
                    .withValues(alpha: isDark ? 0.42 : 0.55),
                width: 5,
              ),
            ),
            gradientColors: [
              isDark
                  ? const Color(0xFF353D5A).withValues(alpha: 0.94)
                  : colorScheme.primary.withValues(alpha: 0.92),
              isDark
                  ? const Color(0xFF2D3550).withValues(alpha: 0.9)
                  : colorScheme.primary.withValues(alpha: 0.88),
            ],
            child: Stack(
              children: [
                _buildBackgroundGradients(isDark),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context, isDark, colorScheme),
                      const SizedBox(height: 16),
                      _buildContent(context, colorScheme, palette, isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackgroundGradients(bool isDark) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: isDark ? 0.11 : 0.16),
                      Colors.white.withValues(alpha: isDark ? 0.04 : 0.08),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.42, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: -52,
            left: -42,
            child: IgnorePointer(
              child: Container(
                width: 220,
                height: 170,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: isDark ? 0.12 : 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, bool isDark, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'NETWORK IMPACT',
          style: TextStyle(
            color: isDark
                ? Colors.white.withValues(alpha: 0.94)
                : colorScheme.onPrimary.withValues(alpha: 0.92),
            fontWeight: FontWeight.bold,
            fontSize: 10,
            letterSpacing: 2.0,
          ),
        ),
        Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UserAnaliticsPage()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bar_chart,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                "LIVE",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, ColorScheme colorScheme,
      AppThemeColors? palette, bool isDark) {
    return Selector<UserStatsProvider, bool>(
      selector: (_, p) => p.isLoading,
      builder: (context, isLoading, child) {
        if (isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }
        return child!;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildViewCount(),
          const SizedBox(height: 20),
          _buildProgressOrStats(context, colorScheme, palette, isDark),
        ],
      ),
    );
  }

  Widget _buildViewCount() {
    return Selector<UserStatsProvider, int>(
      selector: (_, p) => p.totalViewCount,
      builder: (context, views, _) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              views.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.w900,
                height: 1.0,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  )
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "views",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProgressOrStats(BuildContext context, ColorScheme colorScheme,
      AppThemeColors? palette, bool isDark) {
    return Selector<UserStatsProvider, double>(
      selector: (_, p) => p.profileCompletionPercent,
      builder: (context, percent, _) {
        if (percent < 100) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Profile Progress",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  Text(
                    "${percent.toInt()}%",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildProgressBar(context, colorScheme, palette, percent),
            ],
          );
        } else {
          return Consumer<UserStatsProvider>(
            builder: (context, provider, _) {
              return Row(
                children: [
                  _miniStatCard(
                    context: context,
                    icon: FontAwesomeIcons.clock,
                    value:
                        "${(provider.totalTimeSeconds / 60).toStringAsFixed(1)}m",
                    label: "Time Spent",
                  ),
                  const SizedBox(width: 12),
                  _miniStatCard(
                    context: context,
                    icon: FontAwesomeIcons.star,
                    value: provider.averageRating.toStringAsFixed(1),
                    label: "${provider.totalReviews} reviews",
                  ),
                ],
              );
            },
          );
        }
      },
    );
  }

  Widget _buildProgressBar(BuildContext context, ColorScheme colorScheme,
      AppThemeColors? palette, double percent) {
    return Stack(
      children: [
        Container(
          height: 10,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(seconds: 1),
          curve: Curves.easeOutCubic,
          height: 10,
          width: (MediaQuery.of(context).size.width - 72) *
              (percent / 100).clamp(0.0, 1.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                palette?.neonAccent ?? colorScheme.secondary,
                (palette?.neonAccent ?? colorScheme.secondary)
                    .withValues(alpha: 0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: colorScheme.secondary.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _miniStatCard({
    required BuildContext context,
    required FaIconData icon,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FaIcon(icon, size: 14, color: Colors.white70),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
