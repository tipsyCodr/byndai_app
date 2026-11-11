import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/core/services/ai_chatbot_service.dart';
import 'package:gridcard/core/theme/app_theme.dart';
import 'package:gridcard/widgets/glass_box.dart';

class AiChatbotPage extends StatefulWidget {
  const AiChatbotPage({super.key});

  @override
  State<AiChatbotPage> createState() => _AiChatbotPageState();
}

class _AiChatbotPageState extends State<AiChatbotPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;

  /// Builds history list from existing messages (excludes current streaming msg)
  List<Map<String, String>> get _history => _messages
      .where((m) => !m.isStreaming)
      .map((m) => {'role': m.role, 'content': m.content})
      .toList();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    _controller.clear();

    final history = _history; // snapshot before adding new user msg

    setState(() {
      _messages.add(_ChatMessage(role: 'user', content: text));
      _isLoading = true;
    });
    _scrollToBottom();

    // Add a placeholder streaming message
    final streamingMsg = _ChatMessage(role: 'assistant', content: '', isStreaming: true);
    setState(() => _messages.add(streamingMsg));

    final buffer = StringBuffer();
    bool hadError = false;

    try {
      await for (final chunk in AiChatbotService.streamMessage(text, history: history)) {
        buffer.write(chunk);
        setState(() {
          _messages.last = _ChatMessage(
            role: 'assistant',
            content: buffer.toString(),
            isStreaming: true,
          );
        });
        _scrollToBottom();
      }
    } catch (e) {
      hadError = true;
    } finally {
      setState(() {
        _messages.last = _ChatMessage(
          role: 'assistant',
          content: buffer.isEmpty
              ? (hadError ? 'Network error. Please check your connection.' : '')
              : buffer.toString(),
          isError: hadError,
        );
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = Theme.of(context).extension<AppThemeColors>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Messages list
        Expanded(
          child: _messages.isEmpty
              ? _buildEmptyState(colorScheme, palette)
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: _messages.length + (_isLoading && (_messages.isEmpty || !_messages.last.isStreaming) ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length) {
                      return _buildTypingIndicator(colorScheme, palette, isDark);
                    }
                    final msg = _messages[index];
                    return _buildBubble(
                        msg, colorScheme, palette, isDark);
                  },
                ),
        ),

        // Input bar
        SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8, left: 12, right: 12),
            child: GlassBox(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              borderRadius: 32,
              blur: 15,
              opacity: isDark ? 0.2 : 0.12,
              gradientColors: [
                (palette?.glassTop ?? colorScheme.surface)
                    .withValues(alpha: isDark ? 0.7 : 0.8),
                (palette?.glassBottom ?? colorScheme.surface)
                    .withValues(alpha: isDark ? 0.58 : 0.7),
              ],
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: TextStyle(color: colorScheme.onSurface),
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Ask me anything...',
                        hintStyle: TextStyle(
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.6),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      color: _isLoading
                          ? colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.3)
                          : colorScheme.primary,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: IconButton(
                      icon: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.onPrimary,
                              ),
                            )
                          : Icon(
                              CupertinoIcons.arrow_up,
                              color: colorScheme.onPrimary,
                            ),
                      onPressed: _isLoading ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(
      ColorScheme colorScheme, AppThemeColors? palette) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              CupertinoIcons.sparkles,
              size: 40,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'ByndAI Assistant',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask me about networking, leads,\nor anything about the app.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(
      ColorScheme colorScheme, AppThemeColors? palette, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildAvatar(colorScheme),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: (palette?.glassTop ?? colorScheme.surfaceContainerHighest)
                  .withValues(alpha: isDark ? 0.4 : 0.6),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return AnimatedContainer(
                  duration: Duration(milliseconds: 400 + i * 150),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color:
                        colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(
    _ChatMessage msg,
    ColorScheme colorScheme,
    AppThemeColors? palette,
    bool isDark,
  ) {
    final isMe = msg.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            _buildAvatar(colorScheme),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? colorScheme.primary
                    : msg.isError
                        ? colorScheme.errorContainer
                        : (palette?.glassTop ??
                                colorScheme.surfaceContainerHighest)
                            .withValues(alpha: isDark ? 0.4 : 0.6),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
              ),
              child: Text(
                msg.content,
                style: TextStyle(
                  fontSize: 14.5,
                  color: isMe
                      ? colorScheme.onPrimary
                      : msg.isError
                          ? colorScheme.onErrorContainer
                          : colorScheme.onSurface,
                  height: 1.45,
                ),
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildAvatar(ColorScheme colorScheme) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(
        CupertinoIcons.sparkles,
        size: 14,
        color: colorScheme.primary,
      ),
    );
  }
}

class _ChatMessage {
  final String role;
  final String content;
  final bool isError;
  final bool isStreaming;

  const _ChatMessage({
    required this.role,
    required this.content,
    this.isError = false,
    this.isStreaming = false,
  });
}

