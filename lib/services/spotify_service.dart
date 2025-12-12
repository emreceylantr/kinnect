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
    final scopes =
        "user-read-currently-playing user-read-playback-state user-read-recently-played";

    final url = Uri.parse(
      "https://accounts.spotify.com/authorize"
          "?response_type=code"
          "&client_id=$_clientId"
          "&scope=$scopes"
          "&redirect_uri=$_redirectUri"
          "&show_dialog=true",
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<bool> exchangeCodeForToken(String code) async {
    try {
      final res = await http.post(
        Uri.parse("https://accounts.spotify.com/api/token"),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Basic ${base64Encode(utf8.encode("$_clientId:$_clientSecret"))}',
        },
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': _redirectUri,
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        await Supabase.instance.client.from('profiles').update({
          'spotify_refresh_token': data['refresh_token'],
        }).eq('id', Supabase.instance.client.auth.currentUser!.id);
        return true;
      }
    } catch (e) {
      debugPrint("Spotify token error: $e");
    }
    return false;
  }

  Future<Map<String, dynamic>?> getCurrentTrack(String userId) async {
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('spotify_refresh_token')
          .eq('id', userId)
          .single();

      final refreshToken = profile['spotify_refresh_token'];
      if (refreshToken == null) return null;

      final tokenRes = await http.post(
        Uri.parse("https://accounts.spotify.com/api/token"),
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

      // 🔥 ŞU AN ÇALAN
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
            'timestamp': DateTime.now().toIso8601String(),
          };
        }
      }

      // 🔥 SON DİNLENEN
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
            'timestamp': item['played_at'],
          };
        }
      }
    } catch (e) {
      debugPrint("Spotify error: $e");
    }
    return null;
  }
}
