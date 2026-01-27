import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:gridcard/core/services/auth_provider.dart';
import 'package:gridcard/routes/route_names.dart';
import 'package:gridcard/widgets/secure_input_dialog.dart';
import 'package:provider/provider.dart';

class PhoneVerificationPage extends StatefulWidget {
  const PhoneVerificationPage({super.key});

  @override
  State<PhoneVerificationPage> createState() => _PhoneVerificationPageState();
}

class _PhoneVerificationPageState extends State<PhoneVerificationPage> {
  final _phoneController = TextEditingController();
  String _selectedCode = "🇮🇳 +91";

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  /// Initiates the OTP flow when the user clicks "Next".
  void _initiateOtpFlow() async {
    final mobile = _phoneController.text.trim();
    if (mobile.length != 10) {
      _showSnackBar("Please enter a valid 10-digit mobile number");
      return;
    }

    FocusScope.of(context).unfocus();
    _showLoaderDialog();

    final auth = context.read<AuthProvider>();
    final isRegistered = await auth.isRegistered(mobile);

    if (!mounted) return;
    Navigator.pop(context); // Dismiss loader

    if (isRegistered) {
      debugPrint("🔑 Existing user detected, proceeding to PIN login.");
      await _promptPinLogin(mobile);
    } else {
      debugPrint("🆕 New user detected, sending OTP for verification.");
      final success = await auth.getOTP(mobile, isNewUser: true);
      if (success) {
        await _promptOtpEntry(mobile);
      }
    }
  }

