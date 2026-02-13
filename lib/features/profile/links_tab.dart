

// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:gridcard/config/app_config.dart';
// import 'package:gridcard/core/services/user_storage_service.dart';
// import 'package:http/http.dart' as http;

// class LinksTab extends StatefulWidget {
//   final Map<String, dynamic>? userDetails;
//   const LinksTab({super.key, this.userDetails});

//   @override
//   State<LinksTab> createState() => _LinksTabState();
// }

// class _LinksTabState extends State<LinksTab> {
//   static const String _baseUrl = AppConfig.apiBaseUrl;

//   // ================= HEADERS =================
//   Future<Map<String, String>> _getHeaders() async {
//     final token = await UserStorageService().getToken();
//     return {
//       'Content-Type': 'application/json',
//       'Accept': 'application/json',
//       if (token != null) 'Authorization': 'Bearer $token',
//     };
//   }

//   final List<Map<String, String>> socialOptions = [
//     {"label": "Facebook", "value": "facebook"},
//     {"label": "Instagram", "value": "instagram"},
//     {"label": "Twitter", "value": "twitter"},
//     {"label": "LinkedIn", "value": "linkedin"},
//     {"label": "YouTube", "value": "youtube"},
//     {"label": "WhatsApp", "value": "whatsapp"},
//     {"label": "Telegram", "value": "telegram"},
//     {"label": "Snapchat", "value": "snapchat"},
//   ];

//   List<Map<String, String>> savedLinks = [];

//   // ================= API CALL =================
//   Future<void> _createMasterLink({
//     required String name,
//     required String link,
//   }) async {
//     try {
//       final headers = await _getHeaders();

//       final url = Uri.parse("$_baseUrl/master-links");

//       final body = jsonEncode({
//         "name": name, // facebook
//         "link": link, // https://....
//         "status": 1
//       });

//       final response = await http.post(url, headers: headers, body: body);

//       final data = jsonDecode(response.body);

//       if (response.statusCode == 200 || response.statusCode == 201) {
//         // success
//         final msg = data["message"] ?? "Link saved successfully";

//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text(msg)),
//         );

//         // UI me bhi add kar do (optional but useful)
//         setState(() {
//           savedLinks.add({
//             "platform": name,
//             "link": link,
//           });
//         });
//       } else {
//         // error
//         final msg = data["message"] ?? "Something went wrong";

//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text(msg)),
//         );
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Error: $e")),
//       );
//     }
//   }

//   void openAddLinkModal() {
//     String? selectedPlatform;
//     final TextEditingController linkController = TextEditingController();

//     bool isLoading = false;

//     Widget formUI(StateSetter setModalState) {
//       return Column(
//         mainAxisSize: MainAxisSize.min,
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             "Add Social Link",
//             style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
//           ),
//           const SizedBox(height: 14),

//           // ✅ Dropdown
//           DropdownButtonFormField<String>(
//             value: selectedPlatform,
//             decoration: InputDecoration(
//               labelText: "Select Platform",
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//             ),
//             items: socialOptions.map((item) {
//               return DropdownMenuItem<String>(
//                 value: item["value"],
//                 child: Text(item["label"] ?? ""),
//               );
//             }).toList(),
//             onChanged: isLoading
//                 ? null
//                 : (val) {
//                     setModalState(() {
//                       selectedPlatform = val;
//                     });
//                   },
//           ),

//           const SizedBox(height: 12),

//           // ✅ Link Field
//           TextFormField(
//             controller: linkController,
//             enabled: !isLoading,
//             keyboardType: TextInputType.url,
//             decoration: InputDecoration(
//               labelText: "Enter Link",
//               hintText: "https://",
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//             ),
//           ),

//           const SizedBox(height: 16),

//           // ✅ Save Button with Loading
//           SizedBox(
//             width: double.infinity,
//             height: 48,
//             child: ElevatedButton(
//               onPressed: isLoading
//                   ? null
//                   : () async {
//                       if (selectedPlatform == null) {
//                         ScaffoldMessenger.of(context).showSnackBar(
//                           const SnackBar(
//                               content: Text("Please select platform")),
//                         );
//                         return;
//                       }

//                       if (linkController.text.trim().isEmpty) {
//                         ScaffoldMessenger.of(context).showSnackBar(
//                           const SnackBar(content: Text("Please enter link")),
//                         );
//                         return;
//                       }

//                       // ✅ Start Loading
//                       setModalState(() {
//                         isLoading = true;
//                       });

//                       await _createMasterLink(
//                         name: selectedPlatform!,
//                         link: linkController.text.trim(),
//                       );

//                       // ✅ Stop Loading
//                       setModalState(() {
//                         isLoading = false;
//                       });

