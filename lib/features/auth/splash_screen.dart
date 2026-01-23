import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gridcard/core/services/auth_provider.dart';
import 'package:gridcard/routes/route_names.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(duration: const Duration(seconds: 2), vsync: this)
          ..forward();

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);

    // After animation, navigate to phone verification
    // (Session check is now done in main.dart before app starts)
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // If user somehow lands here with valid session, go to home
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isAuthenticated) {
      Navigator.pushReplacementNamed(context, RouteNames.home);
    } else {
      Navigator.pushReplacementNamed(context, RouteNames.phone);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/app-logo.jpg', height: 70),
              const SizedBox(height: 16),
              const Text("Let's Connect",
                  style: TextStyle(color: Colors.black, fontSize: 20)),
            ],
          ),
        ),
      ),
    );
  }
}
