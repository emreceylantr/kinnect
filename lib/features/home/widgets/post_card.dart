// Kinnect - Feed Post Kartı
// home_screen.dart'tan refactor edildi

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/language/app_l10n.dart';
import '../../../data/services/feed_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/image_carousel.dart';
import '../../../shared/widgets/location_display_sheet.dart';
import '../../../shared/widgets/double_tap_overlay.dart';
import '../../post/screens/post_detail_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../../shared/widgets/kinnect_image.dart';
import '../../chat/widgets/share_post_modal.dart';

// ==========================================
// 🎥 VIDEO PLAYER WIDGET
// ==========================================

class _PostVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;

  const _PostVideoPlayer({required this.videoUrl, this.thumbnailUrl});

  @override
  State<_PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<_PostVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitializing = false;
  bool _isPlaying = false;
  bool _hasError = false;

  Future<void> _initAndPlay() async {
    if (_hasError) {
      setState(() => _hasError = false);
    }
    if (_controller != null) {
      if (_controller!.value.isPlaying) {
        await _controller!.pause();
        setState(() => _isPlaying = false);
      } else {
        await _controller!.play();
        setState(() => _isPlaying = true);
      }
      return;
    }

    setState(() => _isInitializing = true);
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await controller.initialize();
      controller.setLooping(true);
      await controller.play();
      if (mounted) {
        setState(() {
          _controller = controller;
          _isPlaying = true;
          _isInitializing = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _isInitializing = false; _hasError = true; });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _initAndPlay,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          height: 350,
          color: Colors.black,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Video veya thumbnail
              if (_controller != null && _controller!.value.isInitialized)
                SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller!.value.size.width,
                      height: _controller!.value.size.height,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                )
              else if (widget.thumbnailUrl != null)
                KinnectImage(
                  imageUrl: widget.thumbnailUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  useShimmer: true,
                )
              else
                Container(color: Colors.grey.shade900),

              // Error overlay
              if (_hasError)
                Container(
                  color: Colors.black87,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white54, size: 32),
                      const SizedBox(height: 8),
                      Text(AppL10n.videoLoadFailed,
                          style: TextStyle(color: Colors.white54, fontSize: 13)),
                      TextButton(
                        onPressed: _initAndPlay,
                        child: const Text('Tekrar Dene',
                            style: TextStyle(color: Colors.white70)),
                      ),
                    ],
                  ),
                )
              // Play/Pause overlay
              else if (!_isPlaying)
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: _isInitializing
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow, color: Colors.white, size: 32),
                ),

              // Video badge
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text('Video', style: TextStyle(color: Colors.white, fontSize: 11)),
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

// ==========================================
// 🔥 BUZLU CAM (GLASSMORPHISM) EFEKTLİ POST KARTI
// ==========================================

