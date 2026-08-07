import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/conversation.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../theme/app_colors.dart';
import 'family_map_screen.dart';
import 'chat_screen.dart';
import '../../widgets/lottie_background.dart';
import '../../widgets/profile_avatar.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool _isAdmin = false;
  bool _roleLoaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final role = await AuthService.getRoleType();
    if (!mounted) return;
    setState(() {
      _isAdmin = role == 'admin';
      _roleLoaded = true;
    });
    final chat = context.read<ChatService>();
    await Future.wait([
      if (_isAdmin) chat.fetchConversations(),
      chat.fetchChannels(),
    ]);
  }

  Future<void> _refresh() async {
    final chat = context.read<ChatService>();
    await Future.wait([
      if (_isAdmin) chat.fetchConversations(),
      chat.fetchChannels(),
    ]);
  }

  void _openCreateGroup(List<Conversation> patients) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CreateGroupSheet(patients: patients),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LottieBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              _buildSearchBar(),
              _buildAvatarRow(context),
              Expanded(child: _buildBody(context)),
            ],
          ),
        ),
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton(
              onPressed: () => _openCreateGroup(context.read<ChatService>().conversations),
              backgroundColor: AppColors.primary,
              tooltip: 'New group chat',
              child: const Icon(Icons.group_add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildBody(BuildContext context) {
    if (!_roleLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    return Consumer<ChatService>(
      builder: (context, chat, _) {
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _sectionHeader('Direct Messages'),
              if (_isAdmin)
                ..._buildDirectSection(context, chat)
              else
                _buildConvoTile(
                  context: context,
                  name: 'Care Team',
                  time: '',
                  preview: 'Tap to message your care team',
                  unread: false,
                  color: AppColors.primary,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ChatScreen(
                        contactName: 'Care Team',
                        contactColor: AppColors.primary,
                        isAdmin: false,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              _sectionHeader('Group Chats'),
              ..._buildGroupSection(context, chat),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildDirectSection(BuildContext context, ChatService chat) {
    if (chat.isLoadingConversations && chat.conversations.isEmpty) {
      return const [Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator()))];
    }
    if (chat.error != null && chat.conversations.isEmpty) {
      return [_inlineMessage(chat.error!, onRetry: chat.fetchConversations)];
    }
    if (chat.conversations.isEmpty) {
      return [_inlineMessage('No conversations yet')];
    }
    return List.generate(chat.conversations.length, (i) {
      final c = chat.conversations[i];
      final last = c.lastMessage;
      final preview = last == null
          ? 'No messages yet'
          : (last.body?.isNotEmpty == true
              ? last.body!
              : (last.hasAttachment ? '📎 ${last.attachmentName ?? 'Attachment'}' : ''));
      return _buildConvoTile(
        context: context,
        name: c.fullName,
        time: last != null ? _timeAgo(last.createdAt) : '',
        preview: preview,
        unread: c.unreadCount > 0,
        color: _avatarColor(i),
        imageUrl: c.profileImageUrl,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              contactName: c.fullName,
              contactColor: _avatarColor(i),
              contactImageUrl: c.profileImageUrl,
              patientId: c.patientId,
              recipientUserId: c.recipientUserId,
              isAdmin: true,
            ),
          ),
        ),
      );
    });
  }

  List<Widget> _buildGroupSection(BuildContext context, ChatService chat) {
    if (chat.isLoadingChannels && chat.channels.isEmpty) {
      return const [Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator()))];
    }
    if (chat.channelError != null && chat.channels.isEmpty) {
      return [_inlineMessage(chat.channelError!, onRetry: chat.fetchChannels)];
    }
    if (chat.channels.isEmpty) {
      return [_inlineMessage('No group chats yet')];
    }
    return List.generate(chat.channels.length, (i) {
      final ch = chat.channels[i];
      final last = ch.lastMessage;
      final preview = last == null
          ? '${ch.participants.length} participants'
          : (last.body?.isNotEmpty == true
              ? last.body!
              : (last.hasAttachment ? '📎 ${last.attachmentName ?? 'Attachment'}' : ''));
      return _buildConvoTile(
        context: context,
        name: ch.name,
        time: last != null ? _timeAgo(last.createdAt) : '',
        preview: preview,
        unread: ch.unreadCount > 0,
        color: _avatarColor(i),
        isGroup: true,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              contactName: ch.name,
              contactColor: _avatarColor(i),
              channelId: ch.channelId,
              isAdmin: _isAdmin,
            ),
          ),
        ),
      );
    });
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
    );
  }

  Widget _inlineMessage(String text, {Future<void> Function()? onRetry}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMedium),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.lightCard,
            child: Icon(Icons.person, color: AppColors.textMedium, size: 22),
          ),
          const Expanded(
            child: Center(
              child: Text('Vitals', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: AppColors.textDark),
            onPressed: () {},
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FamilyMapScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.lightBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.map_outlined, color: AppColors.textDark, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.lightBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppColors.textLight, size: 20),
            const SizedBox(width: 8),
            Text(
              'Search family and groups',
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.textLight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarRow(BuildContext context) {
    final members = [
      {'name': 'Update', 'isAction': true},
      {'name': 'Sarah', 'isAction': false},
      {'name': 'David', 'isAction': false},
      {'name': 'Elena', 'isAction': false},
      {'name': 'Ja...', 'isAction': false},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SizedBox(
        height: 72,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          separatorBuilder: (_, __) => const SizedBox(width: 16),
          itemCount: members.length,
          itemBuilder: (context, i) {
            final m = members[i];
            final isAction = m['isAction'] as bool;
            return Column(
              children: [
                if (isAction)
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary, width: 1.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: AppColors.primary, size: 20),
                  )
                else
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: _avatarColor(i),
                        child: Text(
                          (m['name'] as String)[0],
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (i == 1 || i == 2)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 4),
                Text(
                  m['name'] as String,
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMedium),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Color _avatarColor(int i) {
    const colors = [
      AppColors.primary,
      Color(0xFF8B6BAE),
      Color(0xFF4A90D9),
      Color(0xFF5BA55B),
      Color(0xFFD4875B),
    ];
    return colors[i % colors.length];
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  Widget _buildConvoTile({
    required BuildContext context,
    required String name,
    required String time,
    required String preview,
    required bool unread,
    required Color color,
    required VoidCallback onTap,
    bool isGroup = false,
    String? imageUrl,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            ProfileAvatar.buildAvatar(
              imageUrl: isGroup ? null : imageUrl,
              initials: name.isNotEmpty ? name[0] : '?',
              radius: 24,
              backgroundColor: color,
              icon: isGroup ? Icons.groups : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      Text(
                        time,
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textLight),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (!unread)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.done_all, size: 14, color: AppColors.info),
                        ),
                      Expanded(
                        child: Text(
                          preview,
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMedium),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for an admin to create a group chat from their own patients.
class _CreateGroupSheet extends StatefulWidget {
  final List<Conversation> patients;

  const _CreateGroupSheet({required this.patients});

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final _nameController = TextEditingController();
  final Set<int> _selectedPatientIds = {};
  bool _isCreating = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_selectedPatientIds.length < 2) {
      setState(() => _error = 'Select at least 2 patients.');
      return;
    }
    setState(() {
      _isCreating = true;
      _error = null;
    });
    final chat = context.read<ChatService>();
    final channel = await chat.createChannel(
      name: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
      patientIds: _selectedPatientIds.toList(),
    );
    if (!mounted) return;
    setState(() => _isCreating = false);
    if (channel == null) {
      setState(() => _error = chat.channelError ?? 'Could not create group chat.');
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'New group chat',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'Group name (optional)',
              hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textLight),
              filled: true,
              fillColor: const Color(0xFFF5F5F8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Select at least 2 patients',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMedium),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: widget.patients.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No patients found yet.',
                      style: GoogleFonts.inter(color: AppColors.textMedium),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.patients.length,
                    itemBuilder: (context, i) {
                      final p = widget.patients[i];
                      final selected = _selectedPatientIds.contains(p.patientId);
                      return CheckboxListTile(
                        value: selected,
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selectedPatientIds.add(p.patientId);
                          } else {
                            _selectedPatientIds.remove(p.patientId);
                          }
                        }),
                        title: Text(p.fullName, style: GoogleFonts.inter(fontSize: 14)),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppColors.primary,
                      );
                    },
                  ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: GoogleFonts.inter(fontSize: 13, color: AppColors.danger)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isCreating ? null : _create,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: _isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create group'),
            ),
          ),
        ],
      ),
    );
  }
}
