import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gridcard/core/services/auth_provider.dart';
import 'package:gridcard/core/services/profile_provider.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/widgets/top_alert.dart';
import 'package:universal_html/html.dart' as html;
import 'package:http/http.dart' as http;
import 'package:gridcard/core/services/user_storage_service.dart';
import '../models/flyer_editor_state.dart';
import '../services/flyer_brand_kit_service.dart';
import '../services/flyer_draft_service.dart';

class _OverlayItem {
  final String id;
  Offset position;
  double size;
  bool visible;
  bool locked;
  double rotation;
  double opacity;
  double height;
  double width;

  _OverlayItem({
    required this.id,
    required this.position,
    this.size = 80,
    this.width = 100,
    this.height = 100,
    this.visible = false,
    this.locked = false,
    this.rotation = 0.0,
    this.opacity = 1.0,
  });
}

class _TextOverlayItem extends _OverlayItem {
  String text;
  Color color;
  double fontSize;

  _TextOverlayItem({
    required String id,
    required Offset position,
    this.text = "Your Text",
    this.color = Colors.black,
    this.fontSize = 24,
    double opacity = 1.0,
    bool visible = true,
    bool locked = false,
    double rotation = 0,
  }) : super(
          id: id,
          position: position,
          visible: visible,
          locked: locked,
          rotation: rotation,
          opacity: opacity,
        );
}

class _ShapeOverlayItem extends _OverlayItem {
  Color color;
  String shape;

  _ShapeOverlayItem({
    required String id,
    required Offset position,
    this.color = Colors.grey,
    this.shape = "rect",
    double width = 100,
    double height = 100,
    double opacity = 1.0,
    bool visible = true,
    bool locked = false,
    double rotation = 0,
  }) : super(
          id: id,
          position: position,
          width: width,
          height: height,
          visible: visible,
          locked: locked,
          rotation: rotation,
          opacity: opacity,
        );
}



class FlyerEditorPage extends StatefulWidget {
  final String imageUrl;

  const FlyerEditorPage({super.key, required this.imageUrl});

  @override
  State<FlyerEditorPage> createState() => _FlyerEditorPageState();
}

class _FlyerEditorPageState extends State<FlyerEditorPage> {
  final GlobalKey _captureKey = GlobalKey();
  List<_TextOverlayItem> _texts = [];
  List<_ShapeOverlayItem> _shapes = [];
  _OverlayItem? _selectedItem;

  String _activeCategory = "Brand";
  Map<String, dynamic>? _directBusinessInfo;
  
  late _OverlayItem _profileOverlay;
  late _OverlayItem _logoOverlay;
  late _OverlayItem _onlineQrOverlay;
  late _OverlayItem _offlineQrOverlay;

  int _footerStyleIndex = 0;
  bool _isFooterVisible = true;
  bool _isHeaderVisible = false;
  bool _headerShowLogo = false;
  bool _headerShowBg = false;
  bool _isSaving = false;
  bool _imageLoaded = false;
  bool _isLoadingBusinessInfo = false;

  Color _footerBgColor = Colors.white;
  Color _footerTextColor = Colors.black;
  double _footerOpacity = 0.9;
  
  Color _headerBgColor = Colors.white;
  Color _headerTextColor = Colors.black;
  double _headerOpacity = 0.8;
  double _barFontSize = 14;

  // Gesture temp state
  double _baseSize = 0;
  double _baseWidth = 0;
  double _baseHeight = 0;
  double _baseFontSize = 0;
  double _baseRotation = 0;
  bool _gestureHistoryPushed = false;

  final List<FlyerEditorState> _undoStack = [];
  final List<FlyerEditorState> _redoStack = [];
  bool _isApplyingHistory = false;
  final FlyerDraftService _draftService = FlyerDraftService();
  final FlyerBrandKitService _brandKitService = FlyerBrandKitService();
  Timer? _autosaveDebounce;
  double _exportPixelRatio = 3.0;
  String _exportFormat = 'png';

  static const double _snapThreshold = 8.0;
  static const double _safeMargin = 16.0;
  static const double _footerHeight = 66.0;
  bool _showVerticalGuide = false;
  bool _showHorizontalGuide = false;
  double _guideX = 0;
  double _guideY = 0;
  final List<String> _layerOrder = [];