class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback onRefresh;

  const PostCard({
    super.key,
    required this.post,
    required this.onRefresh,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool isLiked = false;
  final String myId = Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    final likes = widget.post['likes'] as List<dynamic>? ?? [];
    isLiked = likes.any((l) => l['user_id'] == myId);
  }

  Route _createSlideRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeOutQuart;
        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }

  void _toggleLike() async {
    setState(() => isLiked = !isLiked);
    await FeedService().toggleLike(widget.post['id']);
  }

  static String? _extractYouTubeId(String text) {
    final patterns = [
      RegExp(r'youtu\.be/([A-Za-z0-9_\-]{11})'),
      RegExp(r'youtube\.com/watch\?v=([A-Za-z0-9_\-]{11})'),
      RegExp(r'youtube\.com/shorts/([A-Za-z0-9_\-]{11})'),
    ];
    for (final re in patterns) {
      final m = re.firstMatch(text);
      if (m != null) return m.group(1);
    }
    return null;
  }

  Future<void> _openYouTube(String videoId) async {
    final uri = Uri.parse('https://www.youtube.com/watch?v=$videoId');
    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildYouTubePreview(String videoId) {
    final thumbUrl = 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
    return GestureDetector(
      onTap: () => _openYouTube(videoId),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
          color: Colors.white.withOpacity(0.05),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    thumbUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade900,
                      child: const Icon(Icons.videocam, color: Colors.white38, size: 40),
                    ),
                  ),
                ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0000),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 30),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              child: Row(
                children: [
                  const FaIcon(FontAwesomeIcons.youtube, color: Color(0xFFFF0000), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'YouTube\'da izle',
                    style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExpiredMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppL10n.postExpired,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: Colors.grey.shade800,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _goToDetail() async {
    final result = await Navigator.push(
        context, _createSlideRoute(PostDetailScreen(post: widget.post)));
    if (result == true || mounted) {
      widget.onRefresh();
    }
  }

  void _goToProfile(String userId) {
    Navigator.push(context, _createSlideRoute(ProfileScreen(userId: userId)));
  }

  void _openFullScreen(String url) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => Scaffold(
                backgroundColor: Colors.black,
                appBar: AppBar(
                    backgroundColor: Colors.transparent,
                    leading: const BackButton(color: Colors.white)),
                body: Center(
                    child: InteractiveViewer(
                  child: KinnectImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                    useShimmer: true,
                  ),
                )))));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final profile = p['profiles'] ?? {};
    final date = DateTime.tryParse(p['created_at'] ?? '');
    final dateStr = date != null
        ? DateFormat(date.year == DateTime.now().year ? 'd MMM' : 'd MMM y', 'tr').format(date.toLocal())
        : '';
    final likeCount = (p['likes'] as List?)?.length ?? 0;
    final commentCount = (p['comments'] as List?)?.length ?? 0;

    // 🔥 GÖRÜNÜRLÜK VE SÜRE KONTROLÜ
    final bool isPublicPost = (p['visibility'] == 'public');

    // Süre doldu mu kontrolü (24 saat)
    bool isExpired = false;
    if (isPublicPost && date != null) {
      final difference = DateTime.now().difference(date);
      if (difference.inHours >= 24) {
        isExpired = true;
      }
    }

    return GestureDetector(
      onTap: _goToDetail,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(24),
                border:
                    Border.all(color: Colors.white.withOpacity(0.1), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER ---
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                    child: Row(
                      children: [
                        // 📸 AVATAR
                        GestureDetector(
                          onTap: () => _goToProfile(p['user_id']),
                          child: KinnectImage(
                            imageUrl: profile['avatar_url'] ?? '',
                            width: 44,
                            height: 44,
                            isCircle: true,
                            backgroundColor: Colors.white10,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () => _goToProfile(p['user_id']),
                                child: Text(
                                  profile['full_name'] ?? 'Bilinmiyor',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15),
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    '@${profile['username']}',
                                    style: GoogleFonts.poppins(
                                        color: Colors.grey.shade400,
                                        fontSize: 13),
                                  ),
                                  if (p['location'] != null &&
                                      p['location'].toString().isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    const Icon(Icons.location_on,
                                        color: AppColors.primary, size: 12),
                                    const SizedBox(width: 2),
                                    GestureDetector(
                                      onTap: () => showLocationDisplaySheet(
                                          context, p['location']),
                                      child: Container(
                                        constraints:
                                            const BoxConstraints(maxWidth: 120),
                                        color: Colors.transparent,
                                        child: Text(
                                          p['location'],
                                          style: GoogleFonts.poppins(
                                              color: AppColors.primary,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        // SAĞ ÜSTTE GÖRÜNÜRLÜK İKONU
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Icon(
                            isPublicPost
                                ? FontAwesomeIcons.earthAmericas
                                : FontAwesomeIcons.userGroup,
                            color: Colors.white24,
                            size: 14,
                          ),
                        ),
                        Text(dateStr,
                            style: GoogleFonts.poppins(
                                color: Colors.grey.shade400, fontSize: 12)),
                      ],
                    ),
                  ),
                  // --- CONTENT ---
                  if (p['content'] != null &&
                      p['content'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: Text(
                        _extractYouTubeId(p['content'].toString()) != null
                            ? p['content'].toString()
                                .replaceAll(RegExp(r'https?://\S+'), '')
                                .trim()
                            : p['content'],
                        style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 14,
                            height: 1.5),
                      ),
                    ),
                  // 🎬 YouTube önizleme
                  if (p['content'] != null &&
                      _extractYouTubeId(p['content'].toString()) != null)
                    _buildYouTubePreview(
                        _extractYouTubeId(p['content'].toString())!),
                  // --- IMAGE CAROUSEL ---
                  if (p['image_urls'] != null &&
                      (p['image_urls'] as List).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: DoubleTapOverlay(
                        // Eğer süresi dolduysa çift tıklama çalışmaz (veya uyarı verir)
                        onDoubleTap:
                            isExpired ? _showExpiredMessage : _toggleLike,
                        icon: isPublicPost
                            ? FontAwesomeIcons.fire
                            : FontAwesomeIcons.solidHeart,
                        // Süresi dolmuşsa gri, değilse Turuncu/Mor
                        iconColor: isExpired
                            ? Colors.grey
                            : (isPublicPost
                                ? Colors.orange
                                : AppColors.primary),
                        child: ImageCarousel(
                          imageUrls: (p['image_urls'] as List).cast<String>(),
                          height: 350,
                          borderRadius: BorderRadius.circular(18),
                          onImageTap: (url) => _openFullScreen(url),
                          musicTrackName: p['spotify_track_name'],
                          musicArtistName: p['spotify_artist_name'],
                          postId: p['id'],
                        ),
                      ),
                    )
                  // --- SINGLE IMAGE ---
                  else if (p['image_url'] != null)
                    GestureDetector(
                      onTap: () => _openFullScreen(p['image_url']),
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                        width: double.infinity,
                        constraints: const BoxConstraints(maxHeight: 400),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Hero(
                          tag: p['image_url'],
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: DoubleTapOverlay(
                              // Eğer süresi dolduysa çift tıklama çalışmaz
                              onDoubleTap:
                                  isExpired ? _showExpiredMessage : _toggleLike,
                              icon: isPublicPost
                                  ? FontAwesomeIcons.fire
                                  : FontAwesomeIcons.solidHeart,
                              // Süresi dolmuşsa gri, değilse Turuncu/Mor
                              iconColor: isExpired
                                  ? Colors.grey
                                  : (isPublicPost
                                      ? Colors.orange
                                      : AppColors.primary),
                              child: KinnectImage(
                                imageUrl: p['image_url'],
                                width: double.infinity,
                                fit: BoxFit.cover,
                                useShimmer: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // --- VIDEO ---
                  if (p['video_url'] != null && p['video_url'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: _PostVideoPlayer(
                        videoUrl: p['video_url'] as String,
                        thumbnailUrl: (p['video_frame_urls'] as List?)?.isNotEmpty == true
                            ? (p['video_frame_urls'] as List).first as String
                            : null,
                      ),
                    ),
                  // --- ACTION BUTTONS ---
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // 🔥 ALEV veya 💜 KALP BUTONU
                        GestureDetector(
                          // Süresi dolduysa tıklanamaz (uyarı verir), dolmadıysa beğenilir
                          onTap: isExpired ? _showExpiredMessage : _toggleLike,
                          child: Container(
                            color: Colors.transparent,
                            child: Row(
                              children: [
                                // İKON SEÇİMİ
                                Icon(
                                  // Public ise ALEV, değilse KALP
                                  isPublicPost
                                      ? FontAwesomeIcons.fire
                                      : (isLiked
                                          ? FontAwesomeIcons.solidHeart
                                          : FontAwesomeIcons.heart),

                                  // RENK SEÇİMİ (Mantık Burada)
                                  color: isExpired
                                      ? Colors.grey // Süre bittiyse GRİ
                                      : (isLiked
                                          ? (isPublicPost
                                              ? Colors.orange // Aktif Alev
                                              : AppColors.primary) // Aktif Kalp
                                          : Colors.grey
                                              .shade400), // Henüz beğenilmemiş
                                  size: 22,
                                ),
                                if (likeCount > 0) ...[
                                  const SizedBox(width: 6),
                                  Text("$likeCount",
                                      style: GoogleFonts.poppins(
                                          // Sayı rengi de ikona uysun
                                          color: isExpired
                                              ? Colors
                                                  .grey // Süre bittiyse sayı da gri
                                              : (isLiked
                                                  ? (isPublicPost
                                                      ? Colors.orange
                                                      : AppColors.primary)
                                                  : Colors.grey.shade400),
                                          fontWeight: FontWeight.w600)),
                                ]
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Comment Button
                        GestureDetector(
                          onTap: _goToDetail,
                          child: Container(
                            color: Colors.transparent,
                            child: Row(
                              children: [
                                Icon(FontAwesomeIcons.comment,
                                    color: Colors.grey.shade400, size: 22),
                                if (commentCount > 0) ...[
                                  const SizedBox(width: 6),
                                  Text("$commentCount",
                                      style: GoogleFonts.poppins(
                                          color: Colors.grey.shade400,
                                          fontWeight: FontWeight.w600)),
                                ]
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Share Button
                        GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              builder: (_) => SharePostModal(post: widget.post),
                            );
                          },
                          child: Container(
                            color: Colors.transparent,
                            child: Icon(
                              FontAwesomeIcons.paperPlane,
                              color: Colors.grey.shade400,
                              size: 20,
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
        ),
      ),
    );
  }
}
