// import 'package:flutter/material.dart';
// import 'package:gridcard/models/lead_model.dart';
// import 'package:gridcard/core/services/user_storage_service.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// class LeadChatPage extends StatefulWidget {
//   final LeadModel lead;
//   final int? viewerUserId;

//   const LeadChatPage({
//     super.key,
//     required this.lead,
//     required this.viewerUserId,
//   });

//   @override
//   State<LeadChatPage> createState() => _LeadChatPageState();
// }

// class _LeadChatPageState extends State<LeadChatPage> {
//   final List<String> _templates = [
//     "Hi {name}, I'm contacting you regarding your business. Can we connect?",
//     "Hello {name}, I saw your details and wanted to discuss a business opportunity.",
//     "Hi {name}, hope you're doing well. Can I share some details with you?",
//   ];

//   int _selectedIndex = 0;

//   // 1 = mobile_no_1, 2 = mobile_no_2, 3 = mobile_no_3
//   int _selectedMobileIndex = 1;

//   // ================= SANITIZE NUMBER =================
//   String sanitizeMobile(String input) {
//     var phone = input.trim();

//     // remove spaces, dashes, brackets
//     phone = phone.replaceAll(RegExp(r'[^0-9+]'), '');

//     // remove +91
//     if (phone.startsWith("+91")) {
//       phone = phone.substring(3);
//     }

//     // remove 91 if number starts with 91 and total length > 10
//     if (phone.startsWith("91") && phone.length > 10) {
//       phone = phone.substring(2);
//     }

//     // keep last 10 digits if bigger
//     if (phone.length > 10) {
//       phone = phone.substring(phone.length - 10);
//     }

//     return phone;
//   }

//   // ================= GET SELECTED MOBILE =================
//   String _getSelectedMobile() {
//     String raw = "";

//     if (_selectedMobileIndex == 1) raw = widget.lead.mobile_no_1 ?? "";
//     if (_selectedMobileIndex == 2) raw = widget.lead.mobile_no_2 ?? "";
//     if (_selectedMobileIndex == 3) raw = widget.lead.mobile_no_3 ?? "";

//     return sanitizeMobile(raw);
//   }

//   // ================= APPLY TEMPLATE =================
//   String _applyTemplate(String template) {
//     final name = widget.lead.name ?? "there";
//     return template.replaceAll("{name}", name);
//   }

//   // ================= WHATSAPP OPEN =================
//   Future<void> openWhatsApp({
//     required String phone10Digit,
//     required String message,
//   }) async {
//     // WhatsApp API requires country code
//     final phoneWithCountry = "91$phone10Digit";

//     final uri = Uri.parse(
//       "https://wa.me/$phoneWithCountry?text=${Uri.encodeComponent(message)}",
//     );

//     if (!await canLaunchUrl(uri)) {
//       throw "WhatsApp not found / cannot open";
//     }

//     await launchUrl(uri, mode: LaunchMode.externalApplication);
//   }

//   @override
//   Widget build(BuildContext context) {
//     final leadName = widget.lead.name ?? "Unknown";

//     final mobile1 = sanitizeMobile(widget.lead.mobile_no_1 ?? "");
//     final mobile2 = sanitizeMobile(widget.lead.mobile_no_2 ?? "");
//     final mobile3 = sanitizeMobile(widget.lead.mobile_no_3 ?? "");

//     final selectedMessage = _applyTemplate(_templates[_selectedIndex]);
//     final selectedMobile = _getSelectedMobile();

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("WhatsApp Chat"),
//         centerTitle: true,
//       ),
//       body: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.all(14),
//           child: Column(
//             children: [
//               // ================= LEAD INFO =================
//               Container(
//                 width: double.infinity,
//                 padding: const EdgeInsets.all(14),
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(16),
//                   color: Theme.of(context).colorScheme.surface,
//                   border: Border.all(
//                     color: Theme.of(context).dividerColor.withOpacity(0.2),
//                   ),
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       leadName,
//                       style: const TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.w800,
//                       ),
//                     ),
//                     const SizedBox(height: 10),

//                     const Text(
//                       "Select WhatsApp Number:",
//                       style: TextStyle(
//                         fontSize: 13,
//                         fontWeight: FontWeight.w700,
//                       ),
//                     ),

//                     const SizedBox(height: 6),

