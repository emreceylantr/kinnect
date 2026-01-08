// Kinnect - Kıvılcım Modu Ekranı
// Yakındaki Kinnect kullanıcılarını gösterir

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/services/proximity_service.dart';
import '../../profile/screens/profile_screen.dart';

class SparkModeScreen extends StatefulWidget {
  const SparkModeScreen({super.key});

  @override
  State<SparkModeScreen> createState() => _SparkModeScreenState();
}

class _SparkModeScreenState extends State<SparkModeScreen>
    with TickerProviderStateMixin {
  final ProximityService _proximityService = ProximityService();

  late AnimationController _pulseController;
  late AnimationController _rotateController;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

    // Yakındaki kullanıcıları dinle
    _proximityService.nearbyUsersStream.listen((users) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
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
          _errorMessage = "Bluetooth'u açtığından emin ol!";
        }
      }
    } catch (e) {
      _errorMessage = "Bir hata oluştu: $e";
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _proximityService.isSparkModeEnabled;
    final nearbyUsers = _proximityService.nearbyUsers;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Kıvılcım Modu",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Arka plan efektleri
          if (isActive) _buildActiveBackground(),

          // Ana içerik
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Açıklama
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    isActive
                        ? "🔥 Ateş yanıyor! Çevrendeki Kinnect kullanıcılarını arıyor..."
                        : "Yakınındaki Kinnect kullanıcılarını bul ve yeni bağlantılar kur!",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Merkez buton / radar
                Expanded(
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Pulse dalgaları
                        if (isActive) ..._buildPulseWaves(),

                        // Ana buton
                        GestureDetector(
                          onTap: _isLoading ? null : _toggleSparkMode,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: isActive
                                    ? [
                                        AppColors.accentOrange,
                                        AppColors.accentRedAccent,
                                      ]
                                    : [
                                        Colors.grey.shade800,
                                        Colors.grey.shade900,
                                      ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: AppColors.accentOrange
                                            .withValues(alpha: 0.5),
                                        blurRadius: 30,
                                        spreadRadius: 5,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Center(
                              child: _isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : Icon(
                                      isActive
                                          ? Icons.local_fire_department
                                          : Icons.offline_bolt_outlined,
                                      size: 64,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Hata mesajı
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber, color: Colors.red),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: GoogleFonts.poppins(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Yakındaki kullanıcılar listesi - sabit konumda (spark butonunu etkilemesin)
                if (isActive && nearbyUsers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 60),
                    child: _buildNearbyUsersList(nearbyUsers),
                  )
                else
                  const SizedBox(height: 200), // Boş alan - layout sabit kalsın

                // Alt bilgi
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    isActive
                        ? "Bluetooth ile yakınındaki kullanıcıları tarıyor"
                        : "Başlatmak için butona dokun",
                    style: GoogleFonts.poppins(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Aktif mod arka plan efektleri
  Widget _buildActiveBackground() {
    return AnimatedBuilder(
      animation: _rotateController,
      builder: (context, child) {
        return CustomPaint(
          painter: _RadarPainter(
            rotation: _rotateController.value * 2 * pi,
            color: AppColors.accentOrange,
          ),
          size: Size.infinite,
        );
      },
    );
  }

  /// Pulse dalgaları
  List<Widget> _buildPulseWaves() {
    return List.generate(3, (index) {
      return AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final scale = 1.0 + (_pulseController.value * (index + 1) * 0.3);
          final opacity = (1.0 - _pulseController.value) * 0.3;

          return Transform.scale(
            scale: scale,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accentOrange.withValues(alpha: opacity),
                  width: 2,
                ),
              ),
            ),
          );
        },
      );
    });
  }

  /// Yakındaki kullanıcılar listesi
  Widget _buildNearbyUsersList(List<ProximityUser> users) {
    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.people,
                    color: AppColors.accentOrange, size: 20),
                const SizedBox(width: 8),
                Text(
                  "Yakınında ${users.length} kişi",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return _buildUserCard(user);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Kullanıcı kartı
  Widget _buildUserCard(ProximityUser user) {
    return GestureDetector(
      onTap: () {
        if (user.userId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProfileScreen(userId: user.userId!),
            ),
          );
        }
      },
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.accentOrange.withValues(alpha: 0.2),
              AppColors.accentRedAccent.withValues(alpha: 0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.accentOrange.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.accentOrange, AppColors.accentAmber],
                ),
              ),
              child: user.avatarUrl != null
                  ? ClipOval(
                      child: Image.network(
                        user.avatarUrl!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(Icons.person, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 8),

            // İsim veya cihaz ID
            Text(
              user.username ?? "Kinnect User",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // Mesafe
            Text(
              user.distanceText,
              style: GoogleFonts.poppins(
                color: AppColors.accentOrange,
                fontSize: 10,
              ),
            ),

            // Sinyal gücü
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final strength = ((user.rssi.abs() - 30) / 70 * 4).clamp(0, 4);
                return Container(
                  width: 4,
                  height: 6 + (i * 3).toDouble(),
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: i < (4 - strength)
                        ? AppColors.accentOrange
                        : Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

/// Radar efekti painter
class _RadarPainter extends CustomPainter {
  final double rotation;
  final Color color;

  _RadarPainter({required this.rotation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.4;

    // Radar çizgileri
    final paint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, maxRadius * (i / 3), paint);
    }

    // Dönen radar çizgisi
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: rotation,
        endAngle: rotation + pi / 4,
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.3),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    canvas.drawCircle(center, maxRadius, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.rotation != rotation;
  }
}