  @override
  void initState() {
    super.initState();
    _fetchBusinessInfoDirect();
    _profileOverlay = _OverlayItem(id: _newId('profile'), position: const Offset(20, 20), size: 100, visible: false);
    _logoOverlay = _OverlayItem(id: _newId('logo'), position: const Offset(140, 20), size: 100, visible: false);
    _onlineQrOverlay = _OverlayItem(id: _newId('onlineQr'), position: const Offset(20, 140), size: 100, visible: false);
    _offlineQrOverlay = _OverlayItem(id: _newId('offlineQr'), position: const Offset(140, 140), size: 100, visible: false);
    _layerOrder.addAll([_profileOverlay.id, _logoOverlay.id, _onlineQrOverlay.id, _offlineQrOverlay.id]);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(NetworkImage(widget.imageUrl), context).then((_) {
        if (mounted) setState(() => _imageLoaded = true);
      });
      _tryRestoreDraft();
    });
  }

  @override
  void dispose() {
    _autosaveDebounce?.cancel();
    super.dispose();
  }

  // ================= DATA FETCHING =================

  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _fetchBusinessInfoDirect() async {
    setState(() => _isLoadingBusinessInfo = true);
    try {
      final url = Uri.parse('${AppConfig.apiBaseUrl}/business-info');
      final headers = await _getHeaders();
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == true && jsonData['data'] is List) {
          final List dataList = jsonData['data'];
          if (dataList.isNotEmpty) {
            setState(() {
              _directBusinessInfo = dataList[0];
            });
          }
        }
      }
    } catch (e) {
      debugPrint("❌ Error fetching business info: $e");
    } finally {
      setState(() => _isLoadingBusinessInfo = false);
    }
  }

  String? _getProfilePicUrl() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user?.masterUser?.profilePic != null) {
      return '${AppConfig.apiProfileImg}/${user!.masterUser!.profilePic}';
    }
    return null;
  }

  String? _getProfileLogoUrl() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user?.masterUser?.profileLogo != null) {
      return '${AppConfig.apiProfileImg}/${user!.masterUser!.profileLogo}';
    }
    return null;
  }

  String _newId(String prefix) => '${prefix}_${DateTime.now().microsecondsSinceEpoch}';

  List<_OverlayItem> _allOverlays() => [
        _profileOverlay,
        _logoOverlay,
        _onlineQrOverlay,
        _offlineQrOverlay,
        ..._texts,
        ..._shapes,
      ];

  FlyerEditorState _captureSnapshot() {
    final itemById = {for (final item in _allOverlays()) item.id: item};
    final orderedItems = <_OverlayItem>[
      ..._layerOrder.map((id) => itemById[id]).whereType<_OverlayItem>(),
      ...itemById.values.where((item) => !_layerOrder.contains(item.id)),
    ];

    final overlays = orderedItems.map((item) {
      final data = <String, dynamic>{
        'x': item.position.dx,
        'y': item.position.dy,
        'size': item.size,
        'width': item.width,
        'height': item.height,
        'visible': item.visible,
        'locked': item.locked,
        'rotation': item.rotation,
        'opacity': item.opacity,
      };
      String type = 'overlay';
      if (item == _profileOverlay) type = 'profile';
      if (item == _logoOverlay) type = 'logo';
      if (item == _onlineQrOverlay) type = 'onlineQr';
      if (item == _offlineQrOverlay) type = 'offlineQr';
      if (item is _TextOverlayItem) {
        type = 'text';
        data['text'] = item.text;
        data['color'] = item.color.toARGB32();
        data['fontSize'] = item.fontSize;
      } else if (item is _ShapeOverlayItem) {
        type = 'shape';
        data['color'] = item.color.toARGB32();
        data['shape'] = item.shape;
      }
      return FlyerOverlayState(id: item.id, type: type, data: data);
    }).toList();

    return FlyerEditorState(
      activeCategory: _activeCategory,
      selectedId: _selectedItem?.id,
      isFooterVisible: _isFooterVisible,
      isHeaderVisible: _isHeaderVisible,
      headerShowLogo: _headerShowLogo,
      headerShowBg: _headerShowBg,
      footerStyleIndex: _footerStyleIndex,
      footerOpacity: _footerOpacity,
      headerOpacity: _headerOpacity,
      barFontSize: _barFontSize,
      footerBgColorValue: _footerBgColor.toARGB32(),
      footerTextColorValue: _footerTextColor.toARGB32(),
      headerBgColorValue: _headerBgColor.toARGB32(),
      headerTextColorValue: _headerTextColor.toARGB32(),
      overlays: overlays,
    );
  }

  void _restoreSnapshot(FlyerEditorState state) {
    _isApplyingHistory = true;
    final restoredTexts = <_TextOverlayItem>[];
    final restoredShapes = <_ShapeOverlayItem>[];
    _OverlayItem? restoredSelected;

    for (final o in state.overlays) {
      final x = (o.data['x'] as num?)?.toDouble() ?? 0;
      final y = (o.data['y'] as num?)?.toDouble() ?? 0;
      final item = _overlayFromState(o, Offset(x, y));
      if (item == null) continue;

      if (item is _TextOverlayItem) restoredTexts.add(item);
      if (item is _ShapeOverlayItem) restoredShapes.add(item);

      if (o.type == 'profile') _profileOverlay = item;
      if (o.type == 'logo') _logoOverlay = item;
      if (o.type == 'onlineQr') _onlineQrOverlay = item;
      if (o.type == 'offlineQr') _offlineQrOverlay = item;
      if (o.id == state.selectedId) restoredSelected = item;
    }

    setState(() {
      _texts = restoredTexts;
      _shapes = restoredShapes;
      _selectedItem = restoredSelected;
      _activeCategory = state.activeCategory;
      _isFooterVisible = state.isFooterVisible;
      _isHeaderVisible = state.isHeaderVisible;
      _headerShowLogo = state.headerShowLogo;
      _headerShowBg = state.headerShowBg;
      _footerStyleIndex = state.footerStyleIndex;
      _footerOpacity = state.footerOpacity;
      _headerOpacity = state.headerOpacity;
      _barFontSize = state.barFontSize;
      _footerBgColor = Color(state.footerBgColorValue);
      _footerTextColor = Color(state.footerTextColorValue);
      _headerBgColor = Color(state.headerBgColorValue);
      _headerTextColor = Color(state.headerTextColorValue);
      _showHorizontalGuide = false;
      _showVerticalGuide = false;
      _layerOrder
        ..clear()
        ..addAll(state.overlays.map((e) => e.id));
    });
    _isApplyingHistory = false;
  }

  _OverlayItem? _overlayFromState(FlyerOverlayState o, Offset pos) {
    final size = (o.data['size'] as num?)?.toDouble() ?? 80;
    final width = (o.data['width'] as num?)?.toDouble() ?? 100;
    final height = (o.data['height'] as num?)?.toDouble() ?? 100;
    final visible = o.data['visible'] == true;
    final rotation = (o.data['rotation'] as num?)?.toDouble() ?? 0;
    final opacity = (o.data['opacity'] as num?)?.toDouble() ?? 1;

    if (o.type == 'text') {
      return _TextOverlayItem(
        id: o.id,
        position: pos,
        text: o.data['text']?.toString() ?? 'Your Text',
        color: Color((o.data['color'] as num?)?.toInt() ?? Colors.black.toARGB32()),
        fontSize: (o.data['fontSize'] as num?)?.toDouble() ?? 24,
        opacity: opacity,
        visible: visible,
        rotation: rotation,
      );
    }
    if (o.type == 'shape') {
      return _ShapeOverlayItem(
        id: o.id,
        position: pos,
        color: Color((o.data['color'] as num?)?.toInt() ?? Colors.grey.toARGB32()),
        shape: o.data['shape']?.toString() ?? 'rect',
        width: width,
        height: height,
        opacity: opacity,
        visible: visible,
        rotation: rotation,
      );
    }
    return _OverlayItem(
      id: o.id,
      position: pos,
      size: size,
      width: width,
      height: height,
      visible: visible,
      locked: o.data['locked'] == true,
      rotation: rotation,
      opacity: opacity,
    );
  }

  void _pushHistory() {
    if (_isApplyingHistory) return;
    _undoStack.add(_captureSnapshot());
    if (_undoStack.length > 120) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _scheduleAutosave() {
    _autosaveDebounce?.cancel();
    _autosaveDebounce = Timer(const Duration(milliseconds: 600), () async {
      await _draftService.saveDraft(widget.imageUrl, _captureSnapshot());
    });
  }

  Future<void> _tryRestoreDraft() async {
    final draft = await _draftService.loadDraft(widget.imageUrl);
    if (!mounted || draft == null) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Expanded(child: Text('Restore your last flyer draft?')),
              TextButton(
                onPressed: () async {
                  await _draftService.clearDraft(widget.imageUrl);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Discard'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (ctx.mounted) Navigator.pop(ctx);
                  _restoreSnapshot(draft);
                },
                child: const Text('Restore'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_captureSnapshot());
    final prev = _undoStack.removeLast();
    _restoreSnapshot(prev);
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_captureSnapshot());
    final next = _redoStack.removeLast();
    _restoreSnapshot(next);
  }

  void _commitMutation(VoidCallback mutation) {
    _pushHistory();
    setState(mutation);
    _scheduleAutosave();
  }

  void _registerLayer(_OverlayItem item) {
    _layerOrder.remove(item.id);
    _layerOrder.add(item.id);
  }

  String _labelForLayer(_OverlayItem item) {
    if (item == _profileOverlay) return 'Profile';
    if (item == _logoOverlay) return 'Logo';
    if (item == _onlineQrOverlay) return 'Online QR';
    if (item == _offlineQrOverlay) return 'Offline QR';
    if (item is _TextOverlayItem) return 'Text: ${item.text}';
    if (item is _ShapeOverlayItem) return 'Shape: ${item.shape}';
    return 'Layer';
  }

  void _moveLayer(_OverlayItem item, int direction) {
    final current = _layerOrder.indexOf(item.id);
    if (current == -1) return;
    final next = (current + direction).clamp(0, _layerOrder.length - 1);
    if (next == current) return;
    _commitMutation(() {
      final id = _layerOrder.removeAt(current);
      _layerOrder.insert(next, id);
    });
  }

  void _sendLayerToEdge(_OverlayItem item, {required bool front}) {
    final current = _layerOrder.indexOf(item.id);
    if (current == -1) return;
    final target = front ? _layerOrder.length - 1 : 0;
    if (current == target) return;
    _commitMutation(() {
      final id = _layerOrder.removeAt(current);
      _layerOrder.insert(target, id);
    });
  }

  Future<void> _saveBrandKit() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.user?.id?.toString() ?? auth.user?.userName ?? 'me';
    await _brandKitService.save(
      userId: userId,
      kit: FlyerBrandKit(
        footerBgColorValue: _footerBgColor.toARGB32(),
        footerTextColorValue: _footerTextColor.toARGB32(),
        footerOpacity: _footerOpacity,
        headerBgColorValue: _headerBgColor.toARGB32(),
        headerTextColorValue: _headerTextColor.toARGB32(),
        headerOpacity: _headerOpacity,
        footerStyleIndex: _footerStyleIndex,
        headerShowLogo: _headerShowLogo,
        headerShowBg: _headerShowBg,
      ),
    );
    if (mounted) {
      TopAlert.show(context, 'Brand kit saved', isSuccess: true);
    }
  }

  Future<void> _applyBrandKit() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.user?.id?.toString() ?? auth.user?.userName ?? 'me';
    final kit = await _brandKitService.load(userId: userId);
    if (kit == null) {
      if (mounted) TopAlert.show(context, 'No saved brand kit found', isError: true);
      return;
    }
    _commitMutation(() {
      _footerBgColor = Color(kit.footerBgColorValue);
      _footerTextColor = Color(kit.footerTextColorValue);
      _footerOpacity = kit.footerOpacity;
      _headerBgColor = Color(kit.headerBgColorValue);
      _headerTextColor = Color(kit.headerTextColorValue);
      _headerOpacity = kit.headerOpacity;
      _footerStyleIndex = kit.footerStyleIndex;
      _headerShowLogo = kit.headerShowLogo;
      _headerShowBg = kit.headerShowBg;
      _isFooterVisible = true;
    });
  }

  void _addCtaText(String type) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    final mobile = user?.userMobile ?? (_directBusinessInfo?['mobile']?.toString() ?? '');
    final website = (_directBusinessInfo?['website_url']?.toString() ?? 'www.example.com').replaceAll('https://', '');
    String label = 'Contact Us';
    if (type == 'call') label = 'Call Now: $mobile';
    if (type == 'wa') label = 'WhatsApp: $mobile';
    if (type == 'web') label = 'Visit: $website';
    if (type == 'scan') label = 'Scan QR to Connect';
    _commitMutation(() {
      final item = _TextOverlayItem(
        id: _newId('cta'),
        position: const Offset(60, 90),
        text: label,
        color: Colors.white,
        fontSize: 22,
      );
      _texts.add(item);
      _registerLayer(item);
    });
  }

  String _buildShareCaption() {
    final info = _directBusinessInfo ?? {};
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    final name = info['name'] ?? info['fname'] ?? user?.masterUser?.fname ?? 'Bynd User';
    final mobile = info['mobile'] ?? user?.userMobile ?? '';
    final web = info['website_url'] ?? '';
    return 'Flyer by $name\nContact: $mobile\n$web';
  }

  Future<Uint8List> _captureFlyerBytes({required bool jpg}) async {
    final boundary = _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw Exception("Render error");
    final image = await boundary.toImage(pixelRatio: _exportPixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();
    if (!jpg) return pngBytes;
    final decoded = img.decodePng(pngBytes);
    if (decoded == null) return pngBytes;
    return Uint8List.fromList(img.encodeJpg(decoded, quality: 92));
  }

  Future<void> _shareFlyer() async {
    try {
      final bytes = await _captureFlyerBytes(jpg: _exportFormat == 'jpg');
      final ext = _exportFormat == 'jpg' ? 'jpg' : 'png';
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/flyer_share_${DateTime.now().millisecondsSinceEpoch}.$ext');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: _buildShareCaption());
    } catch (e) {
      if (mounted) TopAlert.show(context, "Share failed: $e", isError: true);
    }
  }

  Future<void> _copyCaption() async {
    await Clipboard.setData(ClipboardData(text: _buildShareCaption()));
    if (mounted) TopAlert.show(context, 'Caption copied', isSuccess: true);
  }


  List<_OverlayItem> _orderedLayers() {
    final byId = {for (final item in _allOverlays()) item.id: item};
    final ordered = <_OverlayItem>[
      ..._layerOrder.map((id) => byId[id]).whereType<_OverlayItem>(),
      ...byId.values.where((item) => !_layerOrder.contains(item.id)),
    ];
    return ordered;
  }

  // ================= DIALOGS & MODALS =================

  void _addTextDialog() {
    String value = "";
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Enter Text", style: Theme.of(context).textTheme.titleLarge),
        content: TextField(
          onChanged: (val) => value = val,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Type here..."),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (value.trim().isNotEmpty) {
                _commitMutation(() {
                  final item = _TextOverlayItem(id: _newId('text'), position: const Offset(50, 50), text: value);
                  _texts.add(item);
                  _registerLayer(item);
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  void _addShapeDialog() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Select Shape", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _shapeOption("rect", Icons.crop_square),
                _shapeOption("circle", Icons.circle_outlined),
                _shapeOption("triangle", Icons.change_history),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _shapeOption(String type, IconData icon) {
    return GestureDetector(
      onTap: () {
        _commitMutation(() {
          final item = _ShapeOverlayItem(id: _newId('shape'), position: const Offset(80, 80), shape: type);
          _shapes.add(item);
          _registerLayer(item);
        });
        Navigator.pop(context);
      },
      child: Column(
        children: [
          Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          Text(type.toUpperCase(), style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  void _showColorPicker(Function(Color) onSelected) {
    final colors = [
      Colors.white, Colors.black, Colors.red, Colors.blue, Colors.green,
      Colors.orange, Colors.purple, Colors.teal, Colors.amber, Colors.pink,
      Colors.brown, Colors.grey, Colors.transparent,
    ];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Choose Color", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12, runSpacing: 12,
              children: colors.map((c) => GestureDetector(
                onTap: () {
                  onSelected(c);
                  Navigator.pop(ctx);
                },
                child: Container(
                  width: 45, height: 45,
                  decoration: BoxDecoration(
                    color: c, shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300, width: 0.5),
                  ),
                  child: c == Colors.transparent ? const Icon(Icons.block, size: 20, color: Colors.grey) : null,
                ),
              )).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showTextEditModal(_TextOverlayItem item) {
    String value = item.text;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Edit Text", style: Theme.of(context).textTheme.titleLarge),
        content: TextField(
          controller: TextEditingController(text: item.text),
          onChanged: (val) => value = val,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              _commitMutation(() => item.text = value);
              Navigator.pop(ctx);
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  void _showShapeEditModal(_ShapeOverlayItem item) {
    // Current shape edit is handled via Property Bar for color/opacity
    setState(() => _selectedItem = item);
  }

  void _showAdjustModal(_OverlayItem item) {
    setState(() => _selectedItem = item);
  }

  // ================= GESTURE OVERLAY BUILDER =================

  Widget _buildDraggableOverlay({
    required _OverlayItem item,
    required BoxConstraints constraints,
    required Widget child,
    VoidCallback? onDoubleTap,
  }) {
    return Positioned(
      left: item.position.dx,
      top: item.position.dy,
      child: GestureDetector(
        onScaleStart: (details) {
          if (item.locked) {
            setState(() => _selectedItem = item);
            return;
          }
          if (!_gestureHistoryPushed) {
            _pushHistory();
            _gestureHistoryPushed = true;
          }
          setState(() {
            _selectedItem = item;
            _baseRotation = item.rotation;
            if (item is _ShapeOverlayItem) {
              _baseWidth = item.width;
              _baseHeight = item.height;
            } else if (item is _TextOverlayItem) {
              _baseFontSize = item.fontSize;
            } else {
              _baseSize = item.size;
            }
          });
        },
        onScaleUpdate: (details) {
          if (item.locked) return;
          setState(() {
            // Move: uses delta directly
            final previousPosition = item.position;
            var nextPosition = previousPosition + details.focalPointDelta;
            _showVerticalGuide = false;
            _showHorizontalGuide = false;

            final centerX = constraints.maxWidth / 2;
            final centerY = (constraints.maxHeight - (_isFooterVisible ? 60 : 0)) / 2;

            bool movingTowardX(double guideX) {
              final prevDist = (previousPosition.dx - guideX).abs();
              final nextDist = (nextPosition.dx - guideX).abs();
              return nextDist <= prevDist;
            }

            bool movingTowardY(double guideY) {
              final prevDist = (previousPosition.dy - guideY).abs();
              final nextDist = (nextPosition.dy - guideY).abs();
              return nextDist <= prevDist;
            }

            final xGuides = <double>[_safeMargin, centerX, constraints.maxWidth - _safeMargin];
            for (final other in _orderedLayers()) {
              if (!other.visible || other.id == item.id) continue;
              xGuides.add(other.position.dx);
            }
            for (final x in xGuides) {
              final dist = (nextPosition.dx - x).abs();
              if (dist <= _snapThreshold && movingTowardX(x)) {
                nextPosition = Offset(x, nextPosition.dy);
                _showVerticalGuide = true;
                _guideX = x;
                break;
              }
            }

            final yGuides = <double>[_safeMargin, centerY, constraints.maxHeight - _safeMargin];
            for (final other in _orderedLayers()) {
              if (!other.visible || other.id == item.id) continue;
              yGuides.add(other.position.dy);
            }
            for (final y in yGuides) {
              final dist = (nextPosition.dy - y).abs();
              if (dist <= _snapThreshold && movingTowardY(y)) {
                nextPosition = Offset(nextPosition.dx, y);
                _showHorizontalGuide = true;
                _guideY = y;
                break;
              }
            }

            item.position = nextPosition;
            
            // Rotation: use cumulative from base
            if (details.rotation != 0.0) {
              item.rotation = _baseRotation + details.rotation;
            }

            // Scale: use cumulative from base
            if (details.scale != 1.0) {
              if (item is _ShapeOverlayItem) {
                item.width = (_baseWidth * details.scale).clamp(40.0, 1000.0);
                item.height = (_baseHeight * details.scale).clamp(40.0, 1000.0);
              } else if (item is _TextOverlayItem) {
                item.fontSize = (_baseFontSize * details.scale).clamp(18.0, 300.0);
              } else {
                item.size = (_baseSize * details.scale).clamp(60.0, 1000.0);
              }
            }
          });
        },
        onScaleEnd: (_) {
          _gestureHistoryPushed = false;
          _scheduleAutosave();
          if (_showHorizontalGuide || _showVerticalGuide) {
            setState(() {
              _showHorizontalGuide = false;
              _showVerticalGuide = false;
            });
          }
        },
        onDoubleTap: onDoubleTap,
        child: Transform.rotate(
          angle: item.rotation,
          child: Container(
            decoration: BoxDecoration(
              border: _selectedItem == item ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  // ================= FOOTER SYSTEM =================

  Widget _buildFooterWidget(BoxConstraints constraints) {
    if (!_isFooterVisible) return const SizedBox.shrink();
    final info = _directBusinessInfo ?? {};
    final String bizName = info['legal_name'] ?? "Bynd AI Solutions";
    final String mobile = info['mobile'] ?? "9123456789";
    final String email = info['contact_email'] ?? "support@byndai.com";
    final String web = info['website_url'] ?? "www.byndai.com";
    final String industry = info['industry'] ?? "Technology";
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final String name = info['name'] ?? info['fname'] ?? user?.masterUser?.fname ?? "Bynd User";
    final String designation = info['designation'] ?? info['occupation'] ?? "Consultant";

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity! > 0) {
          setState(() => _footerStyleIndex = (_footerStyleIndex - 1) % 5);
        } else if (details.primaryVelocity! < 0) {
          setState(() => _footerStyleIndex = (_footerStyleIndex + 1) % 5);
        }
        if (_footerStyleIndex < 0) _footerStyleIndex = 4;
        HapticFeedback.selectionClick();
      },
      onTap: () => setState(() {
        _activeCategory = "Footer";
        _selectedItem = null;
      }),
      child: SizedBox(
        height: _footerHeight,
        width: double.infinity,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: _footerBgColor.withOpacity(_footerOpacity),
          border: _activeCategory == "Footer" ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
          boxShadow: [BoxShadow(color: Theme.of(context).shadowColor.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, -2))],
        ),
        child: _buildFooterStyleContent(
          bizName, mobile, email, web, industry, name, designation,
          _getProfilePicUrl(), _getProfileLogoUrl(),
        ),
        ),
      ),
    );
  }

  Widget _buildHeaderOverlay(BoxConstraints constraints) {
    if (!_isHeaderVisible) return const SizedBox.shrink();
    final info = _directBusinessInfo ?? {};
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final String name = info['name'] ?? info['fname'] ?? user?.masterUser?.fname ?? "Bynd User";
    final String mobile = info['mobile'] ?? (user?.userMobile ?? "9123456789");
    final String web = info['website_url'] ?? "www.byndai.com";
    
    final profileUrl = _getProfilePicUrl();
    final logoUrl = _getProfileLogoUrl();
    final String? activeImgUrl = _headerShowLogo ? logoUrl : profileUrl;

    return Positioned(
      top: 0, left: 0, right: 0,
      child: GestureDetector(
        onTap: () => setState(() {
          _activeCategory = "Header";
          _selectedItem = null;
        }),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: _activeCategory == "Header" ? Border.all(color: Colors.blueAccent, width: 2) : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Image (Left)
              if (activeImgUrl != null)
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white10,
                    backgroundImage: NetworkImage(activeImgUrl),
                  ),
                ),
              const SizedBox(width: 10),
              // Contact Info (Right)
              Expanded(
                child: Align(
                  alignment: Alignment.topRight,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.70),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _headerShowBg ? _headerBgColor.withOpacity(_headerOpacity) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _headerShowBg ? [BoxShadow(color: Colors.black12, blurRadius: 2)] : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              name,
                              maxLines: 1,
                              style: TextStyle(
                                color: _headerTextColor,
                                fontWeight: FontWeight.bold,
                                fontSize: _barFontSize + 2,
                                shadows: !_headerShowBg ? [const Shadow(color: Colors.black45, blurRadius: 4)] : null,
                              ),
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              mobile,
                              maxLines: 1,
                              style: TextStyle(
                                color: _headerShowBg ? _headerTextColor.withOpacity(0.8) : _headerTextColor.withOpacity(0.9),
                                fontSize: _barFontSize,
                                shadows: !_headerShowBg ? [const Shadow(color: Colors.black45, blurRadius: 4)] : null,
                              ),
                            ),
                          ),
                          if (web.isNotEmpty)
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                web,
                                maxLines: 1,
                                style: TextStyle(
                                  color: _headerShowBg ? _headerTextColor.withOpacity(0.8) : _headerTextColor.withOpacity(0.9),
                                  fontSize: _barFontSize - 2,
                                  shadows: !_headerShowBg ? [const Shadow(color: Colors.black45, blurRadius: 4)] : null,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooterStyleContent(
    String biz, String mob, String mail, String web, String ind, String name, String des,
    String? profileUrl, String? logoUrl,
  ) {
    switch (_footerStyleIndex) {
      case 3: // Profile Image Style
        return Row(
          children: [
            if (profileUrl != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: _footerTextColor.withOpacity(0.1),
                  backgroundImage: NetworkImage(profileUrl),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(name, style: TextStyle(color: _footerTextColor, fontWeight: FontWeight.bold, fontSize: _barFontSize + 1)),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _footerIconText(Icons.phone, mob, _footerTextColor),
                      const SizedBox(width: 8),
                      Expanded(child: _footerIconText(Icons.language, web, _footerTextColor)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      case 4: // Logo Style
        return Row(
          children: [
            if (logoUrl != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white,
                  child: ClipOval(
                    child: Image.network(
                      logoUrl,
                      fit: BoxFit.contain,
                      width: 44,
                      height: 44,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(biz, style: TextStyle(color: _footerTextColor, fontWeight: FontWeight.bold, fontSize: _barFontSize + 1)),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _footerIconText(Icons.phone, mob, _footerTextColor),
                      const SizedBox(width: 8),
                      Expanded(child: _footerIconText(Icons.language, web, _footerTextColor)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      case 1: // Industry Style
        return Row(
          children: [
            if (logoUrl != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white,
                  child: ClipOval(child: Image.network(logoUrl, fit: BoxFit.contain, width: 40, height: 40)),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text("$biz ($ind)", style: TextStyle(color: _footerTextColor, fontWeight: FontWeight.bold, fontSize: _barFontSize + 1)),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _footerIconText(Icons.phone, mob, _footerTextColor),
                      _footerSep(_footerTextColor),
                      Expanded(child: _footerIconText(Icons.language, web, _footerTextColor)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      case 2: // Personal Style
        return Row(
          children: [
            if (profileUrl != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: _footerTextColor.withOpacity(0.1),
                  backgroundImage: NetworkImage(profileUrl),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(name, style: TextStyle(color: _footerTextColor, fontWeight: FontWeight.bold, fontSize: _barFontSize + 1)),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _footerIconText(Icons.phone, mob, _footerTextColor),
                      _footerSep(_footerTextColor),
                      Expanded(child: _footerIconText(Icons.email, mail, _footerTextColor)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      default: // Style 0: Corporate
        return Row(
          children: [
            if (logoUrl != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white,
                  child: ClipOval(child: Image.network(logoUrl, fit: BoxFit.contain, width: 40, height: 40)),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(biz, style: TextStyle(color: _footerTextColor, fontWeight: FontWeight.bold, fontSize: _barFontSize + 1)),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _footerIconText(Icons.phone, mob, _footerTextColor),
                      _footerSep(_footerTextColor),
                      Expanded(child: _footerIconText(Icons.language, web, _footerTextColor)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
    }
  }

  Widget _footerIconText(IconData icon, String text, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: _barFontSize + 2, color: textColor.withOpacity(0.7)),
        const SizedBox(width: 4),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(text, style: TextStyle(color: textColor, fontSize: _barFontSize)),
          ),
        ),
      ],
    );
  }

  Widget _footerSep(Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(width: 1, height: 15, color: textColor.withOpacity(0.2)),
    );
  }

  // ================= TOOLBAR SYSTEM =================

  Widget _buildPropertyBar() {
    final bool isFooter = _activeCategory == "Footer";
    final bool isHeader = _activeCategory == "Header";
    if (_selectedItem == null && !isFooter && !isHeader) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Color Picker
            _propButton(
              icon: (isFooter || isHeader) ? Icons.format_color_fill : Icons.palette_outlined,
              label: "Color",
              onTap: () => _showColorPicker((c) {
                _commitMutation(() {
                  if (isFooter) _footerBgColor = c;
                  else if (isHeader) _headerBgColor = c;
                  else if (_selectedItem is _TextOverlayItem) (_selectedItem as _TextOverlayItem).color = c;
                  else if (_selectedItem is _ShapeOverlayItem) (_selectedItem as _ShapeOverlayItem).color = c;
                });
              }),
            ),
            if (isFooter || isHeader) _propButton(
              icon: Icons.format_color_text,
              label: "Text",
              onTap: () => _showColorPicker((c) => _commitMutation(() {
                if (isFooter) _footerTextColor = c;
                else if (isHeader) _headerTextColor = c;
              })),
            ),
            if (isHeader) ...[
              const VerticalDivider(),
              _propButton(
                icon: _headerShowBg ? Icons.check_box : Icons.check_box_outline_blank,
                label: "BG",
                onTap: () => _commitMutation(() => _headerShowBg = !_headerShowBg),
              ),
              _propButton(
                icon: _headerShowLogo ? Icons.business : Icons.person,
                label: _headerShowLogo ? "Logo" : "Profile",
                onTap: () => _commitMutation(() => _headerShowLogo = !_headerShowLogo),
              ),
            ],
            const VerticalDivider(),
            // Opacity
            const Icon(Icons.opacity, size: 18, color: Colors.grey),
            SizedBox(
              width: 100,
              child: Slider(
                value: isFooter ? _footerOpacity : (isHeader ? _headerOpacity : (_selectedItem?.opacity ?? 1.0)),
                onChangeStart: (_) => _pushHistory(),
                onChanged: (v) => setState(() {
                  if (isFooter) _footerOpacity = v;
                  else if (isHeader) _headerOpacity = v;
                  else _selectedItem?.opacity = v;
                }),
                onChangeEnd: (_) => _scheduleAutosave(),
              ),
            ),
            const VerticalDivider(),
            // Delete
            _propButton(
              icon: Icons.delete_outline,
              label: "Delete",
              color: Theme.of(context).colorScheme.error,
              onTap: () => _commitMutation(() {
                if (isFooter) {
                  _isFooterVisible = false;
                  _activeCategory = "Brand";
                } else if (isHeader) {
                  _isHeaderVisible = false;
                  _activeCategory = "Brand";
                } else {
                  if (_selectedItem?.locked == true) {
                    TopAlert.show(context, "Unlock layer before deleting", isError: true);
                    return;
                  }
                  if (_selectedItem is _TextOverlayItem) {
                    _texts.remove(_selectedItem);
                    _layerOrder.remove(_selectedItem!.id);
                  } else if (_selectedItem is _ShapeOverlayItem) {
                    _shapes.remove(_selectedItem);
                    _layerOrder.remove(_selectedItem!.id);
                  } else if (_selectedItem == _profileOverlay) {
                    _profileOverlay.visible = false;
                  } else if (_selectedItem == _logoOverlay) {
                    _logoOverlay.visible = false;
                  } else if (_selectedItem == _onlineQrOverlay) {
                    _onlineQrOverlay.visible = false;
                  } else if (_selectedItem == _offlineQrOverlay) {
                    _offlineQrOverlay.visible = false;
                  }
                  _selectedItem = null;
                }
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _propButton({required IconData icon, required String label, required VoidCallback onTap, Color? color}) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          children: [
            Icon(icon, color: color ?? theme.colorScheme.primary, size: 20),
            Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }

  Widget _buildModernToolbar(AuthProvider auth, ProfileProvider profile) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPropertyBar(),
          Container(
            height: 90,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _buildCategoryContent(auth, profile),
          ),
          Container(
            height: 60,
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).dividerColor))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCategoryTab("Brand", Icons.branding_watermark),
                _buildCategoryTab("Add", Icons.add_circle_outline),
                _buildCategoryTab("Layers", Icons.layers),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTab(String title, IconData icon) {
    final bool isActive = _activeCategory == title;
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => setState(() => _activeCategory = title),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.5), size: 24),
          const SizedBox(height: 4),
          Text(title, style: theme.textTheme.labelSmall?.copyWith(
            color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.5),
            fontWeight: isActive ? FontWeight.bold : null,
          )),
        ],
      ),
    );
  }

  Widget _buildCategoryContent(AuthProvider auth, ProfileProvider profile) {
    switch (_activeCategory) {
      case "Add":
        return ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _buildToolbarButton(icon: Icons.text_fields, label: "Text", isSelected: false, onTap: _addTextDialog),
            const SizedBox(width: 16),
            _buildToolbarButton(icon: Icons.category, label: "Shape", isSelected: false, onTap: _addShapeDialog),
            const SizedBox(width: 16),
            _buildToolbarButton(
              icon: Icons.qr_code,
              label: "Online QR",
              isSelected: _onlineQrOverlay.visible,
              onTap: () => _commitMutation(() {
                _onlineQrOverlay.visible = !_onlineQrOverlay.visible;
                if (_onlineQrOverlay.visible) _registerLayer(_onlineQrOverlay);
              }),
            ),
            const SizedBox(width: 16),
            _buildToolbarButton(
              icon: Icons.qr_code_2,
              label: "Offline QR",
              isSelected: _offlineQrOverlay.visible,
              onTap: () => _commitMutation(() {
                _offlineQrOverlay.visible = !_offlineQrOverlay.visible;
                if (_offlineQrOverlay.visible) _registerLayer(_offlineQrOverlay);
              }),
            ),
            const SizedBox(width: 16),
            _buildToolbarButton(icon: Icons.call, label: "Call CTA", isSelected: false, onTap: () => _addCtaText('call')),
            const SizedBox(width: 16),
            _buildToolbarButton(icon: Icons.chat, label: "WA CTA", isSelected: false, onTap: () => _addCtaText('wa')),
            const SizedBox(width: 16),
            _buildToolbarButton(icon: Icons.language, label: "Web CTA", isSelected: false, onTap: () => _addCtaText('web')),
            const SizedBox(width: 16),
            _buildToolbarButton(icon: Icons.qr_code_scanner, label: "Scan CTA", isSelected: false, onTap: () => _addCtaText('scan')),
          ],
        );

      case "Brand":
        return ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _buildToolbarButton(
              icon: Icons.subtitles, label: "Footer", isSelected: _isFooterVisible,
              onTap: () => _commitMutation(() { 
                _isFooterVisible = !_isFooterVisible; 
                if (_isFooterVisible) _activeCategory = "Footer";
                else if (_activeCategory == "Footer") _activeCategory = "Brand";
                _selectedItem = null; 
              }),
            ),
            const SizedBox(width: 16),
            _buildToolbarButton(
              icon: Icons.subtitles_off, label: "Header", isSelected: _isHeaderVisible,
              onTap: () => _commitMutation(() { 
                _isHeaderVisible = !_isHeaderVisible; 
                if (_isHeaderVisible) _activeCategory = "Header";
                else if (_activeCategory == "Header") _activeCategory = "Brand";
                _selectedItem = null; 
              }),
            ),
            const SizedBox(width: 16),
            _buildToolbarButton(
              icon: Icons.account_circle,
              label: "My Profile",
              isSelected: _profileOverlay.visible,
              onTap: () => _commitMutation(() {
                _profileOverlay.visible = !_profileOverlay.visible;
                if (_profileOverlay.visible) _registerLayer(_profileOverlay);
              }),
            ),
            const SizedBox(width: 16),
            if (_getProfileLogoUrl() != null)
              _buildToolbarButton(
                icon: Icons.image,
                label: "My Logo",
                isSelected: _logoOverlay.visible,
                onTap: () => _commitMutation(() {
                  _logoOverlay.visible = !_logoOverlay.visible;
                  if (_logoOverlay.visible) _registerLayer(_logoOverlay);
                }),
              ),
            const SizedBox(width: 16),
            _buildToolbarButton(icon: Icons.save, label: "Save Kit", isSelected: false, onTap: _saveBrandKit),
            const SizedBox(width: 16),
            _buildToolbarButton(icon: Icons.auto_fix_high, label: "Apply Kit", isSelected: false, onTap: _applyBrandKit),
            const SizedBox(width: 16),
            ..._buildDynamicDataButtons(),
          ],
        );
      case "Layers":
        final items = _orderedLayers();
        if (items.isEmpty) return const Center(child: Text("No layers", style: TextStyle(color: Colors.white54)));
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (ctx, i) => Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Container(
              width: 280,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _selectedItem == items[i] ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _selectedItem == items[i] ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedItem = items[i]),
                      child: Text(
                        _labelForLayer(items[i]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ),
                  ),
                  _buildLayerAction(
                    icon: items[i].visible ? Icons.visibility : Icons.visibility_off,
                    tooltip: items[i].visible ? 'Hide' : 'Show',
                    color: items[i].visible ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                    onTap: () => _commitMutation(() => items[i].visible = !items[i].visible),
                  ),
                  _buildLayerAction(
                    icon: items[i].locked ? Icons.lock : Icons.lock_open,
                    tooltip: items[i].locked ? 'Unlock' : 'Lock',
                    color: items[i].locked ? Colors.orangeAccent : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                    onTap: () => _commitMutation(() => items[i].locked = !items[i].locked),
                  ),
                  _buildLayerAction(
                    icon: Icons.arrow_back,
                    tooltip: 'Move Back',
                    color: i == 0 ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                    onTap: i == 0 ? null : () => _moveLayer(items[i], -1),
                  ),
                  _buildLayerAction(
                    icon: Icons.arrow_forward,
                    tooltip: 'Move Front',
                    color: i == items.length - 1 ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                    onTap: i == items.length - 1 ? null : () => _moveLayer(items[i], 1),
                  ),
                  _buildLayerAction(
                    icon: Icons.vertical_align_bottom,
                    tooltip: 'Send to back',
                    color: i == 0 ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                    onTap: i == 0 ? null : () => _sendLayerToEdge(items[i], front: false),
                  ),
                  _buildLayerAction(
                    icon: Icons.vertical_align_top,
                    tooltip: 'Bring to front',
                    color: i == items.length - 1 ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                    onTap: i == items.length - 1 ? null : () => _sendLayerToEdge(items[i], front: true),
                  ),
                ],
              ),
            ),
          ),
        );
      case "Footer":
        return const Center(child: Text("Swipe Footer to switch designs", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)));
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildLayerAction({required IconData icon, required String tooltip, required Color color, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Tooltip(
        message: tooltip,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  List<Widget> _buildDynamicDataButtons() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final data = [
      {"label": "Name", "value": auth.user?.masterUser?.fname, "icon": Icons.person},
      {"label": "Mobile", "value": auth.user?.userMobile, "icon": Icons.phone},
      {"label": "Company", "value": _directBusinessInfo?['legal_name'], "icon": Icons.business},
    ];
    return data.where((d) => d["value"] != null).map((d) => Padding(
      padding: const EdgeInsets.only(right: 12),
      child: _buildToolbarButton(
        icon: d["icon"] as IconData, label: d["label"] as String, isSelected: false,
        onTap: () => _commitMutation(() {
          final item = _TextOverlayItem(id: _newId('text'), position: const Offset(60, 60), text: d["value"].toString());
          _texts.add(item);
          _registerLayer(item);
        }),
      ),
    )).toList();
  }

  Widget _buildToolbarButton({required IconData icon, required String label, required bool isSelected, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.1) : theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? theme.colorScheme.primary : theme.dividerColor),
            ),
            child: Icon(icon, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface, size: 20),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 10)),
        ],
      ),
    );
  }

  // ================= RENDERING HELPERS =================

  Widget _buildQrWidget(String data, double size) {
    return Container(
      width: size, height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: QrImageView(data: data, version: QrVersions.auto, padding: EdgeInsets.zero),
    );
  }


  Widget _buildShape(_ShapeOverlayItem item) {
    final color = item.color.withOpacity(item.opacity);
    if (item.shape == "circle") return Container(width: item.width, height: item.height, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
    if (item.shape == "triangle") return CustomPaint(size: Size(item.width, item.height), painter: TrianglePainter(color));
    return Container(width: item.width, height: item.height, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)));
  }

  Widget _buildCanvasOverlayForItem(
    _OverlayItem item,
    BoxConstraints constraints,
    String? profileUrl,
    String? logoUrl,
  ) {
    if (!item.visible) return const SizedBox.shrink();

    if (item == _profileOverlay && profileUrl != null) {
      return _buildDraggableOverlay(
        item: item,
        constraints: constraints,
        onDoubleTap: () => _showAdjustModal(item),
        child: Container(
          width: item.size,
          height: item.size,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
          child: Opacity(opacity: item.opacity, child: ClipOval(child: Image.network(profileUrl, fit: BoxFit.cover))),
        ),
      );
    }

    if (item == _logoOverlay && logoUrl != null) {
      return _buildDraggableOverlay(
        item: item,
        constraints: constraints,
        onDoubleTap: () => _showAdjustModal(item),
        child: Container(
          width: item.size,
          height: item.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Opacity(
            opacity: item.opacity,
            child: ClipOval(
              child: Image.network(logoUrl, fit: BoxFit.contain),
            ),
          ),
        ),
      );
    }

    if (item == _onlineQrOverlay) {
      return _buildDraggableOverlay(
        item: item,
        constraints: constraints,
        child: _buildQrWidget(_generateOnlineQrData(), item.size),
      );
    }

    if (item == _offlineQrOverlay) {
      return _buildDraggableOverlay(
        item: item,
        constraints: constraints,
        child: _buildQrWidget(_generateOfflineQrData(), item.size),
      );
    }

    if (item is _ShapeOverlayItem) {
      return _buildDraggableOverlay(
        item: item,
        constraints: constraints,
        child: _buildShape(item),
        onDoubleTap: () => _showShapeEditModal(item),
      );
    }


    if (item is _TextOverlayItem) {
      return _buildDraggableOverlay(
        item: item,
        constraints: constraints,
        onDoubleTap: () => _showTextEditModal(item),
        child: Text(
          item.text,
          style: TextStyle(color: item.color.withOpacity(item.opacity), fontSize: item.fontSize, fontWeight: FontWeight.bold),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ================= SAVE LOGIC =================

  Future<void> _saveFlyer() async {
    if (_isSaving) return;

    final prevSelected = _selectedItem;
    final prevCategory = _activeCategory;

    setState(() {
      _isSaving = true;
      _selectedItem = null;
      _activeCategory = "";
    });

    // Let the UI finish rendering without election borders
    await WidgetsBinding.instance.endOfFrame;

    try {
      final bytes = await _captureFlyerBytes(jpg: _exportFormat == 'jpg');
      final ext = _exportFormat == 'jpg' ? 'jpg' : 'png';

      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)..setAttribute("download", "flyer.$ext")..click();
        html.Url.revokeObjectUrl(url);
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/flyer_${DateTime.now().millisecondsSinceEpoch}.$ext');
        await file.writeAsBytes(bytes);
        await Gal.putImage(file.path);
      }
      await _draftService.clearDraft(widget.imageUrl);
      if (mounted) TopAlert.show(context, "✅ Saved to gallery!", isSuccess: true);
    } catch (e) {
      if (mounted) TopAlert.show(context, "Error: $e", isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _selectedItem = prevSelected;
          _activeCategory = prevCategory;
        });
      }
    }
  }

  void _showExportOptionsSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Export Options', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    const Text('Format'),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('PNG'),
                          selected: _exportFormat == 'png',
                          onSelected: (_) => setLocal(() => _exportFormat = 'png'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('JPG'),
                          selected: _exportFormat == 'jpg',
                          onSelected: (_) => setLocal(() => _exportFormat = 'jpg'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Quality: ${(_exportPixelRatio * 100 / 3).round()}%'),
                    Slider(
                      min: 1.5,
                      max: 4.0,
                      divisions: 5,
                      value: _exportPixelRatio,
                      onChanged: (v) => setLocal(() => _exportPixelRatio = v),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (ctx.mounted) Navigator.pop(ctx);
                        setState(() {});
                      },
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ================= BUILD METHOD =================

  @override
  Widget build(BuildContext context) {
    final profileUrl = _getProfilePicUrl();
    final logoUrl = _getProfileLogoUrl();

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): const UndoIntent(),
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): const RedoIntent(),
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): const RedoIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          UndoIntent: CallbackAction<UndoIntent>(onInvoke: (_) {
            _undo();
            return null;
          }),
          RedoIntent: CallbackAction<RedoIntent>(onInvoke: (_) {
            _redo();
            return null;
          }),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            appBar: AppBar(
              backgroundColor: Theme.of(context).colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              title: Text('Flyer Editor', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
              iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
              actions: [
                IconButton(
                  onPressed: _shareFlyer,
                  icon: Icon(Icons.share, color: Theme.of(context).colorScheme.onSurface),
                  tooltip: 'Share Flyer',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveFlyer,
                    icon: _isSaving
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.download_rounded, size: 18),
                    label: Text(_isSaving ? "Saving..." : "Save"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  child: Center(
                    child: !_imageLoaded
                        ? const CircularProgressIndicator()
                        : LayoutBuilder(builder: (context, constraints) {
                              return RepaintBoundary(
                                key: _captureKey,
                                child: Container(
                                  color: Colors.white,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: constraints.maxWidth,
                                          maxHeight: constraints.maxHeight - (_isFooterVisible ? _footerHeight : 0),
                                        ),
                                        child: Stack(
                                          children: [
                                            Image.network(
                                              widget.imageUrl,
                                              fit: BoxFit.contain,
                                            ),
                                            if (_showVerticalGuide)
                                              Positioned(
                                                left: _guideX,
                                                top: 0,
                                                bottom: 0,
                                                child: Container(width: 1.2, color: Colors.cyanAccent.withOpacity(0.75)),
                                              ),
                                            if (_showHorizontalGuide)
                                              Positioned(
                                                left: 0,
                                                right: 0,
                                                top: _guideY,
                                                child: Container(height: 1.2, color: Colors.cyanAccent.withOpacity(0.75)),
                                              ),
                                            // Header
                                            _buildHeaderOverlay(constraints),
                                            ..._orderedLayers().map(
                                              (item) => _buildCanvasOverlayForItem(item, constraints, profileUrl, logoUrl),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Footer appended below image
                                      _buildFooterWidget(constraints),
                                    ],
                                  ),
                                ),
                              );
                            }),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Navigation & Quick Actions
                        Row(
                          children: [
                            IconButton(
                              onPressed: _undoStack.isEmpty ? null : _undo,
                              icon: const Icon(Icons.undo, size: 20),
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            IconButton(
                              onPressed: _redoStack.isEmpty ? null : _redo,
                              icon: const Icon(Icons.redo, size: 20),
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            const Spacer(),
                            Flexible(
                              child: TextButton.icon(
                                onPressed: _showExportOptionsSheet,
                                icon: const Icon(Icons.tune, size: 16),
                                label: Text(_exportFormat.toUpperCase(), style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
                                style: TextButton.styleFrom(visualDensity: VisualDensity.compact, foregroundColor: Theme.of(context).colorScheme.onSurface),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: TextButton.icon(
                                onPressed: _copyCaption,
                                icon: const Icon(Icons.content_copy, size: 16),
                                label: const Text('Caption', style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
                                style: TextButton.styleFrom(visualDensity: VisualDensity.compact, foregroundColor: Theme.of(context).colorScheme.onSurface),
                              ),
                            ),
                          ],
                        ),
                        _buildModernToolbar(Provider.of<AuthProvider>(context, listen: false), Provider.of<ProfileProvider>(context, listen: false)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  String _generateOnlineQrData() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    final profileId = user?.userName ?? user?.id?.toString() ?? 'me';
    return "https://byndai.com/u/$profileId";
  }

  String _generateOfflineQrData() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    final fname = user?.masterUser?.fname ?? 'User';
    final mobile = user?.userMobile ?? '';
    return 'BEGIN:VCARD\nVERSION:3.0\nFN:$fname\nTEL;TYPE=CELL:$mobile\nEND:VCARD';
  }
}

class TrianglePainter extends CustomPainter {
  final Color color;
  TrianglePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    path.moveTo(size.width / 2, 0); path.lineTo(0, size.height); path.lineTo(size.width, size.height); path.close();
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class UndoIntent extends Intent {
  const UndoIntent();
}

class RedoIntent extends Intent {
  const RedoIntent();
}
