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
      if (await Permission.mediaLibrary.isGranted) {
        final Map<dynamic, dynamic>? nativeData = await platform.invokeMethod('getAppleMusicTrack');
        if (nativeData == null) return null;

        final bool isPlaying = nativeData['is_playing'] ?? false; // Swift'ten gelen veri
        final String songName = nativeData['name'] ?? '';
        final String artistName = nativeData['artist'] ?? '';
        final String storeId = nativeData['storeId'] ?? '0';

        if (storeId != '0') {
          final url = Uri.parse('https://itunes.apple.com/lookup?id=$storeId&country=TR');
          final response = await http.get(url);
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['resultCount'] > 0) {
              final track = data['results'][0];
              return {
                'provider': 'apple',
                'is_playing': isPlaying,
                'song_name': track['trackName'],
                'artist_name': track['artistName'],
                'image_url': track['artworkUrl100']?.replaceAll('100x100', '600x600'),
                'preview_url': track['previewUrl'],
                'external_url': track['trackViewUrl'],
              };
            }
          }
        }
        return await _searchFallback(songName, artistName, isPlaying);
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> _searchFallback(String song, String artist, bool isPlaying) async {
    try {
      final query = Uri.encodeComponent("$song $artist");
      final url = Uri.parse('https://itunes.apple.com/search?term=$query&media=music&entity=song&limit=1');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['resultCount'] > 0) {
          final track = data['results'][0];
          return {
            'provider': 'apple',
            'is_playing': isPlaying,
            'song_name': track['trackName'],
            'artist_name': track['artistName'],
            'image_url': track['artworkUrl100']?.replaceAll('100x100', '600x600'),
            'preview_url': track['previewUrl'],
            'external_url': track['trackViewUrl'],
          };
        }
      }
    } catch (_) {}
    return null;
  }
}