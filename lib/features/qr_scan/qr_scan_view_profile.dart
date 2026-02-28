// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// import 'package:gridcard/core/services/user_storage_service.dart';
// import 'package:gridcard/config/app_config.dart';
// import 'package:http/http.dart' as http;

// class QRScanViewProfile extends StatefulWidget {
//   final String receiverId;
//   final String name;
//   final String email;
//   final String mobile;
//   final String senderId;
//   final String senderName;
//   final String profilePic;
//   final String profileLogo;
//   final String legalName;
//   final String industryTitle;

//   const QRScanViewProfile({
//     super.key,
//     required this.receiverId,
//     required this.name,
//     required this.email,
//     required this.mobile,
//     required this.senderId,
//     required this.senderName,
//     required this.profilePic,
//     required this.profileLogo,
//     required this.legalName,
//     required this.industryTitle,
//   });

//   @override
//   State<QRScanViewProfile> createState() => _QRScanViewProfileState();
// }

// class _QRScanViewProfileState extends State<QRScanViewProfile> {
//   static const String _baseUrl = AppConfig.apiBaseUrl;
//   static const String _imageBaseUrl = AppConfig.apiProfileImg;

//   static const _storage = FlutterSecureStorage();
//   bool _isLoading = false;

//   // ================= HEADERS =================
//   static Future<Map<String, String>> _getHeaders(
//       {bool isMultipart = false}) async {
//     final token = await UserStorageService().getToken();
//     return {
//       if (!isMultipart) 'Content-Type': 'application/json',
//       'Accept': 'application/json',
//       if (token != null) 'Authorization': 'Bearer $token',
//     };
//   }

//   // ================= API CALL =================
//   Future<String?> _sendConnectionRequest(int receiverId) async {
//     final url = Uri.parse('$_baseUrl/connection-create');

//     try {
//       final response = await http.post(
//         url,
//         headers: await _getHeaders(),
//         body: jsonEncode({
//           'receiver_id': receiverId,
//         }),
//       );

//       final data = jsonDecode(response.body);

//       if (response.statusCode == 200 || response.statusCode == 201) {
//         return null;
//       }

//       if (response.statusCode == 422) {
//         if (data['errors'] != null && data['errors']['receiver_id'] != null) {
//           return data['errors']['receiver_id'][0];
//         }
//         return data['message'] ?? 'Validation error';
//       }

//       return data['message'] ?? 'Something went wrong';
//     } catch (e) {
//       return 'Server error, please try again';
//     }
//   }

//   // ================= UI =================
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xffF5F7FA),
//       body: Stack(
//         children: [
//           // ================= COVER IMAGE =================
//           SizedBox(
//             height: MediaQuery.of(context).size.height * 0.55,
//             width: double.infinity,
//             child: Stack(
//               fit: StackFit.expand,
//               children: [
//                 // Cover Image
//                 widget.profilePic.isNotEmpty
//                     ? Image.network(
//                         '$_imageBaseUrl/${widget.profilePic}',
//                         fit: BoxFit.cover,
//                       )
//                     : Container(color: Colors.grey.shade300),

//                 // Gradient Overlay
//                 Container(
//                   decoration: const BoxDecoration(
//                     gradient: LinearGradient(
//                       begin: Alignment.topCenter,
//                       end: Alignment.bottomCenter,
//                       colors: [
//                         Colors.transparent,
//                         Colors.black54,
//                         Colors.black87,
//                       ],
//                     ),
//                   ),
//                 ),

//                 // Back Button
//                 SafeArea(
//                   child: IconButton(
//                     icon: const Icon(Icons.arrow_back, color: Colors.white),
//                     onPressed: () => Navigator.pop(context),
//                   ),
//                 ),

//                 // Bottom Center Content
//                 Align(
//                   alignment: Alignment.bottomCenter,
//                   child: Padding(
//                     padding: const EdgeInsets.only(bottom: 30),
//                     child: Column(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         // Logo
//                         CircleAvatar(
//                           radius: 50,
//                           backgroundColor: Colors.white,
//                           backgroundImage: widget.profileLogo.isNotEmpty
//                               ? NetworkImage(
//                                   '$_imageBaseUrl/${widget.profileLogo}',
//                                 )
//                               : null,
//                           child: widget.profileLogo.isEmpty
//                               ? const Icon(Icons.business,
//                                   size: 40, color: Colors.blue)
//                               : null,
//                         ),
//                         const SizedBox(height: 16),

//                         // Name
//                         Text(
//                           widget.name,
//                           style: const TextStyle(
//                             color: Colors.white,
//                             fontSize: 24,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),

//                         const SizedBox(height: 6),

//                         // Legal Name
//                         Text(
//                           widget.legalName,
//                           style: const TextStyle(
//                             color: Colors.white70,
//                             fontSize: 15,
//                           ),
//                         ),

//                         const SizedBox(height: 6),

