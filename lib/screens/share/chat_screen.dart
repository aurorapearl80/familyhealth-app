import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../models/chat_message.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/socket_service.dart';
import '../../theme/app_colors.dart';
import 'video_call_screen.dart';

class ChatScreen extends StatefulWidget {
  final String contactName;
  final Color contactColor;
  final int? patientId;
  final int? recipientUserId;
  final bool isAdmin;

  const ChatScreen({
    super.key,
    required this.contactName,
    required this.contactColor,
    required this.isAdmin,
    this.patientId,
    this.recipientUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _socketService = SocketService();
  bool _isSending = false;
  bool _peerTyping = false;

  int? _myUserId;
  int? _targetUserId;
  int? _typingPatientId;
  Timer? _peerTypingTimeout;
  Timer? _stopTypingDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMessages());
    _initSocket();
    _controller.addListener(_onTextChanged);
  }

  Future<void> _loadMessages() async {
    await context.read<ChatService>().fetchMessages(
          isAdmin: widget.isAdmin,
          patientId: widget.patientId,
        );
    _scrollToBottom();
  }

  Future<void> _initSocket() async {
    final userIdStr = await AuthService.getUserId();
    final myUserId = int.tryParse(userIdStr ?? '');
    if (myUserId == null) return;

    final targetUserId =
        widget.isAdmin ? widget.recipientUserId : await AuthService.getAddedByUserId();
    if (!mounted) return;

    setState(() {
      _myUserId = myUserId;
      _targetUserId = targetUserId;
      _typingPatientId = widget.isAdmin ? widget.patientId : myUserId;
    });

    _socketService.onMessage = (message) {
      if (!mounted) return;
      context.read<ChatService>().receiveLiveMessage(message);
      _scrollToBottom();
    };
    _socketService.onSendError = (reason) {
      if (!mounted || reason != 'user_offline') return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sent — the recipient is offline and will see it when they reconnect.'),
        ),
      );
    };
    _socketService.onTyping = (data) => _handlePeerTyping(data, isTyping: true);
    _socketService.onStopTyping = (data) => _handlePeerTyping(data, isTyping: false);

    _socketService.connect(myUserId);
  }

  void _handlePeerTyping(Map<String, dynamic> data, {required bool isTyping}) {
    if (!mounted || _typingPatientId == null) return;
    final eventPatientId = (data['patient_id'] as num?)?.toInt();
    final eventSenderId = (data['sender_id'] as num?)?.toInt();
    if (eventPatientId != _typingPatientId || eventSenderId == _myUserId) return;

    _peerTypingTimeout?.cancel();
    if (!isTyping) {
      setState(() => _peerTyping = false);
      return;
    }
    setState(() => _peerTyping = true);
    _scrollToBottom();
    _peerTypingTimeout = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _peerTyping = false);
    });
  }

  void _onTextChanged() {
    if (_typingPatientId == null || _myUserId == null) return;
    if (_controller.text.trim().isEmpty) {
      _stopTypingNow();
      return;
    }
    _socketService.emitTyping(patientId: _typingPatientId!, senderId: _myUserId!);
    _stopTypingDebounce?.cancel();
    _stopTypingDebounce = Timer(const Duration(seconds: 2), _stopTypingNow);
  }

  void _stopTypingNow() {
    _stopTypingDebounce?.cancel();
    if (_typingPatientId != null && _myUserId != null) {
      _socketService.emitStopTyping(patientId: _typingPatientId!, senderId: _myUserId!);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _stopTypingDebounce?.cancel();
    _peerTypingTimeout?.cancel();
    _socketService.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    _controller.clear();
    _stopTypingNow();
    final sent = await context.read<ChatService>().sendMessage(
          isAdmin: widget.isAdmin,
          patientId: widget.patientId,
          body: text,
        );
    if (!mounted) return;
    setState(() => _isSending = false);
    if (sent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message. Please try again.')),
      );
      _controller.text = text;
      return;
    }
    if (_targetUserId != null) {
      _socketService.sendPrivateMessage(to: _targetUserId!, message: sent.toJson());
    }
    _scrollToBottom();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any,
    );
    if (result != null && mounted) {
      // TODO: attachment upload isn't part of the documented text-message flow yet.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attachment "${result.files.single.name}" selected — upload not yet supported.')),
      );
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

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  void _openVideoCall() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          contactName: widget.contactName,
          contactColor: widget.contactColor,
          patientId: widget.patientId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: const Color(0xFFEEEEF2),
        surfaceTintColor: Colors.white,
        leadingWidth: 44,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textDark),
          onPressed: () => Navigator.of(context).pop(),
          padding: EdgeInsets.zero,
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: widget.contactColor,
              child: Text(
                widget.contactName[0],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.contactName,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  if (_peerTyping)
                    Text(
                      'Typing…',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.success),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_outlined, color: AppColors.primary, size: 26),
            onPressed: _openVideoCall,
            tooltip: 'Video call',
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEEEEF2)),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ChatService>(
              builder: (context, chat, _) {
                if (chat.isLoadingMessages && chat.messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (chat.error != null && chat.messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            chat.error!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(color: AppColors.textMedium),
                          ),
                          const SizedBox(height: 12),
                          TextButton(onPressed: _loadMessages, child: const Text('Retry')),
                        ],
                      ),
                    ),
                  );
                }
                if (chat.messages.isEmpty && !_peerTyping) {
                  return Center(
                    child: Text(
                      'No messages yet. Say hello!',
                      style: GoogleFonts.inter(color: AppColors.textMedium),
                    ),
                  );
                }
                final itemCount = chat.messages.length + (_peerTyping ? 1 : 0);
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: itemCount,
                  itemBuilder: (_, i) {
                    if (_peerTyping && i == chat.messages.length) {
                      return _buildTypingBubble();
                    }
                    return _buildBubble(chat.messages[i]);
                  },
                );
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  static const double _avatarGutter = 36;

  Widget _buildBubble(ChatMessage msg) {
    final hasText = msg.body != null && msg.body!.isNotEmpty;

    final bubbleContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: msg.isMine ? AppColors.primary : const Color(0xFFF0F0F7),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(msg.isMine ? 18 : 4),
          bottomRight: Radius.circular(msg.isMine ? 4 : 18),
        ),
      ),
      child: msg.attachment != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.insert_drive_file_outlined,
                    size: 16, color: msg.isMine ? Colors.white70 : AppColors.textMedium),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    msg.attachment!.name,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: msg.isMine ? Colors.white : AppColors.textDark,
                    ),
                  ),
                ),
              ],
            )
          : hasText
              ? Text(
                  msg.body!,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: msg.isMine ? Colors.white : AppColors.textDark,
                  ),
                )
              : const SizedBox.shrink(),
    );

    final metaText = Text(
      msg.isMine ? '${_formatTime(msg.createdAt)}   ${msg.isRead ? 'Read' : 'Sent'}' : _formatTime(msg.createdAt),
      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textLight),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: msg.isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Align(
            alignment: msg.isMine ? Alignment.centerRight : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
              child: msg.isMine
                  ? bubbleContent
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: widget.contactColor,
                          child: Text(
                            widget.contactName.isNotEmpty ? widget.contactName[0] : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(child: bubbleContent),
                      ],
                    ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              top: 3,
              left: msg.isMine ? 0 : _avatarGutter,
              right: msg.isMine ? 4 : 0,
            ),
            child: metaText,
          ),
        ],
      ),
    );
  }

  Widget _buildTypingBubble() {
    return const Align(
      alignment: Alignment.centerLeft,
      child: _TypingBubble(),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        8,
        8,
        8,
        MediaQuery.of(context).viewPadding.bottom + 8,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEF2))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file_rounded, color: AppColors.textMedium, size: 22),
            onPressed: _pickFile,
            tooltip: 'Attach file',
          ),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F8),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _controller,
                maxLines: null,
                decoration: InputDecoration.collapsed(
                  hintText: 'Type a message...',
                  hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textLight),
                ),
                textCapitalization: TextCapitalization.sentences,
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textDark),
                onSubmitted: (_) => _sendText(),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _isSending ? null : _sendText,
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(11),
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

/// The received-message-styled bubble shown while the other party is typing.
class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF0F0F7),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(18),
        ),
      ),
      child: const _TypingDots(),
    );
  }
}

/// Three dots that pulse in a staggered wave, like most chat apps' "typing…" cue.
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 8,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final phase = _controller.value * 2 * math.pi;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final opacity = (0.35 + 0.65 * (0.5 + 0.5 * math.sin(phase - i * 1.0))).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Opacity(
                  opacity: opacity,
                  child: const _Dot(),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(color: AppColors.textLight, shape: BoxShape.circle),
    );
  }
}
