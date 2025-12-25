import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:math' as math;
import 'package:lottie/lottie.dart';

class FuelButton extends StatefulWidget {
  final bool isFueled;
  final int count;
  final VoidCallback onTap;
  final double size;
  final bool isExpired; // Sönmüş mü?

  const FuelButton({
    super.key,
    required this.isFueled,
    required this.count,
    required this.onTap,
    this.size = 28,
    this.isExpired = false,
  });

  @override
  State<FuelButton> createState() => _FuelButtonState();
}

class _FuelButtonState extends State<FuelButton> with TickerProviderStateMixin {
  // --- KONTROLCÜLER ---
  late AnimationController _mainController;
  late AnimationController _logController;
  late AnimationController _sparkController;
  late AnimationController _steamController;

  // --- ANİMASYON DEĞERLERİ ---
  late Animation<double> _scaleAnim;
  late Animation<double> _logXAnim;
  late Animation<double> _logYAnim;
  late Animation<double> _logFade;
  late Animation<double> _logRotate;
  late Animation<double> _sparkAnim;
  late Animation<double> _steamAnim;

  @override
  void initState() {
    super.initState();

    // 1. ATEŞ POP EFEKTİ
    _mainController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3).chain(CurveTween(curve: Curves.easeOutBack)), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 50),
    ]).animate(_mainController);

    // 2. ODUN FIRLATMA
    _logController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

    _logXAnim = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(parent: _logController, curve: Curves.easeOutBack),
    );

    // Odun ateşin tepesine düşsün
    _logYAnim = Tween<double>(begin: -40.0, end: -16.0).animate(
      CurvedAnimation(parent: _logController, curve: Curves.easeInQuad),
    );

    _logRotate = Tween<double>(begin: 0.0, end: -0.3).animate(_logController);

    _logFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _logController, curve: const Interval(0.85, 1.0, curve: Curves.easeOut)),
    );

    // 3. KIVILCIMLAR
    _sparkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _sparkAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _sparkController, curve: Curves.easeOutQuad));

    // 4. BUHAR/DUMAN
    _steamController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _steamAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _steamController, curve: Curves.easeOut));

    // Zincirleme Reaksiyon
    _logController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _mainController.forward(from: 0.0);
        _sparkController.forward(from: 0.0);
        _logController.reset();
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _logController.dispose();
    _sparkController.dispose();
    _steamController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.isExpired) return;

    if (!widget.isFueled) {
      _logController.forward(from: 0.0);
    } else {
      _steamController.forward(from: 0.0);
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    Color fireColor;
    bool isAlive = !widget.isExpired;

    // --- RENK MANTIĞI ---
    if (!isAlive) {
      fireColor = Colors.grey.shade400;
    } else if (widget.count == 0) {
      fireColor = Colors.white30; // Sönük
    } else if (widget.count < 5) {
      fireColor = const Color(0xFFFFAB00); // Amber
    } else {
      fireColor = const Color(0xFFFF5722); // Alev Kırmızısı
    }

    if (isAlive && !widget.isFueled && widget.count > 0) {
      fireColor = fireColor.withOpacity(0.85);
    }

    // --- KÜTÜK RENKLERİ (SABİT KAHVERENGİ) ---
    final Color backLogColor = const Color(0xFF2D1E1B); // Koyu Kahve
    final Color frontLogColor = const Color(0xFF4E342E); // Açık Kahve

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.translucent,
      child: SizedBox(
        width: widget.size + 30,
        height: widget.size + 30,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // --- ZEMİN: KÜTÜKLER ---
            Positioned(
              bottom: 4,
              child: SizedBox(
                width: widget.size,
                height: widget.size * 0.4,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // Arkadaki odun
                    Container(
                      width: widget.size * 0.8,
                      height: 6,
                      decoration: BoxDecoration(
                        color: backLogColor,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                            color: Colors.black54,
                            width: 0.5
                        ),
                      ),
                    ),
                    // Çapraz sol
                    Positioned(
                      bottom: 2,
                      child: Transform.rotate(
                        angle: -math.pi / 6,
                        child: Container(
                          width: widget.size * 0.85,
                          height: 6,
                          decoration: BoxDecoration(
                            color: frontLogColor,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                                color: Colors.black45,
                                width: 0.5
                            ),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black45,
                                  offset: Offset(0, 1),
                                  blurRadius: 2
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Çapraz sağ
                    Positioned(
                      bottom: 2,
                      child: Transform.rotate(
                        angle: math.pi / 6,
                        child: Container(
                          width: widget.size * 0.85,
                          height: 6,
                          decoration: BoxDecoration(
                            color: frontLogColor,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                                color: Colors.black45,
                                width: 0.5
                            ),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black54,
                                  offset: Offset(0, 2),
                                  blurRadius: 3
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- ANA GÖRSEL (ATEŞ veya DUMAN) ---
            Positioned(
              bottom: 0,
              // GÜNCELLEME BURADA:
              // isAlive (Alev) -> left: 5
              // !isAlive (Duman) -> right: 2
              left: isAlive ? 5 : null,
              right: isAlive ? null : 2,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: isAlive
                    ? ColorFiltered(
                  // Canlı Ateş (f.json)
                  colorFilter: ColorFilter.mode(fireColor, BlendMode.srcIn),
                  child: Lottie.asset(
                    'assets/animations/f.json',
                    width: widget.size * 1.7,
                    height: widget.size * 1.7,
                    fit: BoxFit.contain,
                    controller: widget.count == 0
                        ? (AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat())
                        : null,
                  ),
                )
                    : Opacity(
                  // Kül Olmuş Duman (s.json)
                  opacity: 0.7,
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
                    child: Lottie.asset(
                      'assets/animations/s.json',
                      width: widget.size * 1.5,
                      height: widget.size * 1.5,
                      fit: BoxFit.contain,
                      controller: (AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat()),
                    ),
                  ),
                ),
              ),
            ),

            // KIVILCIMLAR (Sadece Canlıyken)
            if (isAlive)
              AnimatedBuilder(
                animation: _sparkController,
                builder: (context, child) {
                  if (!_sparkController.isAnimating) return const SizedBox();
                  double val = _sparkAnim.value;
                  double opacity = (1.0 - val).clamp(0.0, 1.0);
                  double spread = val * 28;

                  return Positioned(
                    top: 2,
                    left: 2,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: List.generate(5, (index) {
                        double angleDeg = -90 + (index - 2) * 28.0;
                        double rad = angleDeg * (math.pi / 180);

                        return Transform.translate(
                          offset: Offset(math.cos(rad) * spread, math.sin(rad) * spread - 12),
                          child: Opacity(
                            opacity: opacity,
                            child: Container(
                              width: 3.5,
                              height: 3.5,
                              decoration: BoxDecoration(
                                color: Colors.amberAccent,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.orange, blurRadius: 4, spreadRadius: 1)],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                },
              ),

            // UÇAN ODUN (Sadece Canlıyken atılabilir)
            if (isAlive)
              AnimatedBuilder(
                animation: _logController,
                builder: (context, child) {
                  if (!_logController.isAnimating) return const SizedBox();
                  return Transform.translate(
                    offset: Offset(_logXAnim.value, _logYAnim.value),
                    child: Transform.rotate(
                      angle: _logRotate.value,
                      child: Opacity(
                        opacity: _logFade.value,
                        child: Container(
                          width: 16,
                          height: 5,
                          decoration: BoxDecoration(
                            color: const Color(0xFF795548),
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(color: Colors.black38, width: 0.5),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

            // BUHAR/DUMAN EFEKTİ (Unlike işlemi)
            if (isAlive)
              AnimatedBuilder(
                animation: _steamController,
                builder: (context, child) {
                  if (!_steamController.isAnimating) return const SizedBox();
                  double val = _steamAnim.value;
                  return Positioned(
                    bottom: 15 + (val * 25),
                    child: Opacity(
                      opacity: (1.0 - val).clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 0.6 + val,
                        child: Icon(FontAwesomeIcons.cloud, color: Colors.white54, size: widget.size),
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