import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import 'package:gridcard/core/services/auth_provider.dart';
import 'package:gridcard/routes/route_names.dart';

class PinPage extends StatefulWidget {
  final bool isSetup; // true for setting a new PIN, false for logging in
  final String mobile;

  const PinPage({
    super.key,
    required this.isSetup,
    required this.mobile,
  });

  @override
  State<PinPage> createState() => _PinPageState();
}

class _PinPageState extends State<PinPage> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handlePinSubmit(String pin) async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final auth = context.read<AuthProvider>();
    bool success;

    if (widget.isSetup) {
      success = await auth.setPin(widget.mobile, pin);
    } else {
      success = await auth.loginWithPin(widget.mobile, pin);
    }

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      Navigator.pushNamedAndRemoveUntil(
          context, RouteNames.home, (route) => false);
    } else {
      setState(() {
        _errorText =
            widget.isSetup ? "Failed to set PIN." : "Invalid PIN. Try again.";
        _pinController.clear();
        _focusNode.requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 60,
      height: 60,
      textStyle: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              const Color(0xFF02bdb9).withValues(alpha: 0.1),
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(height: 20),
                Icon(
                  widget.isSetup
                      ? Icons.lock_open_rounded
                      : Icons.lock_person_rounded,
                  size: 64,
                  color: const Color(0xFF02bdb9),
                ),
                const SizedBox(height: 24),
                Text(
                  widget.isSetup ? "Create Your PIN" : "Enter Secure PIN",
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.isSetup
                      ? "Set a 4-digit PIN to secure your account."
                      : "Enter your 4-digit PIN to access your dashboard.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60, fontSize: 16),
                ),
                const SizedBox(height: 60),
                Pinput(
                  length: 4,
                  controller: _pinController,
                  focusNode: _focusNode,
                  defaultPinTheme: defaultPinTheme,
                  obscureText: true,
                  separatorBuilder: (index) => const SizedBox(width: 16),
                  onCompleted: _handlePinSubmit,
                  hapticFeedbackType: HapticFeedbackType.lightImpact,
                  focusedPinTheme: defaultPinTheme.copyWith(
                    decoration: defaultPinTheme.decoration!.copyWith(
                      border: Border.all(color: const Color(0xFF02bdb9)),
                    ),
                  ),
                  errorPinTheme: defaultPinTheme.copyWith(
                    decoration: defaultPinTheme.decoration!.copyWith(
                      border: Border.all(color: Colors.redAccent),
                    ),
                  ),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    _errorText!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
                const Spacer(),
                if (_isLoading)
                  const CircularProgressIndicator(color: Color(0xFF02bdb9))
                else if (!widget.isSetup)
                  TextButton(
                    onPressed: () {
                      // Trigger forgot PIN flow if needed
                    },
                    child: const Text(
                      "Forgot PIN?",
                      style: TextStyle(color: Color(0xFF02bdb9)),
                    ),
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
