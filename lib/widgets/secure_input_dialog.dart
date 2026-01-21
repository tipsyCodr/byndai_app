import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';

enum SecureInputType { otp, loginPin, setPin }

class SecureInputDialog extends StatefulWidget {
  final SecureInputType type;
  final String title;
  final String description;
  final int length;
  final Future<bool> Function(String value)? onSubmit;
  final Future<void> Function()? onForgotPin; // 👈 optional callback for Forgot PIN

  const SecureInputDialog({
    super.key,
    required this.type,
    required this.title,
    required this.description,
    this.length = 4,
    this.onSubmit,
    this.onForgotPin,
  });

  @override
  State<SecureInputDialog> createState() => _SecureInputDialogState();
}

class _SecureInputDialogState extends State<SecureInputDialog> {
  final TextEditingController _controller = TextEditingController();
  bool isLoading = false;

  PinTheme get _pinTheme => PinTheme(
        width: 56,
        height: 56,
        textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade400),
        ),
      );

  void _submit() async {
    final value = _controller.text.trim();
    if (value.length != widget.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Enter a valid ${widget.length}-digit code")),
      );
      return;
    }

    if (widget.onSubmit != null) {
      setState(() => isLoading = true);
      final ok = await widget.onSubmit!(value);
      if (!mounted) return;
      setState(() => isLoading = false);

      if (ok) Navigator.pop(context, true);
    } else {
      Navigator.pop(context, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: colors.onSurface,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Pinput(
            controller: _controller,
            length: widget.length,
            obscureText: widget.type != SecureInputType.otp,
            defaultPinTheme: _pinTheme,
            onCompleted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          Text(
            widget.description,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurface.withOpacity(0.6)),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
              setState(() => isLoading = false); // stop loader inside dialog
              Navigator.pop(context, false);
            },
          child: const Text('Cancel'),
        ),
        if (widget.type == SecureInputType.loginPin) // show only for login
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (widget.onForgotPin != null) {
                await widget.onForgotPin!();
              }
            },
            child: const Text("Forgot PIN?"),
          ),
        FilledButton(
          onPressed: isLoading ? null : _submit,
          child: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Continue'),
        ),
      ],

    );
  }
}
