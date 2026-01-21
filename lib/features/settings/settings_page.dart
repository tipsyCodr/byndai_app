import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/core/services/auth_provider.dart';
import 'package:gridcard/core/services/theme_provider.dart';
import 'package:gridcard/features/profile/business_info_page.dart';
import 'package:gridcard/features/profile/links_management_page.dart';
import 'package:gridcard/features/profile/profile_page.dart';
import 'package:gridcard/features/settings/change_pin_page.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ProfilePage()));
                },
              ),
              _buildSettingsTile(
                context: context,
                icon: CupertinoIcons.briefcase,
                title: "Business Information",
                subtitle: "Company name, designation, etc.",
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const BusinessInfoPage()));
                },
              ),
              _buildSettingsTile(
                context: context,
                icon: CupertinoIcons.link,
                title: "Social Links",
                subtitle: "Manage your digital presence",
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LinksManagementPage()));
                },
              ),
              Divider(
                  color: colorScheme.onSurface.withOpacity(0.05), height: 40),
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
                  activeColor: colorScheme.primary,
                ),
              ),
              Divider(
                  color: colorScheme.onSurface.withOpacity(0.05), height: 40),
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
              Divider(
                  color: colorScheme.onSurface.withOpacity(0.05), height: 40),
              _buildSettingsHeader(context, "Support & Info"),
              _buildSettingsTile(
                context: context,
                icon: CupertinoIcons.info_circle,
                title: "About ByndAI",
                onTap: () {
                  _showInfoPage(context, "About ByndAI",
                      "ByndAI is your ultimate digital networking companion. Scan business cards, manage leads, and grow your professional presence with ease.\n\nVersion 1.0.0");
                },
              ),
              _buildSettingsTile(
                context: context,
                icon: CupertinoIcons.doc_text,
                title: "Privacy Policy",
                onTap: () {
                  _showInfoPage(context, "Privacy Policy",
                      "Your privacy is important to us. We never share your data with third parties without your explicit consent. All business card data is stored securely.\n\nRead more on our website.");
                },
              ),
              _buildSettingsTile(
                context: context,
                icon: CupertinoIcons.question_circle,
                title: "Support",
                onTap: () {
                  _showInfoPage(context, "Support",
                      "Need help? Contact us at support@byndai.com or visit our help center in the app.");
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }

  void _showInfoPage(BuildContext context, String title, String content) {
    final colorScheme = Theme.of(context).colorScheme;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: colorScheme.surface,
          appBar: AppBar(
            title: Text(title, style: TextStyle(color: colorScheme.primary)),
            backgroundColor: colorScheme.surface,
            leading: IconButton(
              icon: Icon(CupertinoIcons.back, color: colorScheme.primary),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              content,
              style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 16,
                  height: 1.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 14),
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
    return ListTile(
      leading: Icon(icon, color: titleColor ?? colorScheme.primary),
      title: Text(title,
          style: TextStyle(
              color: titleColor ?? colorScheme.onSurface,
              fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)))
          : null,
      trailing: trailing ??
          (showTrailing
              ? Icon(Icons.chevron_right,
                  color: colorScheme.onSurface.withOpacity(0.1))
              : null),
      onTap: onTap,
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
            style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              context.read<AuthProvider>().logout();
              Navigator.pop(context); // Close dialog
            },
            child:
                const Text("Logout", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
