import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

// Servislerinizi import edin
import '../services/spotify_service.dart';
import '../services/apple_music_service.dart';

class MusicPlayerCard extends StatefulWidget {
  final String userId;
  final bool isMe;

  const MusicPlayerCard({
    super.key,
    required this.userId,
    required this.isMe,
  });

  @override
  State<MusicPlayerCard> createState() => _MusicPlayerCardState();
}

class _MusicPlayerCardState extends State<MusicPlayerCard> with SingleTickerProviderStateMixin {
  final SpotifyService _spotifyService = SpotifyService();
  final AppleMusicService _appleMusicService = AppleMusicService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Map<String, dynamic>? _trackData;
  String _provider = 'none'; // 'spotify' veya 'apple'
  bool _isPlayingPreview = false;
  Timer? _timer;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _fetchData();

    _animController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_provider == 'spotify' && mounted) _fetchData();
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlayingPreview = state == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('music_provider, current_song_metadata')
          .eq('id', widget.userId)
          .single();

      final provider = profile['music_provider'] ?? 'none';
      final metadata = profile['current_song_metadata']; // JSON gelebilir

      if (mounted) setState(() => _provider = provider);

      if (provider == 'spotify') {
        final data = await _spotifyService.getCurrentTrack(widget.userId);
        if (mounted) setState(() => _trackData = data);
      } else if (provider == 'apple' && metadata != null) {
        if (mounted) setState(() => _trackData = metadata as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  Future<void> _connectSpotify() async {
    await _spotifyService.authenticate();
    // Kullanıcı tarayıcıdan dönünce veriyi kaydetmek için biraz bekle veya deep link callback kullan
    // Basitlik için burada provider'ı güncelliyoruz, token alma serviste olmalı.
    await Supabase.instance.client.from('profiles').update({'music_provider': 'spotify'}).eq('id', widget.userId);
    Future.delayed(const Duration(seconds: 5), _fetchData);
  }

  void _showProviderSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Müzik Kaynağı Seç", style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(FontAwesomeIcons.spotify, color: Color(0xFF1DB954)),
              title: const Text("Spotify", style: TextStyle(color: Colors.white)),
              subtitle: const Text("Anlık dinlediğin şarkıyı gösterir.", style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () { Navigator.pop(context); _connectSpotify(); },
            ),
            const Divider(color: Colors.white10),
            ListTile(
              leading: const Icon(FontAwesomeIcons.apple, color: Colors.white),
              title: const Text("Apple Music / iTunes", style: TextStyle(color: Colors.white)),
              subtitle: const Text("Bir profil şarkısı seç ve burada çalsın.", style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () { Navigator.pop(context); _showAppleSearch(); },
            ),
          ],
        ),
      ),
    );
  }

  void _showAppleSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121212),
      builder: (context) => _AppleMusicSearchSheet(
        onSongSelected: (song) async {
          await Supabase.instance.client.from('profiles').update({
            'music_provider': 'apple',
            'current_song_metadata': song,
          }).eq('id', widget.userId);
          Navigator.pop(context);
          _fetchData();
        },
      ),
    );
  }

  Future<void> _handleTap() async {
    if (_trackData == null) return;
    if (_provider == 'spotify') {
      final uri = Uri.parse(_trackData!['external_url']);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (_provider == 'apple') {
      if (_isPlayingPreview) {
        await _audioPlayer.pause();
      } else {
        final previewUrl = _trackData!['preview_url'];
        if (previewUrl != null) {
          await _audioPlayer.play(UrlSource(previewUrl));
        }
      }
    }
  }

  Widget _buildEqualizerBar(double height, int delay) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final sinValue = (1 + _animController.value) * 0.5;
        final dynamicHeight = 3 + (height * sinValue * ((delay % 2 == 0) ? 0.7 : 1.3));
        return Container(
          width: 3,
          height: dynamicHeight.clamp(3.0, 12.0),
          decoration: BoxDecoration(
            color: _provider == 'spotify' ? const Color(0xFF1DB954) : const Color(0xFFFA243C),
            borderRadius: BorderRadius.circular(5),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_trackData == null) {
      if (widget.isMe) {
        return GestureDetector(
          onTap: _showProviderSelector,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: 50,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.music_note, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text("Müzik Hesabı Bağla", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    final isSpotify = _provider == 'spotify';
    final themeColor = isSpotify ? const Color(0xFF1DB954) : const Color(0xFFFA243C);
    final icon = isSpotify ? FontAwesomeIcons.spotify : FontAwesomeIcons.apple;
    final statusText = isSpotify
        ? (_trackData!['is_playing'] == true ? "Şu an Çalıyor" : "Son Dinlenen")
        : (_isPlayingPreview ? "Önizleme Çalıyor" : "Profil Şarkısı");

    final isPlayingAnim = isSpotify ? (_trackData!['is_playing'] == true) : _isPlayingPreview;

    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 76,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF101010),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.35,
                  child: Image.network(_trackData!['image'] ?? _trackData!['image_url'], fit: BoxFit.cover),
                ),
              ),
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(color: Colors.black.withOpacity(0.5)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))],
                        border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(_trackData!['image'] ?? _trackData!['image_url'], fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Icon(icon, color: themeColor, size: 12),
                              const SizedBox(width: 5),
                              Text(statusText, style: GoogleFonts.poppins(color: themeColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
                              if (isPlayingAnim) ...[
                                const SizedBox(width: 6),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    _buildEqualizerBar(5, 1),
                                    const SizedBox(width: 2),
                                    _buildEqualizerBar(8, 2),
                                    const SizedBox(width: 2),
                                    _buildEqualizerBar(4, 3),
                                  ],
                                ),
                              ]
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(_trackData!['name'] ?? _trackData!['song_name'], style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, height: 1.1), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(_trackData!['artist'] ?? _trackData!['artist_name'], style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w400), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1), border: Border.all(color: Colors.white.withOpacity(0.15))),
                      child: Center(
                        child: Icon(
                          (!isSpotify && _isPlayingPreview) ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white, size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Apple Music Arama Sayfası (Widget dosyası içinde kalabilir)
class _AppleMusicSearchSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onSongSelected;
  const _AppleMusicSearchSheet({required this.onSongSelected});
  @override
  State<_AppleMusicSearchSheet> createState() => _AppleMusicSearchSheetState();
}

class _AppleMusicSearchSheetState extends State<_AppleMusicSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  final AppleMusicService _service = AppleMusicService();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;

  void _search() async {
    setState(() => _loading = true);
    final res = await _service.searchSongs(_controller.text);
    if(mounted) setState(() { _results = res; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text("Apple Music'te Ara", style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Şarkı adı...",
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true, fillColor: Colors.white10,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              suffixIcon: IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: _search),
            ),
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 10),
          _loading ? const CircularProgressIndicator() : Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final song = _results[index];
                return ListTile(
                  leading: ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(song['image'], width: 40, height: 40)),
                  title: Text(song['name'], style: const TextStyle(color: Colors.white)),
                  subtitle: Text(song['artist'], style: const TextStyle(color: Colors.grey)),
                  onTap: () => widget.onSongSelected(song),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}