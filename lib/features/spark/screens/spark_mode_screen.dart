// Kinnect - Kıvılcım Modu Radar Ekranı (v2 Redesign)

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/language/app_l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/proximity_service.dart';
import '../../../shared/widgets/kinnect_image.dart';
import '../../profile/screens/profile_screen.dart';

class SparkModeScreen extends StatefulWidget {
  const SparkModeScreen({super.key});

  @override
  State<SparkModeScreen> createState() => _SparkModeScreenState();
}

class _SparkModeScreenState extends State<SparkModeScreen>
    with TickerProviderStateMixin {
  final ProximityService _proximityService = ProximityService();

  late AnimationController _sweepController;
  late AnimationController _pulseController;
  late AnimationController _togglePulseController;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _sweepController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _togglePulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _proximityService.nearbyUsersStream.listen((users) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sweepController.dispose();
    _pulseController.dispose();
    _togglePulseController.dispose();
    super.dispose();
  }

  Future<void> _toggleSparkMode() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      if (_proximityService.isSparkModeEnabled) {
        await _proximityService.stopSparkMode();
      } else {
        final success = await _proximityService.startSparkMode();
        if (!success) {
          _errorMessage = AppL10n.bluetoothError;
        }
      }
    } catch (_) {
      _errorMessage = AppL10n.anErrorOccurred;
    }
    if (mounted) setState(() => _isLoading = false);
  }

  int _signalPercent(int rssi) =>
      ((rssi + 100) / 70 * 100).clamp(10, 100).round();

  double _angleForUser(ProximityUser user) {
    final key = user.deviceToken ?? user.deviceId;
    return (key.hashCode.abs() % 360) * pi / 180;
  }

  void _showUserSheet(ProximityUser user) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _UserBottomSheet(
        user: user,
        signalPercent: _signalPercent(user.rssi),
        onViewProfile: () {
          Navigator.pop(context);
          if (user.userId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileScreen(userId: user.userId!),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _proximityService.isSparkModeEnabled;
    final nearbyUsers = _proximityService.nearbyUsers;
    final size = MediaQuery.of(context).size;
    final radarCenter = Offset(size.width / 2, size.height / 2 - 20);
    final maxRadius = size.width * 0.40;

    return Scaffold(
      backgroundColor: const Color(0xFF060810),
      body: Stack(
        children: [
          // ── Radar background ──────────────────────────────────
          AnimatedBuilder(
            animation: _sweepController,
            builder: (_, __) => CustomPaint(
              painter: _RadarPainter(
                sweepAngle: _sweepController.value * 2 * pi,
                isActive: isActive,
              ),
              size: Size(size.width, size.height),
            ),
          ),

          // ── User dots on radar ────────────────────────────────
          if (isActive)
            ...nearbyUsers.map((user) {
              final angle = _angleForUser(user);
              final normalized = (user.distance / 15.0).clamp(0.15, 0.90);
              final dotR = maxRadius * normalized;
              final x = radarCenter.dx + cos(angle) * dotR;
              final y = radarCenter.dy + sin(angle) * dotR;
              return Positioned(
                left: x - 22,
                top: y - 22,
                child: _RadarUserDot(
                  user: user,
                  signalPercent: _signalPercent(user.rssi),
                  pulseController: _pulseController,
                  onTap: () => _showUserSheet(user),
                ),
              );
            }),

          // ── Center dot ────────────────────────────────────────
          Positioned(
            left: radarCenter.dx - 6,
            top: radarCenter.dy - 6,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? AppColors.accentOrange : Colors.white38,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppColors.accentOrange.withOpacity(0.8),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
            ),
          ),

          // ── Safe area UI ─────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(isActive, nearbyUsers.length),
                const Spacer(),
                if (isActive && nearbyUsers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Text(
                      AppL10n.scanningSurroundings,
                      style: GoogleFonts.poppins(
                        color: Colors.white38,
                        fontSize: 13,
                      ),
                    ),
                  ),
                _buildToggleButton(isActive),
                const SizedBox(height: 16),
                Text(
                  isActive
                      ? AppL10n.tapToStop
                      : AppL10n.tapToStart,
                  style: GoogleFonts.poppins(
                    color: Colors.white24,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),

          // ── Error ─────────────────────────────────────────────
          if (_errorMessage != null)
            Positioned(
              bottom: 110,
              left: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.redAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.poppins(
                            color: Colors.redAccent, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── TOP BAR ────────────────────────────────────────────────
  Widget _buildTopBar(bool isActive, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white70, size: 16),
            ),
          ),
          const Spacer(),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppL10n.sparkMode,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: isActive
                    ? Text(
                        key: const ValueKey('active'),
                        count == 0
                            ? AppL10n.scanning
                            : AppL10n.nearbyCount(count),
                        style: GoogleFonts.poppins(
                          color: AppColors.accentOrange,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    : Text(
                        key: const ValueKey('inactive'),
                        AppL10n.bluetoothRadar,
                        style: GoogleFonts.poppins(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.accentOrange.withOpacity(0.12)
                  : Colors.white.withOpacity(0.06),
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive
                    ? AppColors.accentOrange.withOpacity(0.35)
                    : Colors.white.withOpacity(0.1),
              ),
            ),
            child: Icon(
              Icons.bluetooth_rounded,
              color: isActive ? AppColors.accentOrange : Colors.white38,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  // ── TOGGLE BUTTON ──────────────────────────────────────────
  Widget _buildToggleButton(bool isActive) {
    return GestureDetector(
      onTap: _isLoading ? null : _toggleSparkMode,
      child: AnimatedBuilder(
        animation: _togglePulseController,
        builder: (_, __) {
          return Stack(
            alignment: Alignment.center,
            children: [
              if (isActive) ...[
                Transform.scale(
                  scale: 1.0 + _togglePulseController.value * 0.22,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accentOrange.withOpacity(
                          (0.35 - _togglePulseController.value * 0.35)
                              .clamp(0, 1),
                        ),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                Transform.scale(
                  scale: 1.0 + _togglePulseController.value * 0.42,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accentOrange.withOpacity(
                          (0.15 - _togglePulseController.value * 0.15)
                              .clamp(0, 1),
                        ),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ],
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isActive
                        ? [AppColors.accentOrange, const Color(0xFFFF1744)]
                        : [
                            const Color(0xFF1A1D2E),
                            const Color(0xFF0E1020)
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: AppColors.accentOrange.withOpacity(0.45),
                            blurRadius: 28,
                            spreadRadius: 3,
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 12,
                          ),
                        ],
                  border: Border.all(
                    color: isActive
                        ? AppColors.accentOrange.withOpacity(0.7)
                        : Colors.white.withOpacity(0.08),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          isActive
                              ? Icons.local_fire_department_rounded
                              : Icons.offline_bolt_outlined,
                          size: 34,
                          color: Colors.white,
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// RADAR BACKGROUND PAINTER
// ═══════════════════════════════════════════════════════════════

class _RadarPainter extends CustomPainter {
  final double sweepAngle;
  final bool isActive;

  const _RadarPainter({required this.sweepAngle, required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 20);
    final maxRadius = size.width * 0.40;

    // Cross lines
    final crossPaint = Paint()
      ..color = Colors.white.withOpacity(0.035)
      ..strokeWidth = 0.8;
    canvas.drawLine(
      Offset(center.dx, center.dy - maxRadius * 1.05),
      Offset(center.dx, center.dy + maxRadius * 1.05),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx - maxRadius * 1.05, center.dy),
      Offset(center.dx + maxRadius * 1.05, center.dy),
      crossPaint,
    );
    // Diagonal lines
    canvas.drawLine(
      Offset(center.dx - maxRadius * 0.74, center.dy - maxRadius * 0.74),
      Offset(center.dx + maxRadius * 0.74, center.dy + maxRadius * 0.74),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx + maxRadius * 0.74, center.dy - maxRadius * 0.74),
      Offset(center.dx - maxRadius * 0.74, center.dy + maxRadius * 0.74),
      crossPaint,
    );

    // Concentric rings
    final ringColor = isActive
        ? const Color(0xFFFF5722).withOpacity(0.18)
        : Colors.white.withOpacity(0.07);
    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final radii = [maxRadius * 0.33, maxRadius * 0.66, maxRadius];
    final labels = ['5m', '10m', '15m'];

    for (int i = 0; i < radii.length; i++) {
      canvas.drawCircle(center, radii[i], ringPaint);

      // Distance label
      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: Colors.white.withOpacity(0.2),
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          center.dx + radii[i] + 4,
          center.dy - 8,
        ),
      );
    }

    if (!isActive) return;

    // Sweep gradient
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: sweepAngle - pi / 2.5,
        endAngle: sweepAngle + 0.01,
        colors: [
          const Color(0xFFFF5722).withOpacity(0.0),
          const Color(0xFFFF5722).withOpacity(0.22),
        ],
        tileMode: TileMode.clamp,
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));
    canvas.drawCircle(center, maxRadius, sweepPaint);

    // Sweep line
    final linePaint = Paint()
      ..color = const Color(0xFFFF5722).withOpacity(0.75)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      center,
      Offset(
        center.dx + cos(sweepAngle) * maxRadius,
        center.dy + sin(sweepAngle) * maxRadius,
      ),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
      old.sweepAngle != sweepAngle || old.isActive != isActive;
}

// ═══════════════════════════════════════════════════════════════
// RADAR USER DOT
// ═══════════════════════════════════════════════════════════════

class _RadarUserDot extends StatelessWidget {
  final ProximityUser user;
  final int signalPercent;
  final AnimationController pulseController;
  final VoidCallback onTap;

  const _RadarUserDot({
    required this.user,
    required this.signalPercent,
    required this.pulseController,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: pulseController,
        builder: (_, __) {
          return SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: 1.0 + pulseController.value * 0.45,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accentOrange.withOpacity(
                          (0.55 - pulseController.value * 0.55).clamp(0, 1),
                        ),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.accentOrange,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentOrange.withOpacity(0.55),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: user.avatarUrl != null
                        ? KinnectImage(
                            imageUrl: user.avatarUrl!,
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: const Color(0xFF1A1D2E),
                            child: const Icon(
                              Icons.person,
                              color: Colors.white54,
                              size: 20,
                            ),
                          ),
                  ),
                ),
                // Signal % badge
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.accentOrange,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      "$signalPercent%",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// USER BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════

class _UserBottomSheet extends StatelessWidget {
  final ProximityUser user;
  final int signalPercent;
  final VoidCallback onViewProfile;

  const _UserBottomSheet({
    required this.user,
    required this.signalPercent,
    required this.onViewProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1020),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.accentOrange.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentOrange.withOpacity(0.08),
            blurRadius: 40,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 22),

          Row(
            children: [
              // Avatar
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accentOrange, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentOrange.withOpacity(0.3),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: user.avatarUrl != null
                      ? KinnectImage(
                          imageUrl: user.avatarUrl!,
                          width: 68,
                          height: 68,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: const Color(0xFF1A1D2E),
                          child: const Icon(Icons.person,
                              color: Colors.white54, size: 36),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName ??
                          user.username ??
                          AppL10n.kinnectUser,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (user.username != null)
                      Text(
                        '@${user.username}',
                        style: GoogleFonts.poppins(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _InfoChip(
                          icon: Icons.location_on_outlined,
                          label: user.distanceText,
                          color: AppColors.accentOrange,
                        ),
                        _InfoChip(
                          icon: Icons.wifi,
                          label: AppL10n.signalLabel(signalPercent),
                          color: const Color(0xFF00E5FF),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: user.userId != null ? onViewProfile : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: user.userId != null
                    ? AppColors.accentOrange
                    : Colors.grey.shade800,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                user.userId != null ? AppL10n.viewProfile : AppL10n.scanning,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
