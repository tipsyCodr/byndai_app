

import 'dart:io';
import 'package:camera/camera.dart';
import 'package:cupertino_icons/cupertino_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:gridcard/core/services/leads_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:gridcard/routes/route_names.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';

class LeadScanner2 extends StatefulWidget {
  final Function(Map<String, dynamic>)? onDataExtracted;

  const LeadScanner2({super.key, this.onDataExtracted});

  @override
  State<LeadScanner2> createState() => _LeadScanner2State();
}

class _LeadScanner2State extends State<LeadScanner2> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;

  XFile? _capturedImage;
  bool _isCameraInitialized = false;
  bool _isCapturedMode = false;
  bool _isLoading = false;
  String _errorMessage = '';
  Map<String, dynamic>? _extractedData;

  static const String _baseUrl = AppConfig.apiBaseUrl;
  final String apiUrl = "$_baseUrl/gpt-ocr";

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    await _requestPermissions();
    _cameras = await availableCameras();
    await _startCamera(0);
  }

  Future<void> _requestPermissions() async {
    if (!kIsWeb) {
      await [
        Permission.camera,
        Permission.storage,
        Permission.photos,
        Permission.microphone,
      ].request();
    }
  }

  Future<void> _startCamera(int index) async {
    _cameraController?.dispose();

    _cameraController = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _cameraController!.initialize();

    if (mounted) {
      setState(() => _isCameraInitialized = true);
    }
  }

  Future<void> _switchCamera() async {
    if (_isCapturedMode) return;

    _selectedCameraIndex = _selectedCameraIndex == 0 ? 1 : 0;

    setState(() {
      _isCameraInitialized = false;
    });

    await _startCamera(_selectedCameraIndex);
  }

  Future<void> _captureImage() async {
    if (!_cameraController!.value.isInitialized) return;

    final XFile file = await _cameraController!.takePicture();

    setState(() {
      _capturedImage = file;
      _isCapturedMode = true;
      _extractedData = null;
    });
  }

  Future<void> _pickFromGallery() async {
    final XFile? img =
        await ImagePicker().pickImage(source: ImageSource.gallery);

    if (img != null) {
      setState(() {
        _capturedImage = img;
        _isCapturedMode = true;
        _extractedData = null;
      });
    }
  }

  void _resetCamera() {
    setState(() {
      _capturedImage = null;
      _isCapturedMode = false;
      _extractedData = null;
      _errorMessage = '';
    });
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
    _cameraController?.dispose();
    super.dispose();
  }

  Widget _buildPreviewBox() {
    return AspectRatio(
      aspectRatio: 1.6,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blueAccent, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: _isCapturedMode && _capturedImage != null
              ? kIsWeb
                  ? Image.network(_capturedImage!.path, fit: BoxFit.cover)
                  : Image.file(File(_capturedImage!.path), fit: BoxFit.cover)
              : _isCameraInitialized
                  ? CameraPreview(_cameraController!)
                  : const Center(
                      child: CircularProgressIndicator(),
                    ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Scan Card'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Expanded(child: Center(child: _buildPreviewBox())),
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: CircularProgressIndicator(),
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
        _circleButton(Icons.photo, _pickFromGallery),
        _captureButton(),
        _circleButton(Icons.cameraswitch, _switchCamera),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _circleButton(Icons.close, _resetCamera),
        _circleButton(Icons.refresh, _resetCamera),
        _circleButton(Icons.check, _submitImage),
      ],
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white24,
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _captureButton() {
    return InkWell(
      onTap: _captureImage,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: const Center(
          child: Icon(Icons.camera_alt, color: Colors.white),
        ),
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
    if (categoryCtrl.text.trim().isEmpty) {
      newErrors['category'] = "Category is required";
    }

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
      } else if (newErrors.containsKey('category')) {
        categoryFocus.requestFocus();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Max 2 selfy images allowed")),
      );
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

  // Future<void> _saveLead(BuildContext context) async {
  //   validate(submit: true);
  //   if (errors.isNotEmpty) return;

  //   setState(() => isSaving = true);

  //   try {
  //     // Convert scanned card image to base64
  //     String? cardImageBase64;
  //     try {
  //       final bytes = await widget.capturedImage.readAsBytes();
  //       cardImageBase64 = base64Encode(bytes);
  //     } catch (e) {
  //       debugPrint("Error converting card image to base64: $e");
  //     }

  //     // ✅ Convert selfy images to base64 list (max 2)
  //     final List<String> selfyImagesBase64 = [];
  //     for (final img in _selfyImages) {
  //       try {
  //         final bytes = await img.readAsBytes();
  //         selfyImagesBase64.add(base64Encode(bytes));
  //       } catch (e) {
  //         debugPrint("Error converting selfy image to base64: $e");
  //       }
  //     }

  //     // ✅ Convert selfy video to base64 (optional)
  //     String? selfyVideoBase64;
  //     String? selfyVideoFilename;
  //     if (_selfyVideo != null) {
  //       try {
  //         final bytes = await _selfyVideo!.readAsBytes();
  //         selfyVideoBase64 = base64Encode(bytes);
  //         selfyVideoFilename = _selfyVideo!.name;
  //       } catch (e) {
  //         debugPrint("Error converting selfy video to base64: $e");
  //       }
  //     }

  //     final userStorage = UserStorageService();
  //     final userId = await userStorage.getUserId();

  //     if (userId == null) {
  //       setState(() => isSaving = false);
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text("❌ User session not found. Please login again."),
  //           backgroundColor: Colors.red,
  //         ),
  //       );
  //       return;
  //     }

  //     final data = {
  //       "user_id": userId,
  //       "name": nameCtrl.text.trim(),
  //       "category": categoryCtrl.text.trim(), // ✅ NEW
  //       "mobiles": mobileCtrls
  //           .map((e) => e.text.trim())
  //           .where((e) => e.isNotEmpty)
  //           .toList(),
  //       "company_name": companyCtrl.text.trim(),
  //       "email": emailCtrl.text.trim(),
  //       "email2": showEmail2 ? email2Ctrl.text.trim() : null,
  //       "website": websiteCtrl.text.trim(),
  //       "address": addressCtrl.text.trim(),

  //       // Existing scanned card image
  //       if (cardImageBase64 != null) "lead_image": cardImageBase64,
  //       "image_filename": widget.capturedImage.name,

  //       // ✅ NEW: Selfy Images (max 2)
  //       "selfy_images": selfyImagesBase64,

  //       // ✅ NEW: Selfy Video
  //       if (selfyVideoBase64 != null) "selfy_video": selfyVideoBase64,
  //       if (selfyVideoFilename != null)
  //         "selfy_video_filename": selfyVideoFilename,
  //     };

  //     debugPrint("📤 Saving lead with new fields:");
  //     debugPrint("Category: ${categoryCtrl.text.trim()}");
  //     debugPrint("Selfy Images: ${selfyImagesBase64.length}");
  //     debugPrint("Selfy Video: ${_selfyVideo?.name}");

  //     final provider = Provider.of<LeadProviders>(context, listen: false);
  //     final success = await provider.addLeadRaw(data);

  //     if (success) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text("✅ Lead Added Successfully"),
  //         ),
  //       );

  //       Navigator.of(context).pushNamedAndRemoveUntil(
  //         RouteNames.home,
  //         (route) => false,
  //       );
  //     } else {
  //       setState(() => isSaving = false);
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text("Failed to save lead"),
  //           backgroundColor: Colors.red,
  //         ),
  //       );
  //     }
  //   } catch (e) {
  //     setState(() => isSaving = false);
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text("Error: ${e.toString()}"),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //   }
  // }

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("❌ User session not found. Please login again."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Build data map with separate selfy fields
      final data = {
        "user_id": userId,
        "name": nameCtrl.text.trim(),
        "category": categoryCtrl.text.trim(),
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

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Lead Added Successfully")),
        );
        Navigator.of(context).pushNamedAndRemoveUntil(
          RouteNames.home,
          (route) => false,
        );
      } else {
        setState(() => isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to save lead"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(label,
            style: const TextStyle(fontSize: 14, color: Colors.black87)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboard,
          maxLines: maxLines,
          onChanged: (_) {
            validate();
            if (onChanged != null) onChanged();
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: error != null ? Colors.red : Colors.grey.shade300,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: error != null ? Colors.red : Colors.grey.shade300,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: error != null ? Colors.red : Colors.blue,
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
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: kIsWeb
                  ? Image.network(widget.capturedImage.path, fit: BoxFit.cover)
                  : Image.file(File(widget.capturedImage.path),
                      fit: BoxFit.cover),
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
                    border: Border.all(color: Colors.grey.shade300),
                    color: Colors.grey.shade50,
                  ),
                  child: const Icon(CupertinoIcons.add,
                      size: 30, color: Colors.black54),
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
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.grey.shade50,
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
        color: Colors.white,
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

                    // ✅ NEW Category
                    _buildValidatedField(
                      "Category",
                      categoryCtrl,
                      categoryFocus,
                      error: errors['category'],
                      suffix: const Icon(Icons.category_outlined),
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
