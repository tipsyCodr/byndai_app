
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart'; // ✅ QR package
import '../../core/services/auth_provider.dart';
import './qr_scanner.dart';

class ProfileQRCodePage extends StatelessWidget {
  const ProfileQRCodePage({super.key});

  String jsonEncode(Map<String, dynamic> data) {
    return json.encode(data);
  }

  // Function to generate QR data from user
  String _generateQrData(Map<String, dynamic> userData) {
    final data = {
      'id': userData['id']?.toString() ?? '',
      'user_mobile': userData['user_mobile']?.toString() ?? '',
      'email': userData['email']?.toString() ?? '',
      'fname': userData['master_user']?['fname']?.toString() ?? '',
      'type': 'gridcard_profile',
      'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
    };

    // Convert to JSON string for QR code
    return jsonEncode(data);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isPortrait = size.height > size.width;
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    // Check if user is available
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Friend Request',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.grey),
              const SizedBox(height: 20),
              const Text(
                'User not found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              Text(
                'Please login again',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    // Prepare user data for QR code
    final userData = {
      'id': user.id,
      'user_mobile': user.userMobile,
      'email': user.email,
      'master_user': user.masterUser?.toJson(),
    };

    final qrData = _generateQrData(userData);
    final userName = user.masterUser?.fname ?? 'User';
    final userMobile = user.userMobile ?? '';
    final userEmail = user.email ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Friend Request',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // QR Code Display Section
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isPortrait ? 24.0 : 48.0,
                    vertical: 24.0,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: isPortrait ? 20 : 40),

                      // Profile Info
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 32),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            // Profile Avatar
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue[100],
                                // Check if profile_pic exists in master_user
                                image:
                                    user.masterUser?.toJson()?['profile_pic'] !=
                                            null
                                        ? DecorationImage(
                                            image: NetworkImage(user.masterUser!
                                                .toJson()['profile_pic']!),
                                            fit: BoxFit.cover,
                                          )
                                        : const DecorationImage(
                                            image: AssetImage(
                                                'assets/profile_placeholder.png'),
                                            fit: BoxFit.cover,
                                          ),
                              ),
                              child:
                                  user.masterUser?.toJson()?['profile_pic'] ==
                                          null
                                      ? const Icon(
                                          Icons.person,
                                          color: Colors.blue,
                                          size: 30,
                                        )
                                      : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // Check if desg exists in master_user
                                  if (user.masterUser?.toJson()?['desg'] !=
                                      null)
                                    Text(
                                      user.masterUser!.toJson()['desg']!,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    userMobile,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    userEmail,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // QR Code Container
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 20,
                              spreadRadius: 2,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          children: [
                            // QR Code Title
                            const Text(
                              'Scan to Connect',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Dynamic QR Code
                            Container(
                              width: isPortrait
                                  ? size.width * 0.6
                                  : size.height * 0.4,
                              height: isPortrait
                                  ? size.width * 0.6
                                  : size.height * 0.4,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.grey[300]!, width: 1),
                              ),
                              child: Center(
                                child: QrImageView(
                                  data: qrData,
                                  version: QrVersions.auto,
                                  size: isPortrait
                                      ? size.width * 0.5
                                      : size.height * 0.35,
                                  eyeStyle: const QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: Colors.black,
                                  ),
                                  dataModuleStyle: const QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: Colors.black,
                                  ),
                                  // Add logo in center if profile_pic exists
                                  embeddedImage: user.masterUser
                                              ?.toJson()?['profile_pic'] !=
                                          null
                                      ? NetworkImage(user.masterUser!
                                          .toJson()['profile_pic']!)
                                      : const AssetImage('assets/app_logo.png')
                                          as ImageProvider,
                                  embeddedImageStyle:
                                      const QrEmbeddedImageStyle(
                                    size: Size(40, 40),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Instructions
                            Text(
                              'Share this QR code to connect with others',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'GridCard ID: GC-${user.id?.toString().padLeft(6, '0') ?? '000000'}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Scan to get contact details',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isPortrait ? 40 : 60),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Buttons
            Container(
              padding: EdgeInsets.fromLTRB(
                isPortrait ? 24 : 48,
                16,
                isPortrait ? 24 : 48,
                isPortrait ? 24 : 32,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!, width: 1),
                ),
              ),
              child: Row(
                children: [
                  // Scan Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _showScanDialog(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_scanner, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Scan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Share Button (New)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // Share QR code functionality
                        _shareQrCode(context, qrData, userName);
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.grey[50],
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.share, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Share',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // void _showScanDialog(BuildContext context) {
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text('Scan QR Code'),
  //       content: const Text(
  //           'Point your camera at another GridCard QR code to connect.'),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: const Text('OK'),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  void _showScanDialog(BuildContext context) {
  // Old dialog को replace करें नीचे के code से:
  
  // QR Scanner Page को open करें
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => QRScannerPage(
        onScanComplete: (scannedData) {
          // जब QR scan complete हो जाए
          _handleScannedData(context, scannedData);
        },
      ),
    ),
  );
}

void _handleScannedData(BuildContext context, Map<String, dynamic> data) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Contact Scanned'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data['fname'] != null)
            Text('Name: ${data['fname']}'),
          if (data['user_mobile'] != null)
            Text('Phone: ${data['user_mobile']}'),
          if (data['email'] != null)
            Text('Email: ${data['email']}'),
          const SizedBox(height: 16),
          const Text('Do you want to save this contact?'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            // यहाँ आप contact save करने की logic add कर सकते हैं
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Contact saved successfully!'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          child: const Text('Save Contact'),
        ),
      ],
    ),
  );
}

  void _shareQrCode(BuildContext context, String qrData, String userName) {
    // Implement share functionality
    // You can use share_plus package for sharing

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Share $userName\'s QR code'),
        action: SnackBarAction(
          label: 'Copy',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: qrData));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('QR data copied to clipboard')),
            );
          },
        ),
      ),
    );
  }
}
