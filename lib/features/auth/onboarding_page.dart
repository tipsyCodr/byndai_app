import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gridcard/routes/route_names.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final palette = theme.extension<AppThemeColors>();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Container(
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
        child: Stack(
          children: [
            Positioned(
              top: -80,
              left: -80,
              child: IgnorePointer(
                child: Container(
                  width: 240,
                  height: 220,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        (palette?.heroStart ?? colorScheme.primary)
                            .withValues(alpha: isDark ? 0.18 : 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -120,
              right: -100,
              child: IgnorePointer(
                child: Container(
                  width: 280,
                  height: 260,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        (palette?.heroEnd ?? colorScheme.secondary)
                            .withValues(alpha: isDark ? 0.16 : 0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            (palette?.heroStart ?? colorScheme.primary)
                                .withValues(alpha: isDark ? 0.54 : 0.14),
                            (palette?.heroEnd ?? colorScheme.secondary)
                                .withValues(alpha: isDark ? 0.46 : 0.14),
                          ],
                        ),
                        border: Border.all(
                          color: colorScheme.primary
                              .withValues(alpha: isDark ? 0.38 : 0.22),
                        ),
                      ),
                      child: Icon(
                        Icons.auto_awesome,
                        size: 46,
                        color: isDark ? Colors.white : colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Welcome to ${AppConfig.appName}!',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 35,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Connect with the right people and grow faster with a modern networking experience.',
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.8),
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        height: 1.35,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(flex: 3),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('seen_onboarding', true);
                          if (context.mounted) {
                            Navigator.pushReplacementNamed(
                                context, RouteNames.phone);
                          }
                        },
                        child: const Text(
                          'Let\'s Get Started',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
