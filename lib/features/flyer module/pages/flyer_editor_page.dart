import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gridcard/core/services/auth_provider.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/widgets/top_alert.dart';
import 'package:universal_html/html.dart' as html;

class _OverlayItem {
  Offset position;
  double size;
  bool visible;
  double initialScale;

  _OverlayItem({
    required this.position,
    this.size = 80,
    this.visible = false,
    this.initialScale = 1.0,
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

  late _OverlayItem _profileOverlay;
  late _OverlayItem _onlineQrOverlay;
  late _OverlayItem _offlineQrOverlay;

  bool _isSaving = false;
  bool _imageLoaded = false;

  double _borderWidth = 3.0;
  Color _borderColor = Colors.white;
  double _qrBorderRadius = 8.0;

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

  String _generateOnlineQrData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final baseUrl = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/api$'), '');
    final profileId = user?.userName ?? user?.id?.toString() ?? 'me';
    return "$baseUrl/u/$profileId";
  }

  String _generateOfflineQrData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final masterJson = user?.masterUser?.toJson();
    final fname = user?.masterUser?.fname ?? 'User';
    final mobile = user?.userMobile ?? '';
    final email = user?.email ?? '';
    final org = masterJson?['legal_name'] ?? '';
    final title = masterJson?['desg'] ?? '';
    final website = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/api$'), '');

    return 'BEGIN:VCARD\n'
           'VERSION:3.0\n'
           'FN:$fname\n'
           'TEL;TYPE=CELL:$mobile\n'
           'EMAIL:$email\n'
           'ORG:$org\n'
           'TITLE:$title\n'
           'URL:$website\n'
           'END:VCARD';
  }

  Future<void> _saveFlyer() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      if (!kIsWeb) {
        final status = await Permission.storage.request();
        if (status.isDenied) {
          if (mounted) TopAlert.show(context, "Storage permission required", isError: true);
          setState(() => _isSaving = false);
          return;
        }
      }

      await Future.delayed(const Duration(milliseconds: 500));

