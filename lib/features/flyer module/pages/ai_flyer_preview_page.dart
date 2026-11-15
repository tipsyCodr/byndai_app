import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gridcard/core/services/ai_flyer_service.dart';
import 'package:gridcard/core/services/auth_provider.dart';
import 'package:gridcard/widgets/top_alert.dart';
import 'flyer_editor_page.dart';

class AiFlyerPreviewPage extends StatefulWidget {
  final Map<String, dynamic> flyer;

  const AiFlyerPreviewPage({super.key, required this.flyer});

  @override
  State<AiFlyerPreviewPage> createState() => _AiFlyerPreviewPageState();
}

class _AiFlyerPreviewPageState extends State<AiFlyerPreviewPage> {
  late Map<String, dynamic> _flyer;
  final GlobalKey _canvasKey = GlobalKey();

  bool _isDownloading = false;
  bool _isRegenerating = false;

  // Footer Options
  bool _isFooterVisible = true;
  int _footerStyleIndex = 4; // Default to Logo style
  Color _footerBgColor = Colors.white;
  Color _footerTextColor = Colors.black87;
  double _footerOpacity = 0.95;
  Map<String, dynamic>? _brandKit;

  @override
  void initState() {
    super.initState();
    _flyer = widget.flyer;
    _loadBrandKit();
  }

  Future<void> _loadBrandKit() async {
    try {
      final kit = await AiFlyerService.getBrandKit();
      if (kit.isNotEmpty && mounted) {
        setState(() {
          _brandKit = kit;
        });
      }
    } catch (_) {}
  }

  String get _imageUrl => _flyer['image_url'] ?? '';

  Future<File?> _captureRenderedFlyer() async {
    try {
      final boundary = _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/ai_flyer_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      return file;
    } catch (e) {
      debugPrint('Capture error: $e');
      return null;
    }
  }

