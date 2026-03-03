import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:gridcard/core/services/auth_provider.dart';
import 'package:gridcard/routes/route_names.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  void _handleGoogleSignIn(BuildContext context) async {
    // Show loader
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) => const Center(
        child: SpinKitPulsingGrid(
          color: Color.fromARGB(255, 92, 165, 225),
          size: 60.0,
        ),
      ),
    );

    final auth = context.read<AuthProvider>();
    final result = await auth.signInWithGoogle();

    // Dismiss loader
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
        // Toast is already shown by the provider
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              const Color(0xFF21254A).withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF21254A).withOpacity(0.05),
                    border: Border.all(
                      color: const Color(0xFF21254A).withOpacity(0.1),
                    ),
                  ),
                  child: const Icon(
                    CupertinoIcons.lock_shield_fill,
                    size: 80,
                    color: Color(0xFF21254A),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  "Welcome to ByndAI",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF21254A),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Secure, AI-powered networking start here.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
                const Spacer(),

                // Login with Mobile Button
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pushNamed(context, RouteNames.phone);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF21254A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "Login with Mobile",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // OR divider
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text("OR",
                          style:
                              TextStyle(color: Colors.black54, fontSize: 13)),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ],
                ),

                const SizedBox(height: 14),

                // Google Sign-In Button
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: OutlinedButton.icon(
                    onPressed: () => _handleGoogleSignIn(context),
                    icon: const Icon(Icons.g_mobiledata,
                        size: 28, color: Color(0xFF21254A)),
                    label: const Text(
                      "Sign in with Google",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF21254A),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFDDDDDD)),
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
                    const Text(
                      "Don't have an account?",
                      style: TextStyle(color: Colors.black54),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, RouteNames.phone);
                      },
                      child: const Text(
                        "Sign Up",
                        style: TextStyle(
                          color: Color(0xFF21254A),
                          fontWeight: FontWeight.bold,
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
      ),
    );
  }
}
