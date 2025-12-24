import 'dart:math';
import 'package:flutter/material.dart';

/// Level calculation with fire-themed progression
class LevelCalculator {
  // XP formula: baseXP * (level ^ exponent)
  static const int baseXP = 50; // Küçük kullanıcı tabanı için düşürüldü
  static const double exponent = 1.4;

  /// Belirli bir seviye için gereken toplam XP
  static int requiredXPForLevel(int level) {
    if (level <= 1) return 0;
    return (baseXP * (level - 1) * pow(level - 1, exponent - 1)).round();
  }

  /// Mevcut XP'ye göre seviyeyi hesapla
  static int calculateLevel(int totalXP) {
    int level = 1;
    while (requiredXPForLevel(level + 1) <= totalXP) {
      level++;
    }
    return level;
  }

  /// Mevcut seviyedeki ilerleme yüzdesi (0.0 - 1.0)
  static double progressToNextLevel(int totalXP) {
    int currentLevel = calculateLevel(totalXP);
    int currentLevelXP = requiredXPForLevel(currentLevel);
    int nextLevelXP = requiredXPForLevel(currentLevel + 1);

    if (nextLevelXP == currentLevelXP) return 1.0;

    int xpInCurrentLevel = totalXP - currentLevelXP;
    int xpNeededForNext = nextLevelXP - currentLevelXP;

    return (xpInCurrentLevel / xpNeededForNext).clamp(0.0, 1.0);
  }

  /// Seviye isimlerini al (Ateş temalı)
  static String getLevelTitle(int level) {
    const titles = {
      1: 'Kıvılcım',
      2: 'Küçük Alev',
      3: 'Yanan Kor',
      4: 'Meşale',
      5: 'Ateş Dansçısı',
      6: 'Alev Ustası',
      7: 'Volkan',
      8: 'Ateş Lordu',
      9: 'Sönmez Ateş',
      10: 'Efsane Alevler',
    };
    return titles[level.clamp(1, 10)] ?? 'Alevlerin Ötesinde';
  }

  /// Seviye rengini al
  static Color getLevelColor(int level) {
    const colors = [
      Color(0xFFFFB347), // 1
      Color(0xFFFF8C42), // 2
      Color(0xFFFF6B35), // 3
      Color(0xFFFF5722), // 4
      Color(0xFFF4511E), // 5
      Color(0xFFE64A19), // 6
      Color(0xFFD84315), // 7
      Color(0xFFBF360C), // 8
      Color(0xFFA52714), // 9
      Color(0xFF8E0000), // 10
    ];
    return colors[(level - 1).clamp(0, 9)];
  }

  /// XP için kısa format (1500 -> 1.5K)
  static String formatXP(int xp) {
    if (xp >= 1000) {
      return '${(xp / 1000).toStringAsFixed(1)}K';
    }
    return xp.toString();
  }
}
