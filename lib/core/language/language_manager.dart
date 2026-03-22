import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageManager {
  static final LanguageManager _instance = LanguageManager._internal();
  factory LanguageManager() => _instance;
  LanguageManager._internal();

  final ValueNotifier<Locale> localeNotifier =
      ValueNotifier(const Locale('tr'));

  bool get isTR => localeNotifier.value.languageCode == 'tr';

  Future<void> loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString('app_language') ?? 'tr';
    localeNotifier.value = Locale(lang);
  }

  Future<void> setLocale(String lang) async {
    localeNotifier.value = Locale(lang);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', lang);
  }
}
