// Kinnect - ML Toxicity Detection Service
// Cloud-hosted ML model for Turkish toxic comment detection

import 'package:http/http.dart' as http;
import 'dart:convert';

/// ML tabanlı toxic yorum tespit servisi.
/// 90%+ doğrulukla Türkçe hakaret/küfür tespiti yapar.
class ToxicityService {
  // Flask ML API - Production (Render)
  static const String baseUrl = 'https://kinnect-toxic-api.onrender.com';

  /// Verilen metni ML model ile toxicity kontrolünden geçirir
  ///
  /// Returns:
  /// - `true` eğer metin toxic ise (model tahmini)
  /// - `false` eğer metin temiz ise veya API'ye ulaşılamazsa
  Future<bool> checkToxicity(String text) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/analiz'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': text}),
          )
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw Exception('API timeout'),
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final isToxic = data['is_toxic'] ?? false;
        final toxicScore = data['toxic_score'] ?? 0.0;

        print(isToxic
            ? '⛔ ML: Toxic (${(toxicScore * 100).toStringAsFixed(1)}%) - "$text"'
            : '✅ ML: Temiz (${(toxicScore * 100).toStringAsFixed(1)}%) - "$text"');

        return isToxic;
      }

      print('⚠️ API hata: ${response.statusCode}');
      return false; // API hatası = yorumu geçir
    } catch (e) {
      print('❌ ML API error: $e');
      return false; // API çalışmıyorsa yorumu geçir
    }
  }
}
