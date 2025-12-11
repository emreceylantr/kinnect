import 'dart:convert';
import 'package:http/http.dart' as http;

class AppleMusicService {
  // iTunes API üzerinden şarkı arama
  Future<List<Map<String, dynamic>>> searchSongs(String query) async {
    if (query.isEmpty) return [];

    try {
      final url = Uri.parse(
          'https://itunes.apple.com/search?term=$query&media=music&entity=song&limit=5');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List results = data['results'];

        return results.map((song) {
          return {
            'name': song['trackName'],
            'artist': song['artistName'],
            'image': song['artworkUrl100']?.replaceAll('100x100', '600x600'), // Yüksek kalite resim
            'preview_url': song['previewUrl'], // 30 sn MP3 linki
            'external_url': song['trackViewUrl'], // Apple Music linki
            'uri': song['trackId'].toString(),
          };
        }).toList();
      }
    } catch (e) {
      print("Apple Music Arama Hatası: $e");
    }
    return [];
  }
}