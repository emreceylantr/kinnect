// Kinnect - Profil İstatistik Widget'ı
// profile_screen.dart'tan refactor edildi

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../co../../../core/theme/app_colors.dart';

/// Profil sayfasındaki istatistik gösterimi
/// Gönderi sayısı, takipçi, takip edilen için kullanılır
class ProfileStat extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const ProfileStat({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  offset: const Offset(0, 1),
                  blurRadius: 4,
                  color: AppColors.bgBlack,
                ),
              ],
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white60,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
