import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

class AppleMusicService {
  static const platform = MethodChannel('com.kinnect.app/music');

  Future<bool> requestPermission() async {
    var status = await Permission.mediaLibrary.status;
    if (status.isDenied) status = await Permission.mediaLibrary.request();
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    return status.isGranted;
  }

  Future<Map<String, dynamic>?> getCurrentTrack() async {
    try {
      if (!await Permission.mediaLibrary.isGranted) return null;

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
    ///emree
  }
}
