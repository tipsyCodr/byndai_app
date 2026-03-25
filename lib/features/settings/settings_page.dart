import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/core/services/auth_provider.dart';
import 'package:gridcard/core/services/theme_provider.dart';
import 'package:gridcard/features/profile/profile_page.dart';
import 'package:gridcard/features/profile/edit_profile_page.dart';
import 'package:gridcard/features/settings/change_pin_page.dart';
import 'package:provider/provider.dart';
import 'package:gridcard/routes/route_names.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import './about_dynamic_page.dart';
import './privacy_dynamic_page.dart';
import './support_dynamic_page.dart';
import 'package:gridcard/widgets/top_alert.dart';
import '../flyer module/pages/flyer_home.dart';

import 'package:gridcard/widgets/glass_box.dart';

// \features\flyer module\pages\flyer_home.dart
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const String _baseUrl = AppConfig.apiBaseUrl;
  Map<String, dynamic>? _userDetails;

  @override
  void initState() {
    super.initState();
    _fetchUserDetails(); // 👈 Yaha call hoga
  }

  // ================= HEADERS =================
  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _fetchUserDetails() async {
    try {
      final int? targetUserId = await UserStorageService().getUserId();

      if (targetUserId == null) return;

      final headers = await _getHeaders();
      final url = Uri.parse("$_baseUrl/user-details/$targetUserId");

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded["status"] == true) {
          if (mounted) {
            setState(() {
              _userDetails = decoded["data"];
            });
          }
        }
      }
    } catch (e) {
      debugPrint("🔴 EXCEPTION in _fetchUserDetails(): $e");
    }
  }

  Future<Map<String, dynamic>?> _fetchAboutPage() async {
    try {
      final response = await http.get(
        Uri.parse("$_baseUrl/page/about"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      }
    } catch (e) {
      debugPrint("Error fetching about page: $e");
    }
    return null;
  }

  Future<Map<String, dynamic>?> _fetchPrivacyPage() async {
    try {
      final response = await http.get(
        Uri.parse("$_baseUrl/page/privacy-policy"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      }
    } catch (e) {
      debugPrint("Error fetching privacy page: $e");
    }
    return null;
  }

  Future<Map<String, dynamic>?> _fetchSupportPage() async {
    try {
      final response = await http.get(
        Uri.parse("$_baseUrl/page/support"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      }
    } catch (e) {
      debugPrint("Error fetching support page: $e");
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildSettingsHeader(context, "Profile Management"),
              _buildSettingsTile(
                context: context,
                icon: CupertinoIcons.person_circle,
                title: "Edit Personal Profile",
                subtitle: "Update name, email, and bio",
                onTap: () async {
                  final userId = await UserStorageService().getUserId();
                  if (!mounted) return;

                  Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfilePage(
                          userId: userId,
                          viewerUserId: userId, // self view.......
                        ),
                      ));
                },
              ),
              _buildSettingsTile(
                context: context,
                icon: CupertinoIcons.briefcase,
                title: "Business Information",
                subtitle: "Company name, designation, etc.",
                onTap: () async {
                  if (_userDetails == null) {
                    TopAlert.show(context, "Please wait, loading profile...");
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditProfilePage(
                        userDetails: _userDetails,
                        initialTabIndex: 3,
                      ),
                    ),
                  );
                },
              ),
              _buildSettingsTile(
                context: context,
                icon: CupertinoIcons.link,
                title: "Social Links",
                subtitle: "Manage your digital presence",
                onTap: () {
                  if (_userDetails == null) {
                    TopAlert.show(context, "Please wait, loading profile...");
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditProfilePage(
                        userDetails: _userDetails,
                        initialTabIndex: 1, // 👈 Links tab ka index
                      ),
                    ),
                  );
                },
              ),
              _buildSettingsTile(
                context: context,
                icon: CupertinoIcons.question_circle,
                title: "ByndCanvas",
                onTap: () async {
                  final pageData = await _fetchSupportPage();

                  if (pageData != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FlyerHomePage(),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 16),
              _buildSettingsHeader(context, "Appearance"),
              _buildSettingsTile(
                context: context,
                icon: themeProvider.isDarkMode
                    ? CupertinoIcons.moon_fill
                    : CupertinoIcons.sun_max_fill,
                title: "Dark Mode",
                subtitle: "Switch between light and dark themes",
                onTap: () => themeProvider.toggleTheme(),
                trailing: CupertinoSwitch(
                  value: themeProvider.isDarkMode,
                  onChanged: (val) => themeProvider.toggleTheme(),
                  activeTrackColor: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              _buildSettingsHeader(context, "Account"),
              _buildSettingsTile(
                context: context,
                icon: CupertinoIcons.lock_shield,
                title: "Change PIN",
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ChangePinPage()));
                },
              ),
              _buildSettingsTile(
                context: context,
                icon: CupertinoIcons.square_arrow_right,
                title: "Logout",
                titleColor: Colors.redAccent,
                onTap: () {
                  _showLogoutDialog(context);
                },
                showTrailing: false,
              ),
              const SizedBox(height: 16),
              _buildSettingsHeader(context, "Support & Info"),
              _buildSettingsTile(
                context: context,
                icon: CupertinoIcons.info_circle,
                title: "About ByndAI",
                onTap: () async {
                  final pageData = await _fetchAboutPage();

                  if (!mounted) return;
                  if (pageData != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AboutDynamicPage(pageData: pageData),
                      ),
                    );
                  }
                },
              ),
              _buildSettingsTile(
                context: context,
                icon: CupertinoIcons.doc_text,
                title: "Privacy Policy",
                onTap: () async {
                  final pageData = await _fetchPrivacyPage();

                  if (!mounted) return;
                  if (pageData != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PrivacyDynamicPage(pageData: pageData),
                      ),
                    );
                  }
                },
              ),
              _buildSettingsTile(
                context: context,
                icon: CupertinoIcons.question_circle,
                title: "Support",
                onTap: () async {
                  final pageData = await _fetchSupportPage();

                  if (!mounted) return;
                  if (pageData != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SupportDynamicPage(pageData: pageData),
                      ),
                    );
                  }
                },
              ),

              // _buildSettingsTile(
              //   context: context,
              //   icon: CupertinoIcons.info_circle,
              //   title: "ByndCanvas",
              //   onTap: () async {
              //     final pageData = await _fetchSupportPage();

              //     if (pageData != null) {
              //       Navigator.push(
              //         context,
              //         MaterialPageRoute(
              //           builder: (_) => FlyerHomePage(),
              //         ),
              //       );
              //     }
              //   },
              // ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildSettingsTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? titleColor,
    bool showTrailing = true,
    Widget? trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GlassBox(
        padding: EdgeInsets.zero,
        borderRadius: 16,
        opacity: isDark ? 0.03 : 0.05,
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (titleColor ?? colorScheme.primary).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child:
                Icon(icon, color: titleColor ?? colorScheme.primary, size: 20),
          ),
          title: Text(title,
              style: TextStyle(
                  color: titleColor ?? colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  letterSpacing: 0.2)),
          subtitle: subtitle != null
              ? Text(subtitle,
                  style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 12))
              : null,
          trailing: trailing ??
              (showTrailing
                  ? Icon(CupertinoIcons.chevron_forward,
                      color: colorScheme.onSurface.withValues(alpha: 0.2),
                      size: 18)
                  : null),
          onTap: onTap,
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title: Text("Logout", style: TextStyle(color: colorScheme.primary)),
        content: Text("Are you sure you want to logout?",
            style:
                TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await context.read<AuthProvider>().logout();

              if (!context.mounted) return;

              Navigator.of(context).pushNamedAndRemoveUntil(
                RouteNames.splash, // ya RouteNames.login
                (route) => false, // 🔥 clears full stack
              );
            },
            child:
                const Text("Logout", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
