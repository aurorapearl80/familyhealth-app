import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/conversation.dart';
import '../../models/patient_location.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/patient_location_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/profile_avatar.dart';
import 'chat_screen.dart';

class FamilyMapScreen extends StatefulWidget {
  const FamilyMapScreen({super.key});

  @override
  State<FamilyMapScreen> createState() => _FamilyMapScreenState();
}

class _FamilyMember {
  final Conversation conversation;
  final PatientLocation? location;

  const _FamilyMember({required this.conversation, this.location});

  String get name => conversation.fullName;

  /// Heuristic, not a real presence signal — the API doesn't report one.
  bool get isOnline =>
      location != null && DateTime.now().difference(location!.recordedAt) < const Duration(minutes: 10);
}

class _FamilyMapScreenState extends State<FamilyMapScreen> {
  GoogleMapController? _mapController;

  static const _defaultCamera = CameraPosition(
    target: LatLng(14.5995, 120.9842),
    zoom: 13,
  );

  bool _isAdmin = false;
  bool _roleLoaded = false;
  bool _isLoading = false;
  String? _error;
  List<_FamilyMember> _members = [];

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
    if (!_isAdmin) return;
    await _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final chat = context.read<ChatService>();
      await chat.fetchConversations();
      if (chat.error != null && chat.conversations.isEmpty) {
        setState(() {
          _error = chat.error;
          _isLoading = false;
        });
        return;
      }
      final conversations = chat.conversations;
      final locations = await Future.wait(
        conversations.map((c) => PatientLocationService.fetchLatest(c.patientId)),
      );
      if (!mounted) return;
      setState(() {
        _members = [
          for (var i = 0; i < conversations.length; i++)
            _FamilyMember(conversation: conversations[i], location: locations[i]),
        ];
        _isLoading = false;
      });
      _fitCameraToMembers();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load family locations: $e';
        _isLoading = false;
      });
    }
  }

  void _fitCameraToMembers() {
    final withLocation = _members.where((m) => m.location != null).toList();
    if (withLocation.isEmpty || _mapController == null) return;
    final first = withLocation.first.location!;
    _mapController!.animateCamera(
      CameraUpdate.newLatLng(LatLng(first.latitude, first.longitude)),
    );
  }

  Color _colorFor(int i) {
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
    return '${diff.inDays}d ago';
  }

  Set<Marker> get _markers {
    final markers = <Marker>{};
    for (var i = 0; i < _members.length; i++) {
      final m = _members[i];
      if (m.location == null) continue;
      markers.add(Marker(
        markerId: MarkerId('member_${m.conversation.patientId}'),
        position: LatLng(m.location!.latitude, m.location!.longitude),
        infoWindow: InfoWindow(title: m.name),
      ));
    }
    return markers;
  }

  Set<Circle> get _circles {
    final circles = <Circle>{};
    for (final m in _members) {
      if (m.location == null || !m.isOnline) continue;
      circles.add(Circle(
        circleId: CircleId('member_${m.conversation.patientId}_range'),
        center: LatLng(m.location!.latitude, m.location!.longitude),
        radius: 120,
        fillColor: AppColors.primary.withOpacity(0.15),
        strokeColor: AppColors.primary.withOpacity(0.3),
        strokeWidth: 1,
      ));
    }
    return circles;
  }

  void _openChat(_FamilyMember member, Color color) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          contactName: member.name,
          contactColor: color,
          contactImageUrl: member.conversation.profileImageUrl,
          patientId: member.conversation.patientId,
          recipientUserId: member.conversation.recipientUserId,
          isAdmin: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildMapArea()),
              ],
            ),
            if (_roleLoaded && _isAdmin)
              DraggableScrollableSheet(
                initialChildSize: 0.38,
                minChildSize: 0.22,
                maxChildSize: 0.65,
                builder: (_, controller) => _buildFamilySheet(controller),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapArea() {
    if (!_roleLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_isAdmin) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'The family map is only available for admin accounts right now.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: AppColors.textMedium),
          ),
        ),
      );
    }
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: _defaultCamera,
          markers: _markers,
          circles: _circles,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          onMapCreated: (c) {
            _mapController = c;
            _fitCameraToMembers();
          },
        ),
        Positioned(top: 16, right: 16, child: _buildLayerButton()),
        if (_isLoading)
          const Positioned(
            top: 16,
            left: 16,
            child: _LoadingChip(),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Vitals',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: AppColors.textDark),
                onPressed: () {},
              ),
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.lightCard,
                child: const Icon(Icons.person,
                    color: AppColors.textMedium, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLayerButton() {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 6),
          ],
        ),
        child: const Icon(Icons.layers_outlined,
            color: AppColors.textDark, size: 22),
      ),
    );
  }

  Widget _buildFamilySheet(ScrollController controller) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, -2)),
        ],
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textLight.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Family Members',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'ADD NEW',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildSheetBody(controller)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSheetBody(ScrollController controller) {
    if (_isLoading && _members.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _members.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: GoogleFonts.inter(color: AppColors.textMedium)),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadMembers, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_members.isEmpty) {
      return Center(
        child: Text('No family members yet', style: GoogleFonts.inter(color: AppColors.textMedium)),
      );
    }
    return ListView.builder(
      controller: controller,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _members.length,
      itemBuilder: (_, i) => Padding(
        padding: EdgeInsets.only(right: i < _members.length - 1 ? 12 : 0),
        child: _buildMemberCard(_members[i], _colorFor(i)),
      ),
    );
  }

  Widget _buildMemberCard(_FamilyMember member, Color color) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Stack(
                children: [
                  ProfileAvatar.buildAvatar(
                    imageUrl: member.conversation.profileImageUrl,
                    initials: member.name.isNotEmpty ? member.name[0] : '?',
                    radius: 22,
                    backgroundColor: color,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: member.isOnline ? AppColors.primary : AppColors.textLight,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      member.location != null
                          ? 'Last updated: ${_timeAgo(member.location!.recordedAt)}'
                          : 'Location unavailable',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: member.location != null
                      ? () => _mapController?.animateCamera(CameraUpdate.newLatLng(
                            LatLng(member.location!.latitude, member.location!.longitude),
                          ))
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: member.location != null ? AppColors.primary : AppColors.textLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.navigation, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'LOCATE',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _buildIconBtn(Icons.chat_bubble_outline, onTap: () => _openChat(member, color)),
              const SizedBox(width: 6),
              _buildIconBtn(Icons.phone_outlined, onTap: () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 16),
      ),
    );
  }
}

class _LoadingChip extends StatelessWidget {
  const _LoadingChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 6)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 8),
          Text('Loading locations…', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
