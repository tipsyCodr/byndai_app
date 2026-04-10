import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gridcard/core/services/auth_provider.dart';
import 'package:gridcard/routes/route_names.dart';
import 'package:gridcard/widgets/top_alert.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:gridcard/widgets/glass_box.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();

  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();

  // Username state
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;
  String? _usernameMessage;

  // Email state
  bool _isCheckingEmail = false;
  bool? _isEmailAvailable;
  String? _emailMessage;

  @override
  void initState() {
    super.initState();

    _usernameFocusNode.addListener(() {
      if (!_usernameFocusNode.hasFocus) {
        _checkUsername();
      }
    });

    _emailFocusNode.addListener(() {
      if (!_emailFocusNode.hasFocus) {
        _checkEmail();
      }
    });
  }

  @override
  void dispose() {
    _usernameFocusNode.dispose();
    _emailFocusNode.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _checkUsername() async {
    final username = _usernameController.text.trim();

    if (username.contains(' ')) {
      setState(() {
        _isUsernameAvailable = false;
        _usernameMessage = "Space not allowed in username";
      });
      return;
    }

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

  Future<void> _checkEmail() async {
    final email = _emailController.text.trim();

    if (!email.contains('@')) {
      setState(() {
        _isEmailAvailable = null;
        _emailMessage = null;
      });
      return;
    }

    setState(() => _isCheckingEmail = true);

    final auth = context.read<AuthProvider>();
    final available = await auth.checkEmailAvailability(email);

    if (!mounted) return;

    setState(() {
      _isCheckingEmail = false;
      _isEmailAvailable = available;
      _emailMessage = available ? "Email available" : "Email already exists";
    });
  }

  Future<void> _registerUser() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isUsernameAvailable != true || _isEmailAvailable != true) return;

    final auth = context.read<AuthProvider>();
    final mobile = auth.pendingRegisterMobile;
    final token = auth.pendingRegisterToken;

    if (mobile == null || token == null) {
      TopAlert.show(context, "Session expired. Please start again.",
          isError: true);
      Navigator.pushNamedAndRemoveUntil(
          context, RouteNames.phone, (_) => false);
      return;
    }

    final requestData = {
      'name': _nameController.text.trim(),
      'user_name': _usernameController.text.trim(),
      'email': _emailController.text.trim(),
      'password': "", // Passwords are not needed anymore
      'mobile': mobile,
      'token': token,
    };

    debugPrint("========== REGISTER REQUEST ==========");
    debugPrint(jsonEncode(requestData));
    debugPrint("=====================================");

    final success = await auth.register(requestData);

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacementNamed(context, RouteNames.home);
    } else {
      TopAlert.show(context, "Registration failed", isError: true);
    }
  }

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
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Enter Your Details",
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Join ByndAI to build your digital presence.",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),

                  GlassBox(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Name
                        TextFormField(
                          controller: _nameController,
                          decoration: _inputDecoration("Full Name", Icons.person),
                          validator: (v) => v == null || v.isEmpty ? "Enter name" : null,
                        ),

                        const SizedBox(height: 20),

                        TextFormField(
                          controller: _usernameController,
                          focusNode: _usernameFocusNode,
                          inputFormatters: [
                            FilteringTextInputFormatter.deny(RegExp(r'[\s\(\)\{\}\[\]]')),
                          ],
                          decoration: _inputDecoration(
                            "Username",
                            Icons.alternate_email,
                            borderColor:
                                _isUsernameAvailable == false ? Colors.red : null,
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return "Enter username";
                            if (v.contains(' ')) return "Space not allowed in username";
                            if (RegExp(r'[\(\)\{\}\[\]]').hasMatch(v)) {
                              return "Brackets not allowed";
                            }
                            if (v.length < 4) return "Minimum 4 characters";
                            return null;
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Use letters, numbers, and special characters",
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
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
                                  color: _isUsernameAvailable == true
                                      ? Colors.green
                                      : Colors.red,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),

                        const SizedBox(height: 20),

                        // ================= EMAIL FIELD =================

                        TextFormField(
                          controller: _emailController,
                          focusNode: _emailFocusNode,
                          decoration: _inputDecoration(
                            "Email",
                            Icons.email,
                            borderColor: _isEmailAvailable == false ? Colors.red : null,
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) =>
                              v == null || !v.contains('@') ? "Enter valid email" : null,
                        ),

                        if (_isCheckingEmail)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: LinearProgressIndicator(minHeight: 2),
                          ),

                        if (_emailMessage != null && !_isCheckingEmail)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 4),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _emailMessage!,
                                style: TextStyle(
                                  color: _isEmailAvailable == true ? Colors.green : Colors.red,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Continue Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: (_isUsernameAvailable == true &&
                              _isEmailAvailable == true)
                          ? _registerUser
                          : null,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text("Continue", 
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        )
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  
                  // TEST POP BUTTON (FOR UI REVIEW)
                  Center(
                    child: TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.bug_report, size: 16),
                      label: const Text("Dev: Back to Login"),
                      style: TextButton.styleFrom(
                        foregroundColor: cs.error.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String label,
    IconData icon, {
    Color? borderColor,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.error, width: 1.5),
      ),
    );
  }
}
