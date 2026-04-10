import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:gridcard/widgets/top_alert.dart';

enum SecureInputType { otp, loginPin, setPin }

class SecureInputDialog extends StatefulWidget {
  final SecureInputType type;
  final String title;
  final String description;
  final int length;
  final Future<bool> Function(String value)? onSubmit;
  final Future<void> Function()?
      onForgotPin; // 👈 optional callback for Forgot PIN

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
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _controller = TextEditingController();
  bool isLoading = false;

  PinTheme _buildPinTheme(ColorScheme cs) {
    return PinTheme(
      width: 56,
      height: 56,
      textStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: cs.onSurface,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
    );
  }

  PinTheme _buildFocusedPinTheme(ColorScheme cs) {
    return _buildPinTheme(cs).copyWith(
      decoration: _buildPinTheme(cs).decoration?.copyWith(
            border: Border.all(color: cs.primary, width: 1.5),
          ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() async {
    final value = _controller.text.trim();
    if (value.length != widget.length) {
      TopAlert.show(context, "Enter a valid ${widget.length}-digit code",
          isError: true);
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
    final defaultPinTheme = _buildPinTheme(colors);
    final focusedPinTheme = _buildFocusedPinTheme(colors);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });

    return AlertDialog(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent, // Disable default surface tint
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
            focusNode: _focusNode,
            autofocus: true,
            length: widget.length,
            obscureText: widget.type != SecureInputType.otp,
            defaultPinTheme: defaultPinTheme,
            focusedPinTheme: focusedPinTheme,
            onCompleted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          Text(
            widget.description,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() => isLoading = false); // stop loader inside dialog
            Navigator.pop(context, false);
          },
          child: Text('Cancel', style: TextStyle(color: colors.primary)),
        ),
        if (widget.type == SecureInputType.loginPin) // show only for login
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (widget.onForgotPin != null) {
                await widget.onForgotPin!();
              }
            },
            child: Text("Forgot PIN?", style: TextStyle(color: colors.primary)),
          ),
        FilledButton(
          onPressed: isLoading ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.onPrimary,
                  ),
                )
              : const Text('Continue'),
        ),
      ],
    );
  }
}
