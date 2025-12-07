import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:math' as math;

class FuelButton extends StatefulWidget {
  final bool isFueled;
  final int count;
  final VoidCallback onTap;
  final double size;

  const FuelButton({
    super.key,
    required this.isFueled,
    required this.count,
    required this.onTap,
    this.size = 28,
  });

  @override
  State<FuelButton> createState() => _FuelButtonState();
}

class _FuelButtonState extends State<FuelButton>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _logController;
  late AnimationController _sparkController;
  late AnimationController _steamController;

  late Animation<double> _scaleAnim;
  late Animation<Offset> _logSlide;
  late Animation<double> _logFade;
  late Animation<double> _logRotate;
  late Animation<double> _sparkAnim;
  late Animation<double> _steamAnim;

  @override
  void initState() {
    super.initState();

    // --- Ateş büyüme / nefes alma ---
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.35)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.35, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_mainController);

    // --- Kütük animasyonu ---
    _logController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _logSlide = Tween<Offset>(
      begin: const Offset(1.3, -1.4),
      end: const Offset(0.0, 0.1),
    ).animate(
      CurvedAnimation(
        parent: _logController,
        curve: Curves.easeInOut,
      ),
    );

    _logRotate = Tween<double>(begin: 0.0, end: -0.45).animate(_logController);

    _logFade = Tween<double>(begin: 0.0, end: 1.0)
        .chain(CurveTween(curve: Curves.easeOut))
        .animate(_logController);

    // --- Kıvılcımlar ---
    _sparkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _sparkAnim = CurvedAnimation(
      parent: _sparkController,
      curve: Curves.easeOut,
    );

    // --- Duman / Söndürme ---
    _steamController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _steamAnim = CurvedAnimation(
      parent: _steamController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _mainController.dispose();
    _logController.dispose();
    _sparkController.dispose();
    _steamController.dispose();
    super.dispose();
  }

  // 🔥 Tıklama davranışı
  void _handleTap() {
    if (!widget.isFueled) {
      // --- HARLAMA ---
      _logController.forward(from: 0.0);
      _mainController.forward(from: 0.0);
      _sparkController.forward(from: 0.0);
    } else {
      // --- SÖNDÜRME ---
      _steamController.forward(from: 0.0);
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 Ateş rengi hesaplama
    Color fireColor;
    if (widget.count == 0) fireColor = Colors.grey.shade700;
    else if (widget.count < 5) fireColor = Colors.orange;
    else fireColor = Colors.redAccent;

    if (!widget.isFueled && widget.count > 0) {
      fireColor = fireColor.withOpacity(0.7);
    }

    return GestureDetector(
      onTap: _handleTap,
      child: SizedBox(
        width: widget.size + 16,
        height: widget.size + 18,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // --- SABİT KÜTÜK TABANI ---
            Positioned(
              bottom: 3,
              child: Icon(
                FontAwesomeIcons.xmarksLines,
                color: const Color(0xFF4E342E),
                size: widget.size * 0.9,
              ),
            ),

            // --- KIVILCIM PARÇACIKLARI ---
            AnimatedBuilder(
              animation: _sparkController,
              builder: (_, __) {
                if (!_sparkController.isAnimating) return const SizedBox();
                final v = _sparkAnim.value;
                final opacity = (1.0 - v).clamp(0.0, 1.0);
                final spread = v * 26;

                return Stack(
                  children: List.generate(6, (i) {
                    final angle = (-90 + i * 36) * (math.pi / 180);
                    return Transform.translate(
                      offset: Offset(
                        math.cos(angle) * spread,
                        math.sin(angle) * spread - 6,
                      ),
                      child: Opacity(
                        opacity: opacity,
                        child: const Icon(
                          Icons.circle,
                          color: Colors.yellow,
                          size: 4,
                        ),
                      ),
                    );
                  }),
                );
              },
            ),

            // --- ANA ATEŞ ---
            Positioned(
              bottom: 5,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Icon(
                  FontAwesomeIcons.fire,
                  size: widget.size,
                  color: fireColor,
                  shadows: widget.isFueled
                      ? [
                    BoxShadow(
                      color: fireColor.withOpacity(0.6),
                      blurRadius: 14,
                      spreadRadius: 1,
                    )
                  ]
                      : [],
                ),
              ),
            ),

            // --- KÜTÜK UÇUŞU ---
            AnimatedBuilder(
              animation: _logController,
              builder: (_, __) {
                if (!_logController.isAnimating) return const SizedBox();
                return SlideTransition(
                  position: _logSlide,
                  child: RotationTransition(
                    turns: _logRotate,
                    child: FadeTransition(
                      opacity: _logFade,
                      child: Container(
                        width: 22,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFF5D4037),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.black54),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // --- DUMAN ---
            AnimatedBuilder(
              animation: _steamController,
              builder: (_, __) {
                if (!_steamController.isAnimating) return const SizedBox();

                final v = _steamAnim.value;

                return Positioned(
                  bottom: 10 + (v * 22),
                  child: Opacity(
                    opacity: (1.0 - v).clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.5 + (v * 1.1),
                      child: Icon(
                        FontAwesomeIcons.cloud,
                        color: Colors.blueGrey.withOpacity(0.6),
                        size: widget.size,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
