// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:gridcard/core/services/auth_provider.dart';
// import 'package:provider/provider.dart';

// class ChangePinPage extends StatefulWidget {
//   const ChangePinPage({super.key});

//   @override
//   State<ChangePinPage> createState() => _ChangePinPageState();
// }

// class _ChangePinPageState extends State<ChangePinPage> {
//   final _formKey = GlobalKey<FormState>();
//   final _oldPinController = TextEditingController();
//   final _newPinController = TextEditingController();
//   final _confirmPinController = TextEditingController();

//   Future<void> _updatePin() async {
//     if (!_formKey.currentState!.validate()) return;

//     final authProvider = context.read<AuthProvider>();
//     // Assuming authProvider or AuthService handles PIN updates
//     // For now we use the logic that might be in AuthService.setPin
//     final success = await authProvider.updatePin(
//         _oldPinController.text, _newPinController.text);

//     if (mounted && success) {
//       ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text("PIN updated successfully")));
//       Navigator.pop(context);
//     } else if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
//           content:
//               Text("Failed to update PIN. Please check your current PIN.")));
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         title: const Text("Change PIN", style: TextStyle(color: Colors.white)),
//         backgroundColor: Colors.black,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(24.0),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               const Text(
//                   "Enter your current and new PIN to keep your account secure.",
//                   style: TextStyle(color: Colors.white70)),
//               const SizedBox(height: 32),
//               _buildPinField(_oldPinController, "Current PIN"),
//               const SizedBox(height: 16),
//               _buildPinField(_newPinController, "New PIN"),
//               const SizedBox(height: 16),
//               _buildPinField(_confirmPinController, "Confirm New PIN",
//                   validator: (val) {
//                 if (val != _newPinController.text) return "PINs do not match";
//                 return null;
//               }),
//               const Spacer(),
//               ElevatedButton(
//                 onPressed: _updatePin,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.blueAccent,
//                   padding: const EdgeInsets.symmetric(vertical: 16),
//                   shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12)),
//                 ),
//                 child: const Text("Update PIN",
//                     style: TextStyle(
//                         color: Colors.white, fontWeight: FontWeight.bold)),
//               ),
//               const SizedBox(height: 20),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildPinField(TextEditingController controller, String label,
//       {String? Function(String?)? validator}) {
//     return TextFormField(
//       controller: controller,
//       obscureText: true,
//       keyboardType: TextInputType.number,
//       maxLength: 4,
//       style:
//           const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 8),
//       textAlign: TextAlign.center,
//       decoration: InputDecoration(
//         labelText: label,
//         labelStyle: const TextStyle(color: Colors.white38, letterSpacing: 0),
//         counterText: "",
//         filled: true,
//         fillColor: Colors.grey[900],
//         border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(12),
//             borderSide: BorderSide.none),
//       ),
//       validator: validator ??
//           (val) =>
//               (val == null || val.length < 4) ? "PIN must be 4 digits" : null,
//     );
//   }
// }

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/core/services/auth_provider.dart';
import 'package:provider/provider.dart';

class ChangePinPage extends StatefulWidget {
  const ChangePinPage({super.key});

  @override
  State<ChangePinPage> createState() => _ChangePinPageState();
}

class _ChangePinPageState extends State<ChangePinPage> {
  final _formKey = GlobalKey<FormState>();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  Future<void> _updatePin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();

    // Now only new PIN is sent
    final success = await authProvider.updatePin("", _newPinController.text);

    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("PIN updated successfully")));
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Failed to update PIN.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Change PIN", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("Enter your new PIN to keep your account secure.",
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 32),
              _buildPinField(_newPinController, "New PIN"),
              const SizedBox(height: 16),
              _buildPinField(_confirmPinController, "Confirm New PIN",
                  validator: (val) {
                if (val != _newPinController.text) return "PINs do not match";
                return null;
              }),
              const Spacer(),
              ElevatedButton(
                onPressed: _updatePin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Update PIN",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinField(TextEditingController controller, String label,
      {String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: 4,
      style:
          const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 8),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38, letterSpacing: 0),
        counterText: "",
        filled: true,
        fillColor: Colors.grey,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      ),
      validator: validator ??
          (val) =>
              (val == null || val.length < 4) ? "PIN must be 4 digits" : null,
    );
  }
}
