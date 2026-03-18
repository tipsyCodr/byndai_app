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
import 'package:gridcard/core/services/profile_provider.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/widgets/top_alert.dart';
import 'package:universal_html/html.dart' as html;

class _OverlayItem {
  Offset position;
  double size; 
  bool visible;

  _OverlayItem({
    required this.position,
    this.size = 80,
    this.visible = false,
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
  late _OverlayItem _infoBarOverlay;

  bool _isSaving = false;
  bool _imageLoaded = false;

  double _borderWidth = 3.0;
  Color _borderColor = Colors.white;
  double _qrBorderRadius = 8.0;

  Color _barBgColor = Colors.white;
  Color _barTextColor = Colors.black;
  double _barOpacity = 0.9;
  double _barFontSize = 12.0;

  @override
  void initState() {
    super.initState();

    _profileOverlay = _OverlayItem(position: const Offset(20, 20), size: 100, visible: true);
    _onlineQrOverlay = _OverlayItem(position: const Offset(20, 140), size: 100, visible: false);
    _offlineQrOverlay = _OverlayItem(position: const Offset(140, 140), size: 100, visible: false);
    _infoBarOverlay = _OverlayItem(position: const Offset(20, 300), size: 300, visible: false);

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

    return 'BEGIN:VCARD\nVERSION:3.0\nFN:$fname\nTEL;TYPE=CELL:$mobile\nEMAIL:$email\nORG:$org\nTITLE:$title\nURL:$website\nEND:VCARD';
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
        html.AnchorElement(href: url)..setAttribute("download", "flyer_${DateTime.now().millisecondsSinceEpoch}.png")..click();
        html.Url.revokeObjectUrl(url);
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/flyer_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(bytes);
        await Gal.putImage(file.path);
      }
      if (mounted) TopAlert.show(context, "✅ Flyer saved to gallery!", isSuccess: true);
    } catch (e) {
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
              decoration: BoxDecoration(color: colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: colorScheme.onSurface.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 16),
                    Text("Overlay Settings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
                    const SizedBox(height: 20),
                    if (_infoBarOverlay.visible) ...[
                      _buildSectionHeader("Info Bar Styles", colorScheme),
                      _buildSectionTitle("Bar Width", colorScheme),
                      _buildSizeSlider(_infoBarOverlay.size, 150, 450, (val) { setSheetState((){}); setState(() => _infoBarOverlay.size = val); }),
                      _buildSectionTitle("Font Size", colorScheme),
                      _buildSizeSlider(_barFontSize, 8, 24, (val) { setSheetState((){}); setState(() => _barFontSize = val); }),
                      _buildSectionTitle("Background Color", colorScheme),
                      _buildColorPicker(_barBgColor, (c) { setSheetState((){}); setState(() => _barBgColor = c); }),
                      _buildSectionTitle("Text Color", colorScheme),
                      _buildColorPicker(_barTextColor, (c) { setSheetState((){}); setState(() => _barTextColor = c); }),
                      const Divider(height: 32),
                    ],
                    if (_profileOverlay.visible) ...[
                      _buildSectionHeader("Profile Settings", colorScheme),
                      _buildSectionTitle("Size", colorScheme),
                      _buildSizeSlider(_profileOverlay.size, 40, 200, (val) { setSheetState((){}); setState(() => _profileOverlay.size = val); }),
                      _buildSectionTitle("Border Color", colorScheme),
                      _buildColorPicker(_borderColor, (c) { setSheetState((){}); setState(() => _borderColor = c); }),
                      const Divider(height: 32),
                    ],
                    if (_onlineQrOverlay.visible || _offlineQrOverlay.visible) ...[
                      _buildSectionHeader("QR Settings", colorScheme),
                      if (_onlineQrOverlay.visible) ...[
                        _buildSectionTitle("Online QR Size", colorScheme),
                        _buildSizeSlider(_onlineQrOverlay.size, 50, 200, (val) { setSheetState((){}); setState(() => _onlineQrOverlay.size = val); }),
                      ],
                      if (_offlineQrOverlay.visible) ...[
                        _buildSectionTitle("Offline QR Size", colorScheme),
                        _buildSizeSlider(_offlineQrOverlay.size, 50, 200, (val) { setSheetState((){}); setState(() => _offlineQrOverlay.size = val); }),
                      ],
                    ],
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, ColorScheme colorScheme) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.primary)));
  }

  Widget _buildSectionTitle(String title, ColorScheme colorScheme) {
    return Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(top: 8), child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurface.withValues(alpha: 0.7)))));
  }

  Widget _buildSizeSlider(double val, double min, double max, ValueChanged<double> onChanged) {
    return Slider(value: val, min: min, max: max, onChanged: onChanged);
  }

  Widget _buildColorPicker(Color current, ValueChanged<Color> onSelected) {
    final colors = [Colors.white, Colors.black, Colors.blue, Colors.red, Colors.green, Colors.amber, Colors.purple, Colors.teal, Colors.grey];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: colors.map((c) => GestureDetector(
          onTap: () => onSelected(c),
          child: Container(width: 28, height: 28, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: current == c ? Colors.blueAccent : Colors.grey.shade400, width: current == c ? 3 : 1))),
        )).toList(),
      ),
    );
  }

  Widget _buildDraggableOverlay({required _OverlayItem item, required Widget child, required BoxConstraints constraints}) {
    return Positioned(
      left: item.position.dx,
      top: item.position.dy,
      child: GestureDetector(
        onScaleUpdate: (details) {
          setState(() {
            if (details.pointerCount == 2) {
              item.size = (item.size * details.scale).clamp(40.0, 450.0);
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

  Widget _buildInfoBar(AuthProvider auth, ProfileProvider profile) {
    final user = auth.user;
    final business = profile.businessInfo;
    final name = user?.masterUser?.fname ?? 'Your Name';
    final role = user?.masterUser?.toJson()['desg'] ?? 'Designation';
    
    // Use legal_name for Business Name
    final company = business?['legal_name'] ?? 
                    user?.masterUser?.toJson()['legal_name'] ?? 
                    'Business Name';
                    
    final contact = user?.userMobile ?? 'Mobile Number';
    
    // Use website_url for Business Website
    final website = business?['website_url'] ?? 
                    'Your Website';

    return Container(
      width: _infoBarOverlay.size,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _barBgColor.withValues(alpha: _barOpacity),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name, style: TextStyle(color: _barTextColor, fontSize: _barFontSize + 4, fontWeight: FontWeight.bold)),
          if (role.toString().isNotEmpty) Text(role.toString(), style: TextStyle(color: _barTextColor.withValues(alpha: 0.8), fontSize: _barFontSize, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Divider(color: _barTextColor.withValues(alpha: 0.2), height: 8),
          const SizedBox(height: 4),
          _buildInfoRow(Icons.business, company.toString()),
          _buildInfoRow(Icons.phone, contact),
          _buildInfoRow(Icons.language, website.toString()),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: _barFontSize, color: _barTextColor.withValues(alpha: 0.6)),
          const SizedBox(width: 6),
          Expanded(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: _barTextColor, fontSize: _barFontSize))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final profile = Provider.of<ProfileProvider>(context);
    final profileUrl = _getProfilePicUrl();
    final hasOverlay = _profileOverlay.visible || _onlineQrOverlay.visible || _offlineQrOverlay.visible || _infoBarOverlay.visible;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: const Text("Edit Flyer"), centerTitle: true, leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)), actions: [if (hasOverlay) IconButton(icon: const Icon(Icons.tune), onPressed: _showSettingsSheet)]),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: !_imageLoaded ? const CircularProgressIndicator() : RepaintBoundary(
                key: _captureKey,
                child: LayoutBuilder(builder: (context, constraints) {
                  return Stack(children: [
                    Image.network(widget.imageUrl, fit: BoxFit.contain, width: constraints.maxWidth, height: constraints.maxHeight),
                    if (_infoBarOverlay.visible) _buildDraggableOverlay(item: _infoBarOverlay, constraints: constraints, child: _buildInfoBar(auth, profile)),
                    if (_profileOverlay.visible && profileUrl != null) _buildDraggableOverlay(item: _profileOverlay, constraints: constraints, child: Container(width: _profileOverlay.size, height: _profileOverlay.size, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _borderColor, width: _borderWidth), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)]), child: ClipOval(child: Image.network(profileUrl, fit: BoxFit.cover)))),
                    if (_onlineQrOverlay.visible) _buildDraggableOverlay(item: _onlineQrOverlay, constraints: constraints, child: _buildQrWidget(_generateOnlineQrData(), _onlineQrOverlay.size, "Connect")),
                    if (_offlineQrOverlay.visible) _buildDraggableOverlay(item: _offlineQrOverlay, constraints: constraints, child: _buildQrWidget(_generateOfflineQrData(), _offlineQrOverlay.size, "Contact")),
                  ]);
                }),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), color: Colors.black,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _buildToolbarButton(Icons.badge, "Details Bar", _infoBarOverlay.visible, () => setState(() => _infoBarOverlay.visible = !_infoBarOverlay.visible)),
              _buildToolbarButton(Icons.account_circle, "Profile", _profileOverlay.visible, () => setState(() => _profileOverlay.visible = !_profileOverlay.visible)),
              _buildToolbarButton(Icons.qr_code, "Online QR", _onlineQrOverlay.visible, () => setState(() => _onlineQrOverlay.visible = !_onlineQrOverlay.visible)),
              _buildToolbarButton(Icons.qr_code_2, "Offline QR", _offlineQrOverlay.visible, () => setState(() => _offlineQrOverlay.visible = !_offlineQrOverlay.visible)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _isSaving ? null : _saveFlyer, icon: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_alt), label: Text(_isSaving ? "Saving..." : "Save Flyer"), style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)))),
          ),
        ],
      ),
    );
  }

  Widget _buildQrWidget(String data, double size, String label) {
    return Container(width: size, height: size, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(_qrBorderRadius), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)]), child: Padding(padding: EdgeInsets.all(size * 0.08), child: Column(children: [Expanded(child: QrImageView(data: data, version: QrVersions.auto)), Text(label, style: TextStyle(fontSize: size * 0.08, fontWeight: FontWeight.bold, color: Colors.black))])));
  }

  Widget _buildToolbarButton(IconData icon, String label, bool active, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Column(children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: active ? Colors.blueAccent.withValues(alpha: 0.2) : Colors.white10, borderRadius: BorderRadius.circular(12), border: Border.all(color: active ? Colors.blueAccent : Colors.white24)), child: Icon(icon, color: active ? Colors.blueAccent : Colors.white60)), const SizedBox(height: 4), Text(label, style: TextStyle(color: active ? Colors.blueAccent : Colors.white54, fontSize: 10))]));
  }
}
