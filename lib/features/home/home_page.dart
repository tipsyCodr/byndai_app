import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ Added for SystemNavigator
import 'package:gridcard/features/discover/discover_page.dart';
import 'package:gridcard/features/leads/leads_page.dart';
import 'package:gridcard/features/profile/profile_page.dart';
import 'package:gridcard/features/settings/settings_page.dart';
import 'package:gridcard/features/home/feed_page.dart';
import 'package:gridcard/core/services/auth_provider.dart'; // ✅ Your AuthProvider
import 'package:gridcard/features/chat/connections_page.dart';
import 'package:provider/provider.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:gridcard/routes/route_names.dart';
import 'package:gridcard/widgets/top_alert.dart';
import '../qr_scan/profile_qr_code.dart';
import 'dart:ui';
import 'package:gridcard/config/app_config.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime? _lastBackPressed;
  // String? _profileLogoUrl;

  final GlobalKey<FeedPageState> _feedKey = GlobalKey<FeedPageState>();

  @override
  void initState() {
    super.initState();
    // _loadProfileLogo();
  }

  // Future<void> _loadProfileLogo() async {
  //   final session = await UserStorageService().loadSession();

  //   final masterUser = session.user?.masterUser;

  //   final logo = masterUser?.profilePic;

  //   if (logo != null && logo.isNotEmpty) {
  //     setState(() {
  //       _profileLogoUrl = "${AppConfig.apiProfileImg}/$logo";
  //     });
  //   }

  //   debugPrint("🟦 FINAL PROFILE LOGO URL = $_profileLogoUrl");
  // }

  Future<void> _onPop(bool didPop, Object? result) async {
    if (didPop) return;

    // If not on the Home tab, navigate back to Home first
    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
      _lastBackPressed = null; // Reset so double-press starts fresh on Home
      return;
    }

    // On Home tab: double-press to exit
    final now = DateTime.now();
    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      TopAlert.show(context, "Press back again to exit");
      return;
    }

    SystemNavigator.pop();
  }

  int _selectedIndex = 0;

  // Screens for each tab
  // final List<Widget> _screens = [
  //   // const FeedPage(),
  //   FeedPage(key: _feedKey),
  //   const LeadsPage(),
  //   const DiscoverPage(),
  //   const SettingsPage(),
  // ];

  List<Widget> _screens() {
    return [
      FeedPage(key: _feedKey),
      const LeadsPage(),
      const DiscoverPage(),
      const SettingsPage(),
    ];
  }

  final List<String> _titles = [
    'Home',
    'My Leads',
    'Discover',
    'Settings',
  ];

  // void _onItemTapped(int index) {
  //   setState(() => _selectedIndex = index);
  // }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);

    if (index == 0) {
      _feedKey.currentState?.refreshFeed();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final auth = Provider.of<AuthProvider>(context, listen: false);

    // Redirect to login if not authenticated
    if (!auth.isAuthenticated) {
      Future.microtask(() {
        if (mounted) {
          // Clear the stack and go to login so back does not return to home
          Navigator.pushNamedAndRemoveUntil(
              context, RouteNames.phone, (route) => false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    final logoUrl = user?.masterUser?.profilePic != null
        ? "${AppConfig.apiProfileImg}/${user!.masterUser!.profilePic}"
        : null;
    return PopScope<Object?>(
      canPop: false, // disable default popping
      onPopInvokedWithResult: _onPop,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        extendBody: true,
        appBar: AppBar(
          backgroundColor: colorScheme.surface.withOpacity(0.8),
          elevation: 0,
          foregroundColor: colorScheme.primary,
          title: Text(
            _titles[_selectedIndex],
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          automaticallyImplyLeading: false,
          leading: IconButton(
            // icon:
            //     Icon(Icons.account_circle_outlined, color: colorScheme.primary),
            // icon: CircleAvatar(
            //   radius: 28,
            //   backgroundColor: Colors.grey.shade200,
            //   backgroundImage: (_profileLogoUrl != null)
            //       ? NetworkImage(_profileLogoUrl!)
            //       : null,
            //   child: (_profileLogoUrl == null)
            //       ? Icon(Icons.person, color: colorScheme.primary)
            //       : null,
            // ),

            icon: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: logoUrl != null ? NetworkImage(logoUrl) : null,
              child: logoUrl == null
                  ? Icon(Icons.person, color: colorScheme.primary)
                  : null,
            ),

            onPressed: () async {
              final userId = await UserStorageService().getUserId();

              if (userId == null) {
                TopAlert.show(context, "User ID not found", isError: true);
                return;
              }

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ProfilePage(
                    userId: userId,
                    viewerUserId: userId, // self view
                  ),
                ),
              );
            },
          ),
          actions: [
            IconButton(
              icon: Icon(CupertinoIcons.qrcode, color: colorScheme.primary),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ProfileQRCodePage(),
                  ),
                );
              },
            ),
            IconButton(
              icon: Icon(CupertinoIcons.chat_bubble_text,
                  color: colorScheme.primary),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (context) => const ConnectionsPage()),
                );
              },
            ),
          ],
        ),
        // body: Stack(
        //   children: [
        //     _screens[_selectedIndex],
        //     _buildFloatingDock(),
        //   ],
        // ),

        body: Stack(
          children: [
            _screens()[_selectedIndex],
            _buildFloatingDock(),
          ],
        ),
      ),
    );
  }

  // Widget _buildFloatingDock() {
  //   final colorScheme = Theme.of(context).colorScheme;
  //   final isDark = Theme.of(context).brightness == Brightness.dark;

  //   return Positioned(
  //     bottom: 12, // 🔥 closer to bottom
  //     left: 16,
  //     right: 16,
  //     child: ClipRRect(
  //       borderRadius: BorderRadius.circular(26),
  //       child: BackdropFilter(
  //         filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
  //         child: Container(
  //           height: 56, // 🔥 compact height
  //           decoration: BoxDecoration(
  //             color: isDark
  //                 ? colorScheme.surfaceContainerHighest.withOpacity(0.9)
  //                 : const Color(0xFF21254A).withOpacity(0.92),
  //             borderRadius: BorderRadius.circular(26),
  //             border:
  //                 Border.all(color: Colors.white.withOpacity(0.08), width: 0.5),
  //             boxShadow: [
  //               BoxShadow(
  //                 color: Colors.black.withOpacity(0.18),
  //                 blurRadius: 14,
  //                 offset: const Offset(0, 6),
  //               ),
  //             ],
  //           ),
  //           child: Row(
  //             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  //             children: [
  //               _buildDockItem(0, CupertinoIcons.home),
  //               _buildDockItem(1, CupertinoIcons.news),
  //               _buildDockItem(2, CupertinoIcons.compass),
  //               _buildDockItem(3, CupertinoIcons.settings),
  //             ],
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Widget _buildFloatingDock() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final profilePicUrl = user?.masterUser?.profilePic != null
        ? "${AppConfig.apiProfileImg}/${user!.masterUser!.profilePic}"
        : null;

    return Positioned(
      bottom: 12,
      left: 16,
      right: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surfaceContainerHighest.withOpacity(0.9)
                  : const Color(0xFF21254A).withOpacity(0.92),
              borderRadius: BorderRadius.circular(26),
              border:
                  Border.all(color: Colors.white.withOpacity(0.08), width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildDockItem(0, CupertinoIcons.home),
                _buildDockItem(1, CupertinoIcons.news),
                _buildDockItem(2, CupertinoIcons.compass),
                _buildDockItem(3, CupertinoIcons.settings,
                    imageUrl: profilePicUrl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget _buildDockItem(int index, IconData icon) {
  //   final isSelected = _selectedIndex == index;

  //   return Expanded(
  //     // 🔥 equal spacing + bigger tap zone
  //     child: GestureDetector(
  //       onTap: () => _onItemTapped(index),
  //       behavior: HitTestBehavior.opaque, // 🔥 full tap area active
  //       child: AnimatedContainer(
  //         duration: const Duration(milliseconds: 220),
  //         curve: Curves.easeOut,
  //         height: 40, // 🔥 bigger height
  //         margin: const EdgeInsets.symmetric(horizontal: 4),
  //         decoration: BoxDecoration(
  //           color: isSelected
  //               ? Colors.white.withOpacity(0.15)
  //               : Colors.transparent,
  //           borderRadius: BorderRadius.circular(28), // 🔥 rounded rectangle
  //         ),
  //         child: Icon(
  //           icon,
  //           color: isSelected ? Colors.white : Colors.white60,
  //           size: 24,
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Widget _buildDockItem(int index, IconData icon, {String? imageUrl}) {
    final isSelected = _selectedIndex == index;
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Center(
            child: (index == 3 && imageUrl != null)
                ? CircleAvatar(
                    radius: 16,
                    backgroundImage: NetworkImage(imageUrl),
                    backgroundColor: Colors.transparent,
                  )
                : Icon(
                    icon,
                    color: isSelected ? Colors.white : Colors.white60,
                    size: 24,
                  ),
          ),
        ),
      ),
    );
  }
}
