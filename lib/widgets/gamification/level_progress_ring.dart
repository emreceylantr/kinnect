import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/gamification/level_calculator.dart';

/// Circular progress ring that displays around profile picture
class LevelProgressRing extends StatelessWidget {
  final String? avatarUrl;
  final int level;
  final double progress; // 0.0 - 1.0
  final double size;
  final VoidCallback? onTap;

  const LevelProgressRing({
    super.key,
    this.avatarUrl,
    required this.level,
    required this.progress,
    this.size = 100,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final levelColor = LevelCalculator.getLevelColor(level);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Arka plan halka (gri)
            CustomPaint(
              size: Size(size, size),
              painter: _RingPainter(
                progress: 1.0,
                color: Colors.white.withOpacity(0.1),
                strokeWidth: 4,
              ),
            ),

            // İlerleme halkası (renkli)
            CustomPaint(
              size: Size(size, size),
              painter: _RingPainter(
                progress: progress,
                color: levelColor,
                strokeWidth: 4,
              ),
            ),

            // Avatar
            Container(
              width: size - 16,
              height: size - 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: levelColor, width: 2),
                image: avatarUrl != null
                    ? DecorationImage(
                        image: NetworkImage(avatarUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: avatarUrl == null
                  ? Icon(Icons.person, size: size / 2, color: Colors.white54)
                  : null,
            ),

            // Seviye rozeti
            Positioned(
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [levelColor, levelColor.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: levelColor.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Text(
                  'LV.$level',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, // Başlangıç: üstten
      2 * pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
