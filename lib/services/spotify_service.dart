import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class SpotifyService {
  // GÜVENLİK NOTU: Client Secret normalde sunucuda tutulmalıdır.
  final String _clientId = "b4d97f8903084d738c777a1dfe07e1fe";
  final String _clientSecret = "REDACTED_SPOTIFY_CLIENT_SECRET";

  // 1. BAĞLANTIYI BAŞLAT (Tarayıcıyı Açar)
  Future<void> authenticate() async {
    try {
      // Supabase'in kendi OAuth fonksiyonunu kullanıyoruz.
      // redirectTo: 'kinnect://callback' -> Bu link Info.plist ile eşleşmeli!
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.spotify,
        redirectTo: 'kinnect://callback',
        scopes: 'user-read-currently-playing user-read-playback-state user-read-recently-played',
        queryParams: {
          'prompt': 'consent', // Her seferinde "Kabul ediyor musun?" diye sorsun
        },
      );
    } catch (e) {
      debugPrint("Spotify Bağlantı Hatası: $e");
    }
  }

  // 2. TOKEN'I VERİTABANINA KAYDET
  // Bu fonksiyonu giriş başarılı olup uygulamaya dönünce çağıracağız.
  Future<void> updateTokenFromSession() async {
    final session = Supabase.instance.client.auth.currentSession;

    // Eğer session varsa ve Spotify token'ı içeriyorsa
    if (session != null && session.providerRefreshToken != null) {
      final user = Supabase.instance.client.auth.currentUser;

      // Sadece giriş yöntemi Spotify ise kaydet
      if (user != null && user.appMetadata['provider'] == 'spotify') {
        try {
          await Supabase.instance.client.from('profiles').update({
            'spotify_refresh_token': session.providerRefreshToken,
            'music_provider': 'spotify',
            // Token'ın ne zaman alındığını da güncelleyelim
            'last_music_update_at': DateTime.now().toIso8601String(),
          }).eq('id', user.id);

          debugPrint("✅ Spotify Token'ı Başarıyla Kaydedildi!");
        } catch (e) {
          debugPrint("❌ Veritabanı Kayıt Hatası: $e");
        }
      }
    } else {
      debugPrint("⚠️ Session boş veya Spotify token'ı yok.");
    }
  }

  // 3. ŞARKI VERİSİNİ ÇEK (Burada değişiklik yok, aynen çalışır)
  Future<Map<String, dynamic>?> getCurrentTrack(String userId) async {
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('spotify_refresh_token')
          .eq('id', userId)
          .maybeSingle();

      if (profile == null) return null;
      final refreshToken = profile['spotify_refresh_token'];
      if (refreshToken == null) return null;

      // Token Yenileme
      final tokenRes = await http.post(
        Uri.parse("https://accounts.spotify.com/api/token"), // URL düzeltildi
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Basic ${base64Encode(utf8.encode("$_clientId:$_clientSecret"))}',
        },
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
        },
      );

      if (tokenRes.statusCode != 200) return null;
      final accessToken = jsonDecode(tokenRes.body)['access_token'];

      // Şu an çalan
      final nowRes = await http.get(
        Uri.parse("https://api.spotify.com/v1/me/player/currently-playing"),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (nowRes.statusCode == 200 && nowRes.body.isNotEmpty) {
        final data = jsonDecode(nowRes.body);
        if (data['item'] != null) {
          return {
            'provider': 'spotify',
            'is_playing': data['is_playing'],
            'song_name': data['item']['name'],
            'artist_name': data['item']['artists'][0]['name'],
            'image_url': data['item']['album']['images'][0]['url'],
            'external_url': data['item']['external_urls']['spotify'],
            'preview_url': data['item']['preview_url'],
            'timestamp': DateTime.now().toIso8601String(),
          };
        }
      }

      // Son dinlenen
      final recentRes = await http.get(
        Uri.parse("https://api.spotify.com/v1/me/player/recently-played?limit=1"),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (recentRes.statusCode == 200) {
        final data = jsonDecode(recentRes.body);
        if (data['items'].isNotEmpty) {
          final item = data['items'][0];
          final track = item['track'];
          return {
            'provider': 'spotify',
            'is_playing': false,
            'song_name': track['name'],
            'artist_name': track['artists'][0]['name'],
            'image_url': track['album']['images'][0]['url'],
            'external_url': track['external_urls']['spotify'],
            'preview_url': track['preview_url'],
            'timestamp': item['played_at'],
          };
        }
      }
    } catch (e) {
      debugPrint("Spotify API Error: $e");
    }
    return null;
  }
}