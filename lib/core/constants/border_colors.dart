// Kinnect - Border Color Options
// Profil halka renkleri için merkezi tanım

import 'package:flutter/material.dart';

/// Profil avatar'ı için seçilebilir halka renkleri
/// edit_profile_screen.dart ve profile_header.dart tarafından kullanılır
class BorderColors {
  static const List<List<Color>> options = [
    [Color(0xFF6C63FF), Color(0xFF448AFF)], // 1. Orijinal (Mor-Mavi)
    [Color(0xFFf5a5cf), Color(0xFFE084B0)], // 2. Pembe
    [Colors.orange, Colors.deepOrange], // 3. Turuncu
    [Colors.black, Color(0xFF2C2C2C)], // 4. Siyah
    [Colors.white, Color(0xFFE0E0E0)], // 5. Beyaz
    [Color(0xFFFF512F), Color(0xFFDD2476)], // 6. Ateş (Kırmızı)
    [Color(0xFF00b09b), Color(0xFF96c93d)], // 7. Doğa (Yeşil)
    [Color(0xFFFFD700), Color(0xFFFDB931)], // 8. Altın
    [Colors.transparent, Colors.transparent], // 9. Yok
  ];

  /// Verilen index'e göre gradient renklerini döndürür
  static List<Color> getColors(int index) {
    if (index < 0 || index >= options.length) {
      return options[0]; // Varsayılan: Mor-Mavi
    }
    return options[index];
  }
}
