import 'dart:async';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Servis importlarını kendi proje yoluna göre ayarla
import '../../data/services/spotify_service.dart';
import '../../data/services/apple_music_service.dart';

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
    with TickerProviderStateMixin {
  final SpotifyService _spotifyService = SpotifyService();
  final AppleMusicService _appleMusicService = AppleMusicService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Map<String, dynamic>? _trackData;
  Timer? _timer;

  late AnimationController _animController;
  late AnimationController _loadingAnimController;

  bool _isPlayingPreview = false;
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();

    // Equalizer animasyonu
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    // Yükleme animasyonu
    _loadingAnimController = AnimationController(
      duration: const Duration(seconds: 1),
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
    _loadingAnimController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // --- DATA FLOW ---

  Future<void> _initDataFlow() async {
    await _fetchFromDB();

    if (widget.isMe) {
      // İlk açılışta bir sync denemesi yap
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

  Future<void> _syncMusicData() async {
    if (!mounted || !widget.isMe) return;

    // Önce veritabanından bağlantı durumunu kontrol et
    bool hasSpotifyToken = false;
    bool hasAppleMusic = false;
    String? currentProvider;

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('spotify_refresh_token, music_provider')
          .eq('id', widget.userId)
          .maybeSingle();

      if (profile != null) {
        hasSpotifyToken = profile['spotify_refresh_token'] != null;
        hasAppleMusic = profile['music_provider'] == 'apple';
        currentProvider = profile['music_provider'];
      }
    } catch (_) {}

    debugPrint(
        '🎵 Music Sync - hasSpotify: $hasSpotifyToken, hasApple: $hasAppleMusic, provider: $currentProvider');

    // Bağlı olan servislerden veri çek
    Map<String, dynamic>? appleTrack;
    Map<String, dynamic>? spotifyTrack;

    // Apple Music bağlıysa veri çek
    if (hasAppleMusic) {
      appleTrack = await _appleMusicService.getCurrentTrack();
      debugPrint(
          '🍎 Apple Track: ${appleTrack != null ? appleTrack['song_name'] : 'NULL'}');
    }

    // Spotify bağlıysa veri çek
    if (hasSpotifyToken) {
      spotifyTrack = await _spotifyService.getCurrentTrack(widget.userId);
      debugPrint(
          '🟢 Spotify Track: ${spotifyTrack != null ? spotifyTrack['song_name'] : 'NULL'}');
    }

    Map<String, dynamic>? winner;

    // Hangisi şu an çalıyorsa ona öncelik ver (is_playing kontrolü)
    final appleIsPlaying = appleTrack?['is_playing'] == true;
    final spotifyIsPlaying = spotifyTrack?['is_playing'] == true;

    debugPrint(
        '🎶 Apple isPlaying: $appleIsPlaying, Spotify isPlaying: $spotifyIsPlaying');

    if (appleIsPlaying && !spotifyIsPlaying) {
      // Sadece Apple çalıyorsa Apple'ı seç
      winner = appleTrack;
    } else if (spotifyIsPlaying && !appleIsPlaying) {
      // Sadece Spotify çalıyorsa Spotify'ı seç
      winner = spotifyTrack;
    } else if (appleIsPlaying && spotifyIsPlaying) {
      // İkisi de çalıyorsa, timestamp'e göre seç (daha güncel olan)
      final appleTime = DateTime.parse(appleTrack!['timestamp']);
      final spotifyTime = DateTime.parse(spotifyTrack!['timestamp']);
      winner = appleTime.isAfter(spotifyTime) ? appleTrack : spotifyTrack;
    } else {
      // Hiçbiri çalmıyorsa, en son çalanı göster (timestamp'e göre)
      if (appleTrack != null && spotifyTrack != null) {
        final appleTime = DateTime.parse(appleTrack['timestamp']);
        final spotifyTime = DateTime.parse(spotifyTrack['timestamp']);
        winner = appleTime.isAfter(spotifyTime) ? appleTrack : spotifyTrack;
      } else {
        winner = appleTrack ?? spotifyTrack;
      }
    }

    debugPrint(
        '🏆 Winner: ${winner != null ? "${winner['provider']} - ${winner['song_name']}" : 'NULL'}');

    if (winner == null) return;

    // Eğer veri aynıysa güncelleme yapma (gereksiz render önle)
    if (_trackData != null && _trackData!['timestamp'] == winner['timestamp']) {
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

  // --- UI ACTIONS ---

  Future<void> _syncTopMusic() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('spotify_refresh_token, music_provider')
          .eq('id', widget.userId)
          .maybeSingle();

      final hasSpotify = profile?['spotify_refresh_token'] != null;
      final hasApple = profile?['music_provider'] == 'apple';

      if (hasSpotify) await _spotifyService.syncTopMusic(widget.userId);
      if (hasApple) await _appleMusicService.syncTopMusic(widget.userId);
    } catch (_) {}
    if (mounted) setState(() => _isSyncing = false);
  }

  void _showConnectionSheet() async {
    bool isSpotifyConnected = false;
    bool isAppleMusicConnected = false;

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('spotify_refresh_token, music_provider')
          .eq('id', widget.userId)
          .maybeSingle();

      if (profile != null) {
        isSpotifyConnected = profile['spotify_refresh_token'] != null;
        isAppleMusicConnected = profile['music_provider'] == 'apple';
      }
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24, borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Müzik Hesaplarını Yönet",
                style: GoogleFonts.poppins(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // ── SPOTIFY ──────────────────────────────────────────────
              if (!isSpotifyConnected)
                _sheetTile(
                  icon: const FaIcon(FontAwesomeIcons.spotify, color: Color(0xFF1DB954)),
                  title: "Spotify ile Bağlan",
                  onTap: () async {
                    Navigator.pop(context);
                    await _spotifyService.authenticate();
                  },
                )
              else
                _sheetTile(
                  icon: const FaIcon(FontAwesomeIcons.spotify, color: Color(0xFF1DB954)),
                  title: "Spotify Bağlantısını Kes",
                  titleColor: Colors.redAccent,
                  tileColor: Colors.red.withOpacity(0.08),
                  trailing: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
                  onTap: () async {
                    Navigator.pop(context);
                    await _disconnectSpotify();
                  },
                ),
              const SizedBox(height: 10),

              // ── APPLE MUSIC ───────────────────────────────────────────
              if (!isAppleMusicConnected)
                _sheetTile(
                  icon: const FaIcon(FontAwesomeIcons.apple, color: Colors.white),
                  title: "Apple Music ile Bağlan",
                  onTap: () async {
                    Navigator.pop(context);
                    final allowed = await _appleMusicService.requestPermission();
                    if (allowed) {
                      setState(() => _isLoading = true);
                      await Supabase.instance.client.from('profiles').update({
                        'music_provider': 'apple',
                      }).eq('id', widget.userId);
                      await _syncMusicData();
                      setState(() => _isLoading = false);
                    }
                  },
                )
              else
                _sheetTile(
                  icon: const FaIcon(FontAwesomeIcons.apple, color: Colors.white),
                  title: "Apple Music Bağlantısını Kes",
                  titleColor: Colors.redAccent,
                  tileColor: Colors.red.withOpacity(0.08),
                  trailing: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
                  onTap: () async {
                    Navigator.pop(context);
                    await _disconnectAppleMusic();
                  },
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetTile({
    required Widget icon,
    required String title,
    String? subtitle,
    Color? titleColor,
    Color? tileColor,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      tileColor: tileColor ?? Colors.white.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: icon,
      title: Text(title,
          style: TextStyle(color: titleColor ?? Colors.white, fontSize: 14)),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: const TextStyle(color: Colors.white38, fontSize: 11))
          : null,
      trailing: trailing,
      onTap: onTap,
    );
  }

  // Spotify bağlantısını kes
  Future<void> _disconnectSpotify() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.from('profiles').update({
        'spotify_refresh_token': null,
        'current_song_metadata': null,
        'music_provider': null,
      }).eq('id', widget.userId);

      setState(() {
        _trackData = null;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Spotify disconnect hatası: $e');
      setState(() => _isLoading = false);
    }
  }

  // Apple Music bağlantısını kes
  Future<void> _disconnectAppleMusic() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.from('profiles').update({
        'current_song_metadata': null,
        'music_provider': null,
        'last_music_update_at': null,
      }).eq('id', widget.userId);

      setState(() {
        _trackData = null;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Apple Music disconnect hatası: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleTap() async {
    if (_trackData == null) return;

    // Spotify ise direkt linke git
    if (_trackData!['provider'] == 'spotify') {
      await launchUrl(Uri.parse(_trackData!['external_url']),
          mode: LaunchMode.externalApplication);
    } else {
      // Apple Music ise ve preview varsa çal, yoksa linke git
      if (_isPlayingPreview) {
        await _audioPlayer.pause();
      } else if (_trackData!['preview_url'] != null) {
        await _audioPlayer.play(UrlSource(_trackData!['preview_url']));
      } else {
        await launchUrl(Uri.parse(_trackData!['external_url']),
            mode: LaunchMode.externalApplication);
      }
    }
  }

  // --- WIDGET BUILDERS ---

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

  Widget _buildLoadingView() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 84,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF101010),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Center(
        child: AnimatedBuilder(
          animation: _loadingAnimController,
          builder: (context, child) {
            final opacity = 0.3 + (_loadingAnimController.value * 0.7);
            return Opacity(
              opacity: opacity,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FaIcon(FontAwesomeIcons.spotify,
                      color: Color(0xFF1DB954), size: 20),
                  const SizedBox(width: 16),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                        color: Colors.white24, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 16),
                  const FaIcon(FontAwesomeIcons.apple,
                      color: Colors.white, size: 20),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Durum: Yükleniyor
    if (_isLoading) {
      return _buildLoadingView();
    }

    // 2. Durum: Hiç veri yok (Hiçbir hesap bağlı değil veya şarkı yok)
    if (_trackData == null) {
      if (widget.isMe) {
        return GestureDetector(
          onTap: _showConnectionSheet,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: 60, // Biraz daha belirgin
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: Colors.white24, style: BorderStyle.solid),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const FaIcon(FontAwesomeIcons.link,
                    color: Colors.white, size: 16),
                const SizedBox(width: 12),
                Text(
                  "Spotify veya Apple Music Bağla",
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        );
      }
      // Başkasının profili ve şarkı yoksa hiçbir şey gösterme
      return const SizedBox.shrink();
    }

    // 3. Durum: Müzik Verisi Var
    final isSpotify = _trackData!['provider'] == 'spotify';
    final themeColor =
        isSpotify ? const Color(0xFF1DB954) : const Color(0xFFFA243C);
    final icon = isSpotify ? FontAwesomeIcons.spotify : FontAwesomeIcons.apple;
    final isAnimPlaying =
        isSpotify ? _trackData!['is_playing'] == true : _isPlayingPreview;
    final statusText = isSpotify
        ? (isAnimPlaying ? "Şu an Dinleniyor" : "Son Dinlenen")
        : (_isPlayingPreview ? "Önizleme Çalıyor" : "Apple Music");

    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              // Arkaplan Blur Resim
              Positioned.fill(
                child: Opacity(
                  opacity: 0.35,
                  child: Image.network(
                    _trackData!['image_url'] ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Container(color: Colors.grey[900]),
                  ),
                ),
              ),
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(color: Colors.black.withOpacity(0.5)),
                ),
              ),

              // İçerik
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Albüm Kapağı
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.1), width: 0.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _trackData!['image_url'] ?? '',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.music_note,
                                  color: Colors.white54),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Şarkı Bilgileri
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Icon(icon, color: themeColor, size: 14),
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
                                  crossAxisAlignment: CrossAxisAlignment.end,
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
                            _trackData!['song_name'] ?? 'Bilinmeyen Şarkı',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _trackData!['artist_name'] ?? 'Bilinmeyen Sanatçı',
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

                    // Play/Pause Butonu (Apple Music için)
                    if (!isSpotify)
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.15)),
                        ),
                        child: Center(
                          child: Icon(
                            _isPlayingPreview
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

              // Sağ üst: refresh + ayar ikonları
              if (widget.isMe)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Refresh ikonu
                        InkWell(
                          borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(12)),
                          onTap: _syncTopMusic,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
                            child: _isSyncing
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        color: Colors.white54, strokeWidth: 1.5),
                                  )
                                : const Icon(Icons.sync,
                                    color: Colors.white54, size: 14),
                          ),
                        ),
                        // Ayar ikonu
                        InkWell(
                          borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(16)),
                          onTap: _showConnectionSheet,
                          child: const Padding(
                            padding: EdgeInsets.fromLTRB(4, 8, 8, 8),
                            child: Icon(Icons.link,
                                color: Colors.white54, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
