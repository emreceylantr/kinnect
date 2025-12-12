import 'dart:async';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

class _MusicPlayerCardState extends State<MusicPlayerCard>
    with SingleTickerProviderStateMixin {
  final SpotifyService _spotifyService = SpotifyService();
  final AppleMusicService _appleMusicService = AppleMusicService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Map<String, dynamic>? _trackData;

  Timer? _timer;
  late AnimationController _animController;

  bool _isPlayingPreview = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlayingPreview = state == PlayerState.playing;
        });
      }
    });

    _initDataFlow();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  /* -------------------------------------------------------------------------- */
  /*                                DATA FLOW                                   */
  /* -------------------------------------------------------------------------- */

  Future<void> _initDataFlow() async {
    await _fetchFromDB();

    if (widget.isMe) {
      await _syncMusicData();
      _timer =
          Timer.periodic(const Duration(seconds: 5), (_) => _syncMusicData());
    } else {
      _timer =
          Timer.periodic(const Duration(seconds: 5), (_) => _fetchFromDB());
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchFromDB() async {
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('current_song_metadata')
          .eq('id', widget.userId)
          .single();

      if (mounted) {
        setState(() {
          _trackData = profile['current_song_metadata'];
        });
      }
    } catch (_) {}
  }

  /* -------------------------------------------------------------------------- */
  /*                          SYNC – TEK OTORİTE                                 */
  /* -------------------------------------------------------------------------- */

  Future<void> _syncMusicData() async {
    if (!mounted || !widget.isMe) return;

    final appleTrack = await _appleMusicService.getCurrentTrack();
    final spotifyTrack =
    await _spotifyService.getCurrentTrack(widget.userId);

    Map<String, dynamic>? winner;

    if (appleTrack != null && spotifyTrack != null) {
      final appleTime = DateTime.parse(appleTrack['timestamp']);
      final spotifyTime = DateTime.parse(spotifyTrack['timestamp']);
      winner = appleTime.isAfter(spotifyTime) ? appleTrack : spotifyTrack;
    } else {
      winner = appleTrack ?? spotifyTrack;
    }

    if (winner == null) return;

    if (_trackData != null &&
        _trackData!['timestamp'] == winner['timestamp']) {
      return;
    }

    setState(() {
      _trackData = winner;
    });

    try {
      await Supabase.instance.client.from('profiles').update({
        'current_song_metadata': winner,
        'music_provider': winner['provider'],
        'last_music_update_at': winner['timestamp'],
      }).eq('id', widget.userId);
    } catch (_) {}
  }

  /* -------------------------------------------------------------------------- */
  /*                                   UI                                       */
  /* -------------------------------------------------------------------------- */

  void _showConnectionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            "Hesaplarını Bağla",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(FontAwesomeIcons.spotify,
                color: Color(0xFF1DB954)),
            title: const Text("Spotify'ı Bağla",
                style: TextStyle(color: Colors.white)),
            onTap: () async {
              Navigator.pop(context);
              await _spotifyService.authenticate();
              setState(() => _isLoading = true);
              _syncMusicData();
            },
          ),
          const Divider(color: Colors.white10),
          ListTile(
            leading:
            const Icon(FontAwesomeIcons.apple, color: Colors.white),
            title: const Text("Apple Music'i Bağla",
                style: TextStyle(color: Colors.white)),
            onTap: () async {
              Navigator.pop(context);
              final allowed =
              await _appleMusicService.requestPermission();
              if (allowed) {
                setState(() => _isLoading = true);
                _syncMusicData();
              }
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _handleTap() async {
    if (_trackData == null) return;

    if (_trackData!['provider'] == 'spotify') {
      await launchUrl(Uri.parse(_trackData!['external_url']),
          mode: LaunchMode.externalApplication);
    } else {
      if (_isPlayingPreview) {
        await _audioPlayer.pause();
      } else if (_trackData!['preview_url'] != null) {
        await _audioPlayer
            .play(UrlSource(_trackData!['preview_url']));
      } else {
        await launchUrl(Uri.parse(_trackData!['external_url']),
            mode: LaunchMode.externalApplication);
      }
    }
  }

  Widget _buildEqualizerBar(double height, int delay) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final sinValue = (1 + _animController.value) * 0.5;
        final dynamicHeight =
            3 + (height * sinValue * ((delay % 2 == 0) ? 0.7 : 1.3));
        final color = _trackData?['provider'] == 'spotify'
            ? const Color(0xFF1DB954)
            : const Color(0xFFFA243C);
        return Container(
          width: 3,
          height: dynamicHeight.clamp(3.0, 10.0),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(5),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(height: 84);
    }

    if (_trackData == null) {
      if (widget.isMe) {
        return GestureDetector(
          onTap: _showConnectionSheet,
          child: Container(
            margin:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: 50,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.link, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text("Müzik Hesaplarını Bağla",
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    final isSpotify = _trackData!['provider'] == 'spotify';
    final themeColor =
    isSpotify ? const Color(0xFF1DB954) : const Color(0xFFFA243C);
    final icon =
    isSpotify ? FontAwesomeIcons.spotify : FontAwesomeIcons.apple;
    final isAnimPlaying =
    isSpotify ? _trackData!['is_playing'] == true : _isPlayingPreview;
    final statusText = isSpotify
        ? (isAnimPlaying ? "Şu an Dinleniyor" : "Son Dinlenen")
        : (_isPlayingPreview ? "Önizleme Çalıyor" : "Apple Music");

    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        margin:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 84,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF101010),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.35,
                  child: Image.network(
                    _trackData!['image_url'] ?? '',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned.fill(
                child: BackdropFilter(
                  filter:
                  ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child:
                  Container(color: Colors.black.withOpacity(0.5)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 0.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _trackData!['image_url'] ?? '',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment:
                        MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Icon(icon,
                                  color: themeColor, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                statusText,
                                style: GoogleFonts.poppins(
                                  color: themeColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isAnimPlaying) ...[
                                const SizedBox(width: 6),
                                Row(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.end,
                                  children: [
                                    _buildEqualizerBar(5, 1),
                                    const SizedBox(width: 2),
                                    _buildEqualizerBar(8, 2),
                                    const SizedBox(width: 2),
                                    _buildEqualizerBar(4, 3),
                                  ],
                                )
                              ]
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _trackData!['song_name'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _trackData!['artist_name'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.15)),
                      ),
                      child: Center(
                        child: Icon(
                          (!isSpotify && _isPlayingPreview)
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 24,
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
