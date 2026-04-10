import 'package:flutter/material.dart';

class ProfileActions extends StatelessWidget {
  final bool isOwner;
  final String requestStatus;
  final VoidCallback onConnect;
  final VoidCallback onChat;
  final VoidCallback onShare;
  final VoidCallback onAiGenerate;
  final VoidCallback onSaveContact;
  final bool isCheckingConnection;
  final bool isGeneratingAI;

  const ProfileActions({
    super.key,
    required this.isOwner,
    required this.requestStatus,
    required this.onConnect,
    required this.onChat,
    required this.onShare,
    required this.onAiGenerate,
    required this.onSaveContact,
    this.isCheckingConnection = false,
    this.isGeneratingAI = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isOwner) {
      return Row(
        children: [
          Expanded(
            child: _buildButton(
              context,
              label: "Share Profile",
              icon: Icons.share,
              onTap: onShare,
              color: colorScheme.primary,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _buildConnectButton(context),
        ),
        const SizedBox(width: 10),
        _buildCircularButton(
          context,
          icon: Icons.chat_bubble_outline,
          onTap: onChat,
          color: Colors.green, // Standard WhatsApp green
        ),
        const SizedBox(width: 10),
        _buildCircularButton(
          context,
          icon: Icons.contact_phone,
          onTap: onSaveContact,
          color: Colors.orange,
        ),
        const SizedBox(width: 10),
        _buildCircularButton(
          context,
          icon: Icons.share,
          onTap: onShare,
          color: colorScheme.secondary,
        ),
      ],
    );
  }

  Widget _buildConnectButton(BuildContext context) {
    String label = "Connect";
    Color color = Colors.blue;
    IconData icon = Icons.person_add;

    if (requestStatus == "pending") {
      label = "Pending";
      color = Colors.orange;
      icon = Icons.hourglass_empty;
    } else if (requestStatus == "accepted") {
      label = "Connected";
      color = Colors.green;
      icon = Icons.check_circle;
    }

    return _buildButton(
      context,
      label: label,
      icon: icon,
      onTap: onConnect,
      color: color,
      isLoading: isCheckingConnection,
    );
  }

  Widget _buildButton(BuildContext context,
      {required String label,
      required IconData icon,
      required VoidCallback onTap,
      required Color color,
      bool isLoading = false}) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            else
              Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularButton(BuildContext context,
      {required IconData icon,
      required VoidCallback onTap,
      required Color color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}
