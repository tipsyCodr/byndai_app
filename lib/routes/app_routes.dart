import 'package:flutter/material.dart';
import 'package:gridcard/features/auth/login_page.dart';
import 'package:gridcard/features/auth/register_page.dart';
import '../features/auth/onboarding_page.dart';
import '../features/home/home_page.dart';
import '../features/profile/profile_page.dart';
import '../features/auth/splash_screen.dart';
import '../features/auth/phone_verification_page.dart';
import './route_names.dart';
import '../features/qr_scan/profile_qr_code.dart';

class AppRoutes {
  static Map<String, WidgetBuilder> get routes => {
        RouteNames.splash: (context) => SplashScreen(),
        RouteNames.home: (context) => HomePage(),
        RouteNames.profile: (context) => ProfilePage(),
        RouteNames.login: (context) => LoginPage(),
        RouteNames.register: (context) => RegisterPage(),
        RouteNames.onboarding: (context) => OnboardingPage(),
        RouteNames.phone: (context) => PhoneVerificationPage(),
        RouteNames.profile_qr: (context) => ProfileQRCodePage(),
      };
}
