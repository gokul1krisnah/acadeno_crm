import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

import '../../core/services/crm_ai_assistant_service.dart';
import '../../ui/leads/data/model/lead_models.dart';
import '../../ui/leads/presentation/widgets/lead_call_sheets.dart';
import '../theme/app_typography.dart';

/// AI chat assistant floating button + responsive chat panel mounted on the
/// Today screen above the bottom navigation bar, powered by Gemini via
/// Firebase AI Logic and grounded in the signed-in staff member's permitted
/// CRM records.
class AiChatAssistantOverlay extends StatefulWidget {
  final CrmAiAssistantService? service;
  final void Function(ExecutiveLeadItem lead)? onOpenLead;

  const AiChatAssistantOverlay({
    super.key,
    this.service,
    this.onOpenLead,
  });

  @override
  State<AiChatAssistantOverlay> createState() => _AiChatAssistantOverlayState();
}

class _AiChatAssistantOverlayState extends State<AiChatAssistantOverlay> {
  static const Color _indigo = Color(0xFF3F35C9);
  static const Color _messagesBg = Color(0xFFF4F6FB);
  static const Color _orangeSend = Color(0xFFEA580C);
  static const Color _botText = Color(0xFF1E293B);
  static const Color _borderSubtle = Color(0xFFE2E8F0);

  static const String _initialGreeting =
      'Hi! I’m your AI assistant. Ask me about today’s follow-ups, hot leads or reminders.';

  static const List<String> _quickReplies = [
    'Today’s follow-ups',
    'Hot leads',
    'Add walk-in lead',
  ];

  late final CrmAiAssistantService _service =
      widget.service ?? CrmAiAssistantService();

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _panelFocusNode = FocusNode(debugLabel: 'AiAssistantPanel');
  final FocusNode _inputFocusNode = FocusNode(debugLabel: 'AiAssistantInput');

  final List<_ChatMessage> _messages = [
    const _ChatMessage(text: _initialGreeting, isUser: false),
  ];

  StreamSubscription<CrmAiStreamChunk>? _streamSub;
  bool _isOpen = false;
  bool _isTyping = false;

