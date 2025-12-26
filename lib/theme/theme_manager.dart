import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🌓 Tema Yöneticisi
/// Uygulamanın karanlık/aydınlık mod durumunu yönetir ve tercihi kaydeder.
class ThemeManager {
  // Singleton pattern
  static final ThemeManager _instance = ThemeManager._internal();
  factory ThemeManager() => _instance;
  ThemeManager._internal();

  // Varsayılan olarak karanlık mod
  final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

  // Getter ile mevcut durumu kontrol et
  bool get isDark => themeNotifier.value == ThemeMode.dark;

  // Başlangıçta tercihi yükle
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkMode =
        prefs.getBool('isDarkMode') ?? true; // Varsayılan true (Dark)
    themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  // Temayı değiştir ve kaydet
  Future<void> toggleTheme(bool isDark) async {
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDark);
  }
}
