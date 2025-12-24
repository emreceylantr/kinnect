// Kinnect - Spotify Müzik Seçici

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';

class MusicPickerScreen extends StatefulWidget {
  const MusicPickerScreen({super.key});

  @override
  State<MusicPickerScreen> createState() => _MusicPickerScreenState();
}

class _MusicPickerScreenState extends State<MusicPickerScreen> {
  final SupabaseClient client = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<Map<String, dynamic>> tracks = [];
  bool isLoading = false;
  String? playingTrackId;
  Timer? _debounce;

  Map<String, dynamic>? selectedTrack;

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

  // Spotify API ile şarkı ara
  Future<void> _searchTracks(String query) async {
    setState(() => isLoading = true);

    try {
      final response = await client.functions.invoke(
        'spotify-search',
        body: {'query': query},
      );

      if (response.data != null && response.data['tracks'] != null) {
        setState(() {
          tracks = List<Map<String, dynamic>>.from(response.data['tracks']);
        });
      }
    } catch (e) {
      debugPrint('Spotify search error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Arama hatası: $e'),
            backgroundColor: Colors.redAccent,
          ),
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

    if (previewUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu şarkının önizlemesi yok'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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
      'artist': track['artists']?.first?['name'] ?? 'Bilinmeyen',
      'preview_url': track['preview_url'],
      'album_image': track['album']?['images']?.first?['url'],
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
          'Müzik Ekle',
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
                hintText: '🔍 Şarkı veya sanatçı ara...',
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

          // Spotify logo
          if (tracks.isEmpty && !isLoading)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.music_note,
                      size: 80,
                      color: const Color(0xFF1DB954).withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Spotify ile şarkı ara',
                      style: GoogleFonts.poppins(
                        color: Colors.white54,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '30 saniyelik önizleme dinleyebilirsin',
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
                child: CircularProgressIndicator(color: Color(0xFF1DB954)),
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
                  final albumImage =
                      track['album']?['images']?.isNotEmpty == true
                          ? track['album']['images'].last['url']
                          : null;
                  final artistName =
                      (track['artists'] as List?)?.isNotEmpty == true
                          ? track['artists'][0]['name']
                          : 'Bilinmeyen';
                  final isPlaying = playingTrackId == track['id'];
                  final hasPreview = track['preview_url'] != null;

                  return GestureDetector(
                    onTap: () => _selectTrack(
                        track), // 🆕 Herhangi bir yere tıklayınca seç
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isPlaying
                            ? const Color(0xFF1DB954).withOpacity(0.15)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: isPlaying
                            ? Border.all(
                                color: const Color(0xFF1DB954), width: 1.5)
                            : null,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
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
                        subtitle: Row(
                          children: [
                            Expanded(
                              child: Text(
                                artistName,
                                style:
                                    GoogleFonts.poppins(color: Colors.white54),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!hasPreview)
                              Text(
                                ' • önizleme yok',
                                style: GoogleFonts.poppins(
                                  color: Colors.orange.withOpacity(0.7),
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Oynat/Durdur (sadece preview varsa)
                            if (hasPreview)
                              IconButton(
                                onPressed: () => _togglePlay(track),
                                icon: Icon(
                                  isPlaying
                                      ? Icons.pause_circle_filled
                                      : Icons.play_circle_filled,
                                  color: const Color(0xFF1DB954),
                                  size: 36,
                                ),
                              ),
                            // Seç butonu (herkese göster)
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
