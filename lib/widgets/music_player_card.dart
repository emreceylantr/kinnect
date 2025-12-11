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

  const MusicPlayerCard({super.key, required this.userId, required this.isMe});

  @override
  State<MusicPlayerCard> createState() => _MusicPlayerCardState();
}

class _MusicPlayerCardState extends State<MusicPlayerCard> with SingleTickerProviderStateMixin {
  final SpotifyService _spotifyService = SpotifyService();
  final AppleMusicService _appleMusicService = AppleMusicService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Map<String, dynamic>? _trackData;
  String _lastActiveProvider = 'none';
  Timer? _timer;
  late AnimationController _animController;
  bool _isPlayingPreview = false;

  // Yükleme durumu
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Animasyon (Hem ekolayzer hem de logo efekti için)
    _animController = AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this
    )..repeat(reverse: true);

    _initDataFlow();

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

  // --- BAŞLATMA MANTIĞI ---
  Future<void> _initDataFlow() async {
    // 1. Önce Veritabanına Bak (Cache)
    await _fetchFromDB();

    // 2. Eğer veri yoksa ve benim profilimse CANLI KONTROLÜ BEKLE
    // (Burası "Bağla" butonunun hemen çıkmasını engeller, logo animasyonu gösterir)
    if (_trackData == null && widget.isMe) {
      await _syncMusicData();
    }

    // 3. Yüklemeyi bitir (Ne varsa onu göster)
    if (mounted && _isLoading) {
      setState(() => _isLoading = false);
    }

    // 4. Periyodik kontrolü başlat
    if (widget.isMe) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) => _syncMusicData());
    }
  }

  Future<void> _fetchFromDB() async {
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('current_song_metadata, music_provider')
          .eq('id', widget.userId)
          .single();

      if (mounted && profile['current_song_metadata'] != null) {
        setState(() {
          _trackData = profile['current_song_metadata'];
          _lastActiveProvider = profile['music_provider'] ?? 'none';
          _isLoading = false; // Veri varsa hemen göster
        });
      }
    } catch (_) {}
  }

  Future<void> _syncMusicData() async {
    if (!mounted) return;

    if (widget.isMe) {
      final appleTrack = await _appleMusicService.getCurrentTrack();
      final spotifyTrack = await _spotifyService.getCurrentTrack(widget.userId);

      bool isApplePlaying = appleTrack?['is_playing'] ?? false;
      bool isSpotifyPlaying = spotifyTrack?['is_playing'] ?? false;

      Map<String, dynamic>? winningTrack;
      String newProvider = _lastActiveProvider;

      if (isApplePlaying && appleTrack != null) {
        winningTrack = appleTrack;
        newProvider = 'apple';
      } else if (isSpotifyPlaying && spotifyTrack != null) {
        winningTrack = spotifyTrack;
        newProvider = 'spotify';
      } else {
        if (_lastActiveProvider == 'apple' && appleTrack != null) {
          winningTrack = appleTrack;
        } else if (_lastActiveProvider == 'spotify' && spotifyTrack != null) {
          winningTrack = spotifyTrack;
        } else {
          winningTrack = appleTrack ?? spotifyTrack;
          if (winningTrack != null) newProvider = winningTrack['provider'];
        }
      }

      if (winningTrack != null) {
        if (mounted) {
          if (_trackData == null || _trackData!['song_name'] != winningTrack['song_name'] || _trackData!['is_playing'] != winningTrack['is_playing']) {
            setState(() {
              _trackData = winningTrack;
              _lastActiveProvider = newProvider;
              _isLoading = false;
            });

            await Supabase.instance.client.from('profiles').update({
              'current_song_metadata': winningTrack,
              'music_provider': newProvider
            }).eq('id', widget.userId);
          }
        }
      }
    }
  }

  void _showConnectionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Hesaplarını Bağla", style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(FontAwesomeIcons.spotify, color: Color(0xFF1DB954)),
              title: const Text("Spotify'ı Bağla", style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                await _spotifyService.authenticate();
                setState(() => _isLoading = true);
                _syncMusicData();
              },
            ),
            const Divider(color: Colors.white10),
            ListTile(
              leading: const Icon(FontAwesomeIcons.apple, color: Colors.white),
              title: const Text("Apple Music'i Bağla", style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                final allowed = await _appleMusicService.requestPermission();
                if (allowed) {
                  setState(() => _isLoading = true);
                  _syncMusicData();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("İzin alındı.")));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("İzin verilmedi.")));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleTap() async {
    if (_trackData == null) return;
    final provider = _trackData!['provider'];

    if (provider == 'spotify') {
      final uri = Uri.parse(_trackData!['external_url']);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (_isPlayingPreview) {
        await _audioPlayer.pause();
      } else {
        final previewUrl = _trackData!['preview_url'];
        if (previewUrl != null) {
          await _audioPlayer.play(UrlSource(previewUrl));
        } else {
          final uri = Uri.parse(_trackData!['external_url']);
          await launchUrl(uri, mode: LaunchMode.externalApplication);
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
        final color = _trackData?['provider'] == 'spotify' ? const Color(0xFF1DB954) : const Color(0xFFFA243C);
        return Container(
          width: 3, height: dynamicHeight.clamp(3.0, 10.0),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 DURUM 0: ÖZEL LOGOLU YÜKLEME EKRANI 🔥
    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFF101010),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              // Nefes alan opaklık efekti (0.3 ile 1.0 arası)
              return Opacity(
                opacity: 0.3 + (_animController.value * 0.7),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(FontAwesomeIcons.spotify, color: Color(0xFF1DB954), size: 24),
                    const SizedBox(width: 16),
                    Container(width: 1, height: 16, color: Colors.white24), // Ayırıcı çizgi
                    const SizedBox(width: 16),
                    const Icon(FontAwesomeIcons.apple, color: Colors.white, size: 24),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }

    // 🔥 DURUM 1: Veri Yok -> Bağla Butonu
    if (_trackData == null) {
      if (widget.isMe) {
        return GestureDetector(
          onTap: _showConnectionSheet,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: 50,
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white24)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.link, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text("Müzik Hesaplarını Bağla", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
            ]),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    // 🔥 DURUM 2: Kart (Veri Var)
    final isSpotify = _trackData!['provider'] == 'spotify';
    final themeColor = isSpotify ? const Color(0xFF1DB954) : const Color(0xFFFA243C);
    final icon = isSpotify ? FontAwesomeIcons.spotify : FontAwesomeIcons.apple;
    final isAnimPlaying = isSpotify ? (_trackData!['is_playing'] == true) : _isPlayingPreview;
    final statusText = isSpotify ? (isAnimPlaying ? "Şu an Dinleniyor" : "Son Dinlenen") : (_isPlayingPreview ? "Önizleme Çalıyor" : "Apple Music");

    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF101010),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned.fill(child: Opacity(opacity: 0.35, child: Image.network(_trackData!['image_url'] ?? '', fit: BoxFit.cover))),
              Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), child: Container(color: Colors.black.withOpacity(0.5)))),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))], border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5)),
                      child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(_trackData!['image_url'] ?? '', fit: BoxFit.cover)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                        Row(children: [
                          Icon(icon, color: themeColor, size: 12),
                          const SizedBox(width: 5),
                          Text(statusText, style: GoogleFonts.poppins(color: themeColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
                          if (isAnimPlaying) ...[const SizedBox(width: 6), Row(crossAxisAlignment: CrossAxisAlignment.end, children: [_buildEqualizerBar(5, 1), const SizedBox(width: 2), _buildEqualizerBar(8, 2), const SizedBox(width: 2), _buildEqualizerBar(4, 3)])]
                        ]),
                        const SizedBox(height: 3),
                        Text(_trackData!['song_name'] ?? '', style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, height: 1.1), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(_trackData!['artist_name'] ?? '', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w400), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                    Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1), border: Border.all(color: Colors.white.withOpacity(0.15))),
                      child: Center(child: Icon((!isSpotify && _isPlayingPreview) ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 20)),
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