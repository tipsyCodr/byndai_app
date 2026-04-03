import 'dart:convert';
import 'dart:io';
import 'dart:math';
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
import 'package:http/http.dart' as http;
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../feature_map/feature_access_helper.dart';
import '../../feature_map/feature_mapper.dart';
import '../../home/SubscriptionPlans.dart';

class _OverlayItem {
  Offset position;
  double size;
  bool visible;
  double rotation;
  double opacity;
  double height;

  _OverlayItem({
    required this.position,
    this.size = 80,
    this.height = 104,
    this.visible = false,
    this.rotation = 0.0,
    this.opacity = 1.0,
  });
}

class _TextOverlayItem extends _OverlayItem {
  String text;
  Color color;
  double fontSize;
  double opacity;

  _TextOverlayItem({
    required Offset position,
    this.text = "Your Text",
    this.color = const ui.Color.fromARGB(255, 151, 151, 151),
    this.fontSize = 24,
    this.opacity = 1.0,
    double size = 150,
    bool visible = true,
    double rotation = 0,
  }) : super(
          position: position,
          size: size,
          visible: visible,
          rotation: rotation,
        );
}

class _ShapeOverlayItem extends _OverlayItem {
  Color color;
  String shape;

  double width;
  double height;
  double opacity;

  _ShapeOverlayItem({
    required Offset position,
    this.color = const ui.Color.fromARGB(255, 151, 151, 151), // ✅ default black
    this.shape = "rect",
    this.width = 100,
    this.height = 100,
    this.opacity = 1.0,
    bool visible = true,
    double rotation = 0,
  }) : super(
          position: position,
          size: 100, // optional, not used now
          visible: visible,
          rotation: rotation,
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
  bool _isBarTransparent = false;

  Map<String, dynamic>? _directBusinessInfo; // 🔥 newly fetched business data
  bool _isLoadingBusinessInfo = true;

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
    _fetchBusinessInfoDirect();
    _profileOverlay = _OverlayItem(
      position: const Offset(20, 20),
      size: 100,
      visible: true,
      opacity: 1.0,
    );
    _onlineQrOverlay = _OverlayItem(
        position: const Offset(20, 140), size: 100, visible: false);
    _offlineQrOverlay = _OverlayItem(
        position: const Offset(140, 140), size: 100, visible: false);
    _infoBarOverlay = _OverlayItem(
        position: const Offset(20, 300), size: 300, visible: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(NetworkImage(widget.imageUrl), context).then((_) {
        if (mounted) setState(() => _imageLoaded = true);
      });
    });
  }

  Future<void> _fetchBusinessInfoDirect() async {
    setState(() => _isLoadingBusinessInfo = true);

    try {
      final url = Uri.parse('${AppConfig.apiBaseUrl}/business-info');
      final headers = await _getHeaders();

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        debugPrint("🔥 RAW API RESPONSE: $jsonData"); // 👈 ADD THIS

        if (jsonData['status'] == true && jsonData['data'] is List) {
          final List dataList = jsonData['data'];

          if (dataList.isNotEmpty) {
            setState(() {
              _directBusinessInfo = dataList[0];
            });

            /// 🔥 IMPORTANT: PRINT AFTER DATA SET
            await _printUserData();
          }
        }
      } else {
        debugPrint("❌ Business info API failed: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Error fetching business info: $e");
    } finally {
      setState(() => _isLoadingBusinessInfo = false);
    }
  }

  Future<void> _printUserData() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final profileProvider =
          Provider.of<ProfileProvider>(context, listen: false);

      final user = authProvider.user;
      final businessFromProvider = profileProvider.businessInfo;

      final token = await UserStorageService().getToken();

      debugPrint("========= USER DATA START =========");
      debugPrint("Token: $token");
      debugPrint("User ID: ${user?.id}");
      debugPrint("Username: ${user?.userName}");
      debugPrint("Name: ${user?.masterUser?.fname}");
      debugPrint("Profile Pic: ${user?.masterUser?.profilePic}");
      debugPrint("Designation: ${user?.masterUser?.toJson()['desg']}");
      debugPrint("Mobile: ${user?.userMobile}");
      debugPrint("Email: ${user?.email}");

      // 🔥 Print from provider (might be null if not fetched)
      debugPrint("--- Business Info (from Provider) ---");
      debugPrint(
          "Company (legal_name): ${businessFromProvider?['legal_name']}");
      debugPrint("Website URL: ${businessFromProvider?['website_url']}");

      // 🔥 Print from direct API call (guaranteed fresh)
      debugPrint("--- Business Info (Direct API) ---");
      debugPrint("legal_name: ${_directBusinessInfo?['legal_name']}");
      debugPrint("gst_no: ${_directBusinessInfo?['gst_no']}");
      debugPrint("address: ${_directBusinessInfo?['address']}");
      debugPrint("website_url: ${_directBusinessInfo?['website_url']}");
      debugPrint("contact_email: ${_directBusinessInfo?['contact_email']}");
      debugPrint("upi_id: ${_directBusinessInfo?['upi_id']}");
      debugPrint("bank_acc_no: ${_directBusinessInfo?['bank_acc_no']}");
      debugPrint("ifsc_code: ${_directBusinessInfo?['ifsc_code']}");
      debugPrint("branch_name: ${_directBusinessInfo?['branch_name']}");

      debugPrint("========= USER DATA END =========");
    } catch (e) {
      debugPrint("❌ Error printing user data: $e");
    }
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

  String? _getProfilePicUrl() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user?.masterUser?.profilePic != null) {
      return '${AppConfig.apiProfileImg}/${user!.masterUser!.profilePic}';
    }
    return null;
  }

  // List<Widget> _buildDynamicDataButtons() {
  //   final auth = Provider.of<AuthProvider>(context, listen: false);

  //   final name = auth.user?.masterUser?.fname;
  //   final mobile = auth.user?.userMobile;
  //   final email = auth.user?.email;
  //   final company = _directBusinessInfo?['legal_name'];
  //   final website = _directBusinessInfo?['website_url'];

  //   final List<Map<String, String?>> items = [
  //     {"label": "Name", "value": name},
  //     {"label": "Mobile", "value": mobile},
  //     {"label": "Email", "value": email},
  //     {"label": "Company", "value": company},
  //     {"label": "Website", "value": website},
  //   ];

  //   return items
  //       .where((item) =>
  //           item["value"] != null &&
  //           item["value"]!.toString().trim().isNotEmpty)
  //       .map((item) {
  //     return Padding(
  //       padding: const EdgeInsets.only(right: 10),
  //       child: ElevatedButton(
  //         onPressed: () {
  //           setState(() {
  //             _texts.add(
  //               _TextOverlayItem(
  //                 position: const Offset(60, 60),
  //                 text: item["value"]!,
  //                 color: Colors.black, // ✅ default black
  //                 fontSize: 22,
  //               ),
  //             );
  //           });
  //         },
  //         child: Text(item["label"]!),
  //       ),
  //     );
  //   }).toList();
  // }

  List<Widget> _buildDynamicDataButtons() {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    final name = auth.user?.masterUser?.fname;
    final mobile = auth.user?.userMobile;
    final email = auth.user?.email;
    final company = _directBusinessInfo?['legal_name'];
    final website = _directBusinessInfo?['website_url'];

    final List<Map<String, dynamic>> items = [
      {"label": "Name", "value": name, "icon": Icons.person},
      {"label": "Mobile", "value": mobile, "icon": Icons.phone},
      {"label": "Email", "value": email, "icon": Icons.email},
      {"label": "Company", "value": company, "icon": Icons.business},
      {"label": "Website", "value": website, "icon": Icons.language},
    ];

    return items
        .where((item) =>
            item["value"] != null && item["value"].toString().trim().isNotEmpty)
        .map((item) {
      return _buildToolbarButton(
        item["icon"] as IconData,
        item["label"] as String,
        false, // always inactive (no highlight)
        () {
          setState(() {
            _texts.add(
              _TextOverlayItem(
                position: const Offset(60, 60),
                text: item["value"].toString(),
                color: const ui.Color.fromARGB(255, 151, 151, 151),
                fontSize: 22,
              ),
            );
          });
        },
      );
    }).toList();
  }

  Future<Map<String, dynamic>> downloadFlyerApi() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final res = await http.post(
        Uri.parse("${AppConfig.apiBaseUrl}/download-flyer"),
        headers: await _getHeaders(),
      );

      final data = jsonDecode(res.body);

      return {
        "statusCode": res.statusCode,
        "data": data,
      };
    } catch (e) {
      return {
        "statusCode": 500,
        "data": {"success": false, "message": e.toString()}
      };
    }
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
      /// 🔥 STEP 1: CALL DOWNLOAD FLYER API
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);

        final res = await http.post(
          Uri.parse("${AppConfig.apiBaseUrl}/download-flyer"),
          headers: await _getHeaders(),
        );

        final data = jsonDecode(res.body);

        /// ❌ LIMIT EXCEEDED
        if (res.statusCode == 403) {
          if (mounted) {
            TopAlert.show(
              context,
              data['message'] ?? "Feature limit exceeded",
              isError: true,
            );

            /// 👉 SUBSCRIPTION PAGE OPEN
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubscriptionPlans()),
            );
          }

          setState(() => _isSaving = false);
          return;
        }

        /// ❌ OTHER ERROR
        if (res.statusCode != 200 || data['success'] != true) {
          if (mounted) {
            TopAlert.show(
              context,
              data['message'] ?? "Something went wrong",
              isError: true,
            );
          }

          setState(() => _isSaving = false);
          return;
        }

        /// ✅ SUCCESS → continue saving flyer
      } catch (apiError) {
        if (mounted) {
          TopAlert.show(
            context,
            "API Error: $apiError",
            isError: true,
          );
        }
        setState(() => _isSaving = false);
        return;
      }

      /// 🔥 EXISTING CODE (UNCHANGED)
      if (!kIsWeb) {
        final status = await Permission.storage.request();
        if (status.isDenied) {
          if (mounted)
            TopAlert.show(context, "Storage permission required",
                isError: true);
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
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File(
            '${tempDir.path}/flyer_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(bytes);
        await Gal.putImage(file.path);
      }

      if (mounted)
        TopAlert.show(context, "✅ Flyer saved to gallery!", isSuccess: true);
    } catch (e) {
      if (mounted)
        TopAlert.show(context, "Failed to save flyer: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addTextDialog() {
    String value = "";

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Enter Text"),
          content: TextField(
            onChanged: (val) => value = val,
            decoration: const InputDecoration(hintText: "Type here..."),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                if (value.trim().isNotEmpty) {
                  setState(() {
                    _texts.add(
                      _TextOverlayItem(
                        position: const Offset(50, 50),
                        text: value,
                      ),
                    );
                  });
                }
                Navigator.pop(ctx);
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  void _addShapeDialog() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Select Shape",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                children: [
                  _shapeOption("rect"),
                  _shapeOption("circle"),
                  _shapeOption("triangle"),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _shapeOption(String type) {
    return GestureDetector(
      onTap: () {
        setState(() {
          // _shapes.add(
          //   _ShapeOverlayItem(
          //     position: const Offset(80, 80),
          //     shape: type,
          //   ),
          // );

          _shapes.add(
            _ShapeOverlayItem(
              position: const Offset(80, 80),
              shape: type,
              width: 120,
              height: 120,
            ),
          );
        });
        Navigator.pop(context);
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: type == "circle"
              ? BorderRadius.circular(30)
              : BorderRadius.circular(8),
        ),
        child: Center(child: Text(type)),
      ),
    );
  }

  Widget _circleBtn(IconData icon, Color color) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Icon(icon, size: 16, color: Colors.white),
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5, // 🔥 half screen
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) {
            return StatefulBuilder(
              builder: (ctx, setSheetState) {
                final colorScheme = Theme.of(context).colorScheme;

                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: SingleChildScrollView(
                    controller: controller, // 🔥 scroll control
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        /// 🔘 DRAG HANDLE
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: colorScheme.onSurface.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),

                        /// 🔷 TITLE
                        Text(
                          "Overlay Settings",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),

                        const SizedBox(height: 20),

                        /// ================= INFO BAR =================
                        if (_infoBarOverlay.visible) ...[
                          _buildSectionHeader("Info Bar Styles", colorScheme),
                          SwitchListTile(
                            title: const Text("Transparent Background"),
                            value: _isBarTransparent,
                            onChanged: (val) {
                              setSheetState(() {});
                              setState(() => _isBarTransparent = val);
                            },
                          ),
                          _buildSectionTitle("Bar Width", colorScheme),
                          _buildSizeSlider(
                            _infoBarOverlay.size,
                            150,
                            450,
                            (val) {
                              setSheetState(() {});
                              setState(() => _infoBarOverlay.size = val);
                            },
                          ),
                          _buildSectionTitle("Font Size", colorScheme),
                          _buildSizeSlider(_barFontSize, 8, 24, (val) {
                            setSheetState(() {});
                            setState(() => _barFontSize = val);
                          }),
                          _buildSectionTitle("Background Color", colorScheme),
                          _buildColorPicker(_barBgColor, (c) {
                            setSheetState(() {});
                            setState(() => _barBgColor = c);
                          }),
                          _buildSectionTitle("Text Color", colorScheme),
                          _buildColorPicker(_barTextColor, (c) {
                            setSheetState(() {});
                            setState(() => _barTextColor = c);
                          }),
                          const Divider(height: 32),
                        ],

                        /// ================= PROFILE =================
                        if (_profileOverlay.visible) ...[
                          _buildSectionHeader("Profile Settings", colorScheme),
                          _buildSectionTitle("Size", colorScheme),
                          _buildSizeSlider(
                            _profileOverlay.size,
                            40,
                            200,
                            (val) {
                              setSheetState(() {});
                              setState(() => _profileOverlay.size = val);
                            },
                          ),
                          _buildSectionTitle("Border Color", colorScheme),
                          _buildColorPicker(_borderColor, (c) {
                            setSheetState(() {});
                            setState(() => _borderColor = c);
                          }),
                          _buildSectionTitle("Opacity", colorScheme),
                          _buildSizeSlider(
                            _profileOverlay.opacity,
                            0.1,
                            1.0,
                            (val) {
                              setSheetState(() {});
                              setState(() => _profileOverlay.opacity = val);
                            },
                          ),
                          const Divider(height: 32),
                        ],

                        /// ================= QR =================
                        if (_onlineQrOverlay.visible ||
                            _offlineQrOverlay.visible) ...[
                          _buildSectionHeader("QR Settings", colorScheme),
                          if (_onlineQrOverlay.visible) ...[
                            _buildSectionTitle("Online QR Size", colorScheme),
                            _buildSizeSlider(
                              _onlineQrOverlay.size,
                              50,
                              200,
                              (val) {
                                setSheetState(() {});
                                setState(() => _onlineQrOverlay.size = val);
                              },
                            ),
                          ],
                          if (_offlineQrOverlay.visible) ...[
                            _buildSectionTitle("Offline QR Size", colorScheme),
                            _buildSizeSlider(
                              _offlineQrOverlay.size,
                              50,
                              200,
                              (val) {
                                setSheetState(() {});
                                setState(() => _offlineQrOverlay.size = val);
                              },
                            ),
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
      },
    );
  }

  Widget _buildSectionHeader(String title, ColorScheme colorScheme) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(title,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary)));
  }

  Widget _buildSectionTitle(String title, ColorScheme colorScheme) {
    return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(title,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withValues(alpha: 0.7)))));
  }

  Widget _buildSizeSlider(
      double val, double min, double max, ValueChanged<double> onChanged) {
    return Slider(value: val, min: min, max: max, onChanged: onChanged);
  }

  Widget _buildColorPicker(Color current, ValueChanged<Color> onSelected) {
    final colors = [
      Colors.white,
      Colors.black,
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.amber,
      Colors.purple,
      Colors.teal,
      Colors.grey
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: colors
            .map((c) => GestureDetector(
                  onTap: () => onSelected(c),
                  child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: current == c
                                  ? Colors.blueAccent
                                  : Colors.grey.shade400,
                              width: current == c ? 3 : 1))),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildDraggableOverlay({
    required _OverlayItem item,
    required Widget child,
    required BoxConstraints constraints,
    required VoidCallback onDoubleTap,
  }) {
    Offset? startPosition;
    double? startRotation;
    double? startSize;
    double? startWidth;
    double? startHeight;

    return Positioned(
      left: item.position.dx,
      top: item.position.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,

        /// 👉 SELECT ITEM
        onTap: () {
          setState(() {
            _selectedItem = item;
          });
        },

        /// 👉 DRAG START
        onPanStart: (details) {
          startPosition = item.position;
        },

        /// 👉 DRAG MOVE (ONLY MOVE, NOT SCALE)
        onPanUpdate: (details) {
          setState(() {
            item.position = Offset(
              (item.position.dx + details.delta.dx)
                  .clamp(0, constraints.maxWidth - 40),
              (item.position.dy + details.delta.dy)
                  .clamp(0, constraints.maxHeight - 40),
            );
          });
        },

        /// 👉 DOUBLE TAP (OPEN EDIT)
        onDoubleTap: onDoubleTap,

        child: Stack(
          clipBehavior: Clip.none,
          children: [
            /// 🔷 MAIN CONTENT
            Container(
              decoration: BoxDecoration(
                border: _selectedItem == item
                    ? Border.all(color: Colors.blue, width: 2)
                    : null,
              ),
              child: Transform.rotate(
                angle: item.rotation,
                child: Opacity(
                  opacity: item.opacity,
                  child: child,
                ),
              ),
            ),

            /// 🔥 CONTROLS (ONLY WHEN SELECTED)
            if (_selectedItem == item) ...[
              /// ❌ DELETE
              Positioned(
                top: -12,
                right: -12,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      if (item is _TextOverlayItem) {
                        _texts.remove(item);
                      } else if (item is _ShapeOverlayItem) {
                        _shapes.remove(item);
                      } else {
                        item.visible = false;
                      }
                    });
                  },
                  child: _circleBtn(Icons.close, Colors.red),
                ),
              ),

              /// 🔄 ROTATE (FIXED FOR MOBILE)
              Positioned(
                bottom: -14,
                right: -14,
                // child: GestureDetector(
                //   onPanStart: (_) {
                //     startRotation = item.rotation;
                //   },
                //   onPanUpdate: (details) {
                //     setState(() {
                //       item.rotation = (item.rotation + details.delta.dx * 0.01);
                //     });
                //   },
                //   child: _circleBtn(Icons.rotate_right, Colors.orange),
                // ),

                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanStart: (_) {
                    startRotation = item.rotation;
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      item.rotation += details.delta.dx * 0.01;
                    });
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    child: _circleBtn(Icons.rotate_right, Colors.orange),
                  ),
                ),
              ),

              /// 🔲 RESIZE (FIXED FOR MOBILE)
              Positioned(
                bottom: -14,
                left: -14,
                // child: GestureDetector(
                //   onPanStart: (_) {
                //     startSize = item.size;

                //     if (item is _ShapeOverlayItem) {
                //       startWidth = item.width;
                //       startHeight = item.height;
                //     }
                //   },
                //   onPanUpdate: (details) {
                //     setState(() {
                //       if (item is _ShapeOverlayItem) {
                //         item.width =
                //             (item.width + details.delta.dx).clamp(40.0, 600.0);
                //         item.height =
                //             (item.height + details.delta.dy).clamp(40.0, 600.0);
                //       } else {
                //         item.size =
                //             (item.size + details.delta.dx).clamp(40.0, 600.0);
                //       }
                //     });
                //   },
                //   child: _circleBtn(Icons.open_in_full, Colors.blue),
                // ),

                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanStart: (_) {
                    startSize = item.size;
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      if (item is _ShapeOverlayItem) {
                        item.width =
                            (item.width + details.delta.dx).clamp(40.0, 600.0);
                        item.height =
                            (item.height + details.delta.dy).clamp(40.0, 600.0);
                      } else {
                        item.size =
                            (item.size + details.delta.dx).clamp(40.0, 600.0);
                      }
                    });
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    child: _circleBtn(Icons.open_in_full, Colors.blue),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAdjustModal(_OverlayItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Adjust Overlay",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  /// 🔵 SIZE
                  Text("Size: ${item.size.toInt()} px"),
                  Slider(
                    value: item.size,
                    min: 40,
                    max: 450,
                    onChanged: (val) {
                      setSheetState(() => item.size = val);
                      setState(() {});
                    },
                  ),

                  /// 🔵 ROTATION
                  Text("Rotation: ${(item.rotation * 180 / pi).toInt()}°"),
                  Slider(
                    value: item.rotation,
                    min: 0,
                    max: 2 * pi,
                    onChanged: (val) {
                      setSheetState(() => item.rotation = val);
                      setState(() {});
                    },
                  ),

                  /// 🔥 NEW: OPACITY
                  Text("Opacity: ${(item.opacity * 100).toInt()}%"),
                  Slider(
                    value: item.opacity,
                    min: 0.1,
                    max: 1.0,
                    onChanged: (val) {
                      setSheetState(() => item.opacity = val);
                      setState(() {});
                    },
                  ),

                  /// HEIGHT
                  Text("Height: ${item.height.toInt()} px"),
                  Slider(
                    value: item.height,
                    min: 60,
                    max: 300,
                    onChanged: (val) {
                      setSheetState(() => item.height = val);
                      setState(() {});
                    },
                  ),

                  const SizedBox(height: 20),

                  /// ❌ REMOVE
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        item.visible = false;
                      });
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Remove"),
                  ),

                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Close"),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showTextEditModal(_TextOverlayItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: DraggableScrollableSheet(
                initialChildSize: 0.6,
                minChildSize: 0.4,
                maxChildSize: 0.9,
                expand: false,
                builder: (_, controller) {
                  return SingleChildScrollView(
                    controller: controller,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade400,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),

                        const Text(
                          "Edit Text",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 16),

                        /// 🔠 FONT SIZE
                        Text("Font Size: ${item.fontSize.toInt()}"),
                        Slider(
                          value: item.fontSize,
                          min: 10,
                          max: 60,
                          onChanged: (val) {
                            setSheetState(() => item.fontSize = val);
                            setState(() {});
                          },
                        ),

                        const SizedBox(height: 12),

                        /// 🔄 ROTATION
                        Text(
                            "Rotation: ${(item.rotation * 180 / pi).toInt()}°"),
                        Slider(
                          value: item.rotation,
                          min: 0,
                          max: 2 * pi,
                          onChanged: (val) {
                            setSheetState(() => item.rotation = val);
                            setState(() {});
                          },
                        ),

                        const SizedBox(height: 16),

                        /// 🎨 COLOR PICKER
                        const Text(
                          "Text Color",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Colors.white,
                            Colors.black,
                            Colors.red,
                            Colors.blue,
                            Colors.green,
                            Colors.yellow,
                            Colors.orange,
                            Colors.purple,
                            Colors.teal,
                            Colors.pink,
                            Colors.brown,
                            Colors.grey,
                          ].map((color) {
                            return GestureDetector(
                              onTap: () {
                                setSheetState(() => item.color = color);
                                setState(() {});
                              },
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: item.color == color
                                        ? Colors.blue
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 16),

                        Text("Opacity: ${(item.opacity * 100).toInt()}%"),
                        Slider(
                          value: item.opacity,
                          min: 0.1,
                          max: 1.0,
                          onChanged: (val) {
                            setSheetState(() => item.opacity = val);
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 20),

                        /// ❌ DELETE BUTTON
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _texts.remove(item);
                              });
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("Delete Text"),
                          ),
                        ),

                        const SizedBox(height: 10),

                        /// ✅ CLOSE BUTTON
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Close"),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  void _showShapeEditModal(_ShapeOverlayItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 🔥 IMPORTANT
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, controller) {
                return SingleChildScrollView(
                  controller: controller,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 20,
                      bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// drag handle
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade400,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),

                        const Text("Edit Shape",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),

                        const SizedBox(height: 16),

                        /// WIDTH
                        Text("Width: ${item.width.toInt()}"),
                        Slider(
                          value: item.width,
                          min: 40,
                          max: 600,
                          onChanged: (val) {
                            setSheetState(() => item.width = val);
                            setState(() {});
                          },
                        ),

                        /// HEIGHT
                        Text("Height: ${item.height.toInt()}"),
                        Slider(
                          value: item.height,
                          min: 40,
                          max: 400,
                          onChanged: (val) {
                            setSheetState(() => item.height = val);
                            setState(() {});
                          },
                        ),

                        /// ROTATION
                        Text(
                            "Rotation: ${(item.rotation * 180 / pi).toInt()}°"),
                        Slider(
                          value: item.rotation,
                          min: 0,
                          max: 2 * pi,
                          onChanged: (val) {
                            setSheetState(() => item.rotation = val);
                            setState(() {});
                          },
                        ),

                        const SizedBox(height: 16),

                        /// COLOR
                        const Text("Color",
                            style: TextStyle(fontWeight: FontWeight.w600)),

                        const SizedBox(height: 10),

                        Wrap(
                          spacing: 10,
                          children: [
                            Colors.black,
                            Colors.red,
                            Colors.blue,
                            Colors.green,
                            Colors.yellow,
                            Colors.white,
                          ].map((c) {
                            return GestureDetector(
                              onTap: () {
                                setSheetState(() => item.color = c);
                                setState(() {});
                              },
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: item.color == c
                                        ? Colors.blue
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 16),

                        /// 🔥 OPACITY
                        Text("Opacity: ${(item.opacity * 100).toInt()}%"),
                        Slider(
                          value: item.opacity,
                          min: 0.1,
                          max: 1.0,
                          onChanged: (val) {
                            setSheetState(() => item.opacity = val);
                            setState(() {});
                          },
                        ),

                        const SizedBox(height: 20),

                        /// DELETE
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() => _shapes.remove(item));
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("Delete"),
                          ),
                        ),

                        const SizedBox(height: 10),

                        /// CLOSE
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Close"),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildInfoBar(AuthProvider auth, ProfileProvider profile) {
    final user = auth.user;

    final fname = user?.masterUser?.fname ?? '';
    final mobile = user?.userMobile ?? '';
    final email = user?.email ?? '';

    final businessName = _directBusinessInfo?['legal_name'] ?? '';

    /// 🔥 FONT SIZES
    const double nameSize = 16; // biggest
    const double infoSize = 12; // same for all below

    return Opacity(
      opacity: _infoBarOverlay.opacity,
      child: Container(
        width: _infoBarOverlay.size,
        height: _infoBarOverlay.height,
        padding: const EdgeInsets.all(12),
        // decoration: BoxDecoration(
        //   // color: Colors.grey.withValues(alpha: 0.9),
        //   borderRadius: BorderRadius.circular(10),
        // ),
        // decoration: BoxDecoration(
        //   color: _barBgColor.withValues(alpha: _barOpacity),
        //   borderRadius: BorderRadius.circular(10),
        // ),
        decoration: _isBarTransparent
            ? null
            : BoxDecoration(
                color: _barBgColor.withValues(alpha: _barOpacity),
                borderRadius: BorderRadius.circular(10),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween, // 🔥 spacing fix
          children: [
            /// 👤 NAME (BIGGEST)
            Text(
              fname,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _barTextColor,
                fontWeight: FontWeight.bold,
                fontSize: nameSize,
              ),
            ),

            /// 🏢 BUSINESS
            _buildFixedRow(businessName, infoSize),

            /// 📱 MOBILE (CONTACT removed → yahan show hoga)
            _buildFixedRow(mobile, infoSize),

            /// 📧 EMAIL
            _buildFixedRow(email, infoSize),
          ],
        ),
      ),
    );
  }

  Widget _buildFixedRow(String text, double fontSize) {
    return SizedBox(
      height: 18, // 🔥 fixed height → spacing always same
      child: text.isNotEmpty
          ? Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _barTextColor,
                fontSize: fontSize,
              ),
            )
          : const SizedBox(), // empty but space reserved
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(icon,
              size: _barFontSize, color: _barTextColor.withValues(alpha: 0.6)),
          const SizedBox(width: 6),
          Expanded(
              child: Text(text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(color: _barTextColor, fontSize: _barFontSize))),
        ],
      ),
    );
  }

  Widget _buildShape(_ShapeOverlayItem item) {
    final colorWithOpacity = item.color.withValues(alpha: item.opacity); // 🔥

    switch (item.shape) {
      case "circle":
        return Container(
          width: item.width,
          height: item.height,
          decoration: BoxDecoration(
            color: colorWithOpacity,
            shape: BoxShape.circle,
          ),
        );

      case "triangle":
        return CustomPaint(
          size: Size(item.width, item.height),
          painter: TrianglePainter(colorWithOpacity), // 🔥
        );

      default:
        return Container(
          width: item.width,
          height: item.height,
          decoration: BoxDecoration(
            color: colorWithOpacity,
            borderRadius: BorderRadius.circular(8),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final profile = Provider.of<ProfileProvider>(context);
    final profileUrl = _getProfilePicUrl();
    final hasOverlay = _profileOverlay.visible ||
        _onlineQrOverlay.visible ||
        _offlineQrOverlay.visible ||
        _infoBarOverlay.visible;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text("Edit Flyer"),
          centerTitle: true,
          leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context)),
          actions: [
            if (hasOverlay)
              IconButton(
                  icon: const Icon(Icons.tune), onPressed: _showSettingsSheet)
          ]),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: !_imageLoaded
                  ? const CircularProgressIndicator()
                  : RepaintBoundary(
                      key: _captureKey,
                      child: LayoutBuilder(builder: (context, constraints) {
                        return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedItem =
                                    null; // deselect when tapping outside
                              });
                            },
                            child: Stack(children: [
                              Image.network(widget.imageUrl,
                                  fit: BoxFit.contain,
                                  width: constraints.maxWidth,
                                  height: constraints.maxHeight),
                              ..._shapes.map((item) {
                                return _buildDraggableOverlay(
                                  item: item,
                                  constraints: constraints,
                                  onDoubleTap: () => _showShapeEditModal(item),
                                  child: _buildShape(item),
                                );
                              }).toList(),
                              if (_infoBarOverlay.visible)
                                _buildDraggableOverlay(
                                    item: _infoBarOverlay,
                                    constraints: constraints,
                                    onDoubleTap: () =>
                                        _showAdjustModal(_infoBarOverlay),
                                    child: _buildInfoBar(auth, profile)),
                              if (_profileOverlay.visible && profileUrl != null)
                                _buildDraggableOverlay(
                                    item: _profileOverlay,
                                    constraints: constraints,
                                    onDoubleTap: () =>
                                        _showAdjustModal(_profileOverlay),
                                    child: Container(
                                      width: _profileOverlay.size,
                                      height: _profileOverlay.size,
                                      decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: _borderColor,
                                              width: _borderWidth),
                                          boxShadow: [
                                            BoxShadow(
                                                color: Colors.black26,
                                                blurRadius: 10)
                                          ]),
                                      child: Opacity(
                                        opacity:
                                            _profileOverlay.opacity, // 👈 APPLY
                                        child: ClipOval(
                                          child: Image.network(profileUrl,
                                              fit: BoxFit.cover),
                                        ),
                                      ),
                                    )),
                              if (_onlineQrOverlay.visible)
                                _buildDraggableOverlay(
                                    item: _onlineQrOverlay,
                                    constraints: constraints,
                                    onDoubleTap: () =>
                                        _showAdjustModal(_onlineQrOverlay),
                                    child: _buildQrWidget(
                                        _generateOnlineQrData(),
                                        _onlineQrOverlay.size,
                                        "Connect")),
                              if (_offlineQrOverlay.visible)
                                _buildDraggableOverlay(
                                    item: _offlineQrOverlay,
                                    constraints: constraints,
                                    onDoubleTap: () =>
                                        _showAdjustModal(_offlineQrOverlay),
                                    child: _buildQrWidget(
                                        _generateOfflineQrData(),
                                        _offlineQrOverlay.size,
                                        "Contact")),
                              ..._texts.map((item) {
                                return _buildDraggableOverlay(
                                  item: item,
                                  constraints: constraints,
                                  onDoubleTap: () => _showTextEditModal(item),
                                  child: Text(
                                    item.text,
                                    style: TextStyle(
                                      color: item.color.withValues(
                                          alpha:
                                              item.opacity), // 🔥 APPLY OPACITY
                                      fontSize: item.fontSize,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ]));
                      }),
                    ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.black,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // _buildToolbarButton(
                  //     Icons.badge,
                  //     "Details Bar",
                  //     _infoBarOverlay.visible,
                  //     () => setState(() =>
                  //         _infoBarOverlay.visible = !_infoBarOverlay.visible)),

                  _buildToolbarButton(
                    Icons.badge,
                    "Details Bar",
                    _infoBarOverlay.visible,
                    () {
                      setState(() {
                        _infoBarOverlay.visible = !_infoBarOverlay.visible;

                        if (_infoBarOverlay.visible) {
                          _infoBarOverlay.position = const Offset(40, 250);
                          _infoBarOverlay.size = 280; // width control
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 10),

                  _buildToolbarButton(
                      Icons.account_circle,
                      "Profile",
                      _profileOverlay.visible,
                      () => setState(() =>
                          _profileOverlay.visible = !_profileOverlay.visible)),
                  const SizedBox(width: 10),
                  _buildToolbarButton(
                      Icons.qr_code,
                      "Online QR",
                      _onlineQrOverlay.visible,
                      () => setState(() => _onlineQrOverlay.visible =
                          !_onlineQrOverlay.visible)),
                  const SizedBox(width: 10),
                  _buildToolbarButton(
                      Icons.qr_code_2,
                      "Offline QR",
                      _offlineQrOverlay.visible,
                      () => setState(() => _offlineQrOverlay.visible =
                          !_offlineQrOverlay.visible)),
                  const SizedBox(width: 10),
                  _buildToolbarButton(
                    Icons.text_fields,
                    "Text",
                    false,
                    _addTextDialog,
                  ),
                  const SizedBox(width: 10),
                  _buildToolbarButton(
                    Icons.category,
                    "Shape",
                    false,
                    _addShapeDialog,
                  ),
                  const SizedBox(width: 10),
                  // ..._buildDynamicDataButtons(),
                  ..._buildDynamicDataButtons()
                      .expand((widget) => [widget, const SizedBox(width: 10)])
                      .toList(),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveFlyer,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_alt),
                    label: Text(_isSaving ? "Saving..." : "Save Flyer"),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14)))),
          ),
        ],
      ),
    );
  }

  Widget _buildQrWidget(String data, double size, String label) {
    return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_qrBorderRadius),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)]),
        child: Padding(
            padding: const EdgeInsets.all(3),
            child: Column(children: [
              Expanded(
                  child: QrImageView(
                data: data,
                version: QrVersions.auto,
                padding: EdgeInsets.zero,
              )),
              // Text(label,
              //     style: TextStyle(
              //         fontSize: size * 0.08,
              //         fontWeight: FontWeight.bold,
              //         color: Colors.black))
            ])));
  }

  Widget _buildToolbarButton(
      IconData icon, String label, bool active, VoidCallback onTap) {
    return GestureDetector(
        onTap: onTap,
        child: Column(children: [
          Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: active
                      ? Colors.blueAccent.withValues(alpha: 0.2)
                      : Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: active ? Colors.blueAccent : Colors.white24)),
              child: Icon(icon,
                  color: active ? Colors.blueAccent : Colors.white60)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: active ? Colors.blueAccent : Colors.white54,
                  fontSize: 10))
        ]));
  }
}

class TrianglePainter extends CustomPainter {
  final Color color;
  TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;

    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
