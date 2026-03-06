import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:gridcard/core/services/auth_provider.dart';
import 'package:gridcard/core/services/auth_service.dart';
import 'package:gridcard/routes/route_names.dart';
import 'package:gridcard/widgets/secure_input_dialog.dart';
import 'package:gridcard/widgets/top_alert.dart';
import 'package:provider/provider.dart';

/// Registration page for Google Sign-In users.
/// Step 1: Prefilled form (name, email, username, password)
/// Step 2: Mobile number + OTP verification
class GoogleRegisterPage extends StatefulWidget {
  const GoogleRegisterPage({super.key});

  @override
  State<GoogleRegisterPage> createState() => _GoogleRegisterPageState();
}

class _GoogleRegisterPageState extends State<GoogleRegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();

  final FocusNode _usernameFocusNode = FocusNode();

  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  // Step tracking: 0 = form, 1 = mobile + OTP
  int _currentStep = 0;

  // Username state
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;
  String? _usernameMessage;

  @override
  void initState() {
    super.initState();

    // Prefill from Google data
    final auth = context.read<AuthProvider>();
    final googleData = auth.googleSignInData;
    if (googleData != null) {
      _nameController.text = googleData['name'] ?? '';
      _emailController.text = googleData['email'] ?? '';
    }

    _usernameFocusNode.addListener(() {
      if (!_usernameFocusNode.hasFocus) {
        _checkUsername();
      }
    });
  }

  @override
  void dispose() {
    _usernameFocusNode.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ================= USERNAME CHECK =================

  Future<void> _checkUsername() async {
    final username = _usernameController.text.trim();

    if (username.length < 4) {
      setState(() {
        _isUsernameAvailable = null;
        _usernameMessage = null;
      });
      return;
    }

    setState(() => _isCheckingUsername = true);

    final auth = context.read<AuthProvider>();
    final available = await auth.checkUsernameAvailability(username);

    if (!mounted) return;

    setState(() {
      _isCheckingUsername = false;
      _isUsernameAvailable = available;
      _usernameMessage =
          available ? "Username available" : "Username already exists";
    });
  }

  // ================= STEP 1: FORM SUBMIT =================

  void _onFormNext() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isUsernameAvailable != true) {
      _checkUsername();
      return;
    }

    setState(() => _currentStep = 1);
  }

  // ================= STEP 2: MOBILE + OTP =================

  void _showTopRightMessage(
    String message, {
    bool isSuccess = false,
    bool isError = false,
  }) {
    if (!mounted) return;
    TopAlert.show(context, message, isSuccess: isSuccess, isError: isError);
  }

  void _showLoaderDialog() {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) => const Center(
        child: SpinKitPulsingGrid(
          color: Color.fromARGB(255, 92, 165, 225),
          size: 60.0,
        ),
      ),
    );
  }

  void _sendOtp() async {
    final mobile = _phoneController.text.trim();
    if (mobile.length != 10) {
      TopAlert.show(context, "Please enter a valid 10-digit mobile number",
          isError: true);
      return;
    }

    FocusScope.of(context).unfocus();
    _showLoaderDialog();

    final auth = context.read<AuthProvider>();
    final success = await auth.getOTP(mobile, isNewUser: true);

    if (!mounted) return;
    Navigator.pop(context); // Dismiss loader

    if (success) {
      _showTopRightMessage("OTP sent successfully");
      await _promptOtpEntry(mobile);
    } else {
      _showTopRightMessage("Failed to send OTP", isError: true);
    }
  }

  Future<void> _promptOtpEntry(String mobile) async {
    await showDialog(
      context: context,
      builder: (_) => SecureInputDialog(
        type: SecureInputType.otp,
        title: "Enter OTP",
        description: "OTP sent to +91 $mobile",
        onSubmit: (otp) => _verifyOtpAndRegister(mobile, otp),
      ),
    );
  }

  Future<bool> _verifyOtpAndRegister(String mobile, String otp) async {
    if (otp.length != 4) {
      TopAlert.show(context, "Enter a valid 4-digit OTP", isError: true);
      return false;
    }

    _showLoaderDialog();
    final auth = context.read<AuthProvider>();
    final otpSuccess = await auth.verifyOTP(mobile, otp);

    if (!mounted) return false;
    Navigator.pop(context); // Dismiss loader

    if (!otpSuccess) {
      _showTopRightMessage("OTP verification failed", isError: true);
      return false;
    }

    _showTopRightMessage("OTP verified successfully", isSuccess: true);

    // Now register with all data
    _showLoaderDialog();

    final googleData = auth.googleSignInData;
    final registerData = {
      'name': _nameController.text.trim(),
      'user_name': _usernameController.text.trim(),
      'email': _emailController.text.trim(),
      'password': _passwordController.text.trim(),
      'mobile': mobile,
      'id_token': googleData?['id_token'] ?? '',
    };

    final registerSuccess = await auth.registerGoogleUser(registerData);

    if (!mounted) return false;
    Navigator.pop(context); // Dismiss loader

    if (registerSuccess) {
      _showTopRightMessage("Registration successful!", isSuccess: true);

      // Navigate to home after a brief delay
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return true;

      Navigator.pushNamedAndRemoveUntil(context, RouteNames.home, (_) => false);
      return true;
    } else {
      final errorMsg = AuthService.lastError ?? 'Registration failed';
      _showTopRightMessage(errorMsg, isError: true);
      return false;
    }
  }

  // ================= BUILD =================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep == 1) {
              setState(() => _currentStep = 0);
            } else {
              final auth = context.read<AuthProvider>();
              auth.clearGoogleSignInData();
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _currentStep == 0 ? _buildFormStep(cs) : _buildMobileStep(cs),
        ),
      ),
    );
  }

  // ================= STEP 1: FORM =================

  Widget _buildFormStep(ColorScheme cs) {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('form_step'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Complete Your Profile",
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "We got your info from Google. Fill in the remaining details.",
            style: TextStyle(
              color: cs.onSurface.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),

          // Name (prefilled, editable)
          TextFormField(
            controller: _nameController,
            decoration: _inputDecoration("Full Name", Icons.person),
            validator: (v) => v == null || v.isEmpty ? "Enter name" : null,
          ),
          const SizedBox(height: 20),

          // Username
          TextFormField(
            controller: _usernameController,
            focusNode: _usernameFocusNode,
            decoration: _inputDecoration(
              "Username",
              Icons.alternate_email,
              borderColor: _isUsernameAvailable == false ? Colors.red : null,
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return "Enter username";
              if (v.length < 4) return "Minimum 4 characters";
              return null;
            },
          ),
          if (_isCheckingUsername) const LinearProgressIndicator(minHeight: 2),
          if (_usernameMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _usernameMessage!,
                style: TextStyle(
                  color:
                      _isUsernameAvailable == true ? Colors.green : Colors.red,
                  fontSize: 13,
                ),
              ),
            ),
          const SizedBox(height: 20),

          // Email (prefilled, read-only)
          TextFormField(
            controller: _emailController,
            decoration: _inputDecoration("Email", Icons.email).copyWith(
              filled: true,
              fillColor: cs.onSurface.withOpacity(0.05),
            ),
            readOnly: true,
            style: TextStyle(color: cs.onSurface.withOpacity(0.6)),
          ),
          const SizedBox(height: 20),

          // Password
          TextFormField(
            controller: _passwordController,
            obscureText: !_passwordVisible,
            decoration: _inputDecoration("Password", Icons.lock).copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                    _passwordVisible ? Icons.visibility : Icons.visibility_off),
                onPressed: () =>
                    setState(() => _passwordVisible = !_passwordVisible),
              ),
            ),
            validator: (v) => v != null && v.length >= 6 ? null : "Min 6 chars",
          ),
          const SizedBox(height: 20),

          // Confirm Password
          TextFormField(
            controller: _confirmController,
            obscureText: !_confirmPasswordVisible,
            decoration: _inputDecoration("Confirm Password", Icons.lock_outline)
                .copyWith(
              suffixIcon: IconButton(
                icon: Icon(_confirmPasswordVisible
                    ? Icons.visibility
                    : Icons.visibility_off),
                onPressed: () => setState(
                    () => _confirmPasswordVisible = !_confirmPasswordVisible),
              ),
            ),
            validator: (v) =>
                v == _passwordController.text ? null : "Passwords mismatch",
          ),
          const SizedBox(height: 30),

          // Next Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _onFormNext,
              child: const Text("Next", style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }

  // ================= STEP 2: MOBILE =================

  Widget _buildMobileStep(ColorScheme cs) {
    return Column(
      key: const ValueKey('mobile_step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Verify Your Mobile",
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          "Enter your mobile number to receive an OTP for verification.",
          style: TextStyle(
            color: cs.onSurface.withOpacity(0.6),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                "🇮🇳 +91",
                style: TextStyle(fontSize: 16, color: cs.onPrimary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                onSubmitted: (value) {
                  if (value.trim().length == 10) {
                    _sendOtp();
                  }
                },
                decoration: InputDecoration(
                  hintText: "Mobile Number",
                  prefixIcon: Icon(Icons.phone, color: cs.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: _sendOtp,
            style: FilledButton.styleFrom(
              backgroundColor: cs.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: Text("Send OTP",
                style: TextStyle(fontSize: 18, color: cs.onPrimary)),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(
    String label,
    IconData icon, {
    Color? borderColor,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor ?? Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor ?? Colors.blue),
      ),
    );
  }
}
