import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SpotifyService {
  final String _clientId = "b4d97f8903084d738c777a1dfe07e1fe";
  final String _clientSecret = "REDACTED_SPOTIFY_CLIENT_SECRET";
  final String _redirectUri = "kinnect://callback";

  Future<void> authenticate() async {
    final String scopes = "user-read-currently-playing user-read-playback-state user-read-recently-played";
    final Uri url = Uri.parse("https://accounts.spotify.com/authorize?response_type=code&client_id=$_clientId&scope=$scopes&redirect_uri=$_redirectUri&show_dialog=true");
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<bool> exchangeCodeForToken(String code) async {
    try {
      final response = await http.post(
        Uri.parse("https://accounts.spotify.com/api/token"),
        headers: {'Content-Type': 'application/x-www-form-urlencoded', 'Authorization': 'Basic ' + base64Encode(utf8.encode('$_clientId:$_clientSecret'))},
        body: {'grant_type': 'authorization_code', 'code': code, 'redirect_uri': _redirectUri},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await Supabase.instance.client.from('profiles').update({'spotify_refresh_token': data['refresh_token']}).eq('id', Supabase.instance.client.auth.currentUser!.id);
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<Map<String, dynamic>?> getCurrentTrack(String userId) async {
    try {
      final profile = await Supabase.instance.client.from('profiles').select('spotify_refresh_token').eq('id', userId).single();
      final refreshToken = profile['spotify_refresh_token'];
      if (refreshToken == null) return null;

      final tokenRes = await http.post(Uri.parse("https://accounts.spotify.com/api/token"),
          headers: {'Content-Type': 'application/x-www-form-urlencoded', 'Authorization': 'Basic ' + base64Encode(utf8.encode('$_clientId:$_clientSecret'))},
          body: {'grant_type': 'refresh_token', 'refresh_token': refreshToken});

      if (tokenRes.statusCode != 200) return null;
      final accessToken = jsonDecode(tokenRes.body)['access_token'];

      // 1. Şu an çalanı kontrol et
      final playerRes = await http.get(Uri.parse("https://api.spotify.com/v1/me/player/currently-playing"), headers: {'Authorization': 'Bearer $accessToken'});
      if (playerRes.statusCode == 200 && playerRes.body.isNotEmpty) {
        final data = jsonDecode(playerRes.body);
        if (data['item'] != null) {
          // Eğer şarkı çalıyorsa veya duraklatılmışsa (ama player açıksa)
          return {
            'provider': 'spotify',
            'is_playing': data['is_playing'], // Burası true ise kesin çalıyordur
            'song_name': data['item']['name'],
            'artist_name': data['item']['artists'][0]['name'],
            'image_url': data['item']['album']['images'][0]['url'],
            'external_url': data['item']['external_urls']['spotify'],
          };
        }
      }

      // 2. Çalan yoksa son dinleneni getir (is_playing: false)
      final recentRes = await http.get(Uri.parse("https://api.spotify.com/v1/me/player/recently-played?limit=1"), headers: {'Authorization': 'Bearer $accessToken'});
      if (recentRes.statusCode == 200) {
        final data = jsonDecode(recentRes.body);
        if ((data['items'] as List).isNotEmpty) {
          final item = data['items'][0]['track'];
          return {
            'provider': 'spotify',
            'is_playing': false,
            'song_name': item['name'],
            'artist_name': item['artists'][0]['name'],
            'image_url': item['album']['images'][0]['url'],
            'external_url': item['external_urls']['spotify'],
          };
        }
      }
    } catch (_) {}
    return null;
  }
}