  Future<void> _saveToGallery() async {
    setState(() => _isDownloading = true);
    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          if (mounted) TopAlert.show(context, 'Permission denied to save photos', isError: true);
          return;
        }
      }

      final file = await _captureRenderedFlyer();
      if (file != null) {
        await Gal.putImage(file.path);
        if (mounted) TopAlert.show(context, '✅ Flyer saved to your gallery!', isSuccess: true);
      } else {
        throw Exception('Could not capture flyer image');
      }
    } catch (e) {
      if (mounted) TopAlert.show(context, 'Failed to save flyer: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _shareFlyer() async {
    setState(() => _isDownloading = true);
    try {
      final file = await _captureRenderedFlyer();
      if (file != null) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Created with Bynd AI!',
        );
      }
    } catch (e) {
      if (mounted) TopAlert.show(context, 'Error sharing flyer: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _regenerate() async {
    final id = _flyer['id'];
    if (id == null) return;

    setState(() => _isRegenerating = true);
    try {
      final result = await AiFlyerService.regenerateFlyer(id);
      if (mounted) {
        TopAlert.show(context, 'Regeneration started! Generating fresh variation...', isSuccess: true);
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) TopAlert.show(context, 'Failed to regenerate: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isRegenerating = false);
    }
  }

  void _openInEditor() {
    if (_imageUrl.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FlyerEditorPage(imageUrl: _imageUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = _flyer['category'] ?? 'Flyer';
    final occasion = _flyer['occasion'] != null ? _flyer['occasion']['name'] : null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              occasion ?? category,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '${_flyer['design_style'] ?? 'Modern'} • Swipe footer to change style',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Toggle Footer',
            icon: Icon(
              _isFooterVisible ? Icons.subtitles : Icons.subtitles_off,
              color: _isFooterVisible ? theme.colorScheme.primary : Colors.white70,
            ),
            onPressed: () => setState(() => _isFooterVisible = !_isFooterVisible),
          ),
          IconButton(
            tooltip: 'Edit in Full Studio',
            icon: const Icon(Icons.edit_note, color: Colors.white),
            onPressed: _openInEditor,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Interactive Repaint Canvas
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: AspectRatio(
                    aspectRatio: _getAspectRatio(),
                    child: RepaintBoundary(
                      key: _canvasKey,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // 1. Pristine AI Artwork
                          if (_imageUrl.isNotEmpty)
                            Image.network(
                              _imageUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (ctx, child, progress) {
                                if (progress == null) return child;
                                return const Center(child: CircularProgressIndicator(color: Colors.white));
                              },
                              errorBuilder: (ctx, err, stack) => const Center(
                                child: Text('Failed to load image', style: TextStyle(color: Colors.white70)),
                              ),
                            )
                          else
                            const Center(child: CircularProgressIndicator()),

                          // 2. Interactive Beautiful Footer Bar (Same as FlyerEditor)
                          if (_isFooterVisible)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: _buildFooterWidget(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Style Switcher Bar & Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Footer Style Pills
                  if (_isFooterVisible) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Footer Style:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            _buildStyleChip(4, 'Logo'),
                            const SizedBox(width: 6),
                            _buildStyleChip(0, 'Modern'),
                            const SizedBox(width: 6),
                            _buildStyleChip(2, 'Minimal'),
                            const SizedBox(width: 6),
                            _buildStyleChip(3, 'Profile'),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isDownloading ? null : _saveToGallery,
                          icon: _isDownloading
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.download_rounded),
                          label: const Text('Save to Gallery', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        onPressed: _isDownloading ? null : _shareFlyer,
                        icon: const Icon(Icons.share_outlined),
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.outlined(
                        tooltip: 'Regenerate Variation',
                        onPressed: _isRegenerating ? null : _regenerate,
                        icon: _isRegenerating
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.refresh_rounded),
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStyleChip(int idx, String label) {
    final isSelected = _footerStyleIndex == idx;
    return GestureDetector(
      onTap: () {
        setState(() => _footerStyleIndex = idx);
        HapticFeedback.selectionClick();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : null,
          ),
        ),
      ),
    );
  }

  double _getAspectRatio() {
    final ratio = _flyer['aspect_ratio']?.toString() ?? '1:1';
    if (ratio == '9:16') return 9 / 16;
    if (ratio == '4:5') return 4 / 5;
    return 1.0;
  }

  Widget _buildFooterWidget() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    final kit = _brandKit ?? {};

    final String bizName = kit['business_name'] ?? user?.masterUser?.fname ?? "My Business";
    final String mobile = kit['whatsapp'] ?? kit['phone'] ?? user?.userMobile ?? "";
    final String web = kit['website'] ?? "";
    final String email = kit['email'] ?? user?.email ?? "";
    final String? logoUrl = kit['logo_url'] ?? user?.masterUser?.profileLogo;
    final String? profileUrl = user?.masterUser?.profileLogo;

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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _footerBgColor.withValues(alpha: _footerOpacity),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: _buildFooterContent(bizName, mobile, email, web, logoUrl, profileUrl),
      ),
    );
  }

  Widget _buildFooterContent(
    String biz,
    String mob,
    String mail,
    String web,
    String? logoUrl,
    String? profileUrl,
  ) {
    switch (_footerStyleIndex) {
      case 4: // Logo Style
        return Row(
          children: [
            if (logoUrl != null && logoUrl.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(right: 10),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.black12, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4),
                  ],
                ),
                child: ClipOval(
                  child: Image.network(
                    logoUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (ctx, err, stack) => const Icon(Icons.business, size: 24),
                  ),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    biz,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _footerTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (mob.isNotEmpty) ...[
                        Icon(Icons.phone, size: 12, color: _footerTextColor.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Text(mob, style: TextStyle(color: _footerTextColor, fontSize: 11)),
                        const SizedBox(width: 8),
                      ],
                      if (web.isNotEmpty) ...[
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.language, size: 12, color: _footerTextColor.withValues(alpha: 0.7)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  web,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: _footerTextColor, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        );

      case 3: // Profile Avatar Style
        return Row(
          children: [
            if (profileUrl != null && profileUrl.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(right: 10),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.black12, width: 1.5),
                ),
                child: ClipOval(
                  child: Image.network(profileUrl, fit: BoxFit.cover),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    biz,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _footerTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.call, size: 12, color: _footerTextColor.withValues(alpha: 0.7)),
                      const SizedBox(width: 4),
                      Text(mob, style: TextStyle(color: _footerTextColor, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );

      case 2: // Minimal Text Style
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                biz,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _footerTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            Row(
              children: [
                if (mob.isNotEmpty) ...[
                  const Icon(Icons.phone, size: 12),
                  const SizedBox(width: 4),
                  Text(mob, style: TextStyle(color: _footerTextColor, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ],
        );

      default: // Modern Style
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    biz,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _footerTextColor, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  if (web.isNotEmpty)
                    Text(web, style: TextStyle(color: _footerTextColor.withValues(alpha: 0.7), fontSize: 11)),
                ],
              ),
            ),
            if (mob.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.chat, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      mob,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
          ],
        );
    }
  }
}
