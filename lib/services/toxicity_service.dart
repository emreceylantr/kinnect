import 'package:http/http.dart' as http;
import 'dart:convert';

class ToxicityService {
  // Flask API'nin local network IP adresi
  static const String baseUrl = 'http://192.168.1.26:5001';

  /// Verilen metni toxicity (zehirli içerik) kontrolünden geçirir
  ///
  /// Returns:
  /// - `true` eğer metin uygunsuz/zehirli içerik içeriyorsa
  /// - `false` eğer metin temiz/uygunsa veya API'ye ulaşılamazsa
  Future<bool> checkToxicity(String text) async {
    try {
      final response = await http
          .post(
        Uri.parse('$baseUrl/analiz'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      )
          .timeout(
        const Duration(seconds: 5), // 5 saniye timeout
        onTimeout: () {
          // Timeout durumunda yorumu engelleme (API yanıt vermiyorsa)
          throw Exception('API timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final isToxic = data['is_toxic'] ?? false;

        print(isToxic
            ? '⛔ Toxic yorum engellendi: "${text.substring(0, text.length > 30 ? 30 : text.length)}..."'
            : '✅ Yorum onaylandı');

        return isToxic;
      }

      // API hata döndü, yorumu engelleme
      print('⚠️ Toxicity API hata döndü: ${response.statusCode}');
      return false;
    } catch (e) {
      // Hata durumunda yorumu engelleme (ağ sorunu vs.)
      print('❌ Toxicity check error: $e');
      return false;
    }
  }
}
