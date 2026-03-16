import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/auth_provider.dart';
import 'package:gridcard/core/services/chat_provider.dart';
import 'package:gridcard/core/services/lead_provider.dart';
import 'package:gridcard/core/services/leads_provider.dart';
import 'package:gridcard/core/services/product_provider.dart';
import 'package:gridcard/core/services/profile_provider.dart';
import 'package:gridcard/core/services/social_provider.dart';
import 'package:gridcard/core/services/theme_provider.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:gridcard/routes/app_routes.dart';
import 'package:gridcard/routes/route_names.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:gridcard/core/services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:ui';
import 'firebase_options.dart';
import 'package:gridcard/core/services/nfc_service.dart';

late final FirebaseAnalytics analytics;

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    debugPrint('[MAIN] Initializing Firebase...');
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      // Initialize Analytics & Crashlytics only if Firebase init succeeded
      analytics = FirebaseAnalytics.instance;
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      debugPrint('[MAIN] Firebase & Crashlytics Initialized.');
    } catch (e) {
      debugPrint('[MAIN] ⚠️ Firebase Initialization failed: $e');
    }

    debugPrint('[MAIN] Initializing Notifications...');
    try {
      await NotificationService.initialize();
      FirebaseMessaging.onBackgroundMessage(NotificationService.firebaseMessagingBackgroundHandler);
      debugPrint('[MAIN] Notifications Initialized.');
    } catch (e) {
      debugPrint('[MAIN] ⚠️ Notification Initialization failed: $e');
    }

    // Load session determining initial route
    debugPrint('[MAIN] Checking for existing session...');
    bool hasValidSession = false;
    UserSession? session;
    try {
      final storageService = UserStorageService();
      session = await storageService.loadSession();
      hasValidSession = session.isValid;
      debugPrint('[MAIN] Session valid: $hasValidSession');
    } catch (e) {
      debugPrint('[MAIN] ⚠️ Session loading failed: $e');
    }

    final initialRoute = hasValidSession ? RouteNames.home : RouteNames.splash;
    debugPrint('[MAIN] Initial route: $initialRoute');

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) {
            final auth = AuthProvider();
            if (hasValidSession && session != null) {
              auth.restoreSession(session);
            }
            return auth;
          }),
          ChangeNotifierProvider(create: (context) => LeadProvider()),
          ChangeNotifierProvider(create: (context) => LeadProviders()),
          ChangeNotifierProvider(create: (context) => ProfileProvider()),
          ChangeNotifierProvider(create: (context) => ProductProvider()),
          ChangeNotifierProvider(create: (context) => SocialProvider()),
          ChangeNotifierProvider(create: (context) => ChatProvider()),
          ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ],
        child: MyApp(initialRoute: initialRoute),
      ),
    );
  } catch (e, stack) {
    debugPrint('[MAIN] 🚨 FATAL ERROR during initialization: $e');
    debugPrint(stack.toString());
    
    // Attempt to run app anyway with splash screen if something really weird happened
    runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('Initialization Error. Please restart the app.')))));
  }
}

class MyApp extends StatelessWidget {
  final String initialRoute;

  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: ThemeData(
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF21254A), // Deep navy accent
          onPrimary: Colors.white,
          secondary: Colors.grey,
          onSecondary: Colors.white,
          error: Colors.red,
          onError: Colors.white,
          surface: Colors.white,
          onSurface: Color(0xFF21254A),
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF5C6BC0), // Brighter Navy for dark mode pop
          onPrimary: Colors.white,
          secondary: Colors.grey,
          surface: const Color(0xFF0F111F), // Deep space navy
          onSurface: Colors.white,
          surfaceContainerHighest: const Color(0xFF1B1E3B), // Card background
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0F111F),
      ),
      initialRoute: initialRoute,
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: analytics),
      ],
      routes: AppRoutes.routes,
      title: AppConfig.appName,
    );
  }
}
