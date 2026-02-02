import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/services/auth_provider.dart';
import './qr_scanner.dart';

class ProfileQRCodePage extends StatefulWidget {
  const ProfileQRCodePage({super.key});

  @override
  State<ProfileQRCodePage> createState() => _ProfileQRCodePageState();
}

class _ProfileQRCodePageState extends State<ProfileQRCodePage> {
  int _selectedTab = 0; // 0 = Connect, 1 = Add to Contact

  String jsonEncode(Map<String, dynamic> data) {
    return json.encode(data);
  }

  // Function to generate QR data for CONNECT tab - सिर्फ ID के लिए
  String _generateConnectQrData(Map<String, dynamic> userData) {
    final data = {
      // 'id': userData['id']?.toString() ?? '',
      'user_name': userData['user_name']?.toString() ?? '',
      'type': 'gridcard_connect',
      'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
    };
    return jsonEncode(data);
  }

  // Function to generate QR data for ADD TO CONTACT tab - Full data
  String _generateContactQrData(Map<String, dynamic> userData) {
    final data = {
      'id': userData['id']?.toString() ?? '',
      'user_mobile': userData['user_mobile']?.toString() ?? '',
      'email': userData['email']?.toString() ?? '',
      'fname': userData['master_user']?['fname']?.toString() ?? '',
      'type': 'gridcard_contact',
      'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
    };
    return jsonEncode(data);
  }

  // Get appropriate QR data based on selected tab
  String _getQrData(Map<String, dynamic> userData) {
    if (_selectedTab == 0) {
      return _generateConnectQrData(userData);
    } else {
      return _generateContactQrData(userData);
    }
  }

  // Get title based on selected tab
  String _getTitle() {
    return _selectedTab == 0 ? 'Scan to Connect' : 'Add to Contact';
  }

  // Get description based on selected tab
  String _getDescription() {
    return _selectedTab == 0
        ? 'Scan to connect using user ID'
        : 'Share this QR code to save contact details';
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
      'user_name': user.userName,
      'email': user.email,
      'fname': user.masterUser?.fname,
      'master_user': user.masterUser?.toJson(),
    };

    debugPrint('========== USER DATA ==========');
    debugPrint(jsonEncode(userData));
    debugPrint('================================');

    final qrData = _getQrData(userData);
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

                      // Tab Selection
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          children: [
                            // Connect Tab (ID only)
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedTab = 0;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: _selectedTab == 0
                                        ? Colors.blue
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Online QR Code',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: _selectedTab == 0
                                            ? Colors.white
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Add to Contact Tab (Full data)
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedTab = 1;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: _selectedTab == 1
                                        ? Colors.blue
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Offline QR Code',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: _selectedTab == 1
                                            ? Colors.white
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                ),
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
                            Text(
                              _getTitle(),
                              style: const TextStyle(
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
                              _getDescription(),
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
                              _selectedTab == 0
                                  ? 'Scan to connect using user ID'
                                  : 'Scan to save contact details',
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
                        _showScanDialog(context, _selectedTab);
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

  void _showScanDialog(BuildContext context, int selectedTab) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QRScannerPage(
          onScanComplete: (scannedData) {
            _handleScannedData(context, scannedData, selectedTab);
          },
        ),
      ),
    );
  }

// New method to show contact save dialog
  void _showContactSaveDialog(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Scanned'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data['fname'] != null) Text('Name: ${data['fname']}'),
            if (data['name'] != null) Text('Name: ${data['name']}'),
            if (data['user_mobile'] != null)
              Text('Phone: ${data['user_mobile']}'),
            if (data['mobile'] != null) Text('Phone: ${data['mobile']}'),
            if (data['email'] != null) Text('Email: ${data['email']}'),
            const SizedBox(height: 16),
            const Text('This contact can be saved to your phone.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to scanner page for saving
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => QRScannerPage(
                    onScanComplete: (scannedData) {
                      // This will trigger the automatic contact save in QRScannerPage
                    },
                  ),
                ),
              );
            },
            child: const Text('Save to Phone'),
          ),
        ],
      ),
    );
  }

  void _handleScannedData(
      BuildContext context, Map<String, dynamic> data, int selectedTab) {
    // Check if this is a contact QR code (Add to Contact tab)
    if (selectedTab == 1) {
      // Show contact save dialog directly
      _showContactSaveDialog(context, data);
    } else {
      // For Connect tab, show regular dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Connection ID Scanned'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (data['id'] != null) Text('User ID: ${data['id']}'),
              const SizedBox(height: 16),
              const Text('Do you want to connect using this ID?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Connection request sent successfully!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Connect'),
            ),
          ],
        ),
      );
    }
  }

  void _shareQrCode(BuildContext context, String qrData, String userName) {
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