//                     Wrap(
//                       spacing: 10,
//                       runSpacing: 8,
//                       children: [
//                         if (mobile1.isNotEmpty)
//                           ChoiceChip(
//                             label: Text("Mobile 1: $mobile1"),
//                             selected: _selectedMobileIndex == 1,
//                             onSelected: (_) {
//                               setState(() => _selectedMobileIndex = 1);
//                             },
//                           ),
//                         if (mobile2.isNotEmpty)
//                           ChoiceChip(
//                             label: Text("Mobile 2: $mobile2"),
//                             selected: _selectedMobileIndex == 2,
//                             onSelected: (_) {
//                               setState(() => _selectedMobileIndex = 2);
//                             },
//                           ),
//                         if (mobile3.isNotEmpty)
//                           ChoiceChip(
//                             label: Text("Mobile 3: $mobile3"),
//                             selected: _selectedMobileIndex == 3,
//                             onSelected: (_) {
//                               setState(() => _selectedMobileIndex = 3);
//                             },
//                           ),
//                       ],
//                     ),

//                     if (mobile1.isEmpty && mobile2.isEmpty && mobile3.isEmpty)
//                       const Padding(
//                         padding: EdgeInsets.only(top: 8),
//                         child: Text(
//                           "No mobile number found for this lead.",
//                           style: TextStyle(color: Colors.red),
//                         ),
//                       ),
//                   ],
//                 ),
//               ),

//               const SizedBox(height: 14),

//               // ================= TEMPLATES =================
//               Expanded(
//                 child: ListView.builder(
//                   itemCount: _templates.length,
//                   itemBuilder: (context, index) {
//                     final msg = _applyTemplate(_templates[index]);

//                     return Container(
//                       margin: const EdgeInsets.only(bottom: 10),
//                       decoration: BoxDecoration(
//                         borderRadius: BorderRadius.circular(14),
//                         border: Border.all(
//                           color: index == _selectedIndex
//                               ? Theme.of(context).colorScheme.primary
//                               : Colors.grey.shade300,
//                           width: index == _selectedIndex ? 1.6 : 1,
//                         ),
//                       ),
//                       child: RadioListTile<int>(
//                         value: index,
//                         groupValue: _selectedIndex,
//                         onChanged: (val) {
//                           if (val == null) return;
//                           setState(() => _selectedIndex = val);
//                         },
//                         title: Text(
//                           msg,
//                           style: const TextStyle(fontSize: 13),
//                         ),
//                       ),
//                     );
//                   },
//                 ),
//               ),

//               // ================= SEND BUTTON =================
//               SizedBox(
//                 width: double.infinity,
//                 height: 50,
//                 child: ElevatedButton.icon(
//                   icon: const FaIcon(FontAwesomeIcons.whatsapp),
//                   label: const Text("Open WhatsApp & Send"),
//                   onPressed: () async {
//                     try {
//                       if (selectedMobile.isEmpty) {
//                         ScaffoldMessenger.of(context).showSnackBar(
//                           const SnackBar(
//                             content: Text("❌ Mobile number missing"),
//                           ),
//                         );
//                         return;
//                       }

//                       // login user data
//                       final session = await UserStorageService().loadSession();
//                       final loginUserMobile = session.user?.userMobile ?? "";

//                       debugPrint("========== WHATSAPP CHAT ==========");
//                       debugPrint("FROM (Login User Mobile): $loginUserMobile");
//                       debugPrint("TO (Lead WhatsApp Mobile): $selectedMobile");
//                       debugPrint("MESSAGE: $selectedMessage");
//                       debugPrint("===================================");

