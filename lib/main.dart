import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load session BEFORE running app to determine initial route
  debugPrint('[MAIN] Checking for existing session...');
  final storageService = UserStorageService();
  final session = await storageService.loadSession();
  final hasValidSession = session.isValid;
  debugPrint('[MAIN] Session valid: $hasValidSession');

  final initialRoute = hasValidSession ? RouteNames.home : RouteNames.splash;
  debugPrint('[MAIN] Initial route: $initialRoute');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) {
          final auth = AuthProvider();
          // Pre-populate auth state if session is valid
          if (hasValidSession) {
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
      routes: AppRoutes.routes,
      title: AppConfig.appName,
    );
  }
}