//                       // ✅ Close Dialog
//                       Navigator.pop(context);
//                     },
//               child: isLoading
//                   ? const SizedBox(
//                       height: 22,
//                       width: 22,
//                       child: CircularProgressIndicator(
//                         strokeWidth: 2.5,
//                         color: Colors.white,
//                       ),
//                     )
//                   : const Text("Save"),
//             ),
//           ),
//         ],
//       );
//     }

//     // ✅ Center Dialog
//     showDialog(
//       context: context,
//       barrierDismissible: !isLoading,
//       builder: (context) {
//         return AlertDialog(
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(16),
//           ),
//           contentPadding: const EdgeInsets.all(16),
//           content: SizedBox(
//             width: 420,
//             child: StatefulBuilder(
//               builder: (context, setModalState) {
//                 return formUI(setModalState);
//               },
//             ),
//           ),
//         );
//       },
//     );
//   }

//   String getLabelFromValue(String value) {
//     final item = socialOptions.firstWhere(
//       (e) => e["value"] == value,
//       orElse: () => {"label": value, "value": value},
//     );
//     return item["label"] ?? value;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: savedLinks.isEmpty
//           ? const Center(
//               child: Text(
//                 "No Links Added",
//                 style: TextStyle(fontSize: 16, color: Colors.grey),
//               ),
//             )
//           : ListView.builder(
//               padding: const EdgeInsets.all(12),
//               itemCount: savedLinks.length,
//               itemBuilder: (context, index) {
//                 final item = savedLinks[index];

//                 return Card(
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(14),
//                   ),
//                   child: ListTile(
//                     title: Text(getLabelFromValue(item["platform"] ?? "")),
//                     subtitle: Text(item["link"] ?? ""),
//                     trailing: IconButton(
//                       icon: const Icon(Icons.delete, color: Colors.red),
//                       onPressed: () {
//                         setState(() {
//                           savedLinks.removeAt(index);
//                         });
//                       },
//                     ),
//                   ),
//                 );
//               },
//             ),

//       floatingActionButton: FloatingActionButton(
//         onPressed: openAddLinkModal,
//         child: const Icon(Icons.add),
//       ),
//     );
//   }
// }


import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:http/http.dart' as http;

class LinksTab extends StatefulWidget {
  final Map<String, dynamic>? userDetails;
  const LinksTab({super.key, this.userDetails});

  @override
  State<LinksTab> createState() => _LinksTabState();
}

class _LinksTabState extends State<LinksTab> {
  static const String _baseUrl = AppConfig.apiBaseUrl;

  // ================= HEADERS =================
  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  final List<Map<String, String>> socialOptions = [
    {"label": "Facebook", "value": "facebook"},
    {"label": "Instagram", "value": "instagram"},
    {"label": "Twitter", "value": "twitter"},
    {"label": "LinkedIn", "value": "linkedin"},
    {"label": "YouTube", "value": "youtube"},
    {"label": "WhatsApp", "value": "whatsapp"},
    {"label": "Telegram", "value": "telegram"},
    {"label": "Snapchat", "value": "snapchat"},
  ];

  // API se aane wali list (id bhi store hoga)
  List<Map<String, dynamic>> savedLinks = [];

