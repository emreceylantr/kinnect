// Kinnect - AppBar Butonları
// home_screen.dart'tan refactor edildi

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../co../../../core/theme/app_colors.dart';

// ==========================================
// 🔔 LOTTİE BİLDİRİM ÇANI BUTONU
// ==========================================

/// Animasyonlu bildirim çanı butonu
/// Lottie animasyonu ve bildirim rozeti içerir
class LottieBellButton extends StatelessWidget {
  final int notificationCount;
  final VoidCallback onTap;

  const LottieBellButton({
    super.key,
    required this.notificationCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 55,
        height: 55,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Lottie Animasyonu (Görsel olarak BÜYÜK)
            Lottie.asset(
              'assets/animations/bell.json',
              width: 85,
              height: 85,
              fit: BoxFit.contain,
            ),
            // Bildirim Rozeti (Badge)
            if (notificationCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.bgDark, width: 2),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Center(
                    child: Text(
                      notificationCount > 99
                          ? '99+'
                          : notificationCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                      textAlign: TextAlign.center,
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

// ==========================================
// 💬 CYBER MESAJ BUTONU
// ==========================================

/// Yeşil neon efektli mesaj butonu
/// CustomPaint ile özel chat balonu çizimi
class CyberMessageButton extends StatelessWidget {
  final VoidCallback onTap;

  const CyberMessageButton({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const neonGreen = Color(0xFF69F0AE);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
          ),
          child: CustomPaint(
            painter: _ChatBubblePainter(neonGreen),
          ),
        ),
      ),
    );
  }
}

/// Chat balonu çizen CustomPainter
class _ChatBubblePainter extends CustomPainter {
  final Color color;

  _ChatBubblePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    const double padding = 7.0;
    const double cornerRadius = 6.0;

    final Path path = Path();

    path.moveTo(padding + cornerRadius, padding);
    path.lineTo(size.width - padding - cornerRadius, padding);
    path.arcToPoint(Offset(size.width - padding, padding + cornerRadius),
        radius: const Radius.circular(cornerRadius));
    path.lineTo(size.width - padding, size.height - padding - 6);

    path.lineTo(size.width - padding + 1.5, size.height - padding + 1.5);
    path.lineTo(size.width - padding - 5, size.height - padding);

    path.lineTo(padding + cornerRadius, size.height - padding);
    path.arcToPoint(Offset(padding, size.height - padding - cornerRadius),
        radius: const Radius.circular(cornerRadius));
    path.lineTo(padding, padding + cornerRadius);
    path.arcToPoint(Offset(padding + cornerRadius, padding),
        radius: const Radius.circular(cornerRadius));

    canvas.drawPath(path, paint);

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..color = color;

    final centerX = size.width / 2;
    final centerY = (padding + (size.height - padding)) / 2 - 1;

    canvas.drawLine(
      Offset(centerX - 5, centerY - 2.5),
      Offset(centerX + 5, centerY - 2.5),
      linePaint,
    );

    canvas.drawLine(
      Offset(centerX - 5, centerY + 2.5),
      Offset(centerX, centerY + 2.5),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
