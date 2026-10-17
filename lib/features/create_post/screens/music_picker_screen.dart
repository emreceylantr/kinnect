// Kinnect - Apple Music Seçici (iTunes Search API)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/language/app_l10n.dart';

class MusicPickerScreen extends StatefulWidget {
  const MusicPickerScreen({super.key});

  @override
  State<MusicPickerScreen> createState() => _MusicPickerScreenState();
}

class _MusicPickerScreenState extends State<MusicPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<Map<String, dynamic>> tracks = [];
  bool isLoading = false;
  String? playingTrackId;
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _audioPlayer.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // Şarkı ara (debounced)
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.trim().isNotEmpty) {
        _searchTracks(query);
      } else {
        setState(() => tracks = []);
      }
    });
  }

  // iTunes API ile şarkı ara
  Future<void> _searchTracks(String query) async {
    setState(() => isLoading = true);

    try {
      final url = Uri.parse(
          'https://itunes.apple.com/search?term=$query&media=music&entity=song&limit=25&country=TR');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;

        setState(() {
          tracks = results.map((track) {
            return {
              'id': track['trackId'].toString(),
              'name': track['trackName'],
              'artist': track['artistName'],
              'preview_url': track['previewUrl'],
              'album_image': track['artworkUrl100']
                  ?.replaceAll('100x100', '600x600'), // Yüksek kalite
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('iTunes search error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Arama hatası: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // Preview çal/durdur
  Future<void> _togglePlay(Map<String, dynamic> track) async {
    final previewUrl = track['preview_url'];
    final trackId = track['id'];

    if (previewUrl == null) return;

    if (playingTrackId == trackId) {
      await _audioPlayer.stop();
      setState(() => playingTrackId = null);
    } else {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(previewUrl));
      setState(() => playingTrackId = trackId);

      // 30 saniye sonra otomatik dur
      Future.delayed(const Duration(seconds: 30), () {
        if (mounted && playingTrackId == trackId) {
          _audioPlayer.stop();
          setState(() => playingTrackId = null);
        }
      });
    }
  }

  // Şarkı seç
  void _selectTrack(Map<String, dynamic> track) {
    _audioPlayer.stop();
    Navigator.pop(context, {
      'id': track['id'],
      'name': track['name'],
      'artist': track['artist'] ?? 'Bilinmeyen',
      'preview_url': track['preview_url'],
      'album_image': track['album_image'],
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050505),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            _audioPlayer.stop();
            Navigator.pop(context);
          },
        ),
        title: Text(
          AppL10n.addMusicTitle,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Arama kutusu
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.poppins(color: Colors.white),
              decoration: InputDecoration(
                hintText: '🔍 ${AppL10n.searchSongOrArtist}',
                hintStyle: GoogleFonts.poppins(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white38),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => tracks = []);
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              onChanged: _onSearchChanged,
            ),
          ),

          // Apple Music Logo / Empty State
          if (tracks.isEmpty && !isLoading)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.music_note, // Apple Music için generic ikon
                      size: 80,
                      color: const Color(0xFFFC3C44)
                          .withOpacity(0.5), // Apple Music Red
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppL10n.searchMusic,
                      style: GoogleFonts.poppins(
                        color: Colors.white54,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppL10n.appleMusicSearchSubtitle,
                      style: GoogleFonts.poppins(
                        color: Colors.white38,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Loading
          if (isLoading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFFFC3C44)),
              ),
            ),

          // Sonuçlar
          if (!isLoading && tracks.isNotEmpty)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: tracks.length,
                itemBuilder: (context, index) {
                  final track = tracks[index];
                  final albumImage = track['album_image'];
                  final artistName = track['artist'] ?? 'Bilinmeyen';

                  final isPlaying = playingTrackId == track['id'];
                  final hasPreview = track['preview_url'] != null;

                  return GestureDetector(
                    onTap: () => _selectTrack(track),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isPlaying
                            ? const Color(0xFFFC3C44).withOpacity(0.15)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: isPlaying
                            ? Border.all(
                                color: const Color(0xFFFC3C44).withOpacity(0.5),
                                width: 1.5,
                              )
                            : Border.all(
                                color: Colors.white.withOpacity(0.1),
                                width: 1,
                              ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: albumImage != null
                              ? Image.network(
                                  albumImage,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                    width: 56,
                                    height: 56,
                                    color: Colors.grey[800],
                                    child: const Icon(Icons.music_note,
                                        color: Colors.white54),
                                  ),
                                )
                              : Container(
                                  width: 56,
                                  height: 56,
                                  color: Colors.grey[800],
                                  child: const Icon(Icons.music_note,
                                      color: Colors.white54),
                                ),
                        ),
                        title: Text(
                          track['name'] ?? 'Bilinmeyen',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          artistName,
                          style: GoogleFonts.poppins(color: Colors.white54),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Oynat/Durdur
                            if (hasPreview)
                              IconButton(
                                onPressed: () => _togglePlay(track),
                                icon: Icon(
                                  isPlaying
                                      ? Icons.pause_circle_filled
                                      : Icons.play_circle_filled,
                                  color: const Color(0xFFFC3C44),
                                  size: 40,
                                ),
                              ),

                            // Seç butonu (Ok)
                            const Icon(
                              Icons.chevron_right,
                              color: Colors.white38,
                              size: 28,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
