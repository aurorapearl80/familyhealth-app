import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../theme/app_colors.dart';
import 'home/home_dashboard_screen.dart';
import 'achieve/activity_screen.dart';
import 'share/messages_screen.dart';
import 'share/family_map_screen.dart';
import 'devices/devices_screen.dart';

class MainNavScreen extends StatefulWidget {
  final int initialIndex;
  const MainNavScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  late int _selectedIndex;
  bool _isAdmin = false;
  bool _roleLoaded = false;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await AuthService.getRoleType();
    if (mounted) {
      setState(() {
        _isAdmin = role == 'admin';
        _roleLoaded = true;
      });
    }
  }

  // ── Screens & nav items built based on role ───────────────────────────────

  List<Widget> get _screens => [
        const HomeDashboardScreen(),
        const ActivityScreen(),
        const MessagesScreen(),
        if (_isAdmin) FamilyMapScreen(isActive: _selectedIndex == 3),
        const DevicesScreen(),
      ];

  // Each entry: (activeIcon, inactiveIcon, label, isSpecial)
  List<_NavEntry> get _navEntries => [
        _NavEntry(Icons.home_rounded, Icons.home_outlined, 'Home'),
        _NavEntry(Icons.show_chart_rounded, Icons.show_chart_outlined, 'Achieve'),
        _NavEntry(Icons.people_rounded, Icons.people_outlined, 'Share'),
        if (_isAdmin)
          _NavEntry(Icons.location_on_rounded, Icons.location_on_outlined, 'Family'),
        _NavEntry(Icons.devices_rounded, Icons.devices_outlined, 'Devices'),
      ];

  @override
  Widget build(BuildContext context) {
    if (!_roleLoaded) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final entries = _navEntries;

    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: Column(
        children: [
          _buildConnectivityBanner(),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: _screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFEEEEF5), width: 1),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                entries.length,
                (i) => _buildNavItem(i, entries[i]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Connectivity banner ───────────────────────────────────────────────────

  Widget _buildConnectivityBanner() {
    return Consumer<ConnectivityService>(
      builder: (context, conn, _) {
        if (conn.isOnline) return const SizedBox.shrink();
        return Material(
          color: const Color(0xFFB71C1C),
          child: SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No internet connection — some features may be unavailable',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Bottom nav item ───────────────────────────────────────────────────────

  Widget _buildNavItem(int index, _NavEntry entry) {
    final isSelected = _selectedIndex == index;
    // Share tab (index 2) always gets the circle treatment
    const shareIndex = 2;

    if (index == shareIndex && isSelected) {
      return GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(entry.activeIcon, color: Colors.white, size: 24),
            ),
          ],
        ),
      );
    }

    // Achieve tab (index 1) gets the pill treatment when selected
    const achieveIndex = 1;
    final activeColor = (index == achieveIndex ||
            index == shareIndex ||
            (entry.label == 'Family'))
        ? AppColors.primary
        : Colors.black;
    final inactiveColor = AppColors.textLight;

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected && index == achieveIndex)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(entry.activeIcon, color: Colors.white, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      entry.label,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              Icon(
                isSelected ? entry.activeIcon : entry.inactiveIcon,
                color: isSelected ? activeColor : inactiveColor,
                size: 24,
              ),
              const SizedBox(height: 2),
              Text(
                entry.label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: isSelected ? activeColor : inactiveColor,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavEntry {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
  const _NavEntry(this.activeIcon, this.inactiveIcon, this.label);
}