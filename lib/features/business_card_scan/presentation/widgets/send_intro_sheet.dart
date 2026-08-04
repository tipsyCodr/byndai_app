import 'package:flutter/material.dart';
import 'package:gridcard/features/business_card_scan/data/services/contact_launcher_service.dart';

class SendIntroSheet extends StatefulWidget {
  final String leadName;
  final List<String> leadPhones;
  final String leadEmail;
  final String yourName;
  final String yourCompany;
  final VoidCallback onDone;

  const SendIntroSheet({
    super.key,
    required this.leadName,
    required this.leadPhones,
    required this.leadEmail,
    required this.yourName,
    required this.yourCompany,
    required this.onDone,
  });

  @override
  State<SendIntroSheet> createState() => _SendIntroSheetState();
}

class _SendIntroSheetState extends State<SendIntroSheet> {
  late TextEditingController _messageCtrl;
  bool _sending = false;
  String? _sentVia;

  @override
  void initState() {
    super.initState();
    _messageCtrl = TextEditingController(
      text: ContactLauncherService.buildMessage(
        leadName: widget.leadName,
        yourName: widget.yourName,
        yourCompany: widget.yourCompany,
      ),
    );
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  bool get _hasPhone => widget.leadPhones.isNotEmpty;
  bool get _hasEmail => widget.leadEmail.trim().isNotEmpty;

  Future<String?> _showPhoneSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1D2E) : surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text("Select Number", style: TextStyle(color: onSurfaceColor, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ...widget.leadPhones.map((p) => ListTile(
                  leading: Icon(Icons.phone, color: onSurfaceColor.withOpacity(0.6)),
                  title: Text(p, style: TextStyle(color: onSurfaceColor)),
                  onTap: () => Navigator.of(ctx).pop(p),
                )),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _send(String channel) async {
    setState(() => _sending = true);
    bool success = false;

    try {
      String? phoneToUse;
      if (channel == 'whatsapp' || channel == 'sms') {
        if (widget.leadPhones.isEmpty) return;
        phoneToUse = widget.leadPhones.first;
        if (widget.leadPhones.length > 1) {
          final selected = await _showPhoneSelector();
          if (selected == null) {
            setState(() => _sending = false);
            return;
          }
          phoneToUse = selected;
        }
      }

      switch (channel) {
        case 'whatsapp':
          success = await ContactLauncherService.sendWhatsApp(
            phone: phoneToUse!,
            message: _messageCtrl.text,
          );
          break;
        case 'sms':
          success = await ContactLauncherService.sendSMS(
            phone: phoneToUse!,
            message: _messageCtrl.text,
          );
          break;
        case 'email':
          success = await ContactLauncherService.sendEmail(
            email: widget.leadEmail,
            subject: 'Great meeting you!',
            body: _messageCtrl.text,
          );
          break;
      }

      if (success) {
        setState(() => _sentVia = channel);
        await Future.delayed(const Duration(milliseconds: 800));
        widget.onDone();
      }
    } catch (e) {
      debugPrint('[SEND_INTRO] Error: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;

    final firstName = widget.leadName.isNotEmpty
        ? widget.leadName.split(' ').first
        : 'Lead';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1117) : surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: onSurfaceColor.withOpacity(0.24),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            children: [
              // Avatar circle
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1F8BFF), Color(0xFF00E5FF)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Introduce yourself to $firstName',
                    style: TextStyle(
                      color: onSurfaceColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    widget.leadPhones.isNotEmpty
                        ? (widget.leadPhones.length > 1
                            ? '${widget.leadPhones.first} (+${widget.leadPhones.length - 1} more)'
                            : widget.leadPhones.first)
                        : widget.leadEmail,
                    style: TextStyle(
                      color: onSurfaceColor.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Message box
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1D2E) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: onSurfaceColor.withOpacity(0.12)),
            ),
            padding: const EdgeInsets.all(14),
            child: TextField(
              controller: _messageCtrl,
              maxLines: 3,
              style: TextStyle(color: onSurfaceColor, fontSize: 13),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: 'Your intro message...',
                hintStyle: TextStyle(color: onSurfaceColor.withOpacity(0.3)),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Channel buttons
          Row(
            children: [
              _ChannelButton(
                icon: Icons.chat,
                label: 'WhatsApp',
                color: const Color(0xFF25D366),
                enabled: _hasPhone,
                sent: _sentVia == 'whatsapp',
                loading: _sending,
                onTap: () => _send('whatsapp'),
              ),
              const SizedBox(width: 10),
              _ChannelButton(
                icon: Icons.sms,
                label: 'SMS',
                color: const Color(0xFF1F8BFF),
                enabled: _hasPhone,
                sent: _sentVia == 'sms',
                loading: _sending,
                onTap: () => _send('sms'),
              ),
              const SizedBox(width: 10),
              _ChannelButton(
                icon: Icons.email_outlined,
                label: 'Email',
                color: const Color(0xFF7B2FFF),
                enabled: _hasEmail,
                sent: _sentVia == 'email',
                loading: _sending,
                onTap: () => _send('email'),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Skip button
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: widget.onDone,
              child: Text(
                'Skip for now',
                style: TextStyle(color: onSurfaceColor.withOpacity(0.4), fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final bool sent;
  final bool loading;
  final VoidCallback onTap;

  const _ChannelButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.sent,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;

    return Expanded(
      child: GestureDetector(
        onTap: (enabled && !loading) ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: sent
                ? color
                : enabled
                    ? color.withOpacity(0.15)
                    : onSurfaceColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: enabled ? color.withOpacity(0.4) : onSurfaceColor.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                sent ? Icons.check : icon,
                color: enabled ? color : onSurfaceColor.withOpacity(0.3),
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                sent ? 'Sent!' : label,
                style: TextStyle(
                  color: enabled ? onSurfaceColor : onSurfaceColor.withOpacity(0.3),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
