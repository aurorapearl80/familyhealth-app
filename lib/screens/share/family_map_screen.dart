import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../theme/app_colors.dart';

class FamilyMapScreen extends StatefulWidget {
  const FamilyMapScreen({super.key});

  @override
  State<FamilyMapScreen> createState() => _FamilyMapScreenState();
}

class _FamilyMapScreenState extends State<FamilyMapScreen> {
  GoogleMapController? _mapController;

  static const _initialCamera = CameraPosition(
    target: LatLng(14.5995, 120.9842),
    zoom: 15,
  );

  final _members = [
    _FamilyMember(
      name: 'Gabriel',
      lastUpdate: '2m ago',
      isOnline: true,
      position: const LatLng(14.5995, 120.9842),
    ),
    _FamilyMember(
      name: 'Elena',
      lastUpdate: '15m ago',
      isOnline: false,
      position: const LatLng(14.6015, 120.9865),
    ),
  ];

  Set<Marker> get _markers => _members.map((m) {
        return Marker(
          markerId: MarkerId(m.name),
          position: m.position,
          infoWindow: InfoWindow(title: m.name),
        );
      }).toSet();

  Set<Circle> get _circles => _members
      .where((m) => m.isOnline)
      .map((m) => Circle(
            circleId: CircleId('${m.name}_range'),
            center: m.position,
            radius: 120,
            fillColor: AppColors.primary.withOpacity(0.15),
            strokeColor: AppColors.primary.withOpacity(0.3),
            strokeWidth: 1,
          ))
      .toSet();

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
                Expanded(
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: _initialCamera,
                        markers: _markers,
                        circles: _circles,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        onMapCreated: (c) => _mapController = c,
                      ),
                      // Layer toggle
                      Positioned(
                        top: 16,
                        right: 16,
                        child: _buildLayerButton(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Bottom sheet
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
          // Drag handle
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
          Expanded(
            child: ListView.builder(
              controller: controller,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _members.length,
              itemBuilder: (_, i) => Padding(
                padding: EdgeInsets.only(right: i < _members.length - 1 ? 12 : 0),
                child: _buildMemberCard(_members[i]),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMemberCard(_FamilyMember member) {
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
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: member.isOnline
                        ? const Color(0xFF8B7355)
                        : const Color(0xFFD4A8A8),
                    child: const Icon(Icons.person,
                        color: Colors.white, size: 24),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: member.isOnline
                            ? AppColors.primary
                            : AppColors.textLight,
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
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      'Last updated: ${member.lastUpdate}',
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
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.navigation,
                            color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'DIRECTIONS',
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
              _buildIconBtn(Icons.chat_bubble_outline),
              const SizedBox(width: 6),
              _buildIconBtn(Icons.phone_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconBtn(IconData icon) {
    return GestureDetector(
      onTap: () {},
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

class _FamilyMember {
  final String name;
  final String lastUpdate;
  final bool isOnline;
  final LatLng position;

  const _FamilyMember({
    required this.name,
    required this.lastUpdate,
    required this.isOnline,
    required this.position,
  });
}
