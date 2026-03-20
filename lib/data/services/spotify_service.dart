import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/api_keys.dart';

class SpotifyService {
  // Spotify API credentials
  final String _clientId = ApiKeys.spotifyClientId;
  final String _clientSecret = ApiKeys.spotifyClientSecret;
  final String _redirectUri = ApiKeys.spotifyRedirectUri;

  // 1. BAĞLANTIYI BAŞLAT - Direkt Spotify OAuth (Supabase Auth DEĞİL!)
  // Bu sayede mevcut hesaba Spotify bağlanır, yeni hesap OLUŞMAZ.
  Future<void> authenticate() async {
    try {
      final scopes =
          'user-read-currently-playing user-read-playback-state user-read-recently-played user-top-read';

      final authUrl = Uri.https('accounts.spotify.com', '/authorize', {
        'client_id': _clientId,
        'response_type': 'code',
        'redirect_uri': _redirectUri,
        'scope': scopes,
        'show_dialog': 'true', // Her zaman izin ekranı göster
      });

      debugPrint("🎵 Spotify Auth URL: $authUrl");

      if (await canLaunchUrl(authUrl)) {
        await launchUrl(authUrl, mode: LaunchMode.externalApplication);
      } else {
        debugPrint("❌ Spotify URL açılamadı");
      }
    } catch (e) {
      debugPrint("Spotify Bağlantı Hatası: $e");
    }
  }

  // 2. CALLBACK'TEN GELEN KODU İŞLE
  // Deep link'ten gelen authorization code'u alıp token'a çevir
  Future<bool> handleCallback(Uri uri) async {
    try {
      debugPrint("🎵 Spotify Callback URI: $uri");

      // URI'den code parametresini al
      final code = uri.queryParameters['code'];
      if (code == null) {
        debugPrint("❌ Authorization code bulunamadı");
        return false;
      }

      debugPrint("✅ Authorization code alındı: ${code.substring(0, 10)}...");

      // Code'u access token'a çevir
      final tokenResponse = await http.post(
        Uri.parse("https://accounts.spotify.com/api/token"),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization':
              'Basic ${base64Encode(utf8.encode("$_clientId:$_clientSecret"))}',
        },
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': _redirectUri,
        },
      );

      debugPrint("🔑 Token Response Status: ${tokenResponse.statusCode}");

      if (tokenResponse.statusCode != 200) {
        debugPrint("❌ Token alma hatası: ${tokenResponse.body}");
        return false;
      }

      final tokenData = jsonDecode(tokenResponse.body);
      final refreshToken = tokenData['refresh_token'];
      final accessToken = tokenData['access_token'];

      debugPrint("🔑 Access Token: ${accessToken != null ? 'ALINDI' : 'YOK'}");
      debugPrint(
          "🔑 Refresh Token: ${refreshToken != null ? 'ALINDI' : 'YOK'}");

      if (refreshToken == null) {
        debugPrint("❌ Refresh token alınamadı");
        return false;
      }

      // Mevcut kullanıcının profiline kaydet
      final userId = Supabase.instance.client.auth.currentUser?.id;
      debugPrint("👤 Kullanıcı ID: $userId");

      if (userId == null) {
        debugPrint("❌ Kullanıcı oturumu yok");
        return false;
      }

      debugPrint("💾 Veritabanına kaydediliyor...");

      final updateResult = await Supabase.instance.client
          .from('profiles')
          .update({
            'spotify_refresh_token': refreshToken,
            'music_provider': 'spotify',
            'last_music_update_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId)
          .select();

      debugPrint("💾 Update sonucu: $updateResult");
      debugPrint("✅ Spotify başarıyla bağlandı ve kaydedildi!");
      return true;
    } catch (e) {
      debugPrint("❌ Spotify callback hatası: $e");
      return false;
    }
  }

  // Eski fonksiyon - artık kullanılmıyor ama uyumluluk için bırakıldı
  Future<void> updateTokenFromSession() async {
    // Bu fonksiyon artık kullanılmıyor
    // Yeni flow: authenticate() -> handleCallback()
    debugPrint("⚠️ updateTokenFromSession artık kullanılmıyor");
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
          'Authorization':
              'Basic ${base64Encode(utf8.encode("$_clientId:$_clientSecret"))}',
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
        Uri.parse(
            "https://api.spotify.com/v1/me/player/recently-played?limit=1"),
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

  // 4. TOP SANATÇI & ŞARKILARI ÇEK ve user_profiles'a kaydet
  Future<bool> syncTopMusic(String userId) async {
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('spotify_refresh_token')
          .eq('id', userId)
          .maybeSingle();

      final refreshToken = profile?['spotify_refresh_token'];
      if (refreshToken == null) return false;

      // Token yenile
      final tokenRes = await http.post(
        Uri.parse('https://accounts.spotify.com/api/token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization':
              'Basic ${base64Encode(utf8.encode("$_clientId:$_clientSecret"))}',
        },
        body: {'grant_type': 'refresh_token', 'refresh_token': refreshToken},
      );
      if (tokenRes.statusCode != 200) return false;
      final accessToken = jsonDecode(tokenRes.body)['access_token'];

      // Top sanatçılar (uzun dönem)
      final artistsRes = await http.get(
        Uri.parse(
            'https://api.spotify.com/v1/me/top/artists?limit=20&time_range=long_term'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      // Top şarkılar (uzun dönem)
      final tracksRes = await http.get(
        Uri.parse(
            'https://api.spotify.com/v1/me/top/tracks?limit=20&time_range=long_term'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      final List<String> topArtists = [];
      final List<String> topTracks = [];

      if (artistsRes.statusCode == 200) {
        final data = jsonDecode(artistsRes.body);
        for (final item in (data['items'] as List)) {
          topArtists.add(item['name'] as String);
        }
      }

      if (tracksRes.statusCode == 200) {
        final data = jsonDecode(tracksRes.body);
        for (final item in (data['items'] as List)) {
          topTracks.add(item['name'] as String);
        }
      }

      if (topArtists.isEmpty && topTracks.isEmpty) return false;

      // user_profiles'a kaydet (upsert)
      await Supabase.instance.client.from('user_profiles').upsert({
        'user_id': userId,
        'spotify_top_artists': topArtists,
        'spotify_top_tracks': topTracks,
        'spotify_synced_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      debugPrint(
          '✅ Spotify sync: ${topArtists.length} sanatçı, ${topTracks.length} şarkı');
      return true;
    } catch (e) {
      debugPrint('Spotify syncTopMusic Error: $e');
      return false;
    }
  }

  // Spotify bağlı mı kontrol et
  Future<bool> isConnected(String userId) async {
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('spotify_refresh_token')
          .eq('id', userId)
          .maybeSingle();
      return profile?['spotify_refresh_token'] != null;
    } catch (_) {
      return false;
    }
  }
}
