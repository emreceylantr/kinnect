import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class AppleMusicService {
  static const platform = MethodChannel('com.kinnect.app/music');

  // ▼▼▼▼ DEĞİŞEN KISIM ▼▼▼▼
  Future<bool> requestPermission() async {
    try {
      // Artık direkt iOS (Swift) tarafına "İzni sen iste" diyoruz.
      final bool granted = await platform.invokeMethod('requestAppleMusicPermission');
      return granted;
    } catch (e) {
      print("İzin hatası: $e");
      return false;
    }
  }
  // ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲

  Future<Map<String, dynamic>?> getCurrentTrack() async {
    try {
      // Paketli kontrolü sildik, direkt Swift'ten veriyi istiyoruz.
      // Swift zaten izin yoksa null döndürecek şekilde ayarlandı.

      final Map<dynamic, dynamic>? native =
      await platform.invokeMethod('getAppleMusicTrack');

      if (native == null) return null;

      final isPlaying = native['is_playing'] ?? false;
      final song = native['name'] ?? '';
      final artist = native['artist'] ?? '';
      final storeId = native['storeId'] ?? '0';

      if (storeId != '0') {
        final res = await http.get(
          Uri.parse('https://itunes.apple.com/lookup?id=$storeId&country=TR'),
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['resultCount'] > 0) {
            final track = data['results'][0];
            return {
              'provider': 'apple',
              'is_playing': isPlaying,
              'song_name': track['trackName'],
              'artist_name': track['artistName'],
              'image_url':
              track['artworkUrl100']?.replaceAll('100x100', '600x600'),
              'preview_url': track['previewUrl'],
              'external_url': track['trackViewUrl'],
              'timestamp': DateTime.now().toIso8601String(),
            };
          }
        }
      }

      return _searchFallback(song, artist, isPlaying);
    } catch (_) {}
    return null;
  }

  // Top şarkı/sanatçıları çek ve user_profiles'a kaydet
  Future<bool> syncTopMusic(String userId) async {
    try {
      final granted = await requestPermission();
      if (!granted) return false;

      final List<dynamic>? tracks =
          await platform.invokeMethod('getTopAppleMusicTracks');

      final List<String> topArtists = [];
      final List<String> topTracks = [];
      final Set<String> seenArtists = {};

      for (final t in (tracks ?? [])) {
        final artist = (t['artist'] as String?) ?? '';
        final track = (t['track'] as String?) ?? '';
        if (artist.isNotEmpty && !seenArtists.contains(artist)) {
          topArtists.add(artist);
          seenArtists.add(artist);
        }
        if (track.isNotEmpty) topTracks.add(track);
      }

      // Kütüphane boşsa şu an çalan şarkıyı fallback olarak kullan
      if (topArtists.isEmpty) {
        final current = await getCurrentTrack();
        if (current != null) {
          final artist = current['artist_name'] as String? ?? '';
          final track = current['song_name'] as String? ?? '';
          if (artist.isNotEmpty) topArtists.add(artist);
          if (track.isNotEmpty) topTracks.add(track);
        }
      }

      if (topArtists.isEmpty && topTracks.isEmpty) return false;

      await Supabase.instance.client.from('user_profiles').upsert({
        'user_id': userId,
        'spotify_top_artists': topArtists.take(20).toList(),
        'spotify_top_tracks': topTracks.take(20).toList(),
        'spotify_synced_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      debugPrint(
          '✅ Apple Music sync: ${topArtists.length} sanatçı, ${topTracks.length} şarkı');
      return true;
    } catch (e) {
      debugPrint('Apple Music syncTopMusic Error: $e');
      return false;
    }
  }

  // Apple Music izni var mı kontrol et
  Future<bool> isConnected() async {
    try {
      final bool granted =
          await platform.invokeMethod('requestAppleMusicPermission');
      return granted;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> _searchFallback(
      String song, String artist, bool isPlaying) async {
    try {
      final q = Uri.encodeComponent("$song $artist");
      final res = await http.get(
        Uri.parse(
            'https://itunes.apple.com/search?term=$q&media=music&entity=song&limit=1'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['resultCount'] > 0) {
          final track = data['results'][0];
          return {
            'provider': 'apple',
            'is_playing': isPlaying,
            'song_name': track['trackName'],
            'artist_name': track['artistName'],
            'image_url':
            track['artworkUrl100']?.replaceAll('100x100', '600x600'),
            'preview_url': track['previewUrl'],
            'external_url': track['trackViewUrl'],
            'timestamp': DateTime.now().toIso8601String(),
          };
        }
      }
    } catch (_) {}
    return null;
  }
}