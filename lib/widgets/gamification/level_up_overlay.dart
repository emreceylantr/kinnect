import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/gamification/level_calculator.dart';

/// Full-screen overlay animation when user levels up
class LevelUpOverlay extends StatefulWidget {
  final int newLevel;
  final VoidCallback onDismiss;

  const LevelUpOverlay({
    super.key,
    required this.newLevel,
    required this.onDismiss,
  });

  @override
  State<LevelUpOverlay> createState() => _LevelUpOverlayState();
}

class _LevelUpOverlayState extends State<LevelUpOverlay>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _particleController;
  late Animation<double> _scaleAnim;

  final List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnim = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    _particleController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..addListener(() => setState(() {}));

    // Generate particles
    final random = Random();
    for (int i = 0; i < 30; i++) {
      _particles.add(_Particle(
        x: random.nextDouble(),
        y: random.nextDouble(),
        vx: (random.nextDouble() - 0.5) * 0.02,
        vy: -random.nextDouble() * 0.01 - 0.005,
        size: random.nextDouble() * 8 + 4,
        color: [
          const Color(0xFFFF6B35),
          const Color(0xFFFF9800),
          const Color(0xFFFFEB3B),
          const Color(0xFFFF5722),
        ][random.nextInt(4)],
      ));
    }

    _scaleController.forward();
    _particleController.repeat();

    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), widget.onDismiss);
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final levelTitle = LevelCalculator.getLevelTitle(widget.newLevel);
    final levelColor = LevelCalculator.getLevelColor(widget.newLevel);

    return Material(
      color: Colors.black.withOpacity(0.85),
      child: Stack(
        children: [
          // Particles
          ..._particles.map((p) {
            final progress = _particleController.value;
            return Positioned(
              left: (p.x + p.vx * progress * 50) *
                  MediaQuery.of(context).size.width,
              top: (p.y + p.vy * progress * 50) *
                  MediaQuery.of(context).size.height,
              child: Opacity(
                opacity: (1 - progress).clamp(0.0, 1.0),
                child: Container(
                  width: p.size,
                  height: p.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.color,
                    boxShadow: [
                      BoxShadow(
                        color: p.color.withOpacity(0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          // Level up card
          Center(
            child: ScaleTransition(
              scale: _scaleAnim,
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: levelColor.withOpacity(0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: levelColor.withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Fire emoji
                    const Text('🔥', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 16),

                    // Level up text
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [levelColor, const Color(0xFFFF9800)],
                      ).createShader(bounds),
                      child: Text(
                        'SEVİYE ATLADIN!',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // New level badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [levelColor, levelColor.withOpacity(0.7)],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: levelColor.withOpacity(0.5),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Text(
                        'LV.${widget.newLevel}',
                        style: GoogleFonts.poppins(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Level title
                    Text(
                      levelTitle,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Dismiss button
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: TextButton(
                onPressed: widget.onDismiss,
                child: Text(
                  'Devam Et',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 16,
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

class _Particle {
  double x, y, vx, vy, size;
  Color color;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
  });
}
