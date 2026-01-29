

// import 'dart:io';
// import 'package:camera/camera.dart';
// import 'package:cupertino_icons/cupertino_icons.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'package:provider/provider.dart';
// import 'package:gridcard/core/services/leads_provider.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:gridcard/routes/route_names.dart';

// class LeadScanner2 extends StatefulWidget {
//   final Function(Map<String, dynamic>)? onDataExtracted;

//   const LeadScanner2({super.key, this.onDataExtracted});

//   @override
//   State<LeadScanner2> createState() => _LeadScanner2State();
// }

// class _LeadScanner2State extends State<LeadScanner2> {
//   CameraController? _cameraController;
//   List<CameraDescription> _cameras = [];
//   int _selectedCameraIndex = 0;

//   XFile? _capturedImage;
//   bool _isCameraInitialized = false;
//   bool _isCapturedMode = false;
//   bool _isLoading = false;
//   String _errorMessage = '';
//   Map<String, dynamic>? _extractedData;

//   final String apiUrl = "http://byndai_server-main.test/api/ocr-extract";

//   @override
//   void initState() {
//     super.initState();
//     _initCamera();
//   }

//   Future<void> _initCamera() async {
//     await _requestPermissions();
//     _cameras = await availableCameras();
//     await _startCamera(0);
//   }

//   Future<void> _requestPermissions() async {
//     if (!kIsWeb) {
//       await [Permission.camera, Permission.storage].request();
//     }
//   }

//   Future<void> _startCamera(int index) async {
//     _cameraController?.dispose();

//     _cameraController = CameraController(
//       _cameras[index],
//       ResolutionPreset.high,
//       enableAudio: false,
//     );

//     await _cameraController!.initialize();

//     if (mounted) {
//       setState(() => _isCameraInitialized = true);
//     }
//   }

//   Future<void> _switchCamera() async {
//     if (_isCapturedMode) return;

//     _selectedCameraIndex = _selectedCameraIndex == 0 ? 1 : 0;

//     setState(() {
//       _isCameraInitialized = false;
//     });

//     await _startCamera(_selectedCameraIndex);
//   }

//   Future<void> _captureImage() async {
//     if (!_cameraController!.value.isInitialized) return;

//     final XFile file = await _cameraController!.takePicture();

//     setState(() {
//       _capturedImage = file;
//       _isCapturedMode = true;
//       _extractedData = null; // Reset previous data
//     });
//   }

//   Future<void> _pickFromGallery() async {
//     final XFile? img =
//         await ImagePicker().pickImage(source: ImageSource.gallery);

//     if (img != null) {
//       setState(() {
//         _capturedImage = img;
//         _isCapturedMode = true;
//         _extractedData = null; // Reset previous data
//       });
//     }
//   }

//   void _resetCamera() {
//     setState(() {
//       _capturedImage = null;
//       _isCapturedMode = false;
//       _extractedData = null;
//       _errorMessage = '';
//     });
//   }

//   Future<void> _submitImage() async {
//     if (_capturedImage == null) return;

//     try {
//       setState(() {
//         _isLoading = true;
//         _errorMessage = '';
//         _extractedData = null;
//       });

//       var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

//       final bytes = await _capturedImage!.readAsBytes();
//       request.files.add(
//         http.MultipartFile.fromBytes(
//           'images[]',
//           bytes,
//           filename: _capturedImage!.name,
//         ),
//       );

//       var response = await request.send();
//       final resStr = await response.stream.bytesToString();

//       if (response.statusCode == 200) {
//         final json = jsonDecode(resStr);

//         // Extract formdata from response
//         if (json['formdata'] != null) {
//           _extractedData = Map<String, dynamic>.from(json['formdata']);
//         } else if (json['text'] != null) {
//           // If formdata is not directly in response, parse from text
//           _extractedData = _parseFormDataFromText(json['text']);
//         }