  bool isPageLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchMasterLinks();
  }

  // ================= GET ALL LINKS =================
  Future<void> _fetchMasterLinks() async {
    try {
      setState(() => isPageLoading = true);

      final headers = await _getHeaders();
      final url = Uri.parse("$_baseUrl/master-links");

      final response = await http.get(url, headers: headers);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (data["status"] == true) {
          final List list = data["data"] ?? [];

          setState(() {
            savedLinks = list.map((e) => Map<String, dynamic>.from(e)).toList();
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data["message"] ?? "Failed to load links")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: ${response.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => isPageLoading = false);
    }
  }

  // ================= CREATE LINK =================
  Future<bool> _createMasterLink({
    required String name,
    required String link,
  }) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse("$_baseUrl/master-links");

      final body = jsonEncode({
        "name": name,
        "link": link,
        "status": 1,
      });

      final response = await http.post(url, headers: headers, body: body);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final msg = data["message"] ?? "Link saved successfully";

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );

        // Response se new data add kar do
        if (data["data"] != null) {
          setState(() {
            savedLinks.insert(0, Map<String, dynamic>.from(data["data"]));
          });
        } else {
          // fallback
          await _fetchMasterLinks();
        }

        return true;
      } else {
        final msg = data["message"] ?? "Something went wrong";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
        return false;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
      return false;
    }
  }

  // ================= UPDATE LINK =================
  Future<bool> _updateMasterLink({
    required int id,
    required String name,
    required String link,
  }) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse("$_baseUrl/master-links/$id");

      final body = jsonEncode({
        "name": name,
        "link": link,
        "status": 1,
      });

      final response = await http.post(url, headers: headers, body: body);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final msg = data["message"] ?? "Link updated successfully";

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );

        // list update
        if (data["data"] != null) {
          final updated = Map<String, dynamic>.from(data["data"]);

          setState(() {
            final index = savedLinks.indexWhere((e) => e["id"] == id);
            if (index != -1) {
              savedLinks[index] = updated;
            }
          });
        } else {
          await _fetchMasterLinks();
        }

        return true;
      } else {
        final msg = data["message"] ?? "Something went wrong";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
        return false;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
      return false;
    }
  }

  // ================= DELETE LINK =================
  Future<bool> _deleteMasterLink(int id) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse("$_baseUrl/master-links/$id");

      final response = await http.delete(url, headers: headers);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final msg = data["message"] ?? "Deleted successfully";

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );

        setState(() {
          savedLinks.removeWhere((e) => e["id"] == id);
        });

        return true;
      } else {
        final msg = data["message"] ?? "Something went wrong";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
        return false;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
      return false;
    }
  }

  // ================= UI HELPERS =================
  String getLabelFromValue(String value) {
    final item = socialOptions.firstWhere(
      (e) => e["value"] == value,
      orElse: () => {"label": value, "value": value},
    );
    return item["label"] ?? value;
  }

  // ================= CREATE MODAL =================
  void openAddLinkModal() {
    _openLinkModal(isEdit: false);
  }

  // ================= EDIT MODAL =================
  void openEditLinkModal(Map<String, dynamic> linkItem) {
    _openLinkModal(isEdit: true, linkItem: linkItem);
  }

  void _openLinkModal({
    required bool isEdit,
    Map<String, dynamic>? linkItem,
  }) {
    String? selectedPlatform = isEdit ? (linkItem?["name"]?.toString()) : null;

    final TextEditingController linkController = TextEditingController(
      text: isEdit ? (linkItem?["link"]?.toString() ?? "") : "",
    );

    bool isLoading = false;

    Widget formUI(StateSetter setModalState) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEdit ? "Edit Social Link" : "Add Social Link",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),

          // Dropdown
          DropdownButtonFormField<String>(
            value: selectedPlatform,
            decoration: InputDecoration(
              labelText: "Select Platform",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: socialOptions.map((item) {
              return DropdownMenuItem<String>(
                value: item["value"],
                child: Text(item["label"] ?? ""),
              );
            }).toList(),
            onChanged: isLoading
                ? null
                : (val) {
                    setModalState(() {
                      selectedPlatform = val;
                    });
                  },
          ),

          const SizedBox(height: 12),

          // Link Field
          TextFormField(
            controller: linkController,
            enabled: !isLoading,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: "Enter Link",
              hintText: "https://",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (selectedPlatform == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("Please select platform")),
                        );
                        return;
                      }

                      if (linkController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Please enter link")),
                        );
                        return;
                      }

                      setModalState(() => isLoading = true);

                      bool ok = false;

                      if (isEdit) {
                        ok = await _updateMasterLink(
                          id: int.parse(linkItem!["id"].toString()),
                          name: selectedPlatform!,
                          link: linkController.text.trim(),
                        );
                      } else {
                        ok = await _createMasterLink(
                          name: selectedPlatform!,
                          link: linkController.text.trim(),
                        );
                      }

                      setModalState(() => isLoading = false);

                      if (ok) {
                        Navigator.pop(context);
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(isEdit ? "Update" : "Save"),
            ),
          ),
        ],
      );
    }

    showDialog(
      context: context,
      barrierDismissible: !isLoading,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.all(16),
          content: SizedBox(
            width: 420,
            child: StatefulBuilder(
              builder: (context, setModalState) {
                return formUI(setModalState);
              },
            ),
          ),
        );
      },
    );
  }

  // ================= DELETE CONFIRM =================
  void confirmDelete(Map<String, dynamic> linkItem) {
    final id = int.parse(linkItem["id"].toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Link"),
          content: const Text("Are you sure you want to delete this link?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteMasterLink(id);
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isPageLoading
          ? const Center(child: CircularProgressIndicator())
          : savedLinks.isEmpty
              ? const Center(
                  child: Text(
                    "No Links Added",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: savedLinks.length,
                  itemBuilder: (context, index) {
                    final item = savedLinks[index];

                    final String name = item["name"]?.toString() ?? "";
                    final String link = item["link"]?.toString() ?? "";

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        title: Text(getLabelFromValue(name)),
                        subtitle: Text(link),
                        trailing: PopupMenuButton<String>(
                          onSelected: (val) {
                            if (val == "edit") {
                              openEditLinkModal(item);
                            } else if (val == "delete") {
                              confirmDelete(item);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: "edit",
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 18),
                                  SizedBox(width: 10),
                                  Text("Edit"),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: "delete",
                              child: Row(
                                children: [
                                  Icon(Icons.delete,
                                      size: 18, color: Colors.red),
                                  SizedBox(width: 10),
                                  Text("Delete"),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

      // + Button
      floatingActionButton: FloatingActionButton(
        onPressed: openAddLinkModal,
        child: const Icon(Icons.add),
      ),
    );
  }
}
