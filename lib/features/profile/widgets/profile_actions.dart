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
    final isDark = theme.brightness == Brightness.dark;

    if (isOwner) {
      return Row(
        children: [
          Expanded(
            child: _buildPrimaryButton(
              label: "Share Profile",
              icon: Icons.share,
              onTap: onShare,
              color: const Color(0xFF1F51E5),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _buildConnectButton(),
        ),
        const SizedBox(width: 8),
        _buildSecondaryButton(
          label: "Message",
          icon: Icons.chat_bubble_outline,
          onTap: onChat,
          isDark: isDark,
        ),
        const SizedBox(width: 8),
        _buildSecondaryButton(
          label: "Share",
          icon: Icons.share_outlined,
          onTap: onShare,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildConnectButton() {
    String label = "Connect";
    Color color = const Color(0xFF1F51E5); // Bright blue
    IconData icon = Icons.person_add_alt_1;

    if (requestStatus == "pending") {
      label = "Pending";
      color = Colors.orange;
      icon = Icons.hourglass_empty;
    } else if (requestStatus == "accepted") {
      label = "Connected";
      color = Colors.green;
      icon = Icons.check_circle_outline;
    }

    return _buildPrimaryButton(
      label: label,
      icon: icon,
      onTap: onConnect,
      color: color,
      isLoading: isCheckingConnection,
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
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
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF1F51E5)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF1F51E5),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
