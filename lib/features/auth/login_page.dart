import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:gridcard/core/services/auth_provider.dart';
import 'package:gridcard/core/theme/app_theme.dart';
import 'package:gridcard/routes/route_names.dart';
import 'package:provider/provider.dart';
import 'package:gridcard/widgets/glass_box.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleGoogleSignIn(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) => Center(
        child: SpinKitPulse(
          color: colorScheme.primary,
          size: 60.0,
        ),
      ),
    );

    final auth = context.read<AuthProvider>();
    final result = await auth.signInWithGoogle();

    if (mounted) Navigator.pop(context);

    switch (result) {
      case GoogleSignInResult.loggedIn:
        if (mounted) {
          Navigator.pushReplacementNamed(context, RouteNames.home);
        }
        break;
      case GoogleSignInResult.needsRegistration:
        if (mounted) {
          Navigator.pushNamed(context, RouteNames.googleRegister);
        }
        break;
      case GoogleSignInResult.failed:
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Google Sign-In failed. Please try again.')),
          );
        }
        break;
    }
  }

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
            // --- Animated Background Blobs ---
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Stack(
                  children: [
                    // Moving Blob 1
                    Positioned(
                      top: -100 + (30 * _controller.value),
                      left: -100 +
                          (20 * math.sin(_controller.value * 2 * math.pi)),
                      child: _buildBlob(
                        size: 300,
                        color: (palette?.heroStart ?? colorScheme.primary)
                            .withValues(alpha: isDark ? 0.25 : 0.15),
                      ),
                    ),
                    // Moving Blob 2
                    Positioned(
                      bottom: -120 +
                          (40 * math.cos(_controller.value * 2 * math.pi)),
                      right: -80 + (30 * _controller.value),
                      child: _buildBlob(
                        size: 350,
                        color: (palette?.heroEnd ?? colorScheme.secondary)
                            .withValues(alpha: isDark ? 0.2 : 0.12),
                      ),
                    ),
                    // Moving Blob 3 (New for depth)
                    Positioned(
                      top: MediaQuery.of(context).size.height * 0.4 +
                          (50 * math.sin(_controller.value * 2 * math.pi)),
                      right: -100 + (20 * _controller.value),
                      child: _buildBlob(
                        size: 200,
                        color: (palette?.neonAccent ?? colorScheme.tertiary)
                            .withValues(alpha: isDark ? 0.15 : 0.08),
                      ),
                    ),
                  ],
                );
              },
            ),

            // Subtle Grain/Texture overlay
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: isDark ? 0.05 : 0.12),
                        Colors.white.withValues(alpha: isDark ? 0.01 : 0.05),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.46, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    // Animated Logo Container
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(seconds: 1),
                      curve: Curves.easeOutBack,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: child,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              (palette?.heroStart ?? colorScheme.primary)
                                  .withValues(alpha: isDark ? 0.6 : 0.14),
                              (palette?.heroEnd ?? colorScheme.secondary)
                                  .withValues(alpha: isDark ? 0.6 : 0.14),
                            ],
                          ),
                          border: Border.all(
                            color: (palette?.neonAccent ?? colorScheme.primary)
                                .withValues(alpha: isDark ? 0.5 : 0.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (palette?.heroStart ?? colorScheme.primary)
                                  .withValues(alpha: isDark ? 0.2 : 0.1),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          CupertinoIcons.sparkles,
                          size: 68,
                          color: isDark ? Colors.white : colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Welcome to ByndAI',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Secure, AI-powered networking starts here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15.5,
                        letterSpacing: 0.15,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    GlassBox(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: FilledButton(
                              onPressed: () {
                                Navigator.pushNamed(context, RouteNames.phone);
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ).copyWith(
                                overlayColor: WidgetStateProperty.all(
                                    Colors.white.withValues(alpha: 0.1)),
                              ),
                              child: const Text(
                                'Login with Mobile',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: colorScheme.outlineVariant
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: colorScheme.outlineVariant
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: OutlinedButton.icon(
                              onPressed: () => _handleGoogleSignIn(context),
                              icon: FaIcon(
                                FontAwesomeIcons.google,
                                size: 20,
                                color: colorScheme.primary,
                              ),
                              label: Text(
                                'Sign in with Google',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.3),
                                side: BorderSide(
                                  color: colorScheme.outlineVariant
                                      .withValues(alpha: 0.5),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account?",
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, RouteNames.phone);
                          },
                          child: Text(
                            'Sign Up',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Debug flows for easier testing
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () =>
                              Navigator.pushNamed(context, RouteNames.register),
                          icon: const Icon(Icons.bug_report, size: 14),
                          label: const Text("Dev: Register"),
                          style: TextButton.styleFrom(
                            foregroundColor:
                                colorScheme.error.withValues(alpha: 0.5),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => Navigator.pushNamed(
                              context, RouteNames.googleRegister),
                          icon: const Icon(Icons.bug_report, size: 14),
                          label: const Text("Dev: G-Register"),
                          style: TextButton.styleFrom(
                            foregroundColor:
                                colorScheme.error.withValues(alpha: 0.5),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlob({required double size, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withValues(alpha: 0.5),
            Colors.transparent,
          ],
          stops: const [0.0, 0.3, 1.0],
        ),
      ),
    );
  }
}
