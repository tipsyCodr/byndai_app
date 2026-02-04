// import 'package:flutter/material.dart';
// import 'package:gridcard/core/services/auth_provider.dart';
// import 'package:gridcard/routes/route_names.dart';
// import 'package:provider/provider.dart';

// class RegisterPage extends StatefulWidget {
//   const RegisterPage({super.key});

//   @override
//   State<RegisterPage> createState() => _RegisterPageState();
// }

// class _RegisterPageState extends State<RegisterPage> {
//   final _formKey = GlobalKey<FormState>();
//   final _nameController = TextEditingController();
//   final _emailController = TextEditingController();
//   final _passwordController = TextEditingController();
//   final _confirmController = TextEditingController();
//   final _usernameController = TextEditingController();
//   bool _passwordVisible = false;

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _usernameController.dispose();
//     _emailController.dispose();
//     _passwordController.dispose();
//     _confirmController.dispose();
//     super.dispose();
//   }

//   void _showSnackBar(String message) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(message)),
//     );
//   }

//   Future<void> _registerUser() async {
//     if (!(_formKey.currentState?.validate() ?? false)) {
//       return;
//     }

//     final auth = context.read<AuthProvider>();
//     final mobile = auth.pendingRegisterMobile;
//     final token = auth.pendingRegisterToken;

//     if (mobile == null || token == null) {
//       _showSnackBar("Registration session has expired. Please start over.");
//       Navigator.of(context)
//           .pushNamedAndRemoveUntil(RouteNames.phone, (route) => false);
//       return;
//     }

//     final success = await auth.register({
//       'name': _nameController.text.trim(),
//       'user_name': _usernameController.text.trim(),
//       'email': _emailController.text.trim(),
//       'password': _passwordController.text.trim(),
//       'mobile': mobile,
//       'token': token,
//     });

//     if (!mounted) return;

//     if (success) {
//       Navigator.pushReplacementNamed(context, RouteNames.home);
//     } else {
//       _showSnackBar("Registration failed. Please try again.");
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final cs = theme.colorScheme;

//     return Scaffold(
//       backgroundColor: cs.surface,
//       appBar: AppBar(
//         backgroundColor: cs.surface,
//         iconTheme: IconThemeData(color: cs.onSurface),
//         elevation: 0,
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 "Enter Your Details",
//                 style: theme.textTheme.headlineMedium?.copyWith(
//                   color: cs.onSurface,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 8),
//               Text(
//                 "Let us get to know you better.",
//                 style: theme.textTheme.bodyLarge
//                     ?.copyWith(color: cs.onSurface.withOpacity(0.7)),
//               ),
//               const SizedBox(height: 32),
//               TextFormField(
//                 controller: _nameController,
//                 decoration: _inputDecoration("Full Name", Icons.person),
//                 validator: (value) =>
//                     (value?.isEmpty ?? true) ? "Please enter your name" : null,
//               ),
//               const SizedBox(height: 20),
//               TextFormField(
//                 controller: _usernameController,
//                 decoration: _inputDecoration("Username", Icons.alternate_email),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return "Please enter username";
//                   }
//                   if (value.length < 4) {
//                     return "Username must be at least 4 characters";
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 20),
//               TextFormField(
//                 controller: _emailController,
//                 keyboardType: TextInputType.emailAddress,
//                 decoration: _inputDecoration("Email", Icons.email),
//                 validator: (value) {
//                   if (value?.isEmpty ?? true) return "Please enter your email";
//                   final emailRegex = RegExp(
//                       r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+$");
//                   if (!emailRegex.hasMatch(value!))
//                     return "Enter a valid email";
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 20),
//               TextFormField(
//                 controller: _passwordController,
//                 obscureText: !_passwordVisible,
//                 decoration: _inputDecoration("Password", Icons.lock).copyWith(
//                   suffixIcon: IconButton(
//                     icon: Icon(
//                       _passwordVisible
//                           ? Icons.visibility
//                           : Icons.visibility_off,
//                       color: cs.onSurface.withOpacity(0.7),
//                     ),
//                     onPressed: () =>
//                         setState(() => _passwordVisible = !_passwordVisible),
//                   ),
//                 ),
//                 validator: (value) => (value?.length ?? 0) < 6
//                     ? "Password must be at least 6 characters"
//                     : null,
//               ),
//               const SizedBox(height: 20),
//               TextFormField(
//                 controller: _confirmController,
//                 obscureText: true,
//                 decoration:
//                     _inputDecoration("Confirm Password", Icons.lock_outline),
//                 validator: (value) {
//                   if (value != _passwordController.text) {
//                     return "Passwords do not match";
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 30),
//               SizedBox(
//                 width: double.infinity,
//                 height: 50,
//                 child: FilledButton(
//                   style: FilledButton.styleFrom(
//                     backgroundColor: cs.primary,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                   ),
//                   onPressed: _registerUser,
//                   child: Text(
//                     "Continue",
//                     style: TextStyle(fontSize: 18, color: cs.onPrimary),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 48),
//               Center(
//                 child: Text(
//                   "Made with ❤️ by Path Idea Multiskill",
//                   style: TextStyle(color: cs.onSurface.withOpacity(0.6)),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   InputDecoration _inputDecoration(String label, IconData icon) {
//     final cs = Theme.of(context).colorScheme;
//     return InputDecoration(
//       filled: true,
//       fillColor: cs.surface.withOpacity(0.1),
//       labelText: label,
//       labelStyle: TextStyle(color: cs.onSurface.withOpacity(0.7)),
//       border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
//       prefixIcon: Icon(icon, color: cs.onSurface.withOpacity(0.7)),
//     );
//   }
// }

