import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:gridcard/core/services/auth_provider.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/widgets/top_alert.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_html/html.dart' as html;

/// Represents a draggable overlay element on the flyer canvas
class _OverlayItem {
  Offset position;
  double size;
  bool visible;
  double initialScale;
  double currentScale;

  _OverlayItem({
    required this.position,
    this.size = 80,
    this.visible = false,
    this.initialScale = 1.0,
    this.currentScale = 1.0,
  });
}

class FlyerEditorPage extends StatefulWidget {
  final String imageUrl;

  const FlyerEditorPage({super.key, required this.imageUrl});

  @override
  State<FlyerEditorPage> createState() => _FlyerEditorPageState();
}

class _FlyerEditorPageState extends State<FlyerEditorPage> {
  final GlobalKey _captureKey = GlobalKey();

  // Overlay items
  late _OverlayItem _profileOverlay;
  late _OverlayItem _onlineQrOverlay;
  late _OverlayItem _offlineQrOverlay;

  bool _isSaving = false;
  bool _imageLoaded = false;

  // Profile border
  double _borderWidth = 3.0;
  Color _borderColor = Colors.white;

  // QR style
  double _qrBorderRadius = 8.0;

  // Which overlay is being edited (for settings panel)
  String? _activeOverlay; // 'profile', 'onlineQr', 'offlineQr'

