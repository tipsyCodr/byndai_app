import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ Added for SystemNavigator
import 'package:gridcard/features/discover/discover_page.dart';
import 'package:gridcard/features/leads/leads_page.dart';
import 'package:gridcard/features/profile/profile_page.dart';
import 'package:gridcard/features/settings/settings_page.dart';
import 'package:gridcard/features/home/feed_page.dart';
import 'package:gridcard/core/services/auth_provider.dart'; // ✅ Your AuthProvider
import 'package:gridcard/features/ai_chatbot/ai_chatbot_page.dart';
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
import 'package:gridcard/features/home/widgets/fluid_bottom_nav_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime? _lastBackPressed;

  final GlobalKey<FeedPageState> _feedKey = GlobalKey<FeedPageState>();
  late final PageController _pageController;
  NfcService? _nfcService;

  List<Widget> get _screens => [
    FeedPage(key: _feedKey),
    const LeadsPage(),
    const DiscoverPage(),
    const SettingsPage(),
    const AiChatbotPage(),
  ];

  @override
  void initState() {
    super.initState();
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
    'AI Assistant',
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
                    ? FaIcon(FontAwesomeIcons.user,
                        color: colorScheme.primary, size: 18)
                    : AppNetworkImage(
                        imageUrl: logoUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        cacheKey: authProvider.profileUpdateCounter
                            .toString(), // 👈 Refresh on update
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
              icon: FaIcon(
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
              icon: FaIcon(
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
      left: 14,
      right: 14,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Main Pill Navigation (4 items with fluid indicator) ─────
          Expanded(
            child: GlassBox(
              padding: EdgeInsets.zero,
              borderRadius: 32,
              blur: 16,
              opacity: isDark ? 0.22 : 0.12,
              gradientColors: [
                (palette?.glassTop ?? colorScheme.surface)
                    .withValues(alpha: isDark ? 0.82 : 0.92),
                (palette?.glassBottom ?? colorScheme.surface)
                    .withValues(alpha: isDark ? 0.68 : 0.82),
              ],
              child: SizedBox(
                height: 52,
                child: FluidBottomNavBar(
                  pageController: _pageController,
                  selectedIndex: _selectedIndex,
                  onItemSelected: _onItemTapped,
                  items: [
                    const FluidNavBarItem(
                      icon: FontAwesomeIcons.house,
                      label: 'Home',
                    ),
                    const FluidNavBarItem(
                      icon: FontAwesomeIcons.addressCard,
                      label: 'Leads',
                    ),
                    const FluidNavBarItem(
                      icon: FontAwesomeIcons.compass,
                      label: 'Discover',
                    ),
                    FluidNavBarItem(
                      icon: FontAwesomeIcons.gear,
                      label: 'Settings',
                      imageUrl: profilePicUrl,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // ── Standalone Circular AI Action Button ─────────────────────
          _buildStandaloneAiButton(4, isDark, colorScheme, palette),
        ],
      ),
    );
  }

  Widget _buildStandaloneAiButton(
    int index,
    bool isDark,
    ColorScheme colorScheme,
    AppThemeColors? palette,
  ) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isSelected
              ? const LinearGradient(
                  colors: [
                    Color(0xFF8B5CF6),
                    Color(0xFFA855F7),
                    Color(0xFF6366F1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected
              ? null
              : (isDark ? const Color(0xFF181A20) : const Color(0xFF18191E)),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.9)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.25)),
            width: isSelected ? 2.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFFA855F7).withValues(alpha: 0.65)
                  : Colors.black.withValues(alpha: isDark ? 0.45 : 0.25),
              blurRadius: isSelected ? 20 : 10,
              spreadRadius: isSelected ? 2 : 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: _buildWaveSparkleIcon(),
        ),
      ),
    );
  }

  /// Custom waveform + sparkles icon matching modern AI UI
  Widget _buildWaveSparkleIcon() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Wave bar 1
        Container(
          width: 2.8,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 2.8),
        // Wave bar 2 (tall center)
        Container(
          width: 2.8,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 2.8),
        // Wave bar 3
        Container(
          width: 2.8,
          height: 14,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 3.5),
        // Mini sparkle
        const FaIcon(
          FontAwesomeIcons.wandMagicSparkles,
          size: 11,
          color: Colors.white,
        ),
      ],
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
