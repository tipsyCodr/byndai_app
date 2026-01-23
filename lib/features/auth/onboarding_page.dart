import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gridcard/routes/route_names.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
        child: Column(
          children: [
            const SizedBox(height: 200),
            Text(
              'Welcome to ${AppConfig.appName}!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Connect with the right people.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w300,
                fontFamily: 'Poppins',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                style:
                    FilledButton.styleFrom(backgroundColor: Colors.blueAccent),
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('seen_onboarding', true);
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, RouteNames.phone);
                  }
                },
                child: const Text('Let\'s Get Started'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
