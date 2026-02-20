import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:gridcard/core/services/leads_provider.dart';
import 'package:gridcard/models/lead_model.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:video_player/video_player.dart';

// ✅ ADD THIS BASE URL AT TOP
const String baseStorageUrl =
    "https://powderblue-jellyfish-554082.hostingersite.com/storage/";

class LeadDetailsPage extends StatefulWidget {
  final LeadModel lead;

  const LeadDetailsPage({super.key, required this.lead});

  @override
  State<LeadDetailsPage> createState() => _LeadDetailsPageState();
}

class _LeadDetailsPageState extends State<LeadDetailsPage> {
  late TextEditingController nameCtrl;
  late TextEditingController companyCtrl;
  late TextEditingController addressCtrl;
  late TextEditingController websiteCtrl;
  VideoPlayerController? _videoController;

  final List<TextEditingController> mobileCtrls = [];
  final List<TextEditingController> emailCtrls = [];

  late TextEditingController categoryCtrl;

  // Selfy Images & Video
  String? _selfyImage1Url;
  String? _selfyImage2Url;
  String? _selfyVideoUrl;

  String? _selfyImage1Base64;
  String? _selfyImage2Base64;
  String? _selfyVideoBase64;

  String? _selfyImage1Filename;
  String? _selfyImage2Filename;
  String? _selfyVideoFilename;

  bool _isSelfy1Changed = false;
  bool _isSelfy2Changed = false;
  bool _isVideoChanged = false;

  final Map<String, String?> errors = {};
  bool isSaving = false;

  // ✅ Image related variables
  String? _currentImageUrl;
  String? _imageBase64;
  String? _imageFilename;
  bool _isImageChanged = false;

  final ImagePicker _picker = ImagePicker();

  bool isValidMobile(String v) => RegExp(r'^[0-9]{10}$').hasMatch(v);
  bool isValidEmail(String v) =>
      RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(v);