      final boundary = _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception("Render boundary not found");

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute("download", "flyer_${DateTime.now().millisecondsSinceEpoch}.png")
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/flyer_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(bytes);
        await Gal.putImage(file.path);
      }

      if (mounted) TopAlert.show(context, "✅ Flyer saved to gallery!", isSuccess: true);
    } catch (e) {
      debugPrint("Save Error: $e");
      if (mounted) TopAlert.show(context, "Failed to save flyer: $e", isError: true);
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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: colorScheme.onSurface.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  Text("Overlay Settings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
                  const SizedBox(height: 20),
                  if (_profileOverlay.visible) ...[
                    _buildSectionTitle("Profile Size", colorScheme),
                    _buildSizeSlider(_profileOverlay.size, 40, 180, (val) { setSheetState((){}); setState(() => _profileOverlay.size = val); }),
                    _buildSectionTitle("Border Width", colorScheme),
                    _buildSliderRow(Icons.circle_outlined, Icons.circle, _borderWidth, 0, 8, (val) { setSheetState((){}); setState(() => _borderWidth = val); }),
                    _buildSectionTitle("Border Color", colorScheme),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                      _colorCircle(Colors.white, setSheetState),
                      _colorCircle(Colors.black, setSheetState),
                      _colorCircle(Colors.red, setSheetState),
                      _colorCircle(Colors.blue, setSheetState),
                      _colorCircle(Colors.green, setSheetState),
                      _colorCircle(Colors.amber, setSheetState),
                      _colorCircle(Colors.purple, setSheetState),
                    ]),
                    const Divider(height: 24),
                  ],
                  if (_onlineQrOverlay.visible || _offlineQrOverlay.visible) ...[
                    if (_onlineQrOverlay.visible) ...[
                      _buildSectionTitle("Online QR Size", colorScheme),
                      _buildSizeSlider(_onlineQrOverlay.size, 50, 200, (val) { setSheetState((){}); setState(() => _onlineQrOverlay.size = val); }),
                    ],
                    if (_offlineQrOverlay.visible) ...[
                      _buildSectionTitle("Offline QR Size", colorScheme),
                      _buildSizeSlider(_offlineQrOverlay.size, 50, 200, (val) { setSheetState((){}); setState(() => _offlineQrOverlay.size = val); }),
                    ],
                    _buildSectionTitle("QR Corner Radius", colorScheme),
                    _buildSliderRow(Icons.square_outlined, Icons.rounded_corner, _qrBorderRadius, 0, 24, (val) { setSheetState((){}); setState(() => _qrBorderRadius = val); }),
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
    return Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onSurface))));
  }

  Widget _buildSizeSlider(double val, double min, double max, ValueChanged<double> onChanged) {
    return Row(children: [const Icon(Icons.photo_size_select_small, size: 18), Expanded(child: Slider(value: val, min: min, max: max, onChanged: onChanged)), const Icon(Icons.photo_size_select_large, size: 24)]);
  }

  Widget _buildSliderRow(IconData i1, IconData i2, double val, double min, double max, ValueChanged<double> onChanged) {
    return Row(children: [Icon(i1, size: 16), Expanded(child: Slider(value: val, min: min, max: max, onChanged: onChanged)), Icon(i2, size: 20)]);
  }

  Widget _colorCircle(Color color, StateSetter setSheetState) {
    final isSelected = _borderColor == color;
    return GestureDetector(
      onTap: () { setSheetState((){}); setState(() => _borderColor = color); },
      child: Container(width: 32, height: 32, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: isSelected ? Colors.blueAccent : Colors.grey.shade400, width: isSelected ? 3 : 1))),
    );
  }

  Widget _buildDraggableOverlay({required _OverlayItem item, required Widget child, required BoxConstraints constraints}) {
    return Positioned(
      left: item.position.dx,
      top: item.position.dy,
      child: GestureDetector(
        onScaleStart: (details) {
          item.initialScale = item.size / 80.0;
        },
        onScaleUpdate: (details) {
          setState(() {
            if (details.pointerCount == 2) {
              item.size = (80.0 * item.initialScale * details.scale).clamp(40.0, 200.0);
            }
            item.position = Offset(
              (item.position.dx + details.focalPointDelta.dx).clamp(-item.size / 2, constraints.maxWidth - item.size / 2),
              (item.position.dy + details.focalPointDelta.dy).clamp(-item.size / 2, constraints.maxHeight - item.size / 2),
            );
          });
        },
        child: child,
      ),
    );
  }

  Widget _buildProfileWidget(String url) {
    return Container(
      width: _profileOverlay.size, height: _profileOverlay.size,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _borderColor, width: _borderWidth), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 2)]),
      child: ClipOval(child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey[300], child: Icon(Icons.person, size: _profileOverlay.size * 0.5, color: Colors.grey[600])))),
    );
  }

  Widget _buildQrWidget(String data, double size, String label) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(_qrBorderRadius), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 1)]),
      child: Padding(
        padding: EdgeInsets.all(size * 0.08),
        child: Column(children: [
          Expanded(child: QrImageView(data: data, version: QrVersions.auto)),
          Text(label, style: TextStyle(fontSize: size * 0.08, fontWeight: FontWeight.bold, color: Colors.black)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileUrl = _getProfilePicUrl();
    final colorScheme = Theme.of(context).colorScheme;
    final hasOverlay = _profileOverlay.visible || _onlineQrOverlay.visible || _offlineQrOverlay.visible;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black, foregroundColor: Colors.white, title: const Text("Edit Flyer"), centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        actions: [if (hasOverlay) IconButton(icon: const Icon(Icons.tune), onPressed: _showSettingsSheet)],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: !_imageLoaded ? const CircularProgressIndicator() : RepaintBoundary(
                key: _captureKey,
                child: LayoutBuilder(builder: (context, constraints) {
                  return Stack(children: [
                    Image.network(widget.imageUrl, fit: BoxFit.contain, width: constraints.maxWidth, height: constraints.maxHeight),
                    if (_profileOverlay.visible && profileUrl != null) _buildDraggableOverlay(item: _profileOverlay, constraints: constraints, child: _buildProfileWidget(profileUrl)),
                    if (_onlineQrOverlay.visible) _buildDraggableOverlay(item: _onlineQrOverlay, constraints: constraints, child: _buildQrWidget(_generateOnlineQrData(), _onlineQrOverlay.size, "Connect")),
                    if (_offlineQrOverlay.visible) _buildDraggableOverlay(item: _offlineQrOverlay, constraints: constraints, child: _buildQrWidget(_generateOfflineQrData(), _offlineQrOverlay.size, "Contact")),
                  ]);
                }),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.black,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _buildToolbarButton(Icons.account_circle, "Profile", _profileOverlay.visible, () => setState(() => _profileOverlay.visible = !_profileOverlay.visible)),
              _buildToolbarButton(Icons.qr_code, "Online QR", _onlineQrOverlay.visible, () => setState(() => _onlineQrOverlay.visible = !_onlineQrOverlay.visible)),
              _buildToolbarButton(Icons.qr_code_2, "Offline QR", _offlineQrOverlay.visible, () => setState(() => _offlineQrOverlay.visible = !_offlineQrOverlay.visible)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _isSaving ? null : _saveFlyer, icon: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_alt), label: Text(_isSaving ? "Saving..." : "Save Flyer"), style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)))),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarButton(IconData icon, String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: active ? Colors.blueAccent.withValues(alpha: 0.2) : Colors.white10, borderRadius: BorderRadius.circular(12), border: Border.all(color: active ? Colors.blueAccent : Colors.white24)), child: Icon(icon, color: active ? Colors.blueAccent : Colors.white60)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: active ? Colors.blueAccent : Colors.white54, fontSize: 10)),
      ]),
    );
  }
}
