import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ Added for SystemNavigator
import 'package:gridcard/features/discover/discover_page.dart';
import 'package:gridcard/features/leads/leads_page.dart';
import 'package:gridcard/features/profile/profile_page.dart';
import 'package:gridcard/features/settings/settings_page.dart';
import 'package:gridcard/features/home/feed_page.dart';
import 'package:gridcard/core/services/auth_provider.dart'; // ✅ Your AuthProvider
import 'package:gridcard/features/chat/connections_page.dart';
import 'package:gridcard/core/services/social_provider.dart';
import 'package:provider/provider.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:gridcard/routes/route_names.dart';
import 'package:gridcard/widgets/top_alert.dart';
import 'package:gridcard/widgets/glass_box.dart';
import 'package:gridcard/core/theme/app_theme.dart';
import '../qr_scan/profile_qr_code.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/nfc_service.dart';
import 'package:gridcard/widgets/app_network_image.dart';
import 'package:gridcard/models/user_model.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime? _lastBackPressed;

  final GlobalKey<FeedPageState> _feedKey = GlobalKey<FeedPageState>();
  late final List<Widget> _screens;
  late final PageController _pageController;
  NfcService? _nfcService;

  @override
  void initState() {
    super.initState();
    _screens = [
      FeedPage(key: _feedKey),
      const LeadsPage(),
      const DiscoverPage(),
      const SettingsPage(),
    ];
    _pageController = PageController(initialPage: _selectedIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nfcService = Provider.of<NfcService>(context, listen: false);
      _initializeNfc();
      final auth = Provider.of<AuthProvider>(context, listen: false);

      debugPrint("📦 Subscription in HomePage: ${auth.subscriptionDetails}");
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nfcService?.stopListening();
    super.dispose();
  }

  Future<void> _initializeNfc() async {
    await _nfcService?.initialize(context: context);
  }

  Future<void> _onPop(bool didPop, Object? result) async {
    if (didPop) return;

    if (_selectedIndex != 0) {
      _onItemTapped(0);
      _lastBackPressed = null;
      return;
    }

    final now = DateTime.now();
    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      TopAlert.show(context, 'Press back again to exit');
      return;
    }

    SystemNavigator.pop();
  }

  int _selectedIndex = 0;

  // List<Widget> _screens() {
  //   return [
  //     FeedPage(key: _feedKey),
  //     const LeadsPage(),
  //     const DiscoverPage(),
  //     const SettingsPage(),
  //   ];
  // }

  final List<String> _titles = [
    'Home',
    'My Leads',
    'Discover',
    'Settings',
  ];

  void _onItemTapped(int index) {
    if (_selectedIndex == index) {
      if (index == 0) {
        // If already on Home, just scroll to top
        _feedKey.currentState?.onBackToTop();
      }
    } else {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      if (index == 0) {
        final socialProvider =
            Provider.of<SocialProvider>(context, listen: false);
        if (socialProvider.shouldRefresh) {
          _feedKey.currentState?.refreshFeed();
        }
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (!auth.isAuthenticated) {
      Future.microtask(() {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            RouteNames.phone,
            (route) => false,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = theme.extension<AppThemeColors>();
    final isDark = theme.brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    final logoUrl = _resolveProfileImageUrl(user);

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: _onPop,
      child: Scaffold(
        backgroundColor: palette?.backgroundStart ?? colorScheme.surface,
        extendBody: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: colorScheme.onSurface,
          title: Text(
            _titles[_selectedIndex],
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
              letterSpacing: 0.7,
            ),
          ),
          centerTitle: true,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: CircleAvatar(
              radius: 28,
              backgroundColor: (palette?.glassTop ?? colorScheme.surface)
                  .withValues(alpha: 0.95),
              child: ClipOval(
                child: logoUrl == null
                    ? Icon(FontAwesomeIcons.user,
                        color: colorScheme.primary, size: 18)
                    : AppNetworkImage(
                        imageUrl: logoUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        cacheKey: authProvider.profileUpdateCounter.toString(), // 👈 Refresh on update
                      ),
              ),
            ),
            onPressed: () async {
              final userId = await UserStorageService().getUserId();
              if (!mounted) return;
              if (userId == null) {
                TopAlert.show(context, 'User ID not found', isError: true);
                return;
              }

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ProfilePage(
                    userId: userId,
                    viewerUserId: userId,
                  ),
                ),
              );
            },
          ),
          actions: [
            IconButton(
              style: IconButton.styleFrom(
                backgroundColor: palette?.glassTop.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(
                FontAwesomeIcons.qrcode,
                color: isDark ? colorScheme.primary : colorScheme.primary,
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ProfileQRCodePage(),
                  ),
                );
              },
            ),
            IconButton(
              icon: Icon(
                FontAwesomeIcons.commentDots,
                color: isDark ? colorScheme.primary : colorScheme.primary,
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ConnectionsPage(),
                  ),
                );
              },
            ),
          ],
        ),
        body: Container(
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
              if (isDark) _buildDarkModePattern(context),
              if (!isDark) _buildLightModePattern(context),
              // _screens()[_selectedIndex],
              Padding(
                padding: EdgeInsets.only(
                  bottom: 72 + MediaQuery.of(context).padding.bottom,
                ),
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  physics: const ClampingScrollPhysics(),
                  children: _screens,
                ),
              ),
              _buildFloatingDock(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLightModePattern(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -150,
            right: -120,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.16),
                    colorScheme.primary.withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: -180,
            child: Container(
              width: 520,
              height: 320,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(240),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.secondary.withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            right: -120,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colorScheme.secondary.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDarkModePattern(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -110,
            right: -140,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colorScheme.secondary.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 140,
            left: -150,
            child: Container(
              width: 420,
              height: 280,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(220),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -180,
            left: 20,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.09),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingDock() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final palette = theme.extension<AppThemeColors>();
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final profilePicUrl = _resolveProfileImageUrl(user);

    return Positioned(
      bottom: 12 + MediaQuery.of(context).padding.bottom,
      left: 16,
      right: 16,
      child: GlassBox(
        padding: EdgeInsets.zero,
        borderRadius: 28,
        blur: 15,
        opacity: isDark ? 0.2 : 0.12,
        gradientColors: [
          (palette?.glassTop ?? colorScheme.surface)
              .withValues(alpha: isDark ? 0.7 : 0.8),
          (palette?.glassBottom ?? colorScheme.surface)
              .withValues(alpha: isDark ? 0.58 : 0.7),
        ],
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildDockItem(0, FontAwesomeIcons.house),
              _buildDockItem(1, FontAwesomeIcons.addressCard),
              _buildDockItem(2, FontAwesomeIcons.compass),
              _buildDockItem(3, FontAwesomeIcons.gear, imageUrl: profilePicUrl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDockItem(int index, IconData icon, {String? imageUrl}) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppThemeColors>();
    final isSelected = _selectedIndex == index;

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
                ? (palette?.dockActive ?? theme.colorScheme.primary).withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.2 : 0.14,
                  )
                : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
            border: isSelected
                ? (theme.brightness == Brightness.dark
                    ? Border.all(color: Colors.transparent, width: 0)
                    : Border.all(
                        color:
                            (palette?.neonAccent ?? theme.colorScheme.secondary)
                                .withValues(alpha: 0.45),
                        width: 0.8,
                      ))
                : null,
          ),
          child: Center(
            child: (index == 3 && imageUrl != null)
                ? CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.transparent,
                    child: ClipOval(
                      child: AppNetworkImage(
                        imageUrl: imageUrl,
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                        cacheKey: context
                            .read<AuthProvider>()
                            .profileUpdateCounter
                            .toString(),
                      ),
                    ),
                  )
                : Icon(
                    icon,
                    color: isSelected
                        ? (theme.brightness == Brightness.dark
                            ? Colors.white
                            : theme.colorScheme.primary)
                        : (palette?.dockInactive ??
                            theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                    size: 24,
                  ),
          ),
        ),
      ),
    );
  }

  String? _resolveProfileImageUrl(UserModel? user) {
    // 1. Try masterUser.profilePic
    final raw = user?.masterUser?.profilePic?.toString();
    if (raw != null && raw.trim().isNotEmpty) {
      return AppConfig.getFullUrl(raw);
    }

    // 2. Try user.profilePic (for new accounts/different API structures)
    final rootPic = user?.profilePic?.toString();
    if (rootPic != null && rootPic.trim().isNotEmpty) {
      return AppConfig.getFullUrl(rootPic);
    }

    // 3. Try user.profileLogo (as a fallback)
    final logo = user?.profileLogo?.toString();
    if (logo != null && logo.trim().isNotEmpty) {
      return AppConfig.getFullUrl(logo);
    }

    return null;
  }
}