//         // Show extracted data in modal
//         if (_extractedData != null && _extractedData!.isNotEmpty) {
//           _showExtractedDataModal();
//         } else {
//           setState(() {
//             _errorMessage = "No data could be extracted from the image";
//           });
//         }
//       } else {
//         throw Exception("OCR Failed: $resStr");
//       }
//     } catch (e) {
//       setState(() => _errorMessage = e.toString());
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   Map<String, dynamic> _parseFormDataFromText(String text) {
//     final Map<String, dynamic> data = {};

//     // Extract email patterns
//     final emailRegex =
//         RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b');
//     final emails = emailRegex.allMatches(text).map((m) => m.group(0)).toList();
//     if (emails.isNotEmpty) data['email1'] = emails[0];
//     if (emails.length > 1) data['email2'] = emails[1];

//     // Extract phone numbers
//     final phoneRegex = RegExp(r'\b\d{10}\b');
//     final phones = phoneRegex.allMatches(text).map((m) => m.group(0)).toList();
//     for (int i = 0; i < phones.length && i < 3; i++) {
//       data['mobile${i + 1}'] = phones[i];
//     }

//     // Try to extract name (first line or after common prefixes)
//     final lines = text.split('\n');
//     for (var line in lines) {
//       if (line.trim().isNotEmpty &&
//           !line.contains('@') &&
//           !RegExp(r'\d{10}').hasMatch(line) &&
//           line.length > 3) {
//         data['name'] = line.trim();
//         break;
//       }
//     }

//     return data;
//   }

  

//   void _showExtractedDataModal() {
//   showModalBottomSheet(
//     context: context,
//     isScrollControlled: true,
//     backgroundColor: Colors.transparent,
//     isDismissible: false, // Optional: prevent dismissing by tapping outside
//     enableDrag: false, // Optional: prevent dismissing by dragging down
//     builder: (context) => SafeArea(
//       child: Padding(
//         padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
//         child: ClipRRect( // ✅ Add ClipRRect here
//           borderRadius: const BorderRadius.only(
//             topLeft: Radius.circular(24),
//             topRight: Radius.circular(24),
//             bottomLeft: Radius.circular(24), // ✅ Add bottom left radius
//             bottomRight: Radius.circular(24), // ✅ Add bottom right radius
//           ),
//           child: ExtractedDataModal(
//             extractedData: _extractedData!,
//             onSave: (data) {
//               if (widget.onDataExtracted != null) {
//                 widget.onDataExtracted!(data);
//               }
//               Navigator.of(context).pop();
//               Navigator.of(context).pop();
//             },
//             onCancel: () {
//               Navigator.of(context).pop();
//             },
//           ),
//         ),
//       ),
//     ),
//   );
// }

//   @override
//   void dispose() {
//     _cameraController?.dispose();
//     super.dispose();
//   }

//   Widget _buildPreviewBox() {
//     return AspectRatio(
//       aspectRatio: 1.6,
//       child: Container(
//         decoration: BoxDecoration(
//           border: Border.all(color: Colors.blueAccent, width: 2),
//           borderRadius: BorderRadius.circular(12),
//         ),
//         child: ClipRRect(
//           borderRadius: BorderRadius.circular(10),
//           child: _isCapturedMode && _capturedImage != null
//               ? kIsWeb
//                   ? Image.network(_capturedImage!.path, fit: BoxFit.cover)
//                   : Image.file(File(_capturedImage!.path), fit: BoxFit.cover)
//               : _isCameraInitialized
//                   ? CameraPreview(_cameraController!)
//                   : const Center(
//                       child: CircularProgressIndicator(),
//                     ),
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         backgroundColor: Colors.black,
//         elevation: 0,
//         title: const Text('Scan Card'),
//         centerTitle: true,
//       ),
//       body: Column(
//         children: [
//           const SizedBox(height: 20),
//           Expanded(child: Center(child: _buildPreviewBox())),

//           // Error Message
//           if (_errorMessage.isNotEmpty)
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//               child: Text(
//                 _errorMessage,
//                 style: const TextStyle(color: Colors.red, fontSize: 14),
//                 textAlign: TextAlign.center,
//               ),
//             ),

//           // Loading Indicator
//           if (_isLoading)
//             const Padding(
//               padding: EdgeInsets.symmetric(vertical: 10),
//               child: CircularProgressIndicator(),
//             ),

//           const SizedBox(height: 20),
//           Padding(
//             padding: const EdgeInsets.only(bottom: 20),
//             child:
//                 _isCapturedMode ? _buildActionButtons() : _buildCameraButtons(),
//           ),
//         ],
//       ),
//     );
//   }

//   // 🔹 Default 3 buttons
//   Widget _buildCameraButtons() {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//       children: [
//         _circleButton(Icons.photo, _pickFromGallery),
//         _captureButton(),
//         _circleButton(Icons.cameraswitch, _switchCamera),
//       ],
//     );
//   }

//   // 🔹 Cancel | Recapture | Submit
//   Widget _buildActionButtons() {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//       children: [
//         _circleButton(Icons.close, _resetCamera),
//         _circleButton(Icons.refresh, _resetCamera),
//         _circleButton(Icons.check, _submitImage),
//       ],
//     );
//   }

//   Widget _circleButton(IconData icon, VoidCallback onTap) {
//     return InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(40),
//       child: Container(
//         width: 56,
//         height: 56,
//         decoration: const BoxDecoration(
//           shape: BoxShape.circle,
//           color: Colors.white24,
//         ),
//         child: Icon(icon, color: Colors.white),
//       ),
//     );
//   }

//   Widget _captureButton() {
//     return InkWell(
//       onTap: _captureImage,
//       borderRadius: BorderRadius.circular(40),
//       child: Container(
//         width: 74,
//         height: 74,
//         decoration: BoxDecoration(
//           shape: BoxShape.circle,
//           border: Border.all(color: Colors.white, width: 4),
//         ),
//         child: const Center(
//           child: Icon(Icons.camera_alt, color: Colors.white),
//         ),
//       ),
//     );
//   }
// }

// // Modal for displaying extracted data - UPDATED to match Add Lead Modal
// class ExtractedDataModal extends StatefulWidget {
//   final Map<String, dynamic> extractedData;
//   final Function(Map<String, dynamic>) onSave;
//   final VoidCallback onCancel;

//   const ExtractedDataModal({
//     super.key,
//     required this.extractedData,
//     required this.onSave,
//     required this.onCancel,
//   });

//   @override
//   State<ExtractedDataModal> createState() => _ExtractedDataModalState();
// }

// class _ExtractedDataModalState extends State<ExtractedDataModal> {
//   final nameCtrl = TextEditingController();
//   final companyCtrl = TextEditingController();
//   final emailCtrl = TextEditingController();
//   final email2Ctrl = TextEditingController();
//   final websiteCtrl = TextEditingController();
//   final addressCtrl = TextEditingController();

//   final List<TextEditingController> mobileCtrls = [
//     TextEditingController(),
//   ];

//   final nameFocus = FocusNode();
//   final emailFocus = FocusNode();
//   final email2Focus = FocusNode();
//   final websiteFocus = FocusNode();
//   final addressFocus = FocusNode();
//   final List<FocusNode> mobileFocusNodes = [
//     FocusNode(),
//   ];

//   bool showEmail2 = false;
//   bool isSaving = false;
//   Map<String, String?> errors = {};

//   bool isValidMobile(String v) => RegExp(r'^[0-9]{10}$').hasMatch(v);
//   bool isValidEmail(String v) =>
//       RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(v);

//   @override
//   void initState() {
//     super.initState();
//     // Fill form with extracted data
//     _fillFormFromExtractedData();
//   }

//   void _fillFormFromExtractedData() {
//     // Fill name
//     if (widget.extractedData['name'] != null &&
//         widget.extractedData['name'].toString().isNotEmpty) {
//       nameCtrl.text = widget.extractedData['name'].toString();
//     }

//     // Fill company
//     if (widget.extractedData['company_name'] != null &&
//         widget.extractedData['company_name'].toString().isNotEmpty) {
//       companyCtrl.text = widget.extractedData['company_name'].toString();
//     }

//     // Fill mobile numbers
//     if (widget.extractedData['mobile1'] != null &&
//         widget.extractedData['mobile1'].toString().isNotEmpty) {
//       mobileCtrls[0].text = widget.extractedData['mobile1'].toString();

//       // Check if we need more mobile fields
//       if (widget.extractedData['mobile2'] != null &&
//           widget.extractedData['mobile2'].toString().isNotEmpty) {
//         if (mobileCtrls.length < 2) {
//           mobileCtrls.add(TextEditingController());
//           mobileFocusNodes.add(FocusNode());
//         }
//         mobileCtrls[1].text = widget.extractedData['mobile2'].toString();
//       }

//       if (widget.extractedData['mobile3'] != null &&
//           widget.extractedData['mobile3'].toString().isNotEmpty) {
//         if (mobileCtrls.length < 3) {
//           mobileCtrls.add(TextEditingController());
//           mobileFocusNodes.add(FocusNode());
//         }
//         mobileCtrls[2].text = widget.extractedData['mobile3'].toString();
//       }
//     }

//     // Fill email1
//     if (widget.extractedData['email1'] != null &&
//         widget.extractedData['email1'].toString().isNotEmpty) {
//       emailCtrl.text = widget.extractedData['email1'].toString();
//     }

//     // Fill email2
//     if (widget.extractedData['email2'] != null &&
//         widget.extractedData['email2'].toString().isNotEmpty) {
//       showEmail2 = true;
//       email2Ctrl.text = widget.extractedData['email2'].toString();
//     }

//     // Fill website
//     if (widget.extractedData['website'] != null &&
//         widget.extractedData['website'].toString().isNotEmpty) {
//       websiteCtrl.text = widget.extractedData['website'].toString();
//     }

//     // Fill address
//     if (widget.extractedData['address'] != null &&
//         widget.extractedData['address'].toString().isNotEmpty) {
//       addressCtrl.text = widget.extractedData['address'].toString();
//     }

//     // Trigger initial validation
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       validate();
//     });
//   }

//   @override
//   void dispose() {
//     nameCtrl.dispose();
//     companyCtrl.dispose();
//     emailCtrl.dispose();
//     email2Ctrl.dispose();
//     websiteCtrl.dispose();
//     addressCtrl.dispose();
//     for (var ctrl in mobileCtrls) {
//       ctrl.dispose();
//     }
//     nameFocus.dispose();
//     emailFocus.dispose();
//     email2Focus.dispose();
//     websiteFocus.dispose();
//     addressFocus.dispose();
//     for (var focus in mobileFocusNodes) {
//       focus.dispose();
//     }
//     super.dispose();
//   }

//   void validate({bool submit = false}) {
//     final Map<String, String?> newErrors = {};

//     if (nameCtrl.text.trim().isEmpty) {
//       newErrors['name'] = "Name is required";
//     }

//     final mob1 = mobileCtrls[0].text.trim();
//     if (mob1.isEmpty) {
//       newErrors['mobile0'] = "Mobile is required";
//     } else if (!isValidMobile(mob1)) {
//       newErrors['mobile0'] = "Enter valid 10 digit mobile";
//     }

//     for (int i = 1; i < mobileCtrls.length; i++) {
//       final mob = mobileCtrls[i].text.trim();
//       if (mob.isNotEmpty && !isValidMobile(mob)) {
//         newErrors['mobile$i'] = "Invalid mobile";
//       }
//     }

//     if (emailCtrl.text.trim().isEmpty) {
//       newErrors['email'] = "Email is required";
//     } else if (!isValidEmail(emailCtrl.text.trim())) {
//       newErrors['email'] = "Invalid email format";
//     }

//     if (showEmail2 &&
//         email2Ctrl.text.trim().isNotEmpty &&
//         !isValidEmail(email2Ctrl.text.trim())) {
//       newErrors['email2'] = "Invalid email format";
//     }

//     if (websiteCtrl.text.length > 25) {
//       newErrors['website'] = "Max 25 characters";
//     }

//     if (addressCtrl.text.length > 120) {
//       newErrors['address'] = "Max 120 characters";
//     }

//     setState(() => errors = newErrors);

//     if (submit && newErrors.isNotEmpty) {
//       if (newErrors.containsKey('name'))
//         nameFocus.requestFocus();
//       else if (newErrors.containsKey('mobile0'))
//         mobileFocusNodes[0].requestFocus();
//       else if (newErrors.containsKey('email'))
//         emailFocus.requestFocus();
//       else if (newErrors.containsKey('email2'))
//         email2Focus.requestFocus();
//       else if (newErrors.containsKey('website'))
//         websiteFocus.requestFocus();
//       else if (newErrors.containsKey('address')) addressFocus.requestFocus();
//     }
//   }

//   Future<void> _saveLead(BuildContext context) async {
//     validate(submit: true);
//     if (errors.isNotEmpty) return;

//     setState(() => isSaving = true);

//     try {
//       final data = {
//         "name": nameCtrl.text.trim(),
//         "mobiles": mobileCtrls
//             .map((e) => e.text.trim())
//             .where((e) => e.isNotEmpty)
//             .toList(),
//         "company_name": companyCtrl.text.trim(),
//         "email": emailCtrl.text.trim(),
//         "email2": showEmail2 ? email2Ctrl.text.trim() : null,
//         "website": websiteCtrl.text.trim(),
//         "address": addressCtrl.text.trim(),
//       };

//       final provider = Provider.of<LeadProviders>(context, listen: false);
//       final success = await provider.addLeadRaw(data);

     
//       if (success) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text("✅ Lead Added Successfully"),
//           ),
//         );

//         // 🔥 Direct go back to Home Page (clear all previous routes)
//         Navigator.of(context).pushNamedAndRemoveUntil(
//           RouteNames.home,
//           (route) => false,
//         );
//       } else {
//         setState(() => isSaving = false);
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text("Failed to save lead"),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     } catch (e) {
//       setState(() => isSaving = false);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text("Error: ${e.toString()}"),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }

//   Widget _buildValidatedField(
//       String label, TextEditingController controller, FocusNode focusNode,
//       {TextInputType? keyboard,
//       String? error,
//       VoidCallback? onChanged,
//       Widget? suffix,
//       int maxLines = 1}) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const SizedBox(height: 8),
//         Text(label,
//             style: const TextStyle(fontSize: 14, color: Colors.black87)),
//         const SizedBox(height: 4),
//         TextField(
//           controller: controller,
//           focusNode: focusNode,
//           keyboardType: keyboard,
//           maxLines: maxLines,
//           onChanged: (_) {
//             validate();
//             if (onChanged != null) onChanged();
//           },
//           decoration: InputDecoration(
//             filled: true,
//             fillColor: Colors.grey.shade50,
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(8),
//               borderSide: BorderSide(
//                 color: error != null ? Colors.red : Colors.grey.shade300,
//               ),
//             ),
//             enabledBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(8),
//               borderSide: BorderSide(
//                 color: error != null ? Colors.red : Colors.grey.shade300,
//               ),
//             ),
//             focusedBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(8),
//               borderSide: BorderSide(
//                 color: error != null ? Colors.red : Colors.blue,
//               ),
//             ),
//             errorText: error,
//             errorStyle: const TextStyle(fontSize: 12),
//             contentPadding: const EdgeInsets.symmetric(
//               horizontal: 12,
//               vertical: 12,
//             ),
//             suffixIcon: suffix,
//           ),
//         ),
//         if (error != null) const SizedBox(height: 4),
//       ],
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final screenWidth = MediaQuery.of(context).size.width;
//     final isDesktop = screenWidth > 800;

//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: const BorderRadius.only(
//           topLeft: Radius.circular(24),
//           topRight: Radius.circular(24),
//           bottomLeft: Radius.circular(24),
//           bottomRight: Radius.circular(24),
//         ),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.2),
//             blurRadius: 20,
//             spreadRadius: 5,
//           ),
//         ],
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(20),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Header
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 const Text(
//                   "Add New Lead",
//                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                 ),
//                 IconButton(
//                   onPressed: widget.onCancel,
//                   icon: const Icon(Icons.close),
//                 ),
//               ],
//             ),

//             const SizedBox(height: 20),

//             // Form Fields
//             Expanded(
//               child: SingleChildScrollView(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     _buildValidatedField("Name", nameCtrl, nameFocus,
//                         error: errors['name']),

//                     Column(
//                       children: List.generate(mobileCtrls.length, (i) {
//                         return _buildValidatedField(
//                           i == 0 ? "Mobile No" : "Mobile ${i + 1}",
//                           mobileCtrls[i],
//                           mobileFocusNodes[i],
//                           keyboard: TextInputType.phone,
//                           error: errors['mobile$i'],
//                           suffix: i == 0 && mobileCtrls.length < 3
//                               ? IconButton(
//                                   icon: const Icon(CupertinoIcons.add_circled),
//                                   onPressed: () {
//                                     setState(() {
//                                       mobileCtrls.add(TextEditingController());
//                                       mobileFocusNodes.add(FocusNode());
//                                     });
//                                   },
//                                 )
//                               : i > 0
//                                   ? IconButton(
//                                       icon: const Icon(CupertinoIcons.delete,
//                                           color: Colors.red),
//                                       onPressed: () {
//                                         setState(() {
//                                           mobileCtrls.removeAt(i);
//                                           mobileFocusNodes.removeAt(i);
//                                         });
//                                       },
//                                     )
//                                   : null,
//                         );
//                       }),
//                     ),

//                     _buildValidatedField(
//                         "Company Name", companyCtrl, FocusNode()),

//                     // Email field with add button
//                     _buildValidatedField(
//                       "Email",
//                       emailCtrl,
//                       emailFocus,
//                       keyboard: TextInputType.emailAddress,
//                       error: errors['email'],
//                       suffix: !showEmail2
//                           ? IconButton(
//                               icon: const Icon(CupertinoIcons.add_circled),
//                               onPressed: () {
//                                 setState(() => showEmail2 = true);
//                               },
//                             )
//                           : null,
//                     ),

//                     // Email 2 field with delete button
//                     if (showEmail2)
//                       _buildValidatedField(
//                         "Email 2",
//                         email2Ctrl,
//                         email2Focus,
//                         keyboard: TextInputType.emailAddress,
//                         error: errors['email2'],
//                         suffix: IconButton(
//                           icon: const Icon(CupertinoIcons.delete,
//                               color: Colors.red),
//                           onPressed: () {
//                             setState(() {
//                               showEmail2 = false;
//                               email2Ctrl.clear();
//                             });
//                           },
//                         ),
//                       ),

//                     _buildValidatedField("Website", websiteCtrl, websiteFocus,
//                         error: errors['website']),

//                     _buildValidatedField("Address", addressCtrl, addressFocus,
//                         maxLines: 2, error: errors['address']),

//                     const SizedBox(height: 24),

//                     // Buttons
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.end,
//                       children: [
//                         TextButton(
//                           onPressed: widget.onCancel,
//                           child: const Text("Cancel"),
//                         ),
//                         const SizedBox(width: 12),
//                         ElevatedButton(
//                           onPressed: isSaving ? null : () => _saveLead(context),
//                           child: isSaving
//                               ? const SizedBox(
//                                   height: 22,
//                                   width: 22,
//                                   child: CircularProgressIndicator(
//                                     strokeWidth: 2.5,
//                                     color: Colors.white,
//                                   ),
//                                 )
//                               : const Text("Save"),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

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

  final String apiUrl = "http://byndai_server-main.test/api/ocr-extract";

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
      await [Permission.camera, Permission.storage].request();
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
      _extractedData = null; // Reset previous data
    });
  }

  Future<void> _pickFromGallery() async {
    final XFile? img =
        await ImagePicker().pickImage(source: ImageSource.gallery);

    if (img != null) {
      setState(() {
        _capturedImage = img;
        _isCapturedMode = true;
        _extractedData = null; // Reset previous data
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

      final bytes = await _capturedImage!.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'images[]',
          bytes,
          filename: _capturedImage!.name,
        ),
      );

      var response = await request.send();
      final resStr = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final json = jsonDecode(resStr);

        // Extract formdata from response
        if (json['formdata'] != null) {
          _extractedData = Map<String, dynamic>.from(json['formdata']);
        } else if (json['text'] != null) {
          // If formdata is not directly in response, parse from text
          _extractedData = _parseFormDataFromText(json['text']);
        }

        // Show extracted data in modal
        if (_extractedData != null && _extractedData!.isNotEmpty) {
          _showExtractedDataModal();
        } else {
          setState(() {
            _errorMessage = "No data could be extracted from the image";
          });
        }
      } else {
        throw Exception("OCR Failed: $resStr");
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _parseFormDataFromText(String text) {
    final Map<String, dynamic> data = {};

    // Extract email patterns
    final emailRegex =
        RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b');
    final emails = emailRegex.allMatches(text).map((m) => m.group(0)).toList();
    if (emails.isNotEmpty) data['email1'] = emails[0];
    if (emails.length > 1) data['email2'] = emails[1];

    // Extract phone numbers
    final phoneRegex = RegExp(r'\b\d{10}\b');
    final phones = phoneRegex.allMatches(text).map((m) => m.group(0)).toList();
    for (int i = 0; i < phones.length && i < 3; i++) {
      data['mobile${i + 1}'] = phones[i];
    }

    // Try to extract name (first line or after common prefixes)
    final lines = text.split('\n');
    for (var line in lines) {
      if (line.trim().isNotEmpty &&
          !line.contains('@') &&
          !RegExp(r'\d{10}').hasMatch(line) &&
          line.length > 3) {
        data['name'] = line.trim();
        break;
      }
    }

    return data;
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
              capturedImage: _capturedImage!, // ✅ Pass captured image
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

          // Error Message
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),

          // Loading Indicator
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

  // 🔹 Default 3 buttons
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

  // 🔹 Cancel | Recapture | Submit
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

// Modal for displaying extracted data - UPDATED to match Add Lead Modal
class ExtractedDataModal extends StatefulWidget {
  final XFile capturedImage; // ✅ Add captured image parameter
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

  bool isValidMobile(String v) => RegExp(r'^[0-9]{10}$').hasMatch(v);
  bool isValidEmail(String v) =>
      RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(v);

  @override
  void initState() {
    super.initState();
    // Fill form with extracted data
    _fillFormFromExtractedData();
  }

  void _fillFormFromExtractedData() {
    // Fill name
    if (widget.extractedData['name'] != null &&
        widget.extractedData['name'].toString().isNotEmpty) {
      nameCtrl.text = widget.extractedData['name'].toString();
    }

    // Fill company
    if (widget.extractedData['company_name'] != null &&
        widget.extractedData['company_name'].toString().isNotEmpty) {
      companyCtrl.text = widget.extractedData['company_name'].toString();
    }

    // Fill mobile numbers
    if (widget.extractedData['mobile1'] != null &&
        widget.extractedData['mobile1'].toString().isNotEmpty) {
      mobileCtrls[0].text = widget.extractedData['mobile1'].toString();

      // Check if we need more mobile fields
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

    // Fill email1
    if (widget.extractedData['email1'] != null &&
        widget.extractedData['email1'].toString().isNotEmpty) {
      emailCtrl.text = widget.extractedData['email1'].toString();
    }

    // Fill email2
    if (widget.extractedData['email2'] != null &&
        widget.extractedData['email2'].toString().isNotEmpty) {
      showEmail2 = true;
      email2Ctrl.text = widget.extractedData['email2'].toString();
    }

    // Fill website
    if (widget.extractedData['website'] != null &&
        widget.extractedData['website'].toString().isNotEmpty) {
      websiteCtrl.text = widget.extractedData['website'].toString();
    }

    // Fill address
    if (widget.extractedData['address'] != null &&
        widget.extractedData['address'].toString().isNotEmpty) {
      addressCtrl.text = widget.extractedData['address'].toString();
    }

    // Trigger initial validation
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
    for (var ctrl in mobileCtrls) {
      ctrl.dispose();
    }
    nameFocus.dispose();
    emailFocus.dispose();
    email2Focus.dispose();
    websiteFocus.dispose();
    addressFocus.dispose();
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

    setState(() => errors = newErrors);

    if (submit && newErrors.isNotEmpty) {
      if (newErrors.containsKey('name'))
        nameFocus.requestFocus();
      else if (newErrors.containsKey('mobile0'))
        mobileFocusNodes[0].requestFocus();
      else if (newErrors.containsKey('email'))
        emailFocus.requestFocus();
      else if (newErrors.containsKey('email2'))
        email2Focus.requestFocus();
      else if (newErrors.containsKey('website'))
        websiteFocus.requestFocus();
      else if (newErrors.containsKey('address')) addressFocus.requestFocus();
    }
  }

  Future<void> _saveLead(BuildContext context) async {
    validate(submit: true);
    if (errors.isNotEmpty) return;

    setState(() => isSaving = true);

    try {
      // Convert image to base64 for sending to API
      String? imageBase64;
      try {
        final bytes = await widget.capturedImage.readAsBytes();
        imageBase64 = base64Encode(bytes);
      } catch (e) {
        debugPrint("Error converting image to base64: $e");
      }

      final data = {
        "name": nameCtrl.text.trim(),
        "mobiles": mobileCtrls
            .map((e) => e.text.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        "company_name": companyCtrl.text.trim(),
        "email": emailCtrl.text.trim(),
        "email2": showEmail2 ? email2Ctrl.text.trim() : null,
        "website": websiteCtrl.text.trim(),
        "address": addressCtrl.text.trim(),
        if (imageBase64 != null) "lead_image": imageBase64, // ✅ Add image to data
        "image_filename": widget.capturedImage.name, // ✅ Add filename
      };

      debugPrint("📤 Saving lead with image data, filename: ${widget.capturedImage.name}");

      final provider = Provider.of<LeadProviders>(context, listen: false);
      final success = await provider.addLeadRaw(data);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Lead Added Successfully"),
          ),
        );

        // 🔥 Direct go back to Home Page (clear all previous routes)
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

  Widget _buildValidatedField(
      String label, TextEditingController controller, FocusNode focusNode,
      {TextInputType? keyboard,
      String? error,
      VoidCallback? onChanged,
      Widget? suffix,
      int maxLines = 1}) {
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

            // Form Fields
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ Scanned Image Preview (FIRST)
                    _buildImagePreview(),

                    _buildValidatedField("Name", nameCtrl, nameFocus,
                        error: errors['name']),

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
                                      icon: const Icon(CupertinoIcons.delete,
                                          color: Colors.red),
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
                        "Company Name", companyCtrl, FocusNode()),

                    // Email field with add button
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

                    // Email 2 field with delete button
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

                    _buildValidatedField("Website", websiteCtrl, websiteFocus,
                        error: errors['website']),

                    _buildValidatedField("Address", addressCtrl, addressFocus,
                        maxLines: 2, error: errors['address']),

                    const SizedBox(height: 24),

                    // Buttons
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