//                       await openWhatsApp(
//                         phone10Digit: selectedMobile,
//                         message: selectedMessage,
//                       );
//                     } catch (e) {
//                       debugPrint("WhatsApp Error: $e");
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         SnackBar(
//                           content: Text("❌ WhatsApp open nahi ho paya: $e"),
//                         ),
//                       );
//                     }
//                   },
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gridcard/models/lead_model.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

class ChatTemplate {
  final String message;
  final String? mediaPath; // image/video path
  final String? mediaType; // "image" or "video"

  ChatTemplate({
    required this.message,
    this.mediaPath,
    this.mediaType,
  });
}

class LeadChatPage extends StatefulWidget {
  final LeadModel lead;
  final int? viewerUserId;

  const LeadChatPage({
    super.key,
    required this.lead,
    required this.viewerUserId,
  });

  @override
  State<LeadChatPage> createState() => _LeadChatPageState();
}

class _LeadChatPageState extends State<LeadChatPage> {
  final List<ChatTemplate> _templates = [
    ChatTemplate(
      message:
          "Hi {name}, I'm contacting you regarding your business. Can we connect?",
    ),
    ChatTemplate(
      message:
          "Hello {name}, I saw your details and wanted to discuss a business opportunity.",
    ),
    ChatTemplate(
      message:
          "Hi {name}, hope you're doing well. Can I share some details with you?",
    ),
  ];

  int _selectedIndex = 0;

  // 1 = mobile_no_1, 2 = mobile_no_2, 3 = mobile_no_3
  int _selectedMobileIndex = 1;

  // ================= SANITIZE NUMBER =================
  String sanitizeMobile(String input) {
    var phone = input.trim();

    // remove spaces, dashes, brackets
    phone = phone.replaceAll(RegExp(r'[^0-9+]'), '');

    // remove +91
    if (phone.startsWith("+91")) {
      phone = phone.substring(3);
    }

    // remove 91 if number starts with 91 and total length > 10
    if (phone.startsWith("91") && phone.length > 10) {
      phone = phone.substring(2);
    }

    // keep last 10 digits if bigger
    if (phone.length > 10) {
      phone = phone.substring(phone.length - 10);
    }

    return phone;
  }

  // ================= GET SELECTED MOBILE =================
  String _getSelectedMobile() {
    String raw = "";

    if (_selectedMobileIndex == 1) raw = widget.lead.mobile_no_1 ?? "";
    if (_selectedMobileIndex == 2) raw = widget.lead.mobile_no_2 ?? "";
    if (_selectedMobileIndex == 3) raw = widget.lead.mobile_no_3 ?? "";

    return sanitizeMobile(raw);
  }

  // ================= APPLY TEMPLATE =================
  String _applyTemplate(String template) {
    final name = widget.lead.name ?? "there";
    return template.replaceAll("{name}", name);
  }

  // ================= WHATSAPP OPEN (TEXT ONLY) =================
  Future<void> openWhatsApp({
    required String phone10Digit,
    required String message,
  }) async {
    // WhatsApp API requires country code
    final phoneWithCountry = "91$phone10Digit";

    final uri = Uri.parse(
      "https://wa.me/$phoneWithCountry?text=${Uri.encodeComponent(message)}",
    );

    if (!await canLaunchUrl(uri)) {
      throw "WhatsApp not found / cannot open";
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ================= ADD TEMPLATE DIALOG =================
  Future<void> _addNewTemplateDialog() async {
    final TextEditingController msgCtrl = TextEditingController();

    String? pickedMediaPath;
    String? pickedMediaType;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add New Template"),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: msgCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: "Enter message template...",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // PICK MEDIA
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.attach_file),
                        label: const Text("Pick Image / Video (Optional)"),
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.media,
                          );

                          if (result != null && result.files.isNotEmpty) {
                            final file = result.files.first;
                            final path = file.path;

                            if (path == null) return;

                            final ext = path.split(".").last.toLowerCase();

                            String type = "image";
                            if (["mp4", "mov", "mkv", "avi"].contains(ext)) {
                              type = "video";
                            }

                            setDialogState(() {
                              pickedMediaPath = path;
                              pickedMediaType = type;
                            });
                          }
                        },
                      ),
                    ),

                    if (pickedMediaPath != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey.shade100,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Selected Media:",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              pickedMediaPath!,
                              style: const TextStyle(fontSize: 11),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Type: ${pickedMediaType ?? ""}",
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextButton.icon(
                              onPressed: () {
                                setDialogState(() {
                                  pickedMediaPath = null;
                                  pickedMediaType = null;
                                });
                              },
                              icon: const Icon(Icons.close),
                              label: const Text("Remove Media"),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final msg = msgCtrl.text.trim();

                if (msg.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("❌ Message required")),
                  );
                  return;
                }

                setState(() {
                  _templates.add(
                    ChatTemplate(
                      message: msg,
                      mediaPath: pickedMediaPath,
                      mediaType: pickedMediaType,
                    ),
                  );
                  _selectedIndex = _templates.length - 1;
                });

                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  // ================= DELETE TEMPLATE =================
  void _deleteTemplate(int index) {
    if (_templates.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ At least 1 template required")),
      );
      return;
    }

    setState(() {
      _templates.removeAt(index);

      if (_selectedIndex >= _templates.length) {
        _selectedIndex = _templates.length - 1;
      }
    });
  }

  // ================= TEMPLATE CARD =================
  Widget _templateCard(int index) {
    final t = _templates[index];
    final msg = _applyTemplate(t.message);

    final bool isSelected = index == _selectedIndex;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.grey.shade300,
          width: isSelected ? 1.6 : 1,
        ),
      ),
      child: Column(
        children: [
          RadioListTile<int>(
            value: index,
            groupValue: _selectedIndex,
            onChanged: (val) {
              if (val == null) return;
              setState(() => _selectedIndex = val);
            },
            title: Text(
              msg,
              style: const TextStyle(fontSize: 13),
            ),
            subtitle: t.mediaPath == null
                ? const Text("Text only")
                : Text("Media: ${t.mediaType ?? "file"}"),
          ),

          // MEDIA PREVIEW (simple)
          if (t.mediaPath != null)
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 14, bottom: 10),
              child: Row(
                children: [
                  Icon(
                    t.mediaType == "video" ? Icons.video_library : Icons.image,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.mediaPath!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),

          // DELETE BUTTON
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: () => _deleteTemplate(index),
              icon: const Icon(Icons.delete_outline),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leadName = widget.lead.name ?? "Unknown";

    final mobile1 = sanitizeMobile(widget.lead.mobile_no_1 ?? "");
    final mobile2 = sanitizeMobile(widget.lead.mobile_no_2 ?? "");
    final mobile3 = sanitizeMobile(widget.lead.mobile_no_3 ?? "");

    final selectedTemplate = _templates[_selectedIndex];

    final selectedMessage = _applyTemplate(selectedTemplate.message);
    final selectedMobile = _getSelectedMobile();

    return Scaffold(
      appBar: AppBar(
        title: const Text("WhatsApp Chat"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addNewTemplateDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              // ================= LEAD INFO =================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      leadName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Select WhatsApp Number:",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        if (mobile1.isNotEmpty)
                          ChoiceChip(
                            label: Text("Mobile 1: $mobile1"),
                            selected: _selectedMobileIndex == 1,
                            onSelected: (_) {
                              setState(() => _selectedMobileIndex = 1);
                            },
                          ),
                        if (mobile2.isNotEmpty)
                          ChoiceChip(
                            label: Text("Mobile 2: $mobile2"),
                            selected: _selectedMobileIndex == 2,
                            onSelected: (_) {
                              setState(() => _selectedMobileIndex = 2);
                            },
                          ),
                        if (mobile3.isNotEmpty)
                          ChoiceChip(
                            label: Text("Mobile 3: $mobile3"),
                            selected: _selectedMobileIndex == 3,
                            onSelected: (_) {
                              setState(() => _selectedMobileIndex = 3);
                            },
                          ),
                      ],
                    ),
                    if (mobile1.isEmpty && mobile2.isEmpty && mobile3.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          "No mobile number found for this lead.",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ================= TEMPLATES =================
              Expanded(
                child: ListView.builder(
                  itemCount: _templates.length,
                  itemBuilder: (context, index) => _templateCard(index),
                ),
              ),

              // ================= SEND BUTTON =================
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: const FaIcon(FontAwesomeIcons.whatsapp),
                  label: const Text("Open WhatsApp & Send"),
                  onPressed: () async {
                    try {
                      if (selectedMobile.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("❌ Mobile number missing"),
                          ),
                        );
                        return;
                      }

                      // login user data (debug only)
                      final session = await UserStorageService().loadSession();
                      final loginUserMobile = session.user?.userMobile ?? "";

                      debugPrint("========== WHATSAPP CHAT ==========");
                      debugPrint("FROM (Login User Mobile): $loginUserMobile");
                      debugPrint("TO (Lead WhatsApp Mobile): $selectedMobile");
                      debugPrint("MESSAGE: $selectedMessage");
                      debugPrint("MEDIA: ${selectedTemplate.mediaPath}");
                      debugPrint("===================================");

                      // ================== TEXT ONLY ==================
                      if (selectedTemplate.mediaPath == null) {
                        await openWhatsApp(
                          phone10Digit: selectedMobile,
                          message: selectedMessage,
                        );
                        return;
                      }

                      // ================== MEDIA SHARE ==================
                      final file = File(selectedTemplate.mediaPath!);

                      if (!file.existsSync()) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("❌ Selected media file not found"),
                          ),
                        );
                        return;
                      }

                      await Share.shareXFiles(
                        [XFile(selectedTemplate.mediaPath!)],
                        text: selectedMessage,
                      );
                    } catch (e) {
                      debugPrint("WhatsApp Error: $e");
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("❌ WhatsApp open nahi ho paya: $e"),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