//===================================================================

// import 'package:flutter/material.dart';
// import 'package:gridcard/core/services/auth_provider.dart';
// import 'package:gridcard/routes/route_names.dart';
// import 'package:provider/provider.dart';

// class RegisterPage extends StatefulWidget {
//   const RegisterPage({super.key});

//   @override
//   State<RegisterPage> createState() => _RegisterPageState();
// }

// class _RegisterPageState extends State<RegisterPage> {
//   final _formKey = GlobalKey<FormState>();
//   final _nameController = TextEditingController();
//   final _emailController = TextEditingController();
//   final _passwordController = TextEditingController();
//   final _confirmController = TextEditingController();
//   final _usernameController = TextEditingController();

//   bool _passwordVisible = false;

//   bool _isCheckingUsername = false;
//   bool? _isUsernameAvailable;
//   String? _usernameMessage;

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _usernameController.dispose();
//     _emailController.dispose();
//     _passwordController.dispose();
//     _confirmController.dispose();
//     super.dispose();
//   }

//   Future<void> _checkUsername() async {
//     final username = _usernameController.text.trim();

//     if (username.length < 4) {
//       setState(() {
//         _isUsernameAvailable = null;
//         _usernameMessage = null;
//       });
//       return;
//     }

//     setState(() {
//       _isCheckingUsername = true;
//     });

//     final auth = context.read<AuthProvider>();
//     final available = await auth.checkUsernameAvailability(username);

//     if (!mounted) return;

//     setState(() {
//       _isCheckingUsername = false;
//       _isUsernameAvailable = available;
//       _usernameMessage = available
//           ? "Username available"
//           : "Username already exists";
//     });
//   }

//   Future<void> _registerUser() async {
//     if (!(_formKey.currentState?.validate() ?? false)) return;
//     if (_isUsernameAvailable != true) return;

//     final auth = context.read<AuthProvider>();
//     final mobile = auth.pendingRegisterMobile;
//     final token = auth.pendingRegisterToken;

//     if (mobile == null || token == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Session expired. Please start again.")),
//       );
//       Navigator.pushNamedAndRemoveUntil(
//           context, RouteNames.phone, (_) => false);
//       return;
//     }

