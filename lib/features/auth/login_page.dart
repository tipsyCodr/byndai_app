import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:gridcard/core/services/auth_provider.dart';
import 'package:gridcard/core/theme/app_theme.dart';
import 'package:gridcard/routes/route_names.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  void _handleGoogleSignIn(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) => Center(
        child: SpinKitPulsingGrid(
          color: colorScheme.secondary,
          size: 60.0,
        ),
      ),
    );

    final auth = context.read<AuthProvider>();
    final result = await auth.signInWithGoogle();

    if (context.mounted) Navigator.pop(context);

    switch (result) {
      case GoogleSignInResult.loggedIn:
        if (context.mounted) {
          Navigator.pushReplacementNamed(context, RouteNames.home);
        }
        break;
      case GoogleSignInResult.needsRegistration:
        if (context.mounted) {
          Navigator.pushNamed(context, RouteNames.googleRegister);
        }
        break;
      case GoogleSignInResult.failed:
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
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: isDark ? 0.06 : 0.15),
                        Colors.white.withValues(alpha: isDark ? 0.02 : 0.08),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.46, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -90,
              left: -90,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      (palette?.heroStart ?? colorScheme.primary)
                          .withValues(alpha: isDark ? 0.2 : 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -120,
              right: -80,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      (palette?.heroEnd ?? colorScheme.secondary)
                          .withValues(alpha: isDark ? 0.18 : 0.1),
                      Colors.transparent,
                    ],
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
                    Container(
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
                      ),
                      child: Icon(
                        CupertinoIcons.sparkles,
                        size: 68,
                        color: isDark ? Colors.white : colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Welcome to ByndAI',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface.withValues(alpha: 0.98),
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
                        color: colorScheme.onSurface.withValues(alpha: 0.78),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pushNamed(context, RouteNames.phone);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Login with Mobile',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: colorScheme.onSurface.withValues(alpha: 0.16),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: colorScheme.onSurface.withValues(alpha: 0.56),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: colorScheme.onSurface.withValues(alpha: 0.16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: OutlinedButton.icon(
                        onPressed: () => _handleGoogleSignIn(context),
                        icon: Icon(
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
                          backgroundColor:
                              (palette?.glassTop ?? Colors.white).withValues(alpha: 0.45),
                          side: BorderSide(
                            color: colorScheme.primary.withValues(alpha: 0.24),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account?",
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
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
}