//                         // Industry
//                         Text(
//                           widget.industryTitle,
//                           style: const TextStyle(
//                             color: Colors.white70,
//                             fontSize: 14,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           // ================= BOTTOM BUTTON CARD =================
//           Positioned(
//             top: MediaQuery.of(context).size.height * 0.52,
//             left: 0,
//             right: 0,
//             child: Container(
//               padding: const EdgeInsets.all(20),
//               decoration: const BoxDecoration(
//                 color: Color(0xffF5F7FA),
//                 borderRadius: BorderRadius.vertical(
//                   top: Radius.circular(30),
//                 ),
//               ),
//               child: SizedBox(
//                 width: double.infinity,
//                 height: 55,
//                 child: ElevatedButton(
//                   onPressed: _isLoading
//                       ? null
//                       : () async {
//                           final receiverId = int.parse(widget.receiverId);

//                           setState(() => _isLoading = true);

//                           final errorMessage =
//                               await _sendConnectionRequest(receiverId);

//                           setState(() => _isLoading = false);

//                           if (!mounted) return;

//                           if (errorMessage == null) {
//                             ScaffoldMessenger.of(context).showSnackBar(
//                               const SnackBar(
//                                 content: Text('✅ Connection request sent'),
//                                 backgroundColor: Colors.green,
//                               ),
//                             );
//                             Navigator.pop(context, true);
//                           } else {
//                             ScaffoldMessenger.of(context).showSnackBar(
//                               SnackBar(
//                                 content: Text(errorMessage),
//                                 backgroundColor: Colors.red,
//                               ),
//                             );
//                           }
//                         },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: const Color(0xff1E1B4B),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(18),
//                     ),
//                   ),
//                   child: _isLoading
//                       ? const CircularProgressIndicator(
//                           color: Colors.white,
//                         )
//                       : const Text(
//                           'Connect',
//                           style: TextStyle(
//                             fontSize: 16,
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//===========================
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:http/http.dart' as http;

class QRScanViewProfile extends StatefulWidget {
  final String receiverId;
  final String name;
  final String email;
  final String mobile;
  final String senderId;
  final String senderName;
  final String profilePic;
  final String profileLogo;
  final String legalName;
  final String industryTitle;

  const QRScanViewProfile({
    super.key,
    required this.receiverId,
    required this.name,
    required this.email,
    required this.mobile,
    required this.senderId,
    required this.senderName,
    required this.profilePic,
    required this.profileLogo,
    required this.legalName,
    required this.industryTitle,
  });

  @override
  State<QRScanViewProfile> createState() => _QRScanViewProfileState();
}

class _QRScanViewProfileState extends State<QRScanViewProfile> {
  static const String _baseUrl = AppConfig.apiBaseUrl;
  static const String _imageBaseUrl = AppConfig.apiProfileImg;
  static const _storage = FlutterSecureStorage();
  bool _isLoading = false;

  Future<Map<String, String>> _getHeaders({bool isMultipart = false}) async {
    final token = await UserStorageService().getToken();
    return {
      if (!isMultipart) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<String?> _sendConnectionRequest(int receiverId) async {
    final url = Uri.parse('$_baseUrl/connection-create');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'receiver_id': receiverId}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) return null;
      if (response.statusCode == 422) {
        if (data['errors'] != null && data['errors']['receiver_id'] != null) {
          return data['errors']['receiver_id'][0];
        }
        return data['message'] ?? 'Validation error';
      }
      return data['message'] ?? 'Something went wrong';
    } catch (e) {
      return 'Server error, please try again';
    }
  }

  void _handleConnect() async {
    final receiverId = int.parse(widget.receiverId);
    setState(() => _isLoading = true);
    final errorMessage = await _sendConnectionRequest(receiverId);
    setState(() => _isLoading = false);
    if (!mounted) return;
    if (errorMessage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Connection request sent'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),
      body: Column(
        children: [
          // ========== COVER SECTION (60% height) ==========
          SizedBox(
            height: screenHeight * 0.6,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Cover image
                if (widget.profilePic.isNotEmpty)
                  Image.network(
                    '$_imageBaseUrl/${widget.profilePic}',
                    fit: BoxFit.cover,
                  )
                else
                  Container(color: Colors.grey.shade300),

                // Gradient overlay
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black54,
                        Colors.black87
                      ],
                    ),
                  ),
                ),

                // Back button
                SafeArea(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),

                // Profile info (aligned bottom inside cover)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo
                        CircleAvatar(
                          radius: 55,
                          backgroundColor: Colors.white,
                          backgroundImage: widget.profileLogo.isNotEmpty
                              ? NetworkImage(
                                  '$_imageBaseUrl/${widget.profileLogo}')
                              : null,
                          child: widget.profileLogo.isEmpty
                              ? const Icon(Icons.business,
                                  size: 45, color: Colors.blue)
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // Name
                        Text(
                          widget.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Legal name
                        Text(
                          widget.legalName,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Industry
                        Text(
                          widget.industryTitle,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ========== BOTTOM SECTION WITH BUTTON ==========
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleConnect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff1E1B4B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Connect',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