  /// Verifies the entered OTP and navigates based on the auth state.
  Future<bool> _verifyOtp(String otp) async {
    final mobile = _phoneController.text.trim();
    if (otp.length != 4) {
      _showSnackBar("Enter a valid 4-digit OTP");
      return false;
    }

    _showLoaderDialog();
    final auth = context.read<AuthProvider>();
    final success = await auth.verifyOTP(mobile, otp);
    if (!mounted) return false;
    Navigator.pop(context); // Dismiss loader

    if (!success) {
      _showSnackBar("OTP verification failed. Try again.");
      return false;
    }

    // Defer navigation until after the current frame to avoid context issues.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Re-read the provider state to be safe.
      final currentAuth = context.read<AuthProvider>();

      if (currentAuth.isAuthenticated) {
        Navigator.pushReplacementNamed(context, RouteNames.home);
      } else if (currentAuth.pendingIsNewUser) {
        Navigator.pushReplacementNamed(context, RouteNames.register);
      } else if (currentAuth.pendingProcess?.toLowerCase() == 'login') {
        await _promptPinLogin(mobile);
      } else {
        // Fallback case
        Navigator.pushReplacementNamed(context, RouteNames.login);
      }
    });

    return true;
  }

  /// Handles the entire PIN login flow, including setup for new users.
  Future<void> _promptPinLogin(String mobile) async {
    final auth = context.read<AuthProvider>();
    final isPinSet = await auth.checkPin(mobile);

    if (!mounted) return;

    if (isPinSet) {
      await _handleExistingPinLogin(mobile);
    } else {
      await _handleNewPinSetup(mobile);
    }
  }

  /// Shows a dialog for the user to enter their existing PIN to log in.
  Future<void> _handleExistingPinLogin(String mobile) async {
    final auth = context.read<AuthProvider>();
    final loggedIn = await showDialog<bool>(
      context: context,
      builder: (_) => SecureInputDialog(
        type: SecureInputType.loginPin,
        title: "Enter your PIN",
        description: "Enter your 4-digit PIN to login.",
        onSubmit: (pin) => auth.loginWithPin(mobile, pin),
        onForgotPin: () => _handleForgotPassword(mobile),
      ),
    );

    if (loggedIn == true && mounted) {
      Navigator.pushReplacementNamed(context, RouteNames.home);
    }
  }

  /// Guides the user to set a new PIN.
  Future<void> _handleNewPinSetup(String mobile) async {
    final auth = context.read<AuthProvider>();
    final pinSet = await showDialog<bool>(
      context: context,
      builder: (_) => SecureInputDialog(
        type: SecureInputType.setPin,
        title: "Set Your PIN",
        description: "Create a 4-digit PIN for future logins.",
        onSubmit: (pin) => auth.setPin(mobile, pin),
      ),
    );

    // If PIN was set successfully, proceed to login with the new PIN.
    if (pinSet == true && mounted) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _promptPinLogin(mobile));
    }
  }

  /// Handles the "Forgot Password" flow by sending a reset OTP.
  Future<void> _handleForgotPassword(String mobile) async {
    final auth = context.read<AuthProvider>();
    _showLoaderDialog();
    final success = await auth.getResetOtp(mobile);
    if (!mounted) return;
    Navigator.pop(context); // Dismiss loader

    if (!success) {
      _showSnackBar("Failed to send reset OTP.");
      return;
    }

    // Prompt for the reset OTP. The general _verifyOtp method will handle
    // the response from the server and navigate accordingly.
    await showDialog(
      context: context,
      builder: (_) => SecureInputDialog(
        type: SecureInputType.otp,
        title: "Enter Reset OTP",
        description: "An OTP has been sent to +91 $mobile",
        onSubmit: (otp) => _verifyOtp(otp),
      ),
    );
  }

  /// Shows a dialog for the user to enter the OTP they received.
  Future<void> _promptOtpEntry(String mobile) async {
    await showDialog(
      context: context,
      builder: (_) => SecureInputDialog(
        type: SecureInputType.otp,
        title: "Enter OTP",
        description: "OTP sent to +91 $mobile",
        onSubmit: (otp) => _verifyOtp(otp),
      ),
    );
  }

  // --- UI Helper Methods ---

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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

  void _showCountryPicker() {
    final colors = Theme.of(context).colorScheme;
    final countries = [
      {"flag": "🇮🇳", "code": "+91", "name": "India"},
      {"flag": "🇺🇸", "code": "+1", "name": "USA"},
      {"flag": "🇬🇧", "code": "+44", "name": "UK"},
      {"flag": "🇦🇪", "code": "+971", "name": "UAE"},
      {"flag": "🇸🇬", "code": "+65", "name": "Singapore"},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text("Select Country Code",
                style: Theme.of(context).textTheme.titleLarge),
          ),
          ...countries.map((c) => ListTile(
                leading: Text(c["flag"]!, style: const TextStyle(fontSize: 22)),
                title: Text(c["name"]!),
                trailing: Text(c["code"]!,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  setState(() => _selectedCode = "${c["flag"]} ${c["code"]}");
                  Navigator.pop(context);
                },
              )),
        ],
      ),
    );
  }

  Widget _buildLoginForm(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Welcome!",
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold, color: colors.onSurface)),
        const SizedBox(height: 6),
        Text("to AI Supercharged Networking App",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w300,
                color: colors.onSurface.withOpacity(0.8))),
        const SizedBox(height: 30),
        Row(
          children: [
            FilledButton(
              onPressed: _showCountryPicker,
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(_selectedCode,
                  style: TextStyle(fontSize: 16, color: colors.onPrimary)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction:
                    TextInputAction.done, // 👈 Enter key shows DONE
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                onSubmitted: (value) {
                  if (value.trim().length == 10) {
                    _initiateOtpFlow(); // 👈 SAME function as Next button
                  } else {
                    _showSnackBar(
                        "Please enter a valid 10-digit mobile number");
                  }
                },
                decoration: InputDecoration(
                  hintText: "Mobile Number",
                  prefixIcon: Icon(Icons.phone, color: colors.primary),
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
          child: FilledButton(
            onPressed: _initiateOtpFlow,
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: Text("Next",
                style: TextStyle(fontSize: 18, color: colors.onPrimary)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: colors.surface,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: isDesktop
            ? Row(
                children: [
                  // LEFT IMAGE PANEL
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colors.primary.withOpacity(0.12),
                            colors.primary.withOpacity(0.04),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/phone_hero.png',
                          width: 420,
                        ),
                      ),
                    ),
                  ),

                  // RIGHT LOGIN FORM

                  Expanded(
                    child: Align(
                      alignment: Alignment.center,
                      child: SingleChildScrollView(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 420),
                          padding: const EdgeInsets.all(32),
                          child: _buildLoginForm(colors),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 30),
                    // Image.asset('assets/phone_hero.png', height: 180),
                    Image.asset(
                      'assets/phone_hero.png',
                      height: 260, // 👈 dynamic height
                      fit: BoxFit.contain,
                    ),

                    const SizedBox(height: 24),
                    _buildLoginForm(colors),
                    const SizedBox(height: 24),
                    Text(
                      "Made with ❤️ by Path Idea Multiskill",
                      style: TextStyle(
                        color: colors.onSurface.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
