import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:provider/provider.dart';
import 'package:gridcard/core/services/leads_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:gridcard/routes/route_names.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:flutter/services.dart';
import 'package:gridcard/features/business_card_scan/presentation/widgets/send_intro_sheet.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:gridcard/widgets/top_alert.dart';
import 'package:gridcard/core/services/auth_provider.dart';
import 'package:gridcard/core/utils/error_formatter.dart';


class LeadScanner2 extends StatefulWidget {
  final Function(Map<String, dynamic>)? onDataExtracted;
  final bool autoOpenCamera;

  const LeadScanner2({
    super.key,
    this.onDataExtracted,
    this.autoOpenCamera = false,
  });

  @override
  State<LeadScanner2> createState() => _LeadScanner2State();
}

class _LeadScanner2State extends State<LeadScanner2> {
  XFile? _capturedImage;
  bool _isCapturedMode = false;
  bool _isLoading = false;
  String _errorMessage = '';
  Map<String, dynamic>? _extractedData;
  static const double _frameAspectRatio = 1.58;
  bool _didAutoOpen = false;

  static const String _baseUrl = AppConfig.apiBaseUrl;
  final String apiUrl = "$_baseUrl/gpt-ocr";

  @override
  void initState() {
    super.initState();
    if (widget.autoOpenCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || _didAutoOpen) return;
        _didAutoOpen = true;
        await _captureImage();
      });
    }
  }

  Future<void> _captureImage() async {
    final XFile? file =
        await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 90);
    if (file == null) {
      _handleCancelledAutoOpenFlow();
      return;
    }
    final XFile? cropped = await _openCropper(file);
    if (cropped == null) {
      _handleCancelledAutoOpenFlow();
      return;
    }
    final XFile normalized = await _normalizeCapturedImage(cropped);

    setState(() {
      _capturedImage = normalized;
      _isCapturedMode = true;
      _extractedData = null;
    });
  }

  Future<void> _pickFromGallery() async {
    final XFile? img =
        await ImagePicker().pickImage(source: ImageSource.gallery);

    if (img != null) {
      final XFile? cropped = await _openCropper(img);
      if (cropped == null) return;
      final XFile normalized = await _normalizeCapturedImage(cropped);
      setState(() {
        _capturedImage = normalized;
        _isCapturedMode = true;
        _extractedData = null;
      });
    }
  }

  void _handleCancelledAutoOpenFlow() {
    if (!mounted) return;
    // If scanner was opened only to auto-launch camera, cancel should return
    // user to previous screen instead of leaving scanner in history.
    if (widget.autoOpenCamera && !_isCapturedMode && _capturedImage == null) {
      Navigator.maybePop(context);
    }
  }

  Future<void> _submitImage() async {
    if (_capturedImage == null) return;

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
        _extractedData = null;
      });

      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.headers['Accept'] = 'application/json';
      final bytes = await _capturedImage!.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: _capturedImage!.name,
        ),
      );

      final response = await request.send();
      final resStr = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final json = jsonDecode(resStr);

        if (json['success'] == true && json['data'] != null) {
          final apiData = json['data'] as Map<String, dynamic>;

          final mappedData = <String, dynamic>{
            if (apiData['name'] != null) 'name': apiData['name'],
            if (apiData['company_name'] != null)
              'company_name': apiData['company_name'],
            if (apiData['email'] != null) 'email1': apiData['email'],
            if (apiData['email2'] != null) 'email2': apiData['email2'],
            if (apiData['website'] != null) 'website': apiData['website'],
            if (apiData['address'] != null) 'address': apiData['address'],
            if (apiData['mobile_no_1'] != null)
              'mobile1': apiData['mobile_no_1'],
            if (apiData['mobile_no_2'] != null)
              'mobile2': apiData['mobile_no_2'],
            if (apiData['mobile_no_3'] != null)
              'mobile3': apiData['mobile_no_3'],
          };

          setState(() {
            _extractedData = mappedData;
          });

          _showExtractedDataModal();
        } else {
          setState(() {
            _errorMessage =
                json['message'] ?? 'No data could be extracted from the image';
          });
        }
      } else {
        throw Exception('OCR failed: ${response.statusCode} - $resStr');
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showExtractedDataModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            child: ExtractedDataModal(
              capturedImage: _capturedImage!,
              extractedData: _extractedData!,
              onSave: (data) {
                if (widget.onDataExtracted != null) {
                  widget.onDataExtracted!(data);
                }
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              onCancel: () {
                Navigator.of(context).pop();
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _buildPreviewBox() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    if (_isCapturedMode && _capturedImage != null) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: colors.primary, width: 2),
          borderRadius: BorderRadius.circular(12),
          color: colors.surfaceContainerHighest.withValues(alpha: 0.2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: AspectRatio(
            aspectRatio: _frameAspectRatio,
            child: kIsWeb
                ? Image.network(
                    _capturedImage!.path,
                    fit: BoxFit.cover,
                  )
                : Image.file(
                    File(_capturedImage!.path),
                    fit: BoxFit.cover,
                  ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: colors.primary, width: 2),
        borderRadius: BorderRadius.circular(12),
        color: colors.surfaceContainerHighest.withValues(alpha: 0.2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AspectRatio(
          aspectRatio: _frameAspectRatio,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.document_scanner_outlined, size: 42, color: colors.onSurfaceVariant),
                const SizedBox(height: 8),
                Text(
                  'Tap capture to open native camera',
                  style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<XFile> _normalizeCapturedImage(XFile imageFile) async {
    try {
      final originalBytes = await imageFile.readAsBytes();
      final decoded = img.decodeImage(originalBytes);
      if (decoded == null) return imageFile;

      final fixedOrientation = img.bakeOrientation(decoded);
      final sourceW = fixedOrientation.width;
      final sourceH = fixedOrientation.height;
      final sourceRatio = sourceW / sourceH;
      const targetRatio = _frameAspectRatio;

      int cropW = sourceW;
      int cropH = sourceH;
      int offsetX = 0;
      int offsetY = 0;

      if (sourceRatio > targetRatio) {
        cropW = (sourceH * targetRatio).round();
        offsetX = ((sourceW - cropW) / 2).round();
      } else if (sourceRatio < targetRatio) {
        cropH = (sourceW / targetRatio).round();
        offsetY = ((sourceH - cropH) / 2).round();
      }

      final cropped = img.copyCrop(
        fixedOrientation,
        x: offsetX,
        y: offsetY,
        width: cropW,
        height: cropH,
      );
      final outputBytes = Uint8List.fromList(img.encodeJpg(cropped, quality: 90));

      if (kIsWeb) {
        return XFile.fromData(
          outputBytes,
          name: imageFile.name,
          mimeType: 'image/jpeg',
        );
      }

      final dir = await getTemporaryDirectory();
      final outPath = '${dir.path}/leadscanner2_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final outFile = File(outPath);
      await outFile.writeAsBytes(outputBytes, flush: true);
      return XFile(outPath);
    } catch (_) {
      return imageFile;
    }
  }

  Future<XFile?> _openCropper(XFile image) {
    return Navigator.push<XFile>(
      context,
      MaterialPageRoute(
        builder: (_) => _LeadImageCropPage(
          imageFile: image,
          aspectRatio: _frameAspectRatio,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: const Text('Scan Card'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _isCapturedMode
                  ? 'Review crop and confirm to scan OCR'
                  : 'Capture a clear business card image',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(child: Center(child: _buildPreviewBox())),
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                _errorMessage,
                style: TextStyle(color: colors.error, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: CircularProgressIndicator(color: colors.primary),
            ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child:
                _isCapturedMode ? _buildActionButtons() : _buildCameraButtons(),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _circleButton(Icons.photo_library_outlined, _pickFromGallery),
        _captureButton(),
        const SizedBox(width: 56, height: 56),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _circleButton(Icons.arrow_back, () => Navigator.pop(context)),
        _circleButton(Icons.crop, () async {
          if (_capturedImage == null) return;
          final cropped = await _openCropper(_capturedImage!);
          if (cropped == null) return;
          final normalized = await _normalizeCapturedImage(cropped);
          if (!mounted) return;
          setState(() => _capturedImage = normalized);
        }),
        _circleButton(Icons.check, _submitImage, filled: true),
      ],
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap, {bool filled = false}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? colors.primary : colors.surfaceContainerHighest,
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Icon(icon, color: filled ? colors.onPrimary : colors.onSurface),
      ),
    );
  }

  Widget _captureButton() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return InkWell(
      onTap: _captureImage,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colors.primary, width: 4),
          color: colors.surface,
        ),
        child: Center(
          child: Icon(Icons.camera_alt, color: colors.primary),
        ),
      ),
    );
  }
}

class _LeadImageCropPage extends StatefulWidget {
  final XFile imageFile;
  final double aspectRatio;

  const _LeadImageCropPage({
    required this.imageFile,
    required this.aspectRatio,
  });

  @override
  State<_LeadImageCropPage> createState() => _LeadImageCropPageState();
}

class _LeadImageCropPageState extends State<_LeadImageCropPage> {
  final CropController _controller = CropController();
  Uint8List? _imageBytes;
  bool _isCropping = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final bytes = await widget.imageFile.readAsBytes();
    if (!mounted) return;
    setState(() => _imageBytes = bytes);
  }

  Future<void> _finishCrop(Uint8List croppedData) async {
    if (_isCropping) return;
    if (mounted) setState(() => _isCropping = true);
    if (kIsWeb) {
      Navigator.pop(
        context,
        XFile.fromData(
          croppedData,
          name: 'lead_crop_${DateTime.now().millisecondsSinceEpoch}.jpg',
          mimeType: 'image/jpeg',
        ),
      );
      return;
    }
    final dir = await getTemporaryDirectory();
    final outPath = '${dir.path}/lead_crop_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outFile = File(outPath);
    await outFile.writeAsBytes(croppedData, flush: true);
    if (!mounted) return;
    Navigator.pop(context, XFile(outFile.path));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    if (_imageBytes == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: colors.primary)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Adjust Card Crop'),
        actions: [
          IconButton(
            onPressed: _isCropping ? null : () => _controller.crop(),
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: Stack(
        children: [
          Crop(
            controller: _controller,
            image: _imageBytes!,
            aspectRatio: widget.aspectRatio,
            initialSize: 0.95,
            withCircleUi: false,
            onCropped: (croppedData) async {
              await _finishCrop(croppedData);
            },
          ),
          if (_isCropping)
            Positioned.fill(
              child: Container(
                color: colors.scrim.withValues(alpha: 0.55),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: colors.primary),
                      const SizedBox(height: 12),
                      Text(
                        'Cropping image...',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ======================= MODAL =======================

class ExtractedDataModal extends StatefulWidget {
  final XFile capturedImage;
  final Map<String, dynamic> extractedData;
  final Function(Map<String, dynamic>) onSave;
  final VoidCallback onCancel;

  const ExtractedDataModal({
    super.key,
    required this.capturedImage,
    required this.extractedData,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<ExtractedDataModal> createState() => _ExtractedDataModalState();
}

class _ExtractedDataModalState extends State<ExtractedDataModal> {
  final nameCtrl = TextEditingController();
  final companyCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final email2Ctrl = TextEditingController();
  final websiteCtrl = TextEditingController();
  final addressCtrl = TextEditingController();

  List<dynamic> _categories = [];
  // String? _selectedCategory;
  int? _selectedCategoryId;
  bool _isCategoryLoading = false;

  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _fetchCategories() async {
    try {
      setState(() => _isCategoryLoading = true);

      final userId = await UserStorageService().getUserId();
      if (userId == null) return;

      final response = await http.get(
        Uri.parse("${AppConfig.apiBaseUrl}/lead-category-user/$userId"),
        headers: await _getHeaders(),
      );

      final json = jsonDecode(response.body);

      if (json["status"] == true) {
        setState(() {
          _categories = json["data"];
        });

        if (_selectedCategoryId == null && _categories.isNotEmpty) {
          // Optional: auto select first category
        }
      }
    } catch (e) {
      debugPrint("Category Fetch Error: $e");
    } finally {
      setState(() => _isCategoryLoading = false);
    }
  }

  void _showAddCategoryModal() {
    final TextEditingController newCategoryCtrl = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Add Category",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: newCategoryCtrl,
                      decoration: const InputDecoration(
                        labelText: "Category Name",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        setModalState(() {});
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Cancel"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: newCategoryCtrl.text.trim().isEmpty ||
                                    isLoading
                                ? null
                                : () async {
                                    setModalState(() => isLoading = true);

                                    try {
                                      final userId = await UserStorageService()
                                          .getUserId();

                                      if (userId == null) {
                                        Navigator.pop(context);
                                        TopAlert.show(context,
                                            "User not found. Login again",
                                            isError: true);
                                        return;
                                      }

                                      final response = await http.post(
                                        Uri.parse(
                                            "${AppConfig.apiBaseUrl}/lead-category-create"),
                                        headers: await _getHeaders(),
                                        body: jsonEncode({
                                          "user_id": userId,
                                          "category":
                                              newCategoryCtrl.text.trim(),
                                        }),
                                      );

                                      final data = jsonDecode(response.body);

                                      if (!context.mounted) return;
                                      Navigator.pop(context);

                                      TopAlert.show(
                                        context,
                                        data["message"] ??
                                            "Something went wrong",
                                        isSuccess: data["status"] == true,
                                        isError: data["status"] != true,
                                      );

                                      if (data["status"] == true) {
                                        _fetchCategories();
                                      }
                                    } catch (e) {
                                      Navigator.pop(context);
                                      TopAlert.show(context, ErrorFormatter.format(e),
                                          isError: true);
                                    }
                                  },
                            child: isLoading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text("Add"),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ✅ NEW: Category Field
  final categoryCtrl = TextEditingController();
  final categoryFocus = FocusNode();

  final List<TextEditingController> mobileCtrls = [
    TextEditingController(),
  ];

  final nameFocus = FocusNode();
  final emailFocus = FocusNode();
  final email2Focus = FocusNode();
  final websiteFocus = FocusNode();
  final addressFocus = FocusNode();
  final List<FocusNode> mobileFocusNodes = [
    FocusNode(),
  ];

  bool showEmail2 = false;
  bool isSaving = false;
  Map<String, String?> errors = {};

  // ✅ NEW: Selfy Images (max 2)
  final List<XFile> _selfyImages = [];

  // ✅ NEW: Selfy Video (max 10 sec)
  XFile? _selfyVideo;

  bool isValidMobile(String v) => RegExp(r'^[0-9]{10}$').hasMatch(v);
  bool isValidEmail(String v) =>
      RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(v);

  @override
  void initState() {
    super.initState();
    _fillFormFromExtractedData();
    _fetchCategories();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    auth.refreshSubscription();
    debugPrint("init page Subscription: ${auth.subscriptionDetails}");
  }

  void _fillFormFromExtractedData() {
    if (widget.extractedData['name'] != null &&
        widget.extractedData['name'].toString().isNotEmpty) {
      nameCtrl.text = widget.extractedData['name'].toString();
    }

    if (widget.extractedData['company_name'] != null &&
        widget.extractedData['company_name'].toString().isNotEmpty) {
      companyCtrl.text = widget.extractedData['company_name'].toString();
    }

    if (widget.extractedData['mobile1'] != null &&
        widget.extractedData['mobile1'].toString().isNotEmpty) {
      mobileCtrls[0].text = widget.extractedData['mobile1'].toString();

      if (widget.extractedData['mobile2'] != null &&
          widget.extractedData['mobile2'].toString().isNotEmpty) {
        if (mobileCtrls.length < 2) {
          mobileCtrls.add(TextEditingController());
          mobileFocusNodes.add(FocusNode());
        }
        mobileCtrls[1].text = widget.extractedData['mobile2'].toString();
      }

      if (widget.extractedData['mobile3'] != null &&
          widget.extractedData['mobile3'].toString().isNotEmpty) {
        if (mobileCtrls.length < 3) {
          mobileCtrls.add(TextEditingController());
          mobileFocusNodes.add(FocusNode());
        }
        mobileCtrls[2].text = widget.extractedData['mobile3'].toString();
      }
    }

    if (widget.extractedData['email1'] != null &&
        widget.extractedData['email1'].toString().isNotEmpty) {
      emailCtrl.text = widget.extractedData['email1'].toString();
    }

    if (widget.extractedData['email2'] != null &&
        widget.extractedData['email2'].toString().isNotEmpty) {
      showEmail2 = true;
      email2Ctrl.text = widget.extractedData['email2'].toString();
    }

    if (widget.extractedData['website'] != null &&
        widget.extractedData['website'].toString().isNotEmpty) {
      websiteCtrl.text = widget.extractedData['website'].toString();
    }

    if (widget.extractedData['address'] != null &&
        widget.extractedData['address'].toString().isNotEmpty) {
      addressCtrl.text = widget.extractedData['address'].toString();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      validate();
    });
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    companyCtrl.dispose();
    emailCtrl.dispose();
    email2Ctrl.dispose();
    websiteCtrl.dispose();
    addressCtrl.dispose();
    categoryCtrl.dispose();

    for (var ctrl in mobileCtrls) {
      ctrl.dispose();
    }

    nameFocus.dispose();
    emailFocus.dispose();
    email2Focus.dispose();
    websiteFocus.dispose();
    addressFocus.dispose();
    categoryFocus.dispose();

    for (var focus in mobileFocusNodes) {
      focus.dispose();
    }

    super.dispose();
  }

  void validate({bool submit = false}) {
    final Map<String, String?> newErrors = {};

    if (nameCtrl.text.trim().isEmpty) {
      newErrors['name'] = "Name is required";
    }

    // ✅ Category required
    // if (categoryCtrl.text.trim().isEmpty) {
    //   newErrors['category'] = "Category is required";
    // }

    final mob1 = mobileCtrls[0].text.trim();
    if (mob1.isEmpty) {
      newErrors['mobile0'] = "Mobile is required";
    } else if (!isValidMobile(mob1)) {
      newErrors['mobile0'] = "Enter valid 10 digit mobile";
    }

    for (int i = 1; i < mobileCtrls.length; i++) {
      final mob = mobileCtrls[i].text.trim();
      if (mob.isNotEmpty && !isValidMobile(mob)) {
        newErrors['mobile$i'] = "Invalid mobile";
      }
    }

    if (emailCtrl.text.trim().isEmpty) {
      newErrors['email'] = "Email is required";
    } else if (!isValidEmail(emailCtrl.text.trim())) {
      newErrors['email'] = "Invalid email format";
    }

    if (showEmail2 &&
        email2Ctrl.text.trim().isNotEmpty &&
        !isValidEmail(email2Ctrl.text.trim())) {
      newErrors['email2'] = "Invalid email format";
    }

    if (websiteCtrl.text.length > 25) {
      newErrors['website'] = "Max 25 characters";
    }

    if (addressCtrl.text.length > 120) {
      newErrors['address'] = "Max 120 characters";
    }

    // ✅ Selfy Images max 2
    if (_selfyImages.length > 2) {
      newErrors['selfy_images'] = "Max 2 selfy images allowed";
    }

    setState(() => errors = newErrors);

    if (submit && newErrors.isNotEmpty) {
      if (newErrors.containsKey('name')) {
        nameFocus.requestFocus();
      } else if (newErrors.containsKey('mobile0')) {
        mobileFocusNodes[0].requestFocus();
      } else if (newErrors.containsKey('email')) {
        emailFocus.requestFocus();
      } else if (newErrors.containsKey('email2')) {
        email2Focus.requestFocus();
      } else if (newErrors.containsKey('website')) {
        websiteFocus.requestFocus();
      } else if (newErrors.containsKey('address')) {
        addressFocus.requestFocus();
      }
    }
  }

  // =================== SELFIE IMAGES ===================

  Future<void> _pickSelfyImage(ImageSource source) async {
    if (_selfyImages.length >= 2) {
      TopAlert.show(context, "❌ Max 2 selfy images allowed", isError: true);
      return;
    }

    final picker = ImagePicker();
    final XFile? img = await picker.pickImage(
      source: source,
      imageQuality: 75,
    );

    if (img != null) {
      setState(() {
        _selfyImages.add(img);
      });
      validate();
    }
  }

  void _removeSelfyImage(int index) {
    setState(() {
      _selfyImages.removeAt(index);
    });
    validate();
  }

  // =================== SELFIE VIDEO ===================

  Future<void> _pickSelfyVideo(ImageSource source) async {
    final picker = ImagePicker();

    final XFile? video = await picker.pickVideo(
      source: source,
      maxDuration: const Duration(seconds: 10),
    );

    if (video == null) return;

    // Extra Safety: check duration (not always available on all devices)
    // But maxDuration usually works properly.
    setState(() {
      _selfyVideo = video;
    });

    validate();
  }

  void _removeSelfyVideo() {
    setState(() {
      _selfyVideo = null;
    });
    validate();
  }

  // =================== SAVE ===================

  Future<void> _saveLead(BuildContext context) async {
    validate(submit: true);
    if (errors.isNotEmpty) return;

    setState(() => isSaving = true);

    try {
      // Convert scanned card image to base64
      String? cardImageBase64;
      try {
        final bytes = await widget.capturedImage.readAsBytes();
        cardImageBase64 = base64Encode(bytes);
      } catch (e) {
        debugPrint("Error converting card image to base64: $e");
      }

      // ✅ Convert selfy images to separate base64 fields (max 2)
      String selfyImage1Base64 = '';
      String selfyImage2Base64 = '';
      String? selfyImage1Filename;
      String? selfyImage2Filename;

      for (int i = 0; i < _selfyImages.length; i++) {
        try {
          final bytes = await _selfyImages[i].readAsBytes();
          final base64Str = base64Encode(bytes);
          if (i == 0) {
            selfyImage1Base64 = base64Str;
            selfyImage1Filename = _selfyImages[i].name;
          } else if (i == 1) {
            selfyImage2Base64 = base64Str;
            selfyImage2Filename = _selfyImages[i].name;
          }
        } catch (e) {
          debugPrint("Error converting selfy image to base64: $e");
        }
      }

      // ✅ Convert selfy video to base64 (optional)
      String selfyVideoBase64 = '';
      String? selfyVideoFilename;
      if (_selfyVideo != null) {
        try {
          final bytes = await _selfyVideo!.readAsBytes();
          selfyVideoBase64 = base64Encode(bytes);
          selfyVideoFilename = _selfyVideo!.name;
        } catch (e) {
          debugPrint("Error converting selfy video to base64: $e");
        }
      }

      final userStorage = UserStorageService();
      final userId = await userStorage.getUserId();

      if (userId == null) {
        setState(() => isSaving = false);
        TopAlert.show(context, "❌ User session not found. Please login again.",
            isError: true);
        return;
      }

      // Build data map with separate selfy fields
      final data = {
        "user_id": userId,
        "name": nameCtrl.text.trim(),
        // "category": categoryCtrl.text.trim(),
        // "category": _selectedCategory ?? "",
        "category_id": _selectedCategoryId,
        "mobiles": mobileCtrls
            .map((e) => e.text.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        "company_name": companyCtrl.text.trim(),
        "email": emailCtrl.text.trim(),
        "email2": showEmail2 ? email2Ctrl.text.trim() : null,
        "website": websiteCtrl.text.trim(),
        "address": addressCtrl.text.trim(),

        // Scanned card image
        if (cardImageBase64 != null) "lead_image": cardImageBase64,
        "image_filename": widget.capturedImage.name,

        // ✅ Selfy images (always present, even if empty)
        "selfy_image_1": selfyImage1Base64,
        "selfy_image_2": selfyImage2Base64,
        if (selfyImage1Filename != null)
          "selfy_image_1_filename": selfyImage1Filename,
        if (selfyImage2Filename != null)
          "selfy_image_2_filename": selfyImage2Filename,

        // ✅ Selfy video (always present, even if empty)
        "selfy_video": selfyVideoBase64,
        if (selfyVideoFilename != null)
          "selfy_video_filename": selfyVideoFilename,
      };

      debugPrint("📤 Saving lead with separate selfy fields:");
      debugPrint("selfy_image_1 length: ${selfyImage1Base64.length}");
      debugPrint("selfy_image_2 length: ${selfyImage2Base64.length}");
      debugPrint("selfy_video length: ${selfyVideoBase64.length}");

      final provider = Provider.of<LeadProviders>(context, listen: false);
      final success = await provider.addLeadRaw(data);

      // if (success) {
      //   TopAlert.show(context, "✅ Lead Added Successfully", isSuccess: true);
      //   Navigator.of(context).pushNamedAndRemoveUntil(
      //     RouteNames.home,
      //     (route) => false,
      //   );
      // } else {
      //   setState(() => isSaving = false);
      //   TopAlert.show(context, "Failed to save lead", isError: true);
      // }

      final auth = Provider.of<AuthProvider>(context, listen: false);

// 🔥 IMPORTANT: API ke baad subscription refresh karo
      await auth.refreshSubscription();

      debugPrint(
          "📦 After api call Updated Subscription: ${auth.subscriptionDetails}");

      if (success) {
        TopAlert.show(context, "✅ Lead Added Successfully", isSuccess: true);

        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => SendIntroSheet(
            leadName: nameCtrl.text.trim(),
            leadPhones: mobileCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList(),
            leadEmail: emailCtrl.text.trim(),
            yourName: 'Your Name',
            yourCompany: 'Your Company',
            onDone: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushNamedAndRemoveUntil(
                RouteNames.home,
                (route) => false,
              );
            },
          ),
        );
      } else {
        setState(() => isSaving = false);

        TopAlert.show(
          context,
          "❌ Feature limit exceeded", // 👈 temporary (better fix below)
          isError: true,
        );
      }
    } catch (e) {
      setState(() => isSaving = false);
      TopAlert.show(context, "Error: ${e.toString()}", isError: true);
    }
  }

  // =================== UI HELPERS ===================

  Widget _buildValidatedField(
    String label,
    TextEditingController controller,
    FocusNode focusNode, {
    TextInputType? keyboard,
    String? error,
    VoidCallback? onChanged,
    Widget? suffix,
    int maxLines = 1,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(
                fontSize: 14, color: isDark ? Colors.white70 : Colors.black87)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboard,
          maxLines: maxLines,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          onChanged: (_) {
            validate();
            if (onChanged != null) onChanged();
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? Colors.grey[900] : Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: error != null
                    ? Colors.red
                    : (isDark ? Colors.grey[700]! : Colors.grey.shade300),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: error != null
                    ? Colors.red
                    : (isDark ? Colors.grey[700]! : Colors.grey.shade300),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: error != null
                    ? Colors.red
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
            errorText: error,
            errorStyle: const TextStyle(fontSize: 12),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            suffixIcon: suffix,
          ),
        ),
        if (error != null) const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildImagePreview() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Scanned Image",
            style: TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: kIsWeb
                  ? Image.network(widget.capturedImage.path, fit: BoxFit.contain)
                  : Image.file(File(widget.capturedImage.path),
                      fit: BoxFit.contain),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NEW: Selfy Images UI
  Widget _buildSelfyImagesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        const Text(
          "Selfy Images (Max 2)",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            // Existing images
            for (int i = 0; i < _selfyImages.length; i++)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: kIsWeb
                        ? Image.network(
                            _selfyImages[i].path,
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            File(_selfyImages[i].path),
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                          ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: InkWell(
                      onTap: () => _removeSelfyImage(i),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),

            // Add buttons
            if (_selfyImages.length < 2)
              InkWell(
                onTap: () async {
                  showCupertinoModalPopup(
                    context: context,
                    builder: (_) => CupertinoActionSheet(
                      title: const Text("Add Selfy Image"),
                      actions: [
                        CupertinoActionSheetAction(
                          onPressed: () {
                            Navigator.pop(context);
                            _pickSelfyImage(ImageSource.camera);
                          },
                          child: const Text("Capture from Camera"),
                        ),
                        CupertinoActionSheetAction(
                          onPressed: () {
                            Navigator.pop(context);
                            _pickSelfyImage(ImageSource.gallery);
                          },
                          child: const Text("Pick from Gallery"),
                        ),
                      ],
                      cancelButton: CupertinoActionSheetAction(
                        onPressed: () => Navigator.pop(context),
                        isDefaultAction: true,
                        child: const Text("Cancel"),
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[700]!
                            : Colors.grey.shade300),
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[900]
                        : Colors.grey.shade50,
                  ),
                  child: Icon(CupertinoIcons.add,
                      size: 30,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
        if (errors['selfy_images'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              errors['selfy_images']!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  // ✅ NEW: Selfy Video UI
  Widget _buildSelfyVideoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          "Selfy Video (Max 10 sec)",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (_selfyVideo == null)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.videocam),
                  label: const Text("Record 10 sec"),
                  onPressed: () => _pickSelfyVideo(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.video_library),
                  label: const Text("Pick Video"),
                  onPressed: () => _pickSelfyVideo(ImageSource.gallery),
                ),
              ),
            ],
          ),
        if (_selfyVideo != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[700]!
                      : Colors.grey.shade300),
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[900]
                  : Colors.grey.shade50,
            ),
            child: Row(
              children: [
                const Icon(Icons.video_file, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selfyVideo!.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                IconButton(
                  onPressed: _removeSelfyVideo,
                  icon: const Icon(Icons.delete, color: Colors.red),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Add New Lead",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildImagePreview(),

                    _buildValidatedField(
                      "Name",
                      nameCtrl,
                      nameFocus,
                      error: errors['name'],
                    ),

                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "  Category",
                          style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline,
                              color: Colors.blue),
                          onPressed: _showAddCategoryModal,
                          tooltip: "Add Category",
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    _isCategoryLoading
                        ? const Center(child: CircularProgressIndicator())
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey[700]!
                                      : Colors.grey.shade300),
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[900]
                                  : Colors.grey.shade50,
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                isExpanded: true,
                                value: _selectedCategoryId,
                                hint: const Text("Select Category"),
                                items: _categories
                                    .map<DropdownMenuItem<int>>((item) {
                                  return DropdownMenuItem<int>(
                                    value: item["id"] as int, // 🔥 force int
                                    child: Text(item["category"].toString()),
                                  );
                                }).toList(),
                                onChanged: (int? value) {
                                  setState(() {
                                    _selectedCategoryId = value;
                                  });
                                },
                              ),
                            ),
                          ),

                    // Mobile Fields
                    Column(
                      children: List.generate(mobileCtrls.length, (i) {
                        return _buildValidatedField(
                          i == 0 ? "Mobile No" : "Mobile ${i + 1}",
                          mobileCtrls[i],
                          mobileFocusNodes[i],
                          keyboard: TextInputType.phone,
                          error: errors['mobile$i'],
                          suffix: i == 0 && mobileCtrls.length < 3
                              ? IconButton(
                                  icon: const Icon(CupertinoIcons.add_circled),
                                  onPressed: () {
                                    setState(() {
                                      mobileCtrls.add(TextEditingController());
                                      mobileFocusNodes.add(FocusNode());
                                    });
                                  },
                                )
                              : i > 0
                                  ? IconButton(
                                      icon: const Icon(
                                        CupertinoIcons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          mobileCtrls.removeAt(i);
                                          mobileFocusNodes.removeAt(i);
                                        });
                                      },
                                    )
                                  : null,
                        );
                      }),
                    ),

                    _buildValidatedField(
                      "Company Name",
                      companyCtrl,
                      FocusNode(),
                    ),

                    _buildValidatedField(
                      "Email",
                      emailCtrl,
                      emailFocus,
                      keyboard: TextInputType.emailAddress,
                      error: errors['email'],
                      suffix: !showEmail2
                          ? IconButton(
                              icon: const Icon(CupertinoIcons.add_circled),
                              onPressed: () {
                                setState(() => showEmail2 = true);
                              },
                            )
                          : null,
                    ),

                    if (showEmail2)
                      _buildValidatedField(
                        "Email 2",
                        email2Ctrl,
                        email2Focus,
                        keyboard: TextInputType.emailAddress,
                        error: errors['email2'],
                        suffix: IconButton(
                          icon: const Icon(CupertinoIcons.delete,
                              color: Colors.red),
                          onPressed: () {
                            setState(() {
                              showEmail2 = false;
                              email2Ctrl.clear();
                            });
                          },
                        ),
                      ),

                    _buildValidatedField(
                      "Website",
                      websiteCtrl,
                      websiteFocus,
                      error: errors['website'],
                    ),

                    _buildValidatedField(
                      "Address",
                      addressCtrl,
                      addressFocus,
                      maxLines: 2,
                      error: errors['address'],
                    ),

                    // ✅ NEW sections
                    _buildSelfyImagesSection(),
                    _buildSelfyVideoSection(),

                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: widget.onCancel,
                          child: const Text("Cancel"),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: isSaving ? null : () => _saveLead(context),
                          child: isSaving
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text("Save"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
