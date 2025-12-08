import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:math' as math;

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

    _mainController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(_mainController);

    _logController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _logSlide = Tween<Offset>(begin: const Offset(1.2, -1.5), end: const Offset(0.0, 0.1)).animate(CurvedAnimation(parent: _logController, curve: Curves.easeIn));
    _logRotate = Tween<double>(begin: 0.0, end: -0.3).animate(_logController);
    _logFade = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 40),
    ]).animate(_logController);

    _sparkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _sparkAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _sparkController, curve: Curves.easeOut));

    _steamController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _steamAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _steamController, curve: Curves.easeOut));
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
      _logController.forward(from: 0.0).then((_) {
        _mainController.forward(from: 0.0);
        _sparkController.forward(from: 0.0);
      });
    } else {
      _steamController.forward(from: 0.0);
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    Color fireColor;
    bool isAlive = !widget.isExpired;

    if (!isAlive) {
      fireColor = Colors.blueGrey.shade700;
    } else if (widget.count == 0) {
      fireColor = Colors.grey.shade700;
    } else if (widget.count < 5) {
      fireColor = Colors.orange;
    } else {
      fireColor = Colors.redAccent;
    }

    if (isAlive && !widget.isFueled && widget.count > 0) fireColor = fireColor.withOpacity(0.7);

    return GestureDetector(
      onTap: _handleTap,
      child: SizedBox(
        width: widget.size + 16,
        height: widget.size + 16,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              bottom: 0,
              child: Icon(
                FontAwesomeIcons.xmarksLines,
                color: const Color(0xFF4E342E),
                size: widget.size * 0.9,
              ),
            ),
            if (isAlive)
              AnimatedBuilder(
                animation: _sparkController,
                builder: (context, child) {
                  if (!_sparkController.isAnimating) return const SizedBox();
                  double val = _sparkAnim.value;
                  double spread = val * 25;
                  return Stack(
                    children: List.generate(5, (index) {
                      double angle = (index * 72 - 90) * (math.pi / 180);
                      return Transform.translate(
                        offset: Offset(math.cos(angle) * spread, math.sin(angle) * spread - 10),
                        child: Opacity(
                          opacity: 1.0 - val,
                          child: const Icon(Icons.circle, color: Colors.yellow, size: 4),
                        ),
                      );
                    }),
                  );
                },
              ),
            Positioned(
              bottom: 4,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Icon(
                  isAlive ? FontAwesomeIcons.fire : FontAwesomeIcons.smog,
                  color: fireColor,
                  size: widget.size,
                  shadows: (isAlive && widget.isFueled) ? [
                    BoxShadow(color: fireColor.withOpacity(0.6), blurRadius: 15, spreadRadius: 1)
                  ] : [],
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _logController,
              builder: (context, child) {
                if (!_logController.isAnimating) return const SizedBox();
                return SlideTransition(
                  position: _logSlide,
                  child: RotationTransition(
                    turns: _logRotate,
                    child: FadeTransition(
                      opacity: _logFade,
                      child: Container(
                        width: 20, height: 8,
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
            AnimatedBuilder(
              animation: _steamController,
              builder: (context, child) {
                if (!_steamController.isAnimating) return const SizedBox();
                double val = _steamAnim.value;
                return Positioned(
                  bottom: 10 + (val * 20),
                  child: Opacity(
                    opacity: 1.0 - val,
                    child: Transform.scale(
                      scale: 0.5 + val,
                      child: Icon(FontAwesomeIcons.cloud, color: Colors.blueGrey.withOpacity(0.5), size: widget.size),
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