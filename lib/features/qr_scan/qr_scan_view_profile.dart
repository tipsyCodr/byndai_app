// import 'dart:io';
// import 'dart:convert';
// import 'package:flutter/services.dart';
// import '../../core/services/auth_provider.dart';
// import 'package:provider/provider.dart';
// import '../../core/services/chat_provider.dart';
// import 'package:flutter/material.dart';

// class QRScanViewProfile extends StatelessWidget {
//   final String receiverId;
//   final String name;
//   final String email;
//   final String mobile;

//   final String senderId;
//   final String senderName;

//   const QRScanViewProfile({
//     super.key,
//     required this.receiverId,
//     required this.name,
//     required this.email,
//     required this.mobile,
//     required this.senderId,
//     required this.senderName,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xffF5F7FA),
//       appBar: AppBar(
//         elevation: 0,
//         backgroundColor: Colors.transparent,
//         foregroundColor: Colors.black,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back),
//           onPressed: () => Navigator.pop(context),
//         ),
//       ),
//       body: Center(
//         child: Padding(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             children: [
//               /// 🔹 Profile Card
//               Container(
//                 width: double.infinity,
//                 padding: const EdgeInsets.symmetric(vertical: 24),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(20),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black.withOpacity(0.05),
//                       blurRadius: 12,
//                       offset: const Offset(0, 6),
//                     ),
//                   ],
//                 ),
//                 child: Column(
//                   children: [
//                     /// 🔹 Profile Image + Logo
//                     Stack(
//                       alignment: Alignment.bottomRight,
//                       children: [
//                         Container(
//                           padding: const EdgeInsets.all(16),
//                           decoration: BoxDecoration(
//                             borderRadius: BorderRadius.circular(20),
//                             color: Colors.grey.shade100,
//                           ),
//                           child: CircleAvatar(
//                             radius: 50,
//                             backgroundColor: Colors.grey.shade300,
//                             child: const Icon(
//                               Icons.person,
//                               size: 60,
//                               color: Colors.black54,
//                             ),
//                           ),
//                         ),

//                         /// Connected Logo
//                         Positioned(
//                           right: 4,
//                           bottom: 4,
//                           child: CircleAvatar(
//                             radius: 16,
//                             backgroundColor: Colors.blue,
//                             child: const Icon(
//                               Icons.rocket_launch,
//                               size: 16,
//                               color: Colors.white,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),

//                     const SizedBox(height: 16),

//                     /// 🔹 Name
//                     Text(
//                       name,
//                       style: const TextStyle(
//                         fontSize: 22,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),

//                     const SizedBox(height: 6),

//                     /// 🔹 Mobile
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         const Icon(Icons.call, size: 16, color: Colors.blue),
//                         const SizedBox(width: 6),
//                         Text(mobile),
//                       ],
//                     ),

//                     const SizedBox(height: 4),

//                     /// 🔹 Email
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         const Icon(Icons.email, size: 16, color: Colors.blue),
//                         const SizedBox(width: 6),
//                         Text(email),
//                       ],
//                     ),

//                     const SizedBox(height: 20),

//                     /// 🔹 Connections Box
//                     Container(
//                       width: 120,
//                       padding: const EdgeInsets.symmetric(vertical: 12),
//                       decoration: BoxDecoration(
//                         color: Colors.blue.shade50,
//                         borderRadius: BorderRadius.circular(14),
//                       ),
//                       child: Column(
//                         children: const [
//                           Text(
//                             '23',
//                             style: TextStyle(
//                               fontSize: 22,
//                               fontWeight: FontWeight.bold,
//                               color: Colors.blue,
//                             ),
//                           ),
//                           SizedBox(height: 4),
//                           Text(
//                             'Connections',
//                             style: TextStyle(fontSize: 12),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),

//               const Spacer(),

//               /// 🔹 Send Request Button
//               SizedBox(
//                 width: double.infinity,
//                 height: 52,
//                 child: ElevatedButton(
//                   onPressed: () {
//                     showDialog(
//                       context: context,
//                       builder: (context) => AlertDialog(
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(16),
//                         ),
//                         title: const Text('Receiver Data'),
//                         content: Column(
//                           mainAxisSize: MainAxisSize.min,
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text('ID: $receiverId'),
//                             Text('Name: $name'),
//                             Text('Mobile: $mobile'),
//                             Text('Email: $email'),
//                             const SizedBox(height: 16),
//                             const Divider(),
//                             const Text(
//                               'Sender Data',
//                               style: TextStyle(fontWeight: FontWeight.bold),
//                             ),
//                             const SizedBox(height: 8),
//                             Text('Sender ID: $senderId'),
//                             Text('Sender Name: $senderName'),
//                           ],
//                         ),
//                         actions: [
//                           TextButton(
//                             onPressed: () => Navigator.pop(context),
//                             child: const Text('Cancel'),
//                           ),
//                           // ElevatedButton(
//                           //   onPressed: () {
//                           //     Navigator.pop(context);
//                           //     debugPrint('✅ Send Request API call here');
//                           //   },
//                           //   child: const Text('Confirm'),
//                           // ),

//                           ElevatedButton(
//                             onPressed: () async {
//                               Navigator.pop(context);

//                               final chatProvider = context.read<ChatProvider>();

//                               final success =
//                                   await chatProvider.sendConnectionRequest(
//                                 int.parse(
//                                     receiverId), // 🔥 yahin se JSON {receiver_id: 9} jaega
//                               );

//                               ScaffoldMessenger.of(context).showSnackBar(
//                                 SnackBar(
//                                   content: Text(
//                                     success
//                                         ? '✅ Connection request sent'
//                                         : '❌ Connection request failed',
//                                   ),
//                                   backgroundColor:
//                                       success ? Colors.green : Colors.red,
//                                 ),
//                               );
//                             },
//                             child: const Text('Confirm'),
//                           ),
//                         ],
//                       ),
//                     );
//                   },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.blue,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(16),
//                     ),
//                   ),
//                   child: const Text(
//                     'Send Request',
//                     style: TextStyle(fontSize: 16),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/chat_provider.dart';
import '../../routes/route_names.dart';
import '../../routes/app_routes.dart';

class QRScanViewProfile extends StatefulWidget {
  final String receiverId;
  final String name;
  final String email;
  final String mobile;

  final String senderId;
  final String senderName;

  const QRScanViewProfile({
    super.key,
    required this.receiverId,
    required this.name,
    required this.email,
    required this.mobile,
    required this.senderId,
    required this.senderName,
  });

  @override
  State<QRScanViewProfile> createState() => _QRScanViewProfileState();
}

class _QRScanViewProfileState extends State<QRScanViewProfile> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// 🔹 PROFILE CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  /// 🔹 Avatar + Logo
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.grey.shade100,
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey.shade300,
                          child: const Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.blue,
                          child: const Icon(
                            Icons.rocket_launch,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  /// 🔹 NAME
                  Text(
                    widget.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  /// 🔹 MOBILE
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.call, size: 16, color: Colors.blue),
                      const SizedBox(width: 6),
                      Text(widget.mobile),
                    ],
                  ),

                  const SizedBox(height: 4),

                  /// 🔹 EMAIL
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.email, size: 16, color: Colors.blue),
                      const SizedBox(width: 6),
                      Text(widget.email),
                    ],
                  ),

                  const SizedBox(height: 20),

                  /// 🔹 CONNECTIONS (Dummy)
                  Container(
                    width: 120,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Column(
                      children: [
                        Text(
                          '23',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Connections',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            /// 🔹 SEND REQUEST BUTTON (Provider Controlled)
            // Consumer<ChatProvider>(
            //   builder: (context, chatProvider, _) {
            //     return SizedBox(
            //       width: double.infinity,
            //       height: 52,
            //       child: ElevatedButton(
            //         onPressed: chatProvider.isLoading
            //             ? null
            //             : () async {
            //                 final success =
            //                     await chatProvider.sendConnectionRequest(
            //                   int.parse(widget.receiverId),
            //                 );

            //                 if (!mounted) return;

            //                 if (success) {
            //                   // 🔥 Scanner + Profile View remove
            //                   // Navigator.popUntil(
            //                   //   context,
            //                   //   (route) =>
            //                   //       route.settings.name == '/profile_qr',
            //                   // );

            //                   Navigator.popUntil(
            //                     context,
            //                     (route) =>
            //                         route.settings.name ==
            //                         RouteNames.profile_qr,
            //                   );

            //                   ScaffoldMessenger.of(context).showSnackBar(
            //                     const SnackBar(
            //                       content: Text('✅ Connection request sent'),
            //                       backgroundColor: Colors.green,
            //                     ),
            //                   );
            //                 } else {
            //                   ScaffoldMessenger.of(context).showSnackBar(
            //                     const SnackBar(
            //                       content: Text('❌ Connection request failed'),
            //                       backgroundColor: Colors.red,
            //                     ),
            //                   );
            //                 }
            //               },
            //         style: ElevatedButton.styleFrom(
            //           backgroundColor: Colors.blue,
            //           shape: RoundedRectangleBorder(
            //             borderRadius: BorderRadius.circular(16),
            //           ),
            //         ),
            //         child: chatProvider.isLoading
            //             ? const SizedBox(
            //                 width: 22,
            //                 height: 22,
            //                 child: CircularProgressIndicator(
            //                   strokeWidth: 2,
            //                   color: Colors.white,
            //                 ),
            //               )
            //             : const Text(
            //                 'Send Request',
            //                 style: TextStyle(fontSize: 16),
            //               ),
            //       ),
            //     );
            //   },
            // ),

            /// 🔹 SEND REQUEST BUTTON (Provider Controlled)
            Consumer<ChatProvider>(
              builder: (context, chatProvider, _) {
                return SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: chatProvider.isLoading
                        ? null
                        : () async {
                            // ✅ Context pass karo provider ko
                            final success =
                                await chatProvider.sendConnectionRequest(
                              context, // 👈 Add context here
                              int.parse(widget.receiverId),
                            );

                            if (!mounted) return;

                            if (success) {
                              Navigator.popUntil(
                                context,
                                (route) =>
                                    route.settings.name ==
                                    RouteNames.profile_qr,
                              );

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✅ Connection request sent'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                            // ❌ Error already shown by provider
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: chatProvider.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Send Request',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
