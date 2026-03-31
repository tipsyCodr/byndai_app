import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ Add this import for Clipboard
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import '../../core/services/profile_provider.dart';
import '../../core/services/auth_provider.dart';
import 'package:provider/provider.dart';
import 'qr_scan_view_profile.dart';
import 'package:gridcard/widgets/top_alert.dart';

class QRScannerPage extends StatefulWidget {
  final Function(Map<String, dynamic>)? onScanComplete;

  const QRScannerPage({super.key, this.onScanComplete});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  MobileScannerController cameraController = MobileScannerController();

  bool _isLoading = false;
  String? _lastScannedData;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _processScannedData(String data) {
    if (_lastScannedData == data) return;

    _lastScannedData = data;

    try {
      // Try to parse as JSON
      final jsonData = jsonDecode(data);
      _showScanResult(jsonData);
    } catch (e) {
      // If not JSON, show raw data
      _showScanResult({'raw_data': data});
    }
  }

  void _showMessageAndGoBack(String message, {bool isSuccess = false}) {
    // Snackbar show
    TopAlert.show(context, message, isSuccess: isSuccess);

    // 1 sec baad auto back
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.pop(context); // 🔥 QR Scanner close
      }
    });
  }

  Future<void> _pickAndScanImage() async {
    setState(() => _isLoading = true);

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        final File imageFile = File(image.path);
        final BarcodeCapture? capture =
            await cameraController.analyzeImage(imageFile.path);

        if (capture != null && capture.barcodes.isNotEmpty) {
          for (final barcode in capture.barcodes) {
            if (barcode.rawValue != null) {
              _processScannedData(barcode.rawValue!);
              break;
            }
          }
        } else {
          _showErrorDialog('No QR code found in the selected image');
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      _showErrorDialog('Error scanning image: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openNativeContactApp(Map<String, dynamic> data) async {
    try {
      String? name = data['fname'] ?? data['name'];
      String? mobile = data['user_mobile'] ?? data['mobile'];
      String? email = data['email'];

      if (name == null || mobile == null) {
        _showErrorDialog('Name & Mobile required');
        return;
      }

      if (!await fc.FlutterContacts.requestPermission()) {
        _showErrorDialog('Contact permission denied');
        return;
      }

      final newContact = fc.Contact()
        ..name.first = name
        ..phones = [fc.Phone(mobile)]
        ..emails = email != null ? [fc.Email(email)] : [];

      await fc.FlutterContacts.openExternalInsert(newContact);
    } catch (e) {
      debugPrint('Contact open error: $e');
      _showErrorDialog('Unable to open contact app');
    }
  }

  // Simple dialog to show contact info and copy options
  void _showSimpleContactSaveDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Contact Information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (data['fname'] != null || data['name'] != null)
                _buildContactInfoRow('Name', data['fname'] ?? data['name']),
              if (data['user_mobile'] != null || data['mobile'] != null)
                _buildContactInfoRow(
                    'Mobile', data['user_mobile'] ?? data['mobile']),
              if (data['email'] != null)
                _buildContactInfoRow('Email', data['email']),
              if (data['id'] != null)
                _buildContactInfoRow('ID', data['id'].toString()),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Copy the information below and add to your contacts manually:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              // Copy contact details to clipboard
              String contactText = '';
              if (data['fname'] != null || data['name'] != null) {
                contactText += 'Name: ${data['fname'] ?? data['name']}\n';
              }
              if (data['user_mobile'] != null || data['mobile'] != null) {
                contactText +=
                    'Mobile: ${data['user_mobile'] ?? data['mobile']}\n';
              }
              if (data['email'] != null) {
                contactText += 'Email: ${data['email']}\n';
              }

              Clipboard.setData(ClipboardData(text: contactText));
              TopAlert.show(context, 'Contact details copied to clipboard',
                  isSuccess: true);
              Navigator.pop(context);
            },
            child: const Text('Copy Details'),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              TopAlert.show(context, '$label copied to clipboard',
                  isSuccess: true);
            },
          ),
        ],
      ),
    );
  }

  void _showProfileCardDialog(Map<String, dynamic> data) {
    final String name = data['fname'] ?? 'N/A';
    final String email = data['email_one'] ?? data['user']?['email'] ?? 'N/A';
    final String mobile =
        data['mobile_one'] ?? data['user']?['user_mobile'] ?? 'N/A';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85, // 🔥 width increased
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              /// 🔹 Avatar
              CircleAvatar(
                radius: 45,
                backgroundColor: Colors.blue.shade100,
                child: const Icon(
                  Icons.person,
                  size: 50,
                  color: Colors.blue,
                ),
              ),

              const SizedBox(height: 12),

              /// 🔹 Name
              Text(
                name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 4),

              /// 🔹 Email
              Text(
                email,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              /// 🔹 Mobile Row
              _profileInfoRow(Icons.phone, mobile),

              const SizedBox(height: 24),

              /// 🔹 Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);

                        debugPrint('📨 Send Request clicked');
                        debugPrint('➡️ User ID: ${data['user_id']}');

                        // 🔥 future me yahan API call lagegi
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Send Request'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileInfoRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _profileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  void _showScanResult(Map<String, dynamic> data) async {
    final type = data['type'];

    // 🔹 OFFLINE QR → Contact Save
    if (type == 'gridcard_contact' ||
        (data['fname'] != null && data['user_mobile'] != null)) {
      _showContactSaveOptions(data);
      return;
    }

    // 🔹 ONLINE QR → API CALL

 

    if (type == 'gridcard_connect' && data['user_name'] != null) {
      final userName = data['user_name'].toString();

      final profileProvider =
          Provider.of<ProfileProvider>(context, listen: false);

      final success =
          await profileProvider.fetchUserProfileByUsername(userName);
      print("API Success Status: $success");
      if (!mounted) return;

      if (success && profileProvider.profileData != null) {
        final profileData = profileProvider.profileData!;
        print("PROFILE DATA JSON:");
        print(jsonEncode(profileData));

        final authUser = Provider.of<AuthProvider>(context, listen: false).user;

        final currentUserId = authUser?.id?.toString();
        final scannedUserId = profileData['user_id']?.toString();

        // ✅ 1. SAME USER CHECK
        // if (currentUserId == scannedUserId) {
        //   _showErrorDialog("❌ You can't connect with yourself");
        //   return;
        // }

        if (currentUserId == scannedUserId) {
          _showMessageAndGoBack("❌ You can't connect with yourself");
          return;
        }

        // ✅ 2. CONNECTION STATUS CHECK (Backend se aana chahiye)
        final connectionStatus = profileData['connection_status'];

        // if (connectionStatus == 'connected') {
        //   _showErrorDialog("✅ Already connected");
        //   return;
        // }

        if (connectionStatus == 'connected') {
          _showMessageAndGoBack("✅ Already connected", isSuccess: true);
          return;
        }

        // if (connectionStatus == 'pending') {
        //   _showErrorDialog("⏳ Request already sent");
        //   return;
        // }

        if (connectionStatus == 'pending') {
          _showMessageAndGoBack("⏳ Request already sent");
          return;
        }

        // ✅ 3. OPEN PROFILE SCREEN (sab sahi hai)
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QRScanViewProfile(
              receiverId: profileData['user_id']?.toString() ?? '',
              name: profileData['fname'] ??
                  profileData['master_user']?['fname'] ??
                  'N/A',
              mobile: profileData['mobile_one'] ??
                  profileData['master_user']?['mobile_one'] ??
                  'N/A',
              email: profileData['email_one'] ??
                  profileData['master_user']?['email_one'] ??
                  'N/A',
              senderId: authUser?.id?.toString() ?? '',
              senderName: authUser?.masterUser?.fname ?? '',
              profilePic: profileData['profile_pic'] ?? '',
              profileLogo: profileData['profile_logo'] ?? '',
              legalName:
                  profileData['business_info']?['legal_name'] ?? '',
              industryTitle: profileData['business_info']?['industry']?['title'] ?? '',
            ),
          ),
        );

        if (result == true && mounted) {
          TopAlert.show(context, '✅ Connection request sent successfully',
              isSuccess: true);

          Navigator.pop(context);
        }
      } else {
        _showErrorDialog('Profile not found');
      }

      return;
    }

    // 🔹 Fallback
    _showRegularScanDialog(data);
  }

  void _showContactSaveOptions(Map<String, dynamic> data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Contact Detected'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (data['fname'] != null || data['name'] != null)
                Text('Name: ${data['fname'] ?? data['name']}'),
              if (data['user_mobile'] != null || data['mobile'] != null)
                Text('Mobile: ${data['user_mobile'] ?? data['mobile']}'),
              if (data['email'] != null) Text('Email: ${data['email']}'),
              const SizedBox(height: 16),
              const Text('How would you like to save this contact?'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showRegularScanDialog(data);
            },
            child: const Text('View Details'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _openNativeContactApp(data);

              // Call onScanComplete callback
              if (widget.onScanComplete != null) {
                widget.onScanComplete!(data);
              }
            },
            child: const Text('Add to Contacts'),
          ),
        ],
      ),
    );
  }

  void _showRegularScanDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('QR Code Scanned'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (data['fname'] != null) _buildInfoRow('Name:', data['fname']),
              if (data['name'] != null) _buildInfoRow('Name:', data['name']),
              if (data['user_mobile'] != null)
                _buildInfoRow('Mobile:', data['user_mobile']),
              if (data['mobile'] != null)
                _buildInfoRow('Mobile:', data['mobile']),
              if (data['email'] != null) _buildInfoRow('Email:', data['email']),
              if (data['id'] != null)
                _buildInfoRow('ID:', data['id'].toString()),
              if (data['type'] != null) _buildInfoRow('Type:', data['type']),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Raw Data:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  data.toString(),
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Scan Again'),
          ),
          ElevatedButton(
            onPressed: () {
              if (widget.onScanComplete != null) {
                widget.onScanComplete!(data);
              }
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // QR Scanner View
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _processScannedData(barcode.rawValue!);
                  break;
                }
              }
            },
          ),

          // Scanner Overlay
          _buildScannerOverlay(),

          // Loading Indicator
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomButtons(),
    );
  }

  Widget _buildScannerOverlay() {
    return Center(
      child: Container(
        width: 250,
        height: 250,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white,
            width: 3,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Colors.white, width: 2),
                    bottom: BorderSide(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ),
            Container(
              height: 2,
              color: Colors.white,
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Colors.white, width: 2),
                    top: BorderSide(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.black87,
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _pickAndScanImage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.upload_file),
              label: const Text(
                'Upload QR',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
