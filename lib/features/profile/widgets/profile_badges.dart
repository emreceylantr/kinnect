// Kinnect - Admin ve Özel Rozet Widget'ları
// profile_screen.dart'tan refactor edildi

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// ==========================================
// 👑 ALTIN NEON TAÇ - ADMIN ROZETİ
// ==========================================

/// Admin kullanıcıları için altın taç rozeti
/// Profil isimlerinin yanında gösterilir
class AdminBadge extends StatelessWidget {
  final double size;

  const AdminBadge({
    super.key,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFF6D00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFAB00).withOpacity(0.6),
            blurRadius: 12.0,
            spreadRadius: 2.0,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          FontAwesomeIcons.crown,
          color: Colors.white,
          size: size * 0.55,
        ),
      ),
    );
  }
}

// ==========================================
// ✅ DOĞRULANMIŞ HESAP ROZETİ (Gelecek için)
// ==========================================

/// Doğrulanmış hesaplar için mavi tik rozeti
class VerifiedBadge extends StatelessWidget {
  final double size;

  const VerifiedBadge({
    super.key,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      child: Icon(
        Icons.verified,
        color: const Color(0xFF1DA1F2), // Twitter blue
        size: size,
      ),
    );
  }
}