//     final success = await auth.register({
//       'name': _nameController.text.trim(),
//       'user_name': _usernameController.text.trim(),
//       'email': _emailController.text.trim(),
//       'password': _passwordController.text.trim(),
//       'mobile': mobile,
//       'token': token,
//     });

//     if (!mounted) return;

//     if (success) {
//       Navigator.pushReplacementNamed(context, RouteNames.home);
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Registration failed")),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final cs = theme.colorScheme;

//     return Scaffold(
//       backgroundColor: cs.surface,
//       appBar: AppBar(
//         backgroundColor: cs.surface,
//         elevation: 0,
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text("Enter Your Details",
//                   style: theme.textTheme.headlineMedium
//                       ?.copyWith(fontWeight: FontWeight.bold)),
//               const SizedBox(height: 32),

//               /// Name
//               TextFormField(
//                 controller: _nameController,
//                 decoration: _inputDecoration("Full Name", Icons.person),
//                 validator: (v) =>
//                     v == null || v.isEmpty ? "Enter name" : null,
//               ),

//               const SizedBox(height: 20),

//               /// Username
//               TextFormField(
//                 controller: _usernameController,
//                 decoration: _inputDecoration(
//                   "Username",
//                   Icons.alternate_email,
//                   borderColor: _isUsernameAvailable == false
//                       ? Colors.red
//                       : null,
//                 ),
//                 validator: (v) {
//                   if (v == null || v.isEmpty) return "Enter username";
//                   if (v.length < 4) return "Minimum 4 characters";
//                   return null;
//                 },
//                 onEditingComplete: _checkUsername,
//               ),

//               if (_isCheckingUsername)
//                 const Padding(
//                   padding: EdgeInsets.only(top: 6),
//                   child: LinearProgressIndicator(minHeight: 2),
//                 ),

//               if (_usernameMessage != null)
//                 Padding(
//                   padding: const EdgeInsets.only(top: 6),
//                   child: Text(
//                     _usernameMessage!,
//                     style: TextStyle(
//                       color: _isUsernameAvailable == true
//                           ? Colors.green
//                           : Colors.red,
//                       fontSize: 13,
//                     ),
//                   ),
//                 ),

//               const SizedBox(height: 20),

//               /// Email
//               TextFormField(
//                 controller: _emailController,
//                 decoration: _inputDecoration("Email", Icons.email),
//                 keyboardType: TextInputType.emailAddress,
//                 validator: (v) =>
//                     v == null || !v.contains('@') ? "Enter valid email" : null,
//               ),

//               const SizedBox(height: 20),

//               /// Password
//               TextFormField(
//                 controller: _passwordController,
//                 obscureText: !_passwordVisible,
//                 decoration: _inputDecoration("Password", Icons.lock).copyWith(
//                   suffixIcon: IconButton(
//                     icon: Icon(_passwordVisible
//                         ? Icons.visibility
//                         : Icons.visibility_off),
//                     onPressed: () =>
//                         setState(() => _passwordVisible = !_passwordVisible),
//                   ),
//                 ),
//                 validator: (v) =>
//                     v != null && v.length >= 6 ? null : "Min 6 chars",
//               ),

//               const SizedBox(height: 20),

//               /// Confirm Password
//               TextFormField(
//                 controller: _confirmController,
//                 obscureText: true,
//                 decoration:
//                     _inputDecoration("Confirm Password", Icons.lock_outline),
//                 validator: (v) =>
//                     v == _passwordController.text ? null : "Passwords mismatch",
//               ),

//               const SizedBox(height: 30),

//               /// Continue Button
//               SizedBox(
//                 width: double.infinity,
//                 height: 50,
//                 child: FilledButton(
//                   onPressed:
//                       _isUsernameAvailable == true ? _registerUser : null,
//                   child: const Text("Continue",
//                       style: TextStyle(fontSize: 18)),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   InputDecoration _inputDecoration(String label, IconData icon,
//       {Color? borderColor}) {
//     return InputDecoration(
//       labelText: label,
//       prefixIcon: Icon(icon),
//       border: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(12),
//       ),
//       enabledBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(12),
//         borderSide: BorderSide(color: borderColor ?? Colors.grey),
//       ),
//       focusedBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(12),
//         borderSide: BorderSide(color: borderColor ?? Colors.blue),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:gridcard/core/services/auth_provider.dart';
import 'package:gridcard/routes/route_names.dart';
import 'package:provider/provider.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _usernameController = TextEditingController();

  final FocusNode _usernameFocusNode = FocusNode();

  bool _passwordVisible = false;

  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;
  String? _usernameMessage;

  @override
  void initState() {
    super.initState();

    /// 🔥 Username field se focus hatne par auto check
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
    super.dispose();
  }

  Future<void> _checkUsername() async {
    final username = _usernameController.text.trim();

    if (username.length < 4) {
      setState(() {
        _isUsernameAvailable = null;
        _usernameMessage = null;
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
    });

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

  Future<void> _registerUser() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isUsernameAvailable != true) return;

    final auth = context.read<AuthProvider>();
    final mobile = auth.pendingRegisterMobile;
    final token = auth.pendingRegisterToken;

    if (mobile == null || token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Session expired. Please start again.")),
      );
      Navigator.pushNamedAndRemoveUntil(
          context, RouteNames.phone, (_) => false);
      return;
    }

    final success = await auth.register({
      'name': _nameController.text.trim(),
      'user_name': _usernameController.text.trim(),
      'email': _emailController.text.trim(),
      'password': _passwordController.text.trim(),
      'mobile': mobile,
      'token': token,
    });

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacementNamed(context, RouteNames.home);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registration failed")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
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
              const SizedBox(height: 32),

              /// Name
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration("Full Name", Icons.person),
                validator: (v) => v == null || v.isEmpty ? "Enter name" : null,
              ),

              const SizedBox(height: 20),

              /// Username
              TextFormField(
                controller: _usernameController,
                focusNode: _usernameFocusNode,
                decoration: _inputDecoration(
                  "Username",
                  Icons.alternate_email,
                  borderColor:
                      _isUsernameAvailable == false ? Colors.red : null,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return "Enter username";
                  if (v.length < 4) return "Minimum 4 characters";
                  return null;
                },
                onEditingComplete: _checkUsername, // ⌨️ Enter press
              ),

              if (_isCheckingUsername)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: LinearProgressIndicator(minHeight: 2),
                ),

              if (_usernameMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _usernameMessage!,
                    style: TextStyle(
                      color: _isUsernameAvailable == true
                          ? Colors.green
                          : Colors.red,
                      fontSize: 13,
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              /// Email
              TextFormField(
                controller: _emailController,
                decoration: _inputDecoration("Email", Icons.email),
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    v == null || !v.contains('@') ? "Enter valid email" : null,
              ),

              const SizedBox(height: 20),

              /// Password
              TextFormField(
                controller: _passwordController,
                obscureText: !_passwordVisible,
                decoration: _inputDecoration("Password", Icons.lock).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(_passwordVisible
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () =>
                        setState(() => _passwordVisible = !_passwordVisible),
                  ),
                ),
                validator: (v) =>
                    v != null && v.length >= 6 ? null : "Min 6 chars",
              ),

              const SizedBox(height: 20),

              /// Confirm Password
              TextFormField(
                controller: _confirmController,
                obscureText: true,
                decoration:
                    _inputDecoration("Confirm Password", Icons.lock_outline),
                validator: (v) =>
                    v == _passwordController.text ? null : "Passwords mismatch",
              ),

              const SizedBox(height: 30),

              /// Continue Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed:
                      _isUsernameAvailable == true ? _registerUser : null,
                  child: const Text("Continue", style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
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