  @override
  void initState() {
    super.initState();

    final lead = widget.lead;
    print('Lead Data: ${widget.lead.toJson()}');
    // ✅ Set initial image
    _currentImageUrl = lead.imageUrl;

    nameCtrl = TextEditingController(text: lead.name ?? "");
    companyCtrl = TextEditingController(text: lead.company_name ?? "");
    addressCtrl = TextEditingController(text: lead.address ?? "");
    websiteCtrl = TextEditingController(text: lead.website ?? "");

    categoryCtrl = TextEditingController(text: widget.lead.category ?? "");

// Selfy URLs build
    _selfyImage1Url = widget.lead.selfy_image_1 != null
        ? baseStorageUrl + widget.lead.selfy_image_1!
        : null;

    _selfyImage2Url = widget.lead.selfy_image_2 != null
        ? baseStorageUrl + widget.lead.selfy_image_2!
        : null;

    _selfyVideoUrl = widget.lead.selfy_video != null
        ? baseStorageUrl + widget.lead.selfy_video!
        : null;

    if ((lead.mobile_no_1 ?? "").isNotEmpty) {
      mobileCtrls.add(TextEditingController(text: lead.mobile_no_1!));
    }
    if ((lead.mobile_no_2 ?? "").isNotEmpty) {
      mobileCtrls.add(TextEditingController(text: lead.mobile_no_2!));
    }
    if ((lead.mobile_no_3 ?? "").isNotEmpty) {
      mobileCtrls.add(TextEditingController(text: lead.mobile_no_3!));
    }
    if (mobileCtrls.isEmpty) mobileCtrls.add(TextEditingController());

    if ((lead.email ?? "").isNotEmpty) {
      emailCtrls.add(TextEditingController(text: lead.email!));
    }
    if ((lead.email2 ?? "").isNotEmpty) {
      emailCtrls.add(TextEditingController(text: lead.email2!));
    }
    if (emailCtrls.isEmpty) emailCtrls.add(TextEditingController());

    if (_selfyVideoUrl != null) {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(_selfyVideoUrl!),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
        ),
      )..initialize().then((_) {
          _videoController!.setLooping(false); // No auto loop

          _videoController!.addListener(() {
            final controller = _videoController!;
            final position = controller.value.position;
            final duration = controller.value.duration;

            if (duration.inSeconds > 0 &&
                position >= duration &&
                !controller.value.isPlaying) {
              // ✅ Video finished → reset to start
              controller.seekTo(Duration.zero);
              controller.pause();
              setState(() {});
            }
          });

          setState(() {});
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _openFullScreenVideo() {
    if (_videoController == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  ),
                ),

                /// Back Button
                Positioned(
                  top: 20,
                  left: 20,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                /// Play Pause in fullscreen
                Center(
                  child: IconButton(
                    icon: Icon(
                      _videoController!.value.isPlaying
                          ? Icons.pause_circle
                          : Icons.play_circle,
                      size: 70,
                      color: Colors.white,
                    ),
                    onPressed: () async {
                      if (_videoController == null) return;

                      final controller = _videoController!;

                      if (controller.value.position >=
                          controller.value.duration) {
                        // ✅ Video ended → restart
                        await controller.seekTo(Duration.zero);
                        await controller.play();
                      } else if (controller.value.isPlaying) {
                        await controller.pause();
                      } else {
                        await controller.play();
                      }

                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickSelfyImage(int type) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image != null) {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      setState(() {
        if (type == 1) {
          _selfyImage1Base64 = base64Image;
          _selfyImage1Filename = image.name;
          _selfyImage1Url = null;
          _isSelfy1Changed = true;
        } else {
          _selfyImage2Base64 = base64Image;
          _selfyImage2Filename = image.name;
          _selfyImage2Url = null;
          _isSelfy2Changed = true;
        }
      });
    }
  }

  // Future<void> _pickVideo() async {
  //   final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);

  //   if (video != null) {
  //     final bytes = await video.readAsBytes();
  //     final base64Video = base64Encode(bytes);

  //     setState(() {
  //       _selfyVideoBase64 = base64Video;
  //       _selfyVideoFilename = video.name;
  //       _selfyVideoUrl = null;
  //       _isVideoChanged = true;
  //     });
  //   }
  // }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);

    if (video != null) {
      final bytes = await video.readAsBytes();
      final base64Video = base64Encode(bytes);

      _videoController?.dispose();

      _videoController = VideoPlayerController.file(File(video.path))
        ..initialize().then((_) {
          _videoController!.setLooping(false);

          _videoController!.addListener(() {
            final controller = _videoController!;
            if (controller.value.position >= controller.value.duration &&
                !controller.value.isPlaying) {
              controller.seekTo(Duration.zero);
              controller.pause();
              setState(() {});
            }
          });

          setState(() {});
        });

      setState(() {
        _selfyVideoBase64 = base64Video;
        _selfyVideoFilename = video.name;
        _selfyVideoUrl = null;
        _isVideoChanged = true;
      });
    }
  }

  Widget _buildMediaSection(
      String title, String? url, String? base64, VoidCallback onTap,
      {bool isVideo = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: onTap,
                )
              ],
            ),
            const SizedBox(height: 10),
            if (url != null || base64 != null)
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade200,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: isVideo
                      ? (_videoController != null &&
                              _videoController!.value.isInitialized)
                          ? Container(
                              width: double.infinity,
                              height: 220,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.black,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox.expand(
                                      child: FittedBox(
                                        fit: BoxFit.cover,
                                        child: SizedBox(
                                          width: _videoController!
                                              .value.size.width,
                                          height: _videoController!
                                              .value.size.height,
                                          child: VideoPlayer(_videoController!),
                                        ),
                                      ),
                                    ),

                                    // ✅ Buffer Loader
                                    if (_videoController!.value.isBuffering)
                                      const Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                        ),
                                      ),

                                    /// ▶ Play / Pause Button
                                    IconButton(
                                      icon: Icon(
                                        _videoController!.value.isPlaying
                                            ? Icons.pause_circle
                                            : Icons.play_circle,
                                        size: 60,
                                        color: Colors.white,
                                      ),
                                      onPressed: () async {
                                        if (_videoController == null) return;

                                        final controller = _videoController!;

                                        if (controller.value.position >=
                                            controller.value.duration) {
                                          await controller
                                              .seekTo(Duration.zero);
                                        }

                                        if (controller.value.isPlaying) {
                                          await controller.pause();
                                        } else {
                                          await controller.play();
                                        }

                                        setState(() {});
                                      },
                                    ),

                                    /// ⛶ Fullscreen Button
                                    Positioned(
                                      bottom: 10,
                                      right: 10,
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.fullscreen,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                        onPressed: () => _openFullScreenVideo(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : const Center(child: CircularProgressIndicator())
                      : (url != null
                          ? Image.network(url, fit: BoxFit.cover)
                          : Image.memory(base64Decode(base64!),
                              fit: BoxFit.cover)),
                ),
              )
            else
              const Text("No file added"),
          ],
        ),
      ),
    );
  }

  // ✅ Function to pick image from gallery
  Future<void> _pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (image != null) {
      await _processImage(image);
    }
  }

  // ✅ Function to capture image from camera
  Future<void> _captureImageFromCamera() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (image != null) {
      await _processImage(image);
    }
  }

  // ✅ Process selected image
  Future<void> _processImage(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      setState(() {
        _imageBase64 = base64Image;
        _imageFilename = imageFile.name;
        _currentImageUrl = null; // Clear URL if new image is selected
        _isImageChanged = true;
      });

      // Show preview in modal
      _showImagePreview(bytes, imageFile.name);
    } catch (e) {
      debugPrint("Error processing image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  // ✅ Show image preview modal
  void _showImagePreview(List<int> imageBytes, String filename) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Image Preview",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  Uint8List.fromList(imageBytes),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              filename,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _imageBase64 = null;
                      _imageFilename = null;
                      _isImageChanged = false;
                    });
                  },
                  child: const Text("Remove"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Use This"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Show image selection options modal
  void _showImageSourceModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text("Take Photo"),
                onTap: () {
                  Navigator.pop(context);
                  _captureImageFromCamera();
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text("Choose from Gallery"),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
              ),
              const Divider(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ Widget to show image section
  Widget _buildImageSection() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0.8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Lead Image",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: const Icon(Icons.add_photo_alternate),
                  onPressed: _showImageSourceModal,
                  tooltip: "Add/Change Image",
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Image Preview or Placeholder
            if (_currentImageUrl != null || _imageBase64 != null)
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade100,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _currentImageUrl != null
                      ? Image.network(
                          _currentImageUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return _buildImagePlaceholder();
                          },
                        )
                      : (_imageBase64 != null
                          ? Image.memory(
                              base64Decode(_imageBase64!),
                              fit: BoxFit.cover,
                            )
                          : _buildImagePlaceholder()),
                ),
              )
            else
              _buildImagePlaceholder(),

            if (_isImageChanged && _imageFilename != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  "New image: $_imageFilename",
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ✅ Image placeholder widget
  Widget _buildImagePlaceholder() {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade200,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_outline,
            size: 60,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            "No image added",
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            "Tap + button to add",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        title: const Text("Edit Lead"),
        centerTitle: true,
      ),
      bottomNavigationBar: isDesktop
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: isSaving ? null : _submit,
                    icon: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: const Text("Save Changes"),
                  ),
                ),
              ),
            ),
      body: Center(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: isDesktop ? 650 : double.infinity),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Add image section at the top
                _buildImageSection(),

                _buildMediaSection(
                  "Selfy Image 1",
                  _selfyImage1Url,
                  _selfyImage1Base64,
                  () => _pickSelfyImage(1),
                ),

                _buildMediaSection(
                  "Selfy Image 2",
                  _selfyImage2Url,
                  _selfyImage2Base64,
                  () => _pickSelfyImage(2),
                ),

                _buildMediaSection(
                  "Selfy Video",
                  _selfyVideoUrl,
                  _selfyVideoBase64,
                  _pickVideo,
                  isVideo: true,
                ),

                _sectionCard(children: [
                  _input("Name", nameCtrl, error: errors['name']),
                  ..._buildMobiles(),
                  _input("Category", categoryCtrl),
                ]),
                _sectionCard(children: [
                  _input("Company", companyCtrl),
                  ..._buildEmails(),
                ]),
                _sectionCard(children: [
                  _input("Website", websiteCtrl),
                  _input("Address", addressCtrl, maxLines: 3),
                ]),
                if (isDesktop)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: isSaving ? null : _submit,
                        icon: isSaving
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Icon(Icons.check),
                        label: const Text("Save Changes"),
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

  Widget _sectionCard({required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0.8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 2),
        child: Column(children: children),
      ),
    );
  }

  List<Widget> _buildMobiles() {
    return List.generate(mobileCtrls.length, (i) {
      return _input(
        i == 0 ? "Mobile" : "Mobile ${i + 1}",
        mobileCtrls[i],
        keyboard: TextInputType.phone,
        error: errors['mobile$i'],
        suffix: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (i == 0 && mobileCtrls.length < 3)
              IconButton(
                icon: const Icon(CupertinoIcons.add_circled),
                onPressed: () =>
                    setState(() => mobileCtrls.add(TextEditingController())),
              ),
            if (i > 0)
              IconButton(
                icon: const Icon(CupertinoIcons.delete, color: Colors.red),
                onPressed: () => setState(() => mobileCtrls.removeAt(i)),
              ),
          ],
        ),
      );
    });
  }

  List<Widget> _buildEmails() {
    return List.generate(emailCtrls.length, (i) {
      return _input(
        i == 0 ? "Email" : "Email ${i + 1}",
        emailCtrls[i],
        keyboard: TextInputType.emailAddress,
        error: errors['email$i'],
        suffix: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (i == 0 && emailCtrls.length < 2)
              IconButton(
                icon: const Icon(CupertinoIcons.add_circled),
                onPressed: () =>
                    setState(() => emailCtrls.add(TextEditingController())),
              ),
            if (i > 0)
              IconButton(
                icon: const Icon(CupertinoIcons.delete, color: Colors.red),
                onPressed: () => setState(() => emailCtrls.removeAt(i)),
              ),
          ],
        ),
      );
    });
  }

  Widget _input(
    String label,
    TextEditingController ctrl, {
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
    String? error,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          errorText: error,
          suffixIcon: suffix,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 1.6,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1.4),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1.6),
          ),
        ),
      ),
    );
  }

  void validate() {
    errors.clear();

    if (nameCtrl.text.trim().isEmpty) {
      errors['name'] = "Name required";
    }

    for (int i = 0; i < mobileCtrls.length; i++) {
      final v = mobileCtrls[i].text.trim();
      if (v.isEmpty) {
        errors['mobile$i'] = "Required";
      } else if (!isValidMobile(v)) {
        errors['mobile$i'] = "Invalid mobile";
      }
    }

    for (int i = 0; i < emailCtrls.length; i++) {
      final v = emailCtrls[i].text.trim();
      if (v.isNotEmpty && !isValidEmail(v)) {
        errors['email$i'] = "Invalid email";
      }
    }
  }

  Future<void> _submit() async {
    validate();

    if (errors.isNotEmpty) {
      setState(() {});
      return;
    }

    final mobiles = mobileCtrls
        .map((e) => e.text.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final emails = emailCtrls
        .map((e) => e.text.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // final payload = {
    //   "name": nameCtrl.text.trim(),
    //   "company_name": companyCtrl.text.trim(),
    //   "address": addressCtrl.text.trim(),
    //   "website": websiteCtrl.text.trim(),
    //   "mobile_no_1": mobiles.isNotEmpty ? mobiles[0] : "",
    //   "mobile_no_2": mobiles.length > 1 ? mobiles[1] : null,
    //   "mobile_no_3": mobiles.length > 2 ? mobiles[2] : null,
    //   "email": emails.isNotEmpty ? emails[0] : null,
    //   "email2": emails.length > 1 ? emails[1] : null,
    //   // ✅ Add image data if changed
    //   if (_isImageChanged && _imageBase64 != null) "lead_image": _imageBase64,
    //   if (_isImageChanged && _imageFilename != null)
    //     "image_filename": _imageFilename,
    // };

    final payload = {
      "name": nameCtrl.text.trim(),
      "company_name": companyCtrl.text.trim(),
      "category": categoryCtrl.text.trim(),
      "address": addressCtrl.text.trim(),
      "website": websiteCtrl.text.trim(),
      "mobile_no_1": mobiles.isNotEmpty ? mobiles[0] : "",
      "mobile_no_2": mobiles.length > 1 ? mobiles[1] : null,
      "mobile_no_3": mobiles.length > 2 ? mobiles[2] : null,
      "email": emails.isNotEmpty ? emails[0] : null,
      "email2": emails.length > 1 ? emails[1] : null,
      if (_isImageChanged && _imageBase64 != null) "lead_image": _imageBase64,
      if (_isImageChanged && _imageFilename != null)
        "image_filename": _imageFilename,
      if (_isSelfy1Changed && _selfyImage1Base64 != null)
        "selfy_image_1": _selfyImage1Base64,
      if (_isSelfy1Changed && _selfyImage1Filename != null)
        "selfy_image_1_filename": _selfyImage1Filename,
      if (_isSelfy2Changed && _selfyImage2Base64 != null)
        "selfy_image_2": _selfyImage2Base64,
      if (_isSelfy2Changed && _selfyImage2Filename != null)
        "selfy_image_2_filename": _selfyImage2Filename,
      if (_isVideoChanged && _selfyVideoBase64 != null)
        "selfy_video": _selfyVideoBase64,
      if (_isVideoChanged && _selfyVideoFilename != null)
        "selfy_video_filename": _selfyVideoFilename,
    };

    setState(() => isSaving = true);

    final provider = context.read<LeadProviders>();
    final success = await provider.updateLead(widget.lead.id!, payload);

    setState(() => isSaving = false);

    if (success) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Lead Updated Successfully")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Update Failed")),
      );
    }
  }
}
