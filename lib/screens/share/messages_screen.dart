import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import 'family_map_screen.dart';
import 'chat_screen.dart';
import '../../widgets/lottie_background.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  static const _convos = [
    {
      'name': 'Sarah Mom',
      'time': '2m ago',
      'preview': 'Did you see Dad\'s heart rate ...',
      'unread': true,
      'colorValue': 0xFF8B6BAE,
    },
    {
      'name': 'David (Dad)',
      'time': '1h ago',
      'preview': 'I just finished my morning walk...',
      'unread': false,
      'colorValue': 0xFF4A90D9,
    },
    {
      'name': 'Family Care Circle',
      'time': '3h ago',
      'preview': 'Elena: Dr. Smith confirmed the ...',
      'unread': false,
      'colorValue': 0xFF5BA55B,
    },
    {
      'name': 'Nurse Clara',
      'time': 'Yesterday',
      'preview': 'The lab results are ready for yo...',
      'unread': false,
      'colorValue': 0xFFD4875B,
    },
  ];

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
              Expanded(child: _buildConversationList(context)),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.group_add, color: Colors.white),
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

  Widget _buildConversationList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Recent Conversations',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _convos.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF0F0F5)),
            itemBuilder: (context, i) {
              final c = _convos[i];
              return _buildConvoItem(
                context: context,
                name: c['name'] as String,
                time: c['time'] as String,
                preview: c['preview'] as String,
                unread: c['unread'] as bool,
                color: Color(c['colorValue'] as int),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildConvoItem({
    required BuildContext context,
    required String name,
    required String time,
    required String preview,
    required bool unread,
    required Color color,
    int? patientId,
  }) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            contactName: name,
            contactColor: color,
            patientId: patientId,
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color,
              child: Text(
                name[0],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
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
