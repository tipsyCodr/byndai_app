import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:gridcard/core/services/auth_provider.dart';
import 'package:gridcard/core/services/auth_service.dart';
import 'package:gridcard/routes/route_names.dart';
import 'package:gridcard/widgets/secure_input_dialog.dart';
import 'package:gridcard/widgets/top_alert.dart';
import 'package:provider/provider.dart';
import 'package:gridcard/widgets/glass_box.dart';

/// Registration page for Google Sign-In users.
/// Step 1: Prefilled form (name, email, username)
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
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();

  final FocusNode _usernameFocusNode = FocusNode();

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
    final cs = Theme.of(context).colorScheme;
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) => Center(
        child: SpinKitPulse(
          color: cs.primary,
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

    // 1. Check if mobile is already registered
    final isRegistered = await auth.isRegistered(mobile);
    if (!mounted) return;

    if (isRegistered) {
      Navigator.pop(context); // Dismiss loader
      _showTopRightMessage("Mobile number already registered", isError: true);
      return;
    }

    // 2. If not registered, send OTP
    final success = await auth.getOTP(mobile, isNewUser: true);

    if (!mounted) return;
    Navigator.pop(context); // Dismiss loader

    if (success) {
      _showTopRightMessage("OTP sent successfully");
      await _promptOtpEntry(mobile);
    } else {
      final errorMsg = AuthService.lastError ?? "Failed to send OTP";
      _showTopRightMessage(errorMsg, isError: true);
    }
  }

  Future<void> _promptOtpEntry(String mobile) async {
    final success = await showDialog<bool>(
      context: context,
      builder: (_) => SecureInputDialog(
        type: SecureInputType.otp,
        title: "Enter OTP",
        description: "OTP sent to +91 $mobile",
        onSubmit: (otp) => _verifyOtpAndRegister(mobile, otp),
      ),
    );

    if (success == true && mounted) {
      Navigator.pushNamedAndRemoveUntil(context, RouteNames.home, (_) => false);
    }
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
      'password': "", // Password not needed
      'mobile': mobile,
      'id_token': googleData?['id_token'] ?? '',
    };

    final registerSuccess = await auth.registerGoogleUser(registerData);

    if (!mounted) return false;
    Navigator.pop(context); // Dismiss loader

    if (registerSuccess) {
      _showTopRightMessage("Registration successful!", isSuccess: true);

      // We return true here, and _promptOtpEntry will handle navigation
      // to avoid 'Navigator.pop' assertion errors while the dialog is active.
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: cs.onSurface),
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
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cs.surface,
              cs.surfaceContainerHighest.withValues(alpha: 0.5),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _currentStep == 0 ? _buildFormStep(cs) : _buildMobileStep(cs),
            ),
          ),
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
              color: cs.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),

          GlassBox(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
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
                if (_isCheckingUsername) 
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                if (_usernameMessage != null && !_isCheckingUsername)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _usernameMessage!,
                        style: TextStyle(
                          color:
                              _isUsernameAvailable == true ? Colors.green : Colors.red,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),

                // Email (prefilled, read-only)
                TextFormField(
                  controller: _emailController,
                  decoration: _inputDecoration("Email", Icons.email).copyWith(
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  ),
                  readOnly: true,
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 48),

          // Next Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _onFormNext,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text("Next", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 20),
          // TEST POP BUTTON
          Center(
            child: TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.bug_report, size: 16),
              label: const Text("Dev: Back"),
              style: TextButton.styleFrom(
                foregroundColor: cs.error.withValues(alpha: 0.7),
              ),
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
            color: cs.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 32),
        GlassBox(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
                ),
                child: Text(
                  "🇮🇳 +91",
                  style: TextStyle(
                      fontSize: 16,
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  cursorColor: cs.primary,
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
                    hintStyle: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 16,
                    ),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                    prefixIcon: Icon(Icons.phone, color: cs.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                          color: cs.outlineVariant.withValues(alpha: 0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: cs.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            onPressed: _sendOtp,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text("Send OTP",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
    final cs = Theme.of(context).colorScheme;

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: cs.onSurfaceVariant,
        fontSize: 14,
      ),
      floatingLabelStyle: TextStyle(
        color: cs.primary,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(icon, color: cs.primary, size: 22),
      filled: true,
      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: borderColor ?? cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: borderColor ?? cs.primary,
          width: 1.5,
        ),
      ),
    );
  }
}
