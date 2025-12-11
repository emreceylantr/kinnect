import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SpotifyService {
  // 🔥 API Bilgilerin (Ekran görüntüsünden doğrulandı)
  final String _clientId = "b4d97f8903084d738c777a1dfe07e1fe";
  final String _clientSecret = "REDACTED_SPOTIFY_CLIENT_SECRET";
  final String _redirectUri = "kinnect://callback";

  // 1. Tarayıcıyı Açıp İzin İsteme
  Future<void> authenticate() async {
    final String scopes = "user-read-currently-playing user-read-playback-state user-read-recently-played";
    final String authUrl = "https://accounts.spotify.com/authorize"
        "?response_type=code"
        "&client_id=$_clientId"
        "&scope=$scopes"
        "&redirect_uri=$_redirectUri";

    final Uri url = Uri.parse(authUrl);

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      debugPrint("Spotify auth sayfası açılamadı.");
    }
  }

  // 2. Gelen Kodu Token'a Çevirip Kaydetme
  Future<bool> exchangeCodeForToken(String code) async {
    try {
      final response = await http.post(
        Uri.parse("https://accounts.spotify.com/api/token"),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Basic ' + base64Encode(utf8.encode('$_clientId:$_clientSecret')),
        },
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': _redirectUri,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final refreshToken = data['refresh_token'];

        // Supabase'e kaydet
        final userId = Supabase.instance.client.auth.currentUser!.id;
        await Supabase.instance.client.from('profiles').update({
          'spotify_refresh_token': refreshToken,
        }).eq('id', userId);

        return true;
      } else {
        debugPrint("Token Hatası: ${response.body}");
      }
    } catch (e) {
      debugPrint("Token Alma Hatası: $e");
    }
    return false;
  }

  // 3. Şarkı Verisini Çekme
  Future<Map<String, dynamic>?> getCurrentTrack(String userId) async {
    try {
      // a. Refresh Token Çek
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('spotify_refresh_token')
          .eq('id', userId)
          .single();

      final refreshToken = profile['spotify_refresh_token'];
      if (refreshToken == null) return null;

      // b. Yeni Access Token Al
      final tokenResponse = await http.post(
        Uri.parse("https://accounts.spotify.com/api/token"),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Basic ' + base64Encode(utf8.encode('$_clientId:$_clientSecret')),
        },
        body: {'grant_type': 'refresh_token', 'refresh_token': refreshToken},
      );

      if (tokenResponse.statusCode != 200) return null;
      final accessToken = jsonDecode(tokenResponse.body)['access_token'];

      // c. Şu An Çalan Şarkıyı İste
      final playerResponse = await http.get(
        Uri.parse("https://api.spotify.com/v1/me/player/currently-playing"),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (playerResponse.statusCode == 200 && playerResponse.body.isNotEmpty) {
        final data = jsonDecode(playerResponse.body);
        if (data['item'] != null) {
          return {
            'is_playing': data['is_playing'],
            'song_name': data['item']['name'],
            'artist_name': data['item']['artists'][0]['name'],
            'image_url': data['item']['album']['images'][0]['url'],
            'external_url': data['item']['external_urls']['spotify'],
          };
        }
      }

      // d. Eğer çalan yoksa "Son Dinlenen" (Recently Played) İste
      final recentResponse = await http.get(
        Uri.parse("https://api.spotify.com/v1/me/player/recently-played?limit=1"),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (recentResponse.statusCode == 200) {
        final data = jsonDecode(recentResponse.body);
        if ((data['items'] as List).isNotEmpty) {
          final item = data['items'][0]['track'];
          return {
            'is_playing': false,
            'song_name': item['name'],
            'artist_name': item['artists'][0]['name'],
            'image_url': item['album']['images'][0]['url'],
            'external_url': item['external_urls']['spotify'],
          };
        }
      }
    } catch (e) {
      debugPrint("Şarkı çekme hatası: $e");
    }
    return null;
  }
}