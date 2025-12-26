import 'package:flutter/material.dart';
import 'theme_manager.dart';

/// 🎨 Merkezi Renk Paleti (Dinamik Tema Destekli)
/// Light/Dark moda göre renkleri otomatik değiştirir.
class AppColors {
  // Tema durumu kontrolü
  static bool get isDark => ThemeManager().isDark;

  // ==================== PRIMARY COLORS ====================
  // Marka renkleri genelde her iki temada da aynı kalır veya çok az değişir
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryDark = Color(0xFF4834D4);
  static const Color primaryLight = Color(0xFF8B5CF6);

  // ==================== BACKGROUNDS ====================
  static Color get bgDark => isDark
      ? const Color(0xFF0A0A0F)
      : const Color(0xFFF5F5F5); // Dark background or light gray
  static Color get bgBlack => isDark
      ? Colors.black
      : const Color(0xFFFAFAFA); // Black in dark mode, off‑white in light mode
  static Color get bgCard => isDark
      ? const Color(0xFF1E1E1E)
      : const Color(0xFFFFFFFF); // Dark card or pure white
  static Color get bgCardDark => isDark
      ? const Color(0xFF121212)
      : const Color(0xFFE0E0E0); // Darker card variant or light gray
  static Color get bgCardLight => isDark
      ? const Color(0xFF2C2C2C)
      : const Color(0xFFD0D0D0); // Light card variant or medium gray
  static Color get bgCardExplore =>
      isDark ? const Color(0xFF16161F) : const Color(0xFFF5F5F5);
  static const Color bgTransparent = Colors.transparent;

  // ==================== ACCENT COLORS ====================
  static const Color accentOrange = Color(0xFFFF5722);
  static const Color accentAmber = Color(0xFFFFAB00);
  static const Color accentRed = Colors.red;
  static const Color accentRedAccent = Colors.redAccent;
  static const Color accentGreen = Colors.green;
  static const Color accentGreenAccent = Colors.greenAccent;
  static const Color accentBlueGrey = Colors.blueGrey;

  // ==================== TEXT COLORS ====================
  static Color get textWhite => isDark ? Colors.white : Colors.black;
  static Color get textWhite70 => isDark ? Colors.white70 : Colors.black87;
  static Color get textWhite60 => isDark ? Colors.white60 : Colors.black54;
  static Color get textWhite54 => isDark ? Colors.white54 : Colors.black54;
  static Color get textWhite38 => isDark ? Colors.white38 : Colors.black38;
  static Color get textWhite30 => isDark ? Colors.white30 : Colors.black26;
  static Color get textWhite24 => isDark ? Colors.white24 : Colors.black12;
  static Color get textWhite12 => isDark ? Colors.white12 : Colors.black12;
  static Color get textWhite10 => isDark ? Colors.white10 : Colors.black12;

  // ==================== GREY SCALE ====================
  static final Color grey400 = Colors.grey.shade400;
  static final Color grey800 = Colors.grey[800]!;
  static final Color grey900 = Colors.grey[900]!;
  static const Color greyShade = Colors.grey;

  // ==================== SPECIAL ====================
  static const Color splash = Color(0xFF06060A);
  static const Color splashPurple = Color(0xFF7C3AED);
  static const Color splashViolet = Color(0xFF8B5CF6);

  // ==================== OPACITY HELPERS ====================
  // Helper functions for common ops
  static Color primaryOpacity(double opacity) => primary.withOpacity(opacity);

  // ==================== GRADIENTS ====================
  static LinearGradient get primaryGradient => const LinearGradient(
        colors: [primary, primaryDark],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get cardGradient => LinearGradient(
        colors: [bgCard, bgCardDark],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}
