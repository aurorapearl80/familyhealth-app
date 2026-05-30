import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/ble_summary_service.dart';
import '../../services/location_service.dart';
import '../../services/onesignal_service.dart';
import '../../services/patient_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/profile_avatar.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoggingOut = false;

  // ── Logout ─────────────────────────────────────────────────────────────────

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Log Out',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to log out?',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.textMedium)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Log Out',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    setState(() => _isLoggingOut = true);

    // 1. Stop GPS tracking
    context.read<LocationService>().stop();

    // 2. Unlink OneSignal identity
    await OneSignalService.logout();

    // 3. Invalidate the token on the server (best-effort)
    await AuthService.logoutFromServer();

    if (!context.mounted) return;

    // 4. Clear local data
    await AuthService.clearToken();
    if (!context.mounted) return;
    context.read<BleSummaryService>().clear();
    context.read<PatientService>().clear();

    // 5. Navigate to login
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _capitalize(String? s) {
    if (s == null || s.isEmpty) return '—';
    return s[0].toUpperCase() + s.substring(1);
  }

  String _formatUnit(String? unit) {
    if (unit == null) return '—';
    return unit.replaceAll('_', '/').toUpperCase();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final patient = context.watch<PatientService>();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      body: RefreshIndicator(
        onRefresh: () => context.read<PatientService>().fetch(),
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildSliverAppBar(context, patient),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildStatsRow(patient),
                    const SizedBox(height: 20),
                    _buildSection(
                      icon: Icons.person_outline_rounded,
                      title: 'Personal Information',
                      color: const Color(0xFF6C63FF),
                      child: _buildPersonalInfo(patient),
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      icon: Icons.medical_services_outlined,
                      title: 'Medical Information',
                      color: const Color(0xFFE91E8C),
                      child: _buildMedicalInfo(patient),
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      icon: Icons.shield_outlined,
                      title: 'Insurance',
                      color: const Color(0xFF00BCD4),
                      child: _buildInsuranceInfo(patient),
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      icon: Icons.business_outlined,
                      title: 'Organization & Programs',
                      color: const Color(0xFF4CAF50),
                      child: _buildOrgInfo(patient),
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      icon: Icons.straighten_outlined,
                      title: 'Measurement Units',
                      color: const Color(0xFFFF9800),
                      child: _buildUnitsInfo(patient),
                    ),
                    const SizedBox(height: 28),
                    _buildLogoutButton(context),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sliver app bar (collapses to a regular top bar) ────────────────────────

  Widget _buildSliverAppBar(BuildContext context, PatientService patient) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: const Color(0xFF1A1040),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
          onPressed: () => context.read<PatientService>().fetch(),
        ),
      ],
      title: Text(
        'My Profile',
        style: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: _buildHeroSection(patient),
      ),
    );
  }

  Widget _buildHeroSection(PatientService patient) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A1040),
            Color(0xFF2D1B69),
            Color(0xFF4A2C9E),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            left: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          // Content
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 50), // space for status bar + appbar
                // Profile image
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFFE91E8C)],
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF1A1040),
                    ),
                    child: ProfileAvatar.buildAvatar(
                      imageUrl: patient.profileImageUrl,
                      initials: patient.initials,
                      radius: 44,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  patient.displayName,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                if (patient.email != null)
                  Text(
                    patient.email!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white54,
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (patient.memberId != null) ...[
                      _heroBadge(
                        patient.memberId!,
                        Icons.badge_outlined,
                        const Color(0xFF6C63FF),
                      ),
                      const SizedBox(width: 8),
                    ],
                    _heroBadge(
                      _capitalize(patient.status),
                      patient.status == 'active'
                          ? Icons.check_circle_outline
                          : Icons.cancel_outlined,
                      patient.status == 'active'
                          ? const Color(0xFF4CAF50)
                          : AppColors.danger,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats row ──────────────────────────────────────────────────────────────

  Widget _buildStatsRow(PatientService patient) {
    final age = patient.age;
    return Row(
      children: [
        Expanded(
          child: _statCard(
            label: 'AGE',
            value: age != null ? '$age yrs' : '—',
            icon: Icons.cake_outlined,
            color: const Color(0xFF6C63FF),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            label: 'HEIGHT',
            value: patient.height ?? '—',
            icon: Icons.height_rounded,
            color: const Color(0xFF00BCD4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            label: 'WEIGHT',
            value: patient.weight != null ? '${patient.weight} lbs' : '—',
            icon: Icons.monitor_weight_outlined,
            color: const Color(0xFF4CAF50),
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppColors.textLight,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Section wrapper ────────────────────────────────────────────────────────

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Color color,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 15),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      ],
    );
  }

  // ── Info row helper ────────────────────────────────────────────────────────

  Widget _infoRow(String label, String? value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: AppColors.textLight),
            const SizedBox(width: 6),
          ],
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? '—',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipRow(String label, List<String> items, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textLight,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          if (items.isEmpty)
            Text('—',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: items.map((item) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    item,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ── Section content builders ───────────────────────────────────────────────

  Widget _buildPersonalInfo(PatientService p) {
    return Column(
      children: [
        _infoRow('Full Name', p.fullName, icon: Icons.person_outline),
        _infoRow('Gender', _capitalize(p.gender), icon: Icons.wc_outlined),
        _infoRow('Date of Birth', _formatDate(p.dateOfBirth),
            icon: Icons.cake_outlined),
        _infoRow('Email', p.email, icon: Icons.email_outlined),
        _infoRow('Phone', p.phone, icon: Icons.phone_outlined),
        _infoRow('Home Phone', p.homeNumber, icon: Icons.home_outlined),
        _infoRow('Address', p.completeAddress,
            icon: Icons.location_on_outlined),
        _infoRow('State', p.state, icon: Icons.map_outlined),
        _infoRow('Country', p.country, icon: Icons.flag_outlined),
        _infoRow('ZIP Code', p.zipCode, icon: Icons.pin_drop_outlined),
      ],
    );
  }

  Widget _buildMedicalInfo(PatientService p) {
    return Column(
      children: [
        _chipRow('Conditions', p.conditions, AppColors.danger),
        const Divider(height: 8, thickness: 0.5),
        const SizedBox(height: 8),
        _infoRow('General Practitioner', p.generalPractitioner,
            icon: Icons.local_hospital_outlined),
        _infoRow('Angel Support', p.angelSupport,
            icon: Icons.support_agent_outlined),
        _infoRow('Glucose Test Rate', p.glucoseTestRate,
            icon: Icons.water_drop_outlined),
        const Divider(height: 8, thickness: 0.5),
        const SizedBox(height: 8),
        _chipRow('Practitioners', p.practitioners, const Color(0xFFE91E8C)),
      ],
    );
  }

  Widget _buildInsuranceInfo(PatientService p) {
    final hasPrimary = p.primaryInsuranceName != null;
    final hasSecondary = p.secondaryInsuranceName != null;

    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.shield_outlined,
                size: 13, color: const Color(0xFF00BCD4)),
            const SizedBox(width: 6),
            Text(
              'Primary Insurance',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF00BCD4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (hasPrimary) ...[
          _infoRow('Provider', p.primaryInsuranceName),
          _infoRow('Policy ID', p.primaryInsurancePolicyId),
          _infoRow('Group #', p.primaryInsuranceGroupNumber),
          _infoRow('Phone', p.primaryInsurancePhone),
        ] else
          Text('No primary insurance on file',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textLight)),
        if (hasSecondary) ...[
          const Divider(height: 16, thickness: 0.5),
          Row(
            children: [
              Icon(Icons.shield_outlined,
                  size: 13, color: AppColors.textLight),
              const SizedBox(width: 6),
              Text(
                'Secondary Insurance',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _infoRow('Provider', p.secondaryInsuranceName),
          _infoRow('Policy ID', p.secondaryInsurancePolicyId),
          _infoRow('Phone', p.secondaryInsurancePhone),
        ],
      ],
    );
  }

  Widget _buildOrgInfo(PatientService p) {
    return Column(
      children: [
        _infoRow('Organization', p.organization,
            icon: Icons.business_outlined),
        _infoRow('Member ID', p.memberId, icon: Icons.badge_outlined),
        _infoRow('Status', _capitalize(p.status),
            icon: Icons.info_outline_rounded),
        const Divider(height: 8, thickness: 0.5),
        const SizedBox(height: 8),
        _chipRow('Enrolled Programs', p.enrolledPrograms,
            const Color(0xFF4CAF50)),
      ],
    );
  }

  Widget _buildUnitsInfo(PatientService p) {
    return Column(
      children: [
        _infoRow('Height', _formatUnit(p.unitHeight),
            icon: Icons.height_rounded),
        _infoRow('Weight', _formatUnit(p.unitWeight),
            icon: Icons.monitor_weight_outlined),
        _infoRow('Temperature', _formatUnit(p.unitTemperature),
            icon: Icons.thermostat_outlined),
        _infoRow('Glucose', _formatUnit(p.unitGlucose),
            icon: Icons.water_drop_outlined),
        _infoRow('Blood Pressure', _formatUnit(p.unitBloodPressure),
            icon: Icons.monitor_heart_outlined),
      ],
    );
  }

  // ── Logout button ──────────────────────────────────────────────────────────

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoggingOut ? null : () => _logout(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFECEC),
          foregroundColor: AppColors.danger,
          disabledBackgroundColor: const Color(0xFFFFECEC),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
                color: AppColors.danger.withValues(alpha: 0.3)),
          ),
        ),
        child: _isLoggingOut
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.danger.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Logging out…',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.danger.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.logout_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Log Out',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