  @override
  void dispose() {
    _streamSub?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    _panelFocusNode.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _togglePanel() {
    setState(() {
      _isOpen = !_isOpen;
    });
    if (_isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _panelFocusNode.requestFocus();
          _scrollToBottom();
        }
      });
    } else {
      _inputFocusNode.unfocus();
      _panelFocusNode.unfocus();
    }
  }

  void _closePanel() {
    if (!_isOpen) return;
    setState(() => _isOpen = false);
    _inputFocusNode.unfocus();
    _panelFocusNode.unfocus();
  }

  void _openReferencedLead(CrmAiRecordReference ref) {
    if (widget.onOpenLead != null) {
      widget.onOpenLead!(ref.leadItem);
      return;
    }
    LeadCallSheets.showLeadDetailSheet(context, lead: ref.leadItem);
  }

  void _sendMessage(String rawText, {bool isRetry = false}) {
    final text = rawText.trim();
    if (text.isEmpty || _isTyping) return;

    if (_inputController.text.trim() == text) {
      _inputController.clear();
    }
    _streamSub?.cancel();

    setState(() {
      if (isRetry && _messages.isNotEmpty && _messages.last.isError) {
        _messages.removeLast();
      } else {
        _messages.add(_ChatMessage(text: text, isUser: true));
      }
      _isTyping = true;
    });
    _scrollToBottom();

    int? activeBotIndex;

    _streamSub = _service
        .sendMessageStream(text, isManualRetry: isRetry)
        .listen(
      (chunk) {
        if (!mounted) return;
        setState(() {
          _isTyping = false;
          final botMsg = _ChatMessage(
            text: chunk.accumulatedText,
            isUser: false,
            references: chunk.references,
          );
          if (activeBotIndex == null) {
            _messages.add(botMsg);
            activeBotIndex = _messages.length - 1;
          } else {
            _messages[activeBotIndex!] = botMsg;
          }
        });
        _scrollToBottom();
      },
      onError: (Object error) {
        if (!mounted) return;
        final classified = CrmAiAssistantService.classifyError(error);
        setState(() {
          _isTyping = false;
          // Preserve the user's message in the input box so they can edit or retry easily.
          if (_inputController.text.trim().isEmpty) {
            _inputController.text = text;
            _inputController.selection = TextSelection.fromPosition(
              TextPosition(offset: _inputController.text.length),
            );
          }
          final errMsg = _ChatMessage(
            text: classified.message,
            isUser: false,
            isError: true,
            retryPrompt: text,
          );
          if (activeBotIndex == null) {
            _messages.add(errMsg);
          } else {
            _messages[activeBotIndex!] = errMsg;
          }
        });
        _scrollToBottom();
      },
      onDone: () {
        if (!mounted) return;
        if (_isTyping) {
          setState(() => _isTyping = false);
        }
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;

        const double edgeInset = 16.0;
        const double fabSize = 58.0;
        const double panelFabGap = 12.0;

        // Adapt 330x390px panel cleanly to smaller phones or open keyboards.
        final double availableWidth = math.max(220.0, maxW - (edgeInset * 2));
        final double panelWidth = math.min(330.0, availableWidth);

        final double availableHeight = math.max(
          210.0,
          maxH - fabSize - edgeInset - panelFabGap - 12.0,
        );
        final double panelHeight = math.min(390.0, availableHeight);

        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): _closePanel,
          },
          child: Focus(
            focusNode: _panelFocusNode,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Chat panel anchored above the floating button
                Positioned(
                  right: edgeInset,
                  bottom: edgeInset + fabSize + panelFabGap,
                  child: IgnorePointer(
                    ignoring: !_isOpen,
                    child: AnimatedOpacity(
                      opacity: _isOpen ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      child: AnimatedScale(
                        scale: _isOpen ? 1.0 : 0.92,
                        alignment: Alignment.bottomRight,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        child: _buildChatPanel(
                          width: panelWidth,
                          height: panelHeight,
                        ),
                      ),
                    ),
                  ),
                ),

                // 58px round floating assistant button
                Positioned(
                  right: edgeInset,
                  bottom: edgeInset,
                  child: _buildFloatingButton(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloatingButton() {
    final label = _isOpen ? 'Close AI Assistant' : 'Open AI Assistant';
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: _togglePanel,
            customBorder: const CircleBorder(),
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: _indigo,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _indigo.withValues(alpha: 0.36),
                    blurRadius: 18,
                    spreadRadius: 1,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: _isOpen
                    ? const Icon(
                        Icons.close_rounded,
                        key: ValueKey('close_icon'),
                        color: Colors.white,
                        size: 26,
                      )
                    : const _SparkleIcon(
                        key: ValueKey('sparkle_icon'),
                        size: 26,
                        color: Colors.white,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatPanel({required double width, required double height}) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              color: Color(0x241E1B4B),
              blurRadius: 28,
              spreadRadius: 0,
              offset: Offset(0, 10),
            ),
            BoxShadow(
              color: Color(0x0D0F172A),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Column(
            children: [
              // Indigo header
              _buildHeader(),

              // Scrollable messages area (#F4F6FB, hidden scrollbar)
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: _messagesBg,
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(
                      context,
                    ).copyWith(scrollbars: false),
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final msg in _messages) _buildMessageBubble(msg),
                          if (_isTyping) _buildTypingBubble(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Quick-reply chips
              _buildQuickReplyBar(),

              // Input row
              _buildInputRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: _indigo,
      padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: const _SparkleIcon(size: 19, color: Colors.white),
          ),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AI Assistant',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                    size: 14.5,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Ask about your leads',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                    size: 11.5,
                    weight: FontWeight.w400,
                    color: const Color(0xFFDDE3FF),
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'Close AI Assistant',
            child: Tooltip(
              message: 'Close',
              child: InkWell(
                onTap: _closePanel,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    final isUser = msg.isUser;
    final isError = msg.isError;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isUser ? 18 : 5),
      bottomRight: Radius.circular(isUser ? 5 : 18),
    );

    final Color bubbleBg = isUser
        ? _indigo
        : (isError ? const Color(0xFFFEF2F2) : Colors.white);
    final Color borderColor = isError
        ? const Color(0xFFFCA5A5)
        : const Color(0xFFE6EAF2);
    final Color textColor = isUser
        ? Colors.white
        : (isError ? const Color(0xFFB91C1C) : _botText);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 252),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleBg,
              borderRadius: radius,
              border: isUser ? null : Border.all(color: borderColor, width: 0.8),
              boxShadow: isUser
                  ? null
                  : const [
                      BoxShadow(
                        color: Color(0x0A0F172A),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  msg.text,
                  style: AppTypography.body(
                    size: 12.5,
                    weight: FontWeight.w400,
                    color: textColor,
                    height: 1.4,
                  ),
                ),
                if (!isUser && msg.references.isNotEmpty) ...[
                  const Gap(8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final ref in msg.references)
                        Semantics(
                          button: true,
                          label: 'Open record ${ref.displayName}',
                          child: InkWell(
                            onTap: () => _openReferencedLead(ref),
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: _indigo.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.open_in_new_rounded,
                                    size: 11,
                                    color: _indigo,
                                  ),
                                  const Gap(4),
                                  Flexible(
                                    child: Text(
                                      '${ref.displayName} (#${ref.id})',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.body(
                                        size: 10.5,
                                        weight: FontWeight.w600,
                                        color: _indigo,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                if (isError &&
                    msg.retryPrompt != null &&
                    msg.retryPrompt!.isNotEmpty) ...[
                  const Gap(8),
                  Semantics(
                    button: true,
                    label: 'Retry message',
                    child: InkWell(
                      onTap: () =>
                          _sendMessage(msg.retryPrompt!, isRetry: true),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFF87171)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.refresh_rounded,
                              size: 12,
                              color: Color(0xFFB91C1C),
                            ),
                            const Gap(4),
                            Text(
                              'Retry',
                              style: AppTypography.body(
                                size: 11,
                                weight: FontWeight.w600,
                                color: const Color(0xFFB91C1C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(5),
              bottomRight: Radius.circular(18),
            ),
            border: Border.all(color: const Color(0xFFE6EAF2), width: 0.8),
          ),
          child: Text(
            'Typing...',
            style: AppTypography.body(
              size: 12,
              weight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickReplyBar() {
    return Container(
      color: _messagesBg,
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      width: double.infinity,
      child: Wrap(
        spacing: 8,
        runSpacing: 7,
        children: [
          for (final label in _quickReplies)
            Material(
              color: Colors.white,
              shape: StadiumBorder(
                side: BorderSide(color: _indigo.withValues(alpha: 0.28)),
              ),
              child: InkWell(
                onTap: () => _sendMessage(label),
                customBorder: const StadiumBorder(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 6,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                      size: 12,
                      weight: FontWeight.w600,
                      color: _indigo,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputRow() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _borderSubtle, width: 0.8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: _messagesBg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _borderSubtle, width: 0.9),
              ),
              alignment: Alignment.center,
              child: TextField(
                controller: _inputController,
                focusNode: _inputFocusNode,
                textInputAction: TextInputAction.send,
                onSubmitted: _sendMessage,
                style: AppTypography.body(
                  size: 13,
                  weight: FontWeight.w400,
                  color: _botText,
                ),
                decoration: InputDecoration(
                  hintText: 'Type a message',
                  hintStyle: AppTypography.body(
                    size: 13,
                    weight: FontWeight.w400,
                    color: const Color(0xFF94A3B8),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ),
          const Gap(8),
          Semantics(
            button: true,
            label: 'Send message',
            child: Tooltip(
              message: 'Send',
              child: Material(
                color: _orangeSend,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () => _sendMessage(_inputController.text),
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final String? retryPrompt;
  final List<CrmAiRecordReference> references;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
    this.retryPrompt,
    this.references = const [],
  });
}

/// Crisp vector sparkle icon made from one large four-point star and one small star.
class _SparkleIcon extends StatelessWidget {
  final double size;
  final Color color;

  const _SparkleIcon({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _SparkleIconPainter(color: color),
    );
  }
}

class _SparkleIconPainter extends CustomPainter {
  final Color color;

  const _SparkleIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Large four-point star (slightly left & down to balance the small star)
    _drawFourPointStar(
      canvas,
      paint,
      center: Offset(size.width * 0.43, size.height * 0.56),
      outerRadius: size.width * 0.40,
      innerRadius: size.width * 0.12,
    );

    // Small four-point star (top-right)
    _drawFourPointStar(
      canvas,
      paint,
      center: Offset(size.width * 0.78, size.height * 0.24),
      outerRadius: size.width * 0.18,
      innerRadius: size.width * 0.055,
    );
  }

  void _drawFourPointStar(
    Canvas canvas,
    Paint paint, {
    required Offset center,
    required double outerRadius,
    required double innerRadius,
  }) {
    final path = Path()
      ..moveTo(center.dx, center.dy - outerRadius)
      ..quadraticBezierTo(
        center.dx + innerRadius * 0.55,
        center.dy - innerRadius * 0.55,
        center.dx + outerRadius,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx + innerRadius * 0.55,
        center.dy + innerRadius * 0.55,
        center.dx,
        center.dy + outerRadius,
      )
      ..quadraticBezierTo(
        center.dx - innerRadius * 0.55,
        center.dy + innerRadius * 0.55,
        center.dx - outerRadius,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx - innerRadius * 0.55,
        center.dy - innerRadius * 0.55,
        center.dx,
        center.dy - outerRadius,
      )
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparkleIconPainter oldDelegate) =>
      oldDelegate.color != color;
}