  @override
  void initState() {
    super.initState();

    _profileOverlay = _OverlayItem(
      position: const Offset(20, 20),
      size: 80,
      visible: true,
    );
    _onlineQrOverlay = _OverlayItem(
      position: const Offset(20, 120),
      size: 100,
      visible: false,
    );
    _offlineQrOverlay = _OverlayItem(
      position: const Offset(140, 120),
      size: 100,
      visible: false,
    );

    // Pre-cache the flyer image
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(NetworkImage(widget.imageUrl), context).then((_) {
        if (mounted) setState(() => _imageLoaded = true);
      });
    });
  }

  String? _getProfilePicUrl() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user?.masterUser?.profilePic != null) {
      return '${AppConfig.apiProfileImg}/${user!.masterUser!.profilePic}';
    }
    return null;
  }

  /// Generate QR data for Online (Connect) QR
  String _generateOnlineQrData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final data = {
      'user_name': user?.userName?.toString() ?? '',
      'type': 'gridcard_connect',
      'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
    };
    return json.encode(data);
  }

  /// Generate QR data for Offline (Contact) QR
  String _generateOfflineQrData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final data = {
      'id': user?.id?.toString() ?? '',
      'user_mobile': user?.userMobile?.toString() ?? '',
      'email': user?.email?.toString() ?? '',
      'fname': user?.masterUser?.fname?.toString() ?? '',
      'type': 'gridcard_contact',
      'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
    };
    return json.encode(data);
  }

  Future<void> _saveFlyer() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

      if (!kIsWeb) {
        final status = await Permission.storage.request();
        if (status.isDenied) {
          TopAlert.show(context, "Storage permission is required to save flyers", isError: true);
          setState(() => _isSaving = false);
          return;
        }
      }

      await Future.delayed(const Duration(milliseconds: 500));

      final boundary = _captureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception("Render boundary not found");

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute(
              "download", "flyer_${DateTime.now().millisecondsSinceEpoch}.png")
          ..click();
        html.Url.revokeObjectUrl(url);
        debugPrint("WEB: Flyer download initiated");
      } else {
        final tempDir = await getTemporaryDirectory();
        final fileName = 'flyer_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File('${tempDir.path}/$fileName');
        
        await file.writeAsBytes(bytes);
        debugPrint("FILE: Saved to temporary path: ${file.path}");
        
        if (await file.exists()) {
          debugPrint("FILE: File exists, now saving to gallery via Gal...");
          await Gal.putImage(file.path);
          debugPrint("GAL: Successfully saved to gallery");
        } else {
          throw Exception("Temporary file was not created correctly");
        }
      }

      if (mounted) {
        TopAlert.show(context, "✅ Flyer saved to gallery!", isSuccess: true);
      }
    } catch (e) {
      debugPrint("Save Error: $e");
      if (mounted) {
        TopAlert.show(context, "Failed to save flyer: $e", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final colorScheme = Theme.of(context).colorScheme;
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text("Overlay Settings",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      )),
                  const SizedBox(height: 20),

                  // Profile size
                  if (_profileOverlay.visible) ...[
                    _buildSectionTitle("Profile Image Size", colorScheme),
                    _buildSizeSlider(
                      value: _profileOverlay.size,
                      min: 40,
                      max: 180,
                      onChanged: (val) {
                        setSheetState(() {});
                        setState(() => _profileOverlay.size = val);
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildSectionTitle("Border Width", colorScheme),
                    _buildSliderRow(
                      icon1: Icons.circle_outlined,
                      icon2: Icons.circle,
                      value: _borderWidth,
                      min: 0,
                      max: 8,
                      onChanged: (val) {
                        setSheetState(() {});
                        setState(() => _borderWidth = val);
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildSectionTitle("Border Color", colorScheme),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _colorCircle(Colors.white, setSheetState),
                        _colorCircle(Colors.black, setSheetState),
                        _colorCircle(Colors.red, setSheetState),
                        _colorCircle(Colors.blue, setSheetState),
                        _colorCircle(Colors.green, setSheetState),
                        _colorCircle(Colors.amber, setSheetState),
                        _colorCircle(Colors.purple, setSheetState),
                      ],
                    ),
                    const Divider(height: 24),
                  ],

                  // QR size
                  if (_onlineQrOverlay.visible ||
                      _offlineQrOverlay.visible) ...[
                    if (_onlineQrOverlay.visible) ...[
                      _buildSectionTitle("Online QR Size", colorScheme),
                      _buildSizeSlider(
                        value: _onlineQrOverlay.size,
                        min: 50,
                        max: 200,
                        onChanged: (val) {
                          setSheetState(() {});
                          setState(() => _onlineQrOverlay.size = val);
                        },
                      ),
                    ],
                    if (_offlineQrOverlay.visible) ...[
                      _buildSectionTitle("Offline QR Size", colorScheme),
                      _buildSizeSlider(
                        value: _offlineQrOverlay.size,
                        min: 50,
                        max: 200,
                        onChanged: (val) {
                          setSheetState(() {});
                          setState(() => _offlineQrOverlay.size = val);
                        },
                      ),
                    ],
                    _buildSectionTitle("QR Corner Radius", colorScheme),
                    _buildSliderRow(
                      icon1: Icons.square_outlined,
                      icon2: Icons.rounded_corner,
                      value: _qrBorderRadius,
                      min: 0,
                      max: 24,
                      onChanged: (val) {
                        setSheetState(() {});
                        setState(() => _qrBorderRadius = val);
                      },
                    ),
                  ],

                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, ColorScheme colorScheme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            )),
      ),
    );
  }

  Widget _buildSizeSlider({
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        const Icon(Icons.photo_size_select_small, size: 18),
        Expanded(child: Slider(value: value, min: min, max: max, onChanged: onChanged)),
        const Icon(Icons.photo_size_select_large, size: 24),
      ],
    );
  }

  Widget _buildSliderRow({
    required IconData icon1,
    required IconData icon2,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon1, size: 16),
        Expanded(child: Slider(value: value, min: min, max: max, onChanged: onChanged)),
        Icon(icon2, size: 20),
      ],
    );
  }

  Widget _colorCircle(Color color, StateSetter setSheetState) {
    final isSelected = _borderColor == color;
    return GestureDetector(
      onTap: () {
        setSheetState(() {});
        setState(() => _borderColor = color);
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.grey.shade400,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 6,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
      ),
    );
  }

  /// Builds a draggable overlay positioned widget
  Widget _buildDraggableOverlay({
    required _OverlayItem item,
    required Widget child,
    required BoxConstraints constraints,
  }) {
    return Positioned(
      left: item.position.dx,
      top: item.position.dy,
      child: GestureDetector(
        onScaleStart: (details) {
          item.initialScale = item.currentScale;
        },
        onScaleUpdate: (details) {
          setState(() {
            // Pinch-to-zoom
            if (details.pointerCount == 2) {
              item.currentScale =
                  (item.initialScale * details.scale).clamp(0.5, 3.0);
              item.size = (80 * item.currentScale).clamp(40.0, 200.0);
            }
            // Drag
            item.position = Offset(
              (item.position.dx + details.focalPointDelta.dx)
                  .clamp(-item.size / 2, constraints.maxWidth - item.size / 2),
              (item.position.dy + details.focalPointDelta.dy)
                  .clamp(-item.size / 2, constraints.maxHeight - item.size / 2),
            );
          });
        },
        child: child,
      ),
    );
  }

  /// Builds the circular profile overlay widget
  Widget _buildProfileWidget(String profilePicUrl) {
    return Container(
      width: _profileOverlay.size,
      height: _profileOverlay.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _borderColor, width: _borderWidth),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.network(
          profilePicUrl,
          fit: BoxFit.cover,
          width: _profileOverlay.size,
          height: _profileOverlay.size,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.grey[300],
            child: Icon(Icons.person,
                size: _profileOverlay.size * 0.5, color: Colors.grey[600]),
          ),
        ),
      ),
    );
  }

  /// Builds a QR code overlay widget
  Widget _buildQrWidget(String qrData, double size, String label) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_qrBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_qrBorderRadius),
        child: Padding(
          padding: EdgeInsets.all(size * 0.06),
          child: Column(
            children: [
              Expanded(
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: size * 0.08,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bottom toolbar toggle button
  Widget _buildToolbarButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.blueAccent.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive ? Colors.blueAccent : Colors.white24,
                width: 1.5,
              ),
            ),
            child: Icon(icon,
                color: isActive ? Colors.blueAccent : Colors.white60, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                color: isActive ? Colors.blueAccent : Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profilePicUrl = _getProfilePicUrl();
    final colorScheme = Theme.of(context).colorScheme;
    final hasAnyOverlay = _profileOverlay.visible ||
        _onlineQrOverlay.visible ||
        _offlineQrOverlay.visible;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text("Edit Flyer"),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (hasAnyOverlay)
            IconButton(
              icon: const Icon(Icons.tune, color: Colors.white),
              tooltip: "Adjust Settings",
              onPressed: _showSettingsSheet,
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Canvas area ──
          Expanded(
            child: Center(
              child: !_imageLoaded
                  ? const CircularProgressIndicator(color: Colors.white)
                  : RepaintBoundary(
                      key: _captureKey,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Stack(
                              children: [
                                // Flyer background
                                Image.network(
                                  widget.imageUrl,
                                  fit: BoxFit.contain,
                                  width: constraints.maxWidth,
                                  height: constraints.maxHeight,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.grey[900],
                                    child: const Center(
                                      child: Icon(Icons.broken_image,
                                          color: Colors.white54, size: 60),
                                    ),
                                  ),
                                ),

                                // Profile image overlay
                                if (_profileOverlay.visible &&
                                    profilePicUrl != null)
                                  _buildDraggableOverlay(
                                    item: _profileOverlay,
                                    constraints: constraints,
                                    child: _buildProfileWidget(profilePicUrl),
                                  ),

                                // Online QR overlay
                                if (_onlineQrOverlay.visible)
                                  _buildDraggableOverlay(
                                    item: _onlineQrOverlay,
                                    constraints: constraints,
                                    child: _buildQrWidget(
                                      _generateOnlineQrData(),
                                      _onlineQrOverlay.size,
                                      "Scan to Connect",
                                    ),
                                  ),

                                // Offline QR overlay
                                if (_offlineQrOverlay.visible)
                                  _buildDraggableOverlay(
                                    item: _offlineQrOverlay,
                                    constraints: constraints,
                                    child: _buildQrWidget(
                                      _generateOfflineQrData(),
                                      _offlineQrOverlay.size,
                                      "Save Contact",
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
            ),
          ),

          // ── Hint text ──
          if (hasAnyOverlay)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: Text(
                "Drag to move • Pinch to resize • Tap icons below to toggle",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
            ),

          // ── Overlay toggles toolbar ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.black,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildToolbarButton(
                  icon: Icons.account_circle,
                  label: "Profile",
                  isActive: _profileOverlay.visible,
                  onTap: () {
                    if (profilePicUrl == null) {
                      TopAlert.show(
                          context, "No profile picture found, please upload one",
                          isError: true);
                      return;
                    }
                    setState(
                        () => _profileOverlay.visible = !_profileOverlay.visible);
                  },
                ),
                _buildToolbarButton(
                  icon: Icons.qr_code,
                  label: "Online QR",
                  isActive: _onlineQrOverlay.visible,
                  onTap: () {
                    setState(() =>
                        _onlineQrOverlay.visible = !_onlineQrOverlay.visible);
                  },
                ),
                _buildToolbarButton(
                  icon: Icons.qr_code_2,
                  label: "Offline QR",
                  isActive: _offlineQrOverlay.visible,
                  onTap: () {
                    setState(() =>
                        _offlineQrOverlay.visible = !_offlineQrOverlay.visible);
                  },
                ),
                _buildToolbarButton(
                  icon: Icons.tune,
                  label: "Settings",
                  isActive: false,
                  onTap: hasAnyOverlay
                      ? _showSettingsSheet
                      : () => TopAlert.show(
                          context, "Add an overlay first to adjust settings"),
                ),
              ],
            ),
          ),

          // ── Save button ──
          Container(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            color: Colors.black,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveFlyer,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_alt, size: 18),
                label: Text(_isSaving ? "Saving..." : "Save Flyer"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
