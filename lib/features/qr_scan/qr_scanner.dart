// import 'dart:io';
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:mobile_scanner/mobile_scanner.dart';
// import 'package:image_picker/image_picker.dart';

// class QRScannerPage extends StatefulWidget {
//   final Function(Map<String, dynamic>)? onScanComplete;
  
//   const QRScannerPage({super.key, this.onScanComplete});

//   @override
//   State<QRScannerPage> createState() => _QRScannerPageState();
// }

// class _QRScannerPageState extends State<QRScannerPage> {
//   MobileScannerController cameraController = MobileScannerController(
//     torchEnabled: false,
//   );
  
//   bool _isTorchOn = false;
//   bool _isLoading = false;
//   String? _lastScannedData;

//   @override
//   void dispose() {
//     cameraController.dispose();
//     super.dispose();
//   }

//   Future<void> _toggleTorch() async {
//     try {
//       await cameraController.toggleTorch();
//       setState(() {
//         _isTorchOn = !_isTorchOn;
//       });
//     } catch (e) {
//       debugPrint('Error toggling torch: $e');
//     }
//   }

//   void _processScannedData(String data) {
//     if (_lastScannedData == data) return;
    
//     _lastScannedData = data;
    
//     try {
//       // Try to parse as JSON
//       final jsonData = jsonDecode(data);
//       _showScanResult(jsonData);
//     } catch (e) {
//       // If not JSON, show raw data
//       _showScanResult({'raw_data': data});
//     }
//   }

//   Future<void> _pickAndScanImage() async {
//     setState(() => _isLoading = true);
    
//     try {
//       final ImagePicker picker = ImagePicker();
//       final XFile? image = await picker.pickImage(
//         source: ImageSource.gallery,
//         imageQuality: 85,
//       );

//       if (image != null) {
//         final File imageFile = File(image.path);
//         final BarcodeCapture? capture = await cameraController.analyzeImage(imageFile.path);
        
//         if (capture != null && capture.barcodes.isNotEmpty) {
//           for (final barcode in capture.barcodes) {
//             if (barcode.rawValue != null) {
//               _processScannedData(barcode.rawValue!);
//               break;
//             }
//           }
//         } else {
//           _showErrorDialog('No QR code found in the selected image');
//         }
//       }
//     } catch (e) {
//       debugPrint('Error picking image: $e');
//       _showErrorDialog('Error scanning image: $e');
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   void _showScanResult(Map<String, dynamic> data) {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => AlertDialog(
//         title: const Text('QR Code Scanned'),
//         content: SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               if (data['fname'] != null) 
//                 _buildInfoRow('Name:', data['fname']),
//               if (data['user_mobile'] != null) 
//                 _buildInfoRow('Mobile:', data['user_mobile']),
//               if (data['email'] != null) 
//                 _buildInfoRow('Email:', data['email']),
//               if (data['id'] != null) 
//                 _buildInfoRow('ID:', data['id'].toString()),
              
//               const SizedBox(height: 16),
//               const Divider(),
//               const SizedBox(height: 8),
//               const Text(
//                 'Raw Data:',
//                 style: TextStyle(fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 4),
//               Container(
//                 padding: const EdgeInsets.all(8),
//                 decoration: BoxDecoration(
//                   color: Colors.grey[100],
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Text(
//                   data.toString(),
//                   style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Scan Again'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               if (widget.onScanComplete != null) {
//                 widget.onScanComplete!(data);
//               }
//               Navigator.pop(context);
//               Navigator.pop(context);
//             },
//             child: const Text('Save Contact'),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildInfoRow(String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           SizedBox(
//             width: 70,
//             child: Text(
//               label,
//               style: const TextStyle(fontWeight: FontWeight.w500),
//             ),
//           ),
//           Expanded(
//             child: Text(
//               value,
//               style: TextStyle(color: Colors.grey[700]),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showErrorDialog(String message) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Error'),
//         content: Text(message),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('OK'),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Scan QR Code'),
//         centerTitle: true,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back),
//           onPressed: () => Navigator.pop(context),
//         ),
//         actions: [
//           IconButton(
//             icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off),
//             onPressed: _toggleTorch,
//             tooltip: _isTorchOn ? 'Turn off torch' : 'Turn on torch',
//           ),
//         ],
//       ),
//       body: Stack(
//         children: [
//           // QR Scanner View
//           MobileScanner(
//             controller: cameraController,
//             onDetect: (capture) {
//               final List<Barcode> barcodes = capture.barcodes;
//               for (final barcode in barcodes) {
//                 if (barcode.rawValue != null) {
//                   _processScannedData(barcode.rawValue!);
//                   break;
//                 }
//               }
//             },
//           ),

//           // Scanner Overlay
//           _buildScannerOverlay(),

//           // Loading Indicator
//           if (_isLoading)
//             Container(
//               color: Colors.black54,
//               child: const Center(
//                 child: CircularProgressIndicator(
//                   color: Colors.white,
//                 ),
//               ),
//             ),
//         ],
//       ),
//       bottomNavigationBar: _buildBottomButtons(),
//     );
//   }

//   Widget _buildScannerOverlay() {
//     return Center(
//       child: Container(
//         width: 250,
//         height: 250,
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(20),
//           border: Border.all(
//             color: Colors.white,
//             width: 3,
//           ),
//         ),
//         child: Column(
//           children: [
//             Expanded(
//               child: Container(
//                 decoration: const BoxDecoration(
//                   border: Border(
//                     right: BorderSide(color: Colors.white, width: 2),
//                     bottom: BorderSide(color: Colors.white, width: 2),
//                   ),
//                 ),
//               ),
//             ),
//             Container(
//               height: 2,
//               color: Colors.white,
//             ),
//             Expanded(
//               child: Container(
//                 decoration: const BoxDecoration(
//                   border: Border(
//                     left: BorderSide(color: Colors.white, width: 2),
//                     top: BorderSide(color: Colors.white, width: 2),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildBottomButtons() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       color: Colors.black87,
//       child: Row(
//         children: [
//           Expanded(
//             child: ElevatedButton.icon(
//               onPressed: _pickAndScanImage,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.blue,
//                 foregroundColor: Colors.white,
//                 padding: const EdgeInsets.symmetric(vertical: 16),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//               ),
//               icon: const Icon(Icons.upload_file),
//               label: const Text(
//                 'Upload QR',
//                 style: TextStyle(fontSize: 16),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }


import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';

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
        final BarcodeCapture? capture = await cameraController.analyzeImage(imageFile.path);
        
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

  void _showScanResult(Map<String, dynamic> data) {
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
              if (data['fname'] != null) 
                _buildInfoRow('Name:', data['fname']),
              if (data['user_mobile'] != null) 
                _buildInfoRow('Mobile:', data['user_mobile']),
              if (data['email'] != null) 
                _buildInfoRow('Email:', data['email']),
              if (data['id'] != null) 
                _buildInfoRow('ID:', data['id'].toString()),
              
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
            child: const Text('Save Contact'),
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
        // Torch button removed from here
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