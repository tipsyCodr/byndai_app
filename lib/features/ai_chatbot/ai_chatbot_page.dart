import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gridcard/core/services/ai_chatbot_service.dart';
import 'package:gridcard/core/theme/app_theme.dart';
import 'package:intl/intl.dart';

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
  bool _isLoadingConversation = false;

  int? _currentConversationId;
  String _currentTitle = 'New Chat';
  List<Map<String, dynamic>> _conversations = [];

  /// Builds history list from existing messages (excludes streaming/error msgs)
  List<Map<String, String>> get _history => _messages
      .where((m) => !m.isStreaming && !m.isError)
      .map((m) => {'role': m.role, 'content': m.content})
      .toList();

  @override
  void initState() {
    super.initState();
    _fetchConversationsList();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchConversationsList() async {
    final list = await AiChatbotService.fetchConversations();
    if (mounted) {
      setState(() {
        _conversations = list;
      });
    }
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

  void _startNewChat() {
    setState(() {
      _currentConversationId = null;
      _currentTitle = 'New Chat';
      _messages.clear();
      _isLoading = false;
    });
  }

  Future<void> _loadConversation(int id, String title) async {
    setState(() {
      _isLoadingConversation = true;
      _currentConversationId = id;
      _currentTitle = title;
      _messages.clear();
    });

    final rawMessages = await AiChatbotService.fetchMessages(id);

    if (!mounted) return;

    setState(() {
      _isLoadingConversation = false;
      for (final m in rawMessages) {
        final role = m['role']?.toString() ?? 'user';
        final content = m['content']?.toString() ?? '';
        if (content.isNotEmpty) {
          _messages.add(_ChatMessage(role: role, content: content));
        }
      }
    });

    _scrollToBottom();
  }

  Future<void> _deleteConversation(int id) async {
    final success = await AiChatbotService.deleteConversation(id);
    if (success && mounted) {
      setState(() {
        _conversations.removeWhere((c) => c['id'] == id);
        if (_currentConversationId == id) {
          _startNewChat();
        }
      });
    }
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

    final buffer = StringBuffer();
    bool hadError = false;

    try {
      await for (final chunk in AiChatbotService.streamMessage(
        text,
        conversationId: _currentConversationId,
        history: history,
        onMeta: (convId, title) {
          if (mounted) {
            setState(() {
              _currentConversationId = convId;
              _currentTitle = title;
            });
            _fetchConversationsList();
          }
        },
      )) {
        buffer.write(chunk);
        setState(() {
          if (_messages.isNotEmpty && _messages.last.isStreaming) {
            _messages.last = _ChatMessage(
              role: 'assistant',
              content: buffer.toString(),
              isStreaming: true,
            );
          } else {
            _messages.add(_ChatMessage(
              role: 'assistant',
              content: buffer.toString(),
              isStreaming: true,
            ));
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      hadError = true;
    } finally {
      setState(() {
        if (buffer.isNotEmpty) {
          if (_messages.isNotEmpty && _messages.last.isStreaming) {
            _messages.last = _ChatMessage(
              role: 'assistant',
              content: buffer.toString(),
              isError: hadError,
            );
          } else {
            _messages.add(_ChatMessage(
              role: 'assistant',
              content: buffer.toString(),
              isError: hadError,
            ));
          }
        } else {
          // If stream produced nothing, clean up empty placeholder
          _messages.removeWhere((m) => m.isStreaming && m.content.isEmpty);
        }
        _isLoading = false;
      });
      _scrollToBottom();
    }

    // Fallback to standard request if stream produced nothing
    if (buffer.isEmpty && !hadError) {
      setState(() => _isLoading = true);
      try {
        final result = await AiChatbotService.sendMessage(
          text,
          conversationId: _currentConversationId,
          history: history,
        );

        final reply = result['reply']?.toString() ?? '';
        final isErr = result['is_error'] == true;

        if (result.containsKey('conversation_id') && result['conversation_id'] != null) {
          _currentConversationId = result['conversation_id'] as int;
          _currentTitle = result['conversation_title']?.toString() ?? _currentTitle;
          _fetchConversationsList();
        }

        setState(() {
          _messages.add(_ChatMessage(
            role: 'assistant',
            content: reply,
            isError: isErr,
          ));
        });
      } catch (_) {
        setState(() {
          _messages.add(const _ChatMessage(
            role: 'assistant',
            content: 'Network error. Please try again.',
            isError: true,
          ));
        });
      } finally {
        setState(() => _isLoading = false);
        _scrollToBottom();
      }
    }
  }

  void _openHistoryModal() {
    _fetchConversationsList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;
            final isDark = theme.brightness == Brightness.dark;

            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Drag Handle
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const FaIcon(
                              FontAwesomeIcons.clockRotateLeft,
                              size: 18,
                              color: Color(0xFFA855F7),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Chat History',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            if (_conversations.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_conversations.length}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _startNewChat();
                          },
                          icon: const Icon(CupertinoIcons.plus_circle_fill, size: 18),
                          label: const Text('New Chat'),
                          style: TextButton.styleFrom(
                            foregroundColor: colorScheme.primary,
                            textStyle: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // List of Chats
                  Expanded(
                    child: _conversations.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FaIcon(
                                  FontAwesomeIcons.message,
                                  size: 38,
                                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No previous conversations yet',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            itemCount: _conversations.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final conv = _conversations[index];
                              final id = conv['id'] as int;
                              final title = conv['title']?.toString() ?? 'Chat';
                              final lastMsg = conv['last_message']?.toString() ?? '';
                              final updated = conv['updated_at']?.toString() ?? '';
                              final isCurrent = _currentConversationId == id;

                              String timeFormatted = '';
                              if (updated.isNotEmpty) {
                                try {
                                  final dt = DateTime.parse(updated).toLocal();
                                  timeFormatted = DateFormat('MMM d, h:mm a').format(dt);
                                } catch (_) {}
                              }

                              return InkWell(
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _loadConversation(id, title);
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isCurrent
                                        ? colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.1)
                                        : colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.3 : 0.45),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isCurrent
                                          ? colorScheme.primary.withValues(alpha: 0.5)
                                          : Colors.transparent,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: isCurrent
                                              ? colorScheme.primary.withValues(alpha: 0.18)
                                              : colorScheme.surfaceContainerHigh,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: FaIcon(
                                            isCurrent
                                                ? FontAwesomeIcons.solidCommentDots
                                                : FontAwesomeIcons.comment,
                                            size: 16,
                                            color: isCurrent
                                                ? colorScheme.primary
                                                : colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    title,
                                                    style: TextStyle(
                                                      fontSize: 14.5,
                                                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                                                      color: colorScheme.onSurface,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (timeFormatted.isNotEmpty)
                                                  Text(
                                                    timeFormatted,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            if (lastMsg.isNotEmpty) ...[
                                              const SizedBox(height: 3),
                                              Text(
                                                lastMsg,
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: Icon(
                                          CupertinoIcons.trash,
                                          size: 17,
                                          color: colorScheme.error.withValues(alpha: 0.7),
                                        ),
                                        onPressed: () async {
                                          await _deleteConversation(id);
                                          setModalState(() {});
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = Theme.of(context).extension<AppThemeColors>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // ── Top Header Controls Bar ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            children: [
              // History Pill Button
              InkWell(
                onTap: _openHistoryModal,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (palette?.glassTop ?? colorScheme.surface)
                        .withValues(alpha: isDark ? 0.35 : 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.15),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const FaIcon(
                        FontAwesomeIcons.clockRotateLeft,
                        size: 13,
                        color: Color(0xFFA855F7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _conversations.isEmpty ? 'History' : 'Chats (${_conversations.length})',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Active Chat Title Pill
              Expanded(
                child: Text(
                  _currentTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(width: 8),

              // New Chat Button
              InkWell(
                onTap: _startNewChat,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.plus,
                        size: 13,
                        color: Colors.white,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'New',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Messages list ───────────────────────────────────────────────────
        Expanded(
          child: _isLoadingConversation
              ? Center(
                  child: CircularProgressIndicator(
                    color: colorScheme.primary,
                  ),
                )
              : _messages.isEmpty
                  ? _buildEmptyState(colorScheme, palette)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: _messages.length +
                          (_isLoading &&
                                  (_messages.isEmpty || !_messages.last.isStreaming)
                              ? 1
                              : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length) {
                          return _buildTypingIndicator(
                              colorScheme, palette, isDark);
                        }
                        final msg = _messages[index];
                        return _buildBubble(
                            msg, colorScheme, palette, isDark);
                      },
                    ),
        ),

        // ── Minimal Input bar (matching Image 1) ─────────────────────────
        SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8, left: 14, right: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Quick context chip (@business) with explanation
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () {
                          final current = _controller.text;
                          if (!current.contains('@business')) {
                            _controller.text = current.isEmpty
                                ? '@business '
                                : '$current @business ';
                            _controller.selection = TextSelection.fromPosition(
                              TextPosition(offset: _controller.text.length),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colorScheme.primary.withValues(alpha: 0.25),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.briefcase,
                                size: 12,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '@business',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tap to include your business details',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Seamless Minimal Input Pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1E26) : Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : Colors.black.withValues(alpha: 0.08),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                        blurRadius: 14,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: TextStyle(
                            fontSize: 15,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 4,
                          minLines: 1,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: InputDecoration(
                            hintText: 'Ask anything, or use @business...',
                            hintStyle: TextStyle(
                              fontSize: 14.5,
                              color: colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.55),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.primary,
                              ),
                            )
                          : IconButton(
                              icon: Icon(
                                CupertinoIcons.arrow_up_circle_fill,
                                color: colorScheme.primary,
                                size: 30,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: _sendMessage,
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, AppThemeColors? palette) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(
              'assets/icons/b-ai.svg',
              height: 48,
              fit: BoxFit.contain,
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
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: SvgPicture.asset(
          'assets/icons/b-ai.svg',
          fit: BoxFit.contain,
        ),
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
