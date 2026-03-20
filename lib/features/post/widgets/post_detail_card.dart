import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';

import 'package:kinnect/core/theme/app_colors.dart';
import 'package:kinnect/shared/widgets/fuel_button.dart';
import 'package:kinnect/shared/widgets/location_display_sheet.dart';
import 'package:kinnect/features/post/widgets/taggable_post_image.dart';
import 'package:kinnect/shared/widgets/image_carousel.dart';
import 'package:kinnect/shared/widgets/double_tap_overlay.dart';
import 'package:kinnect/features/profile/screens/profile_screen.dart';
import 'package:kinnect/shared/widgets/kinnect_image.dart';

// 🎥 Post detail video player
class _PostVideoPlayerDetail extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;

  const _PostVideoPlayerDetail({required this.videoUrl, this.thumbnailUrl});

  @override
  State<_PostVideoPlayerDetail> createState() => _PostVideoPlayerDetailState();
}

class _PostVideoPlayerDetailState extends State<_PostVideoPlayerDetail> {
  VideoPlayerController? _controller;
  bool _isInitializing = false;
  bool _isPlaying = false;

  Future<void> _initAndPlay() async {
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
      final controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
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
      if (mounted) setState(() => _isInitializing = false);
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          height: 350,
          color: Colors.black,
          child: Stack(
            alignment: Alignment.center,
            children: [
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
              if (!_isPlaying)
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: _isInitializing
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow,
                          color: Colors.white, size: 32),
                ),
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text('Video',
                          style:
                              TextStyle(color: Colors.white, fontSize: 11)),
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

// Callback typedefs
typedef OnToggleLike = void Function();
typedef OnToggleFuel = void Function();
typedef OnShowLikers = void Function();
typedef OnShowReport = void Function();
typedef OnShowEdit = void Function();
typedef OnDeletePost = void Function();

class PostDetailCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final String myId;
  final bool isAlive; // Üst ekrandan 24 saat kontrolü yapılarak geliyor
  final bool isExploreMode;
  final bool isLiked;
  final bool isFueled;
  final int likeCount;
  final int fuelCount;
  final int commentCount;
  final bool isEdited;
  final List<Map<String, dynamic>> emojiReactions;

  // Callbacks
  final OnToggleLike onToggleLike;
  final OnToggleFuel onToggleFuel;
  final OnShowLikers onShowLikers;
  final OnShowReport onShowReport;
  final OnShowEdit onShowEdit;
  final OnDeletePost onDeletePost;
  final VoidCallback onShowAllReactions;
  final Function(BuildContext) onShowPhotoEmojiPicker;
  final Function(String path, String type) onSendEmojiReaction;

  const PostDetailCard({
    super.key,
    required this.post,
    required this.myId,
    required this.isAlive,
    required this.isExploreMode,
    required this.isLiked,
    required this.isFueled,
    required this.likeCount,
    required this.fuelCount,
    required this.commentCount,
    this.isEdited = false,
    required this.emojiReactions,
    required this.onToggleLike,
    required this.onToggleFuel,
    required this.onShowLikers,
    required this.onShowReport,
    required this.onShowEdit,
    required this.onDeletePost,
    required this.onShowAllReactions,
    required this.onShowPhotoEmojiPicker,
    required this.onSendEmojiReaction,
  });

  @override
  State<PostDetailCard> createState() => _PostDetailCardState();
}

class _PostDetailCardState extends State<PostDetailCard> {
  final AudioPlayer _musicPlayer = AudioPlayer();
  bool _isMusicPlaying = false;

  @override
  void dispose() {
    _musicPlayer.dispose();
    super.dispose();
  }

  void _showExpiredMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Bu gönderinin alev süresi doldu! 🔥",
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: Colors.grey.shade800,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _getEmojiIcon(String? emojiType) {
    if (emojiType == null) return '📸';
    switch (emojiType) {
      case 'smile':
        return '😊';
      case 'cry':
        return '😢';
      case 'laugh':
        return '😂';
      case 'surprise':
        return '😮';
      case 'thumbsUp':
        return '👍';
      case 'love':
        return '😍';
      default:
        return '📸';
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.post["profiles"] ?? {};
    final text = widget.post["content"] ?? "";
    final image = widget.post["image_url"];
    final date = DateTime.tryParse(widget.post["created_at"] ?? "");
    final dateStr = date != null ? "${date.day}/${date.month}" : "";
    final location = widget.post['location'];

    final isMyPost = widget.post["user_id"] == widget.myId;

    // 🔥 GÖRÜNÜRLÜK KONTROLÜ
    // Eğer 'public' ise true, değilse (arkadaşlar) false
    final bool isPublicPost = (widget.post['visibility'] == 'public');

    // 🔥 SÜRE KONTROLÜ
    // isAlive parametresi zaten üst ekrandan 24 saat kontrolü yapılarak geliyor
    // Eğer public ise ve alive değilse (24 saat geçtiyse) expired sayılır.
    final bool isExpired = isPublicPost && !widget.isAlive;

    // Explore Modu için renkler (Zaten alev odaklı olduğu için koruyoruz)
    Color statusColor = Colors.grey;
    if (widget.isAlive) {
      if (widget.fuelCount > 10) {
        statusColor = AppColors.accentRedAccent;
      } else if (widget.fuelCount > 5) {
        statusColor = const Color(0xFFFF5722);
      } else if (widget.fuelCount > 0) {
        statusColor = const Color(0xFFFFAB00);
      }
    } else {
      statusColor = Colors.blueGrey;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: Colors.white.withOpacity(0.1), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- HEADER ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ProfileScreen(
                                    userId: widget.post["user_id"]))),
                        child: KinnectImage(
                          imageUrl: profile["avatar_url"] ?? "",
                          width: 44,
                          height: 44,
                          isCircle: true,
                          fit: BoxFit.cover,
                          useShimmer: false,
                          backgroundColor: Colors.white10,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // ORTA KISIM
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(profile["full_name"] ?? "İsimsiz",
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold)),
                            Text("@${profile["username"]}",
                                style: GoogleFonts.poppins(
                                    color: Colors.grey.shade400, fontSize: 12)),
                            if (location != null &&
                                location.toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: GestureDetector(
                                  onTap: () => showLocationDisplaySheet(
                                      context, location),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.location_on_outlined,
                                          color: AppColors.primary, size: 14),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          location,
                                          style: GoogleFonts.poppins(
                                              color: AppColors.primary,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // SAĞ KISIM
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              // GÖRÜNÜRLÜK İKONU (Dünya veya Grup)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Icon(
                                  isPublicPost
                                      ? FontAwesomeIcons.earthAmericas
                                      : FontAwesomeIcons.userGroup,
                                  color: Colors.white24,
                                  size: 12,
                                ),
                              ),
                              if (widget.isEdited)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Text(
                                    "(düzenlendi)",
                                    style: GoogleFonts.poppins(
                                      color: Colors.white38,
                                      fontSize: 10,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              Text(dateStr,
                                  style: GoogleFonts.poppins(
                                      color: Colors.grey.shade400,
                                      fontSize: 12)),
                            ],
                          ),
                          Container(
                            width: 28,
                            height: 28,
                            margin: const EdgeInsets.only(top: 4),
                            alignment: Alignment.centerRight,
                            child: PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.more_horiz,
                                  color: Colors.white70, size: 20),
                              color: const Color(0xFF2C2C2C),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              onSelected: (value) {
                                if (value == 'report') widget.onShowReport();
                                if (value == 'edit') widget.onShowEdit();
                                if (value == 'delete') widget.onDeletePost();
                              },
                              itemBuilder: (BuildContext context) {
                                if (isMyPost) {
                                  return [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.edit_outlined,
                                              color: AppColors.primary,
                                              size: 18),
                                          const SizedBox(width: 10),
                                          Text("Düzenle",
                                              style: GoogleFonts.poppins(
                                                  color: Colors.white,
                                                  fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.delete_outline,
                                              color: AppColors.accentRedAccent,
                                              size: 18),
                                          const SizedBox(width: 10),
                                          Text("Sil",
                                              style: GoogleFonts.poppins(
                                                  color:
                                                  AppColors.accentRedAccent,
                                                  fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                  ];
                                } else {
                                  return [
                                    PopupMenuItem(
                                      value: 'report',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.flag_outlined,
                                              color: Colors.white70, size: 18),
                                          const SizedBox(width: 10),
                                          Text("Şikayet Et",
                                              style: GoogleFonts.poppins(
                                                  color: Colors.white,
                                                  fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                  ];
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // --- İÇERİK ---
                if (text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(text,
                        style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 15)),
                  ),
                ],

                // 🖼️ ETİKETLİ VE MÜZİKLİ GÖRSEL
                if (widget.post['image_urls'] != null &&
                    (widget.post['image_urls'] as List).length > 1) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DoubleTapOverlay(
                      // Süre bittiyse uyar, değilse beğen
                      onDoubleTap: isExpired ? _showExpiredMessage : widget.onToggleLike,
                      icon: isPublicPost
                          ? FontAwesomeIcons.fire
                          : FontAwesomeIcons.solidHeart,
                      // Expired: Gri, Public: Turuncu, Friend: Mor
                      iconColor: isExpired
                          ? Colors.grey
                          : (isPublicPost ? Colors.orange : AppColors.primary),
                      child: ImageCarousel(
                        imageUrls:
                        (widget.post['image_urls'] as List).cast<String>(),
                        height: 350,
                        borderRadius: BorderRadius.circular(12),
                        musicTrackName: widget.post['spotify_track_name'],
                        musicArtistName: widget.post['spotify_artist_name'],
                        postId: widget.post['id'],
                      ),
                    ),
                  ),
                ] else if (image != null) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: DoubleTapOverlay(
                        // Süre bittiyse uyar, değilse beğen
                        onDoubleTap: isExpired ? _showExpiredMessage : widget.onToggleLike,
                        icon: isPublicPost
                            ? FontAwesomeIcons.fire
                            : FontAwesomeIcons.solidHeart,
                        // Expired: Gri, Public: Turuncu, Friend: Mor
                        iconColor: isExpired
                            ? Colors.grey
                            : (isPublicPost ? Colors.orange : AppColors.primary),
                        child: TaggablePostImage(
                          imageUrl: image,
                          postId: widget.post['id'],
                          borderRadius: BorderRadius.circular(12),
                          musicTrackName: widget.post['spotify_track_name'],
                          musicArtistName: widget.post['spotify_artist_name'],
                        ),
                      ),
                    ),
                  ),
                ] else if (widget.post['video_url'] != null &&
                    widget.post['video_url'].toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _PostVideoPlayerDetail(
                      videoUrl: widget.post['video_url'] as String,
                      thumbnailUrl: (widget.post['video_frame_urls'] as List?)
                                  ?.isNotEmpty ==
                              true
                          ? (widget.post['video_frame_urls'] as List).first
                              as String
                          : null,
                    ),
                  ),
                ] else if (widget.post['spotify_track_name'] != null) ...[
                  // 🎵 Görsel yokken müzik bilgisi göster
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: GestureDetector(
                      onTap: () {
                        if (_isMusicPlaying) {
                          _musicPlayer.pause();
                          setState(() => _isMusicPlaying = false);
                        } else {
                          final previewUrl = widget.post['spotify_preview_url'];
                          if (previewUrl != null) {
                            _musicPlayer.play(UrlSource(previewUrl));
                            setState(() => _isMusicPlaying = true);
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF1DB954).withOpacity(0.3),
                              const Color(0xFF1DB954).withOpacity(0.1),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                            const Color(0xFF1DB954).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1DB954),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _isMusicPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.post['spotify_track_name'] ?? '',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.post['spotify_artist_name'] ?? '',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              FontAwesomeIcons.spotify,
                              color: Color(0xFF1DB954),
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // --- AKSİYON BAR ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: widget.isExploreMode
                      ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Fuel Button (Explore Modu - Buraya dokunmadık, kendi mantığı var)
                      FuelButton(
                        isFueled: widget.isFueled,
                        count: widget.fuelCount,
                        isExpired: !widget.isAlive,
                        onTap: widget.onToggleFuel,
                        size: 28,
                      ),
                      // 2. Beğeni Sayısı
                      GestureDetector(
                        onTap: widget.onShowLikers,
                        child: Padding(
                          padding: EdgeInsets.only(
                              left: 2, top: widget.isAlive ? 32.0 : 38.0),
                          child: Text(
                            "${widget.fuelCount}",
                            style: GoogleFonts.poppins(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      // 3. Yorum Sayısı
                      Padding(
                        padding: EdgeInsets.only(
                            top: widget.isAlive ? 32.0 : 38.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(FontAwesomeIcons.comment,
                                  size: 16, color: Colors.white38),
                              const SizedBox(width: 6),
                              Text("${widget.commentCount}",
                                  style: GoogleFonts.poppins(
                                      color: Colors.white38,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                      : Row(
                    // 🔥 NORMAL MOD (Public veya Friend)
                    children: [
                      // 1. Beğeni / Alev Butonu
                      Row(
                        children: [
                          // İkon
                          GestureDetector(
                            // Süre dolduysa uyarı, yoksa beğeni
                            onTap: isExpired ? _showExpiredMessage : widget.onToggleLike,
                            child: Icon(
                              // Public -> Alev, Friend -> Kalp
                              isPublicPost
                                  ? FontAwesomeIcons.fire
                                  : (widget.isLiked
                                  ? FontAwesomeIcons.solidHeart
                                  : FontAwesomeIcons.heart),
                              // Renk: Expired->Gri, Public->Turuncu, Friend->Mor
                              color: isExpired
                                  ? Colors.grey
                                  : (widget.isLiked
                                  ? (isPublicPost
                                  ? Colors.orange
                                  : AppColors.primary)
                                  : Colors.grey.shade400),
                              size: 22,
                            ),
                          ),
                          // Sayı
                          if (widget.likeCount > 0) ...[
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: widget.onShowLikers,
                              child: Text("${widget.likeCount}",
                                  style: GoogleFonts.poppins(
                                      color: isExpired
                                          ? Colors.grey
                                          : (widget.isLiked
                                          ? (isPublicPost
                                          ? Colors.orange
                                          : AppColors.primary)
                                          : Colors.grey.shade400),
                                      fontWeight: FontWeight.w600)),
                            ),
                          ]
                        ],
                      ),
                      // 2. Yorum
                      const SizedBox(width: 24),
                      Container(
                        color: Colors.transparent,
                        child: Row(
                          children: [
                            Icon(FontAwesomeIcons.comment,
                                color: Colors.grey.shade400, size: 22),
                            if (widget.commentCount > 0) ...[
                              const SizedBox(width: 6),
                              Text("${widget.commentCount}",
                                  style: GoogleFonts.poppins(
                                      color: Colors.grey.shade400,
                                      fontWeight: FontWeight.w600)),
                            ]
                          ],
                        ),
                      ),
                      const Spacer(),
                      // 3. Mevcut Tepkiler - Sağda
                      if (widget.emojiReactions.isNotEmpty) ...[
                        GestureDetector(
                          onTap: widget.onShowAllReactions,
                          child: Row(
                            children: [
                              SizedBox(
                                width: (widget.emojiReactions.length > 3
                                    ? 3
                                    : widget
                                    .emojiReactions.length) *
                                    22 +
                                    10,
                                height: 28,
                                child: Stack(
                                  children: [
                                    for (int i = 0;
                                    i <
                                        (widget.emojiReactions
                                            .length >
                                            3
                                            ? 3
                                            : widget.emojiReactions
                                            .length);
                                    i++)
                                      Positioned(
                                        left: i * 18.0,
                                        child: Stack(
                                          children: [
                                            Container(
                                              width: 28,
                                              height: 28,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                    color:
                                                    AppColors.bgBlack,
                                                    width: 2),
                                                image: DecorationImage(
                                                  image: NetworkImage(
                                                      widget.emojiReactions[
                                                      i][
                                                      'emoji_url'] ??
                                                          ''),
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              right: 0,
                                              bottom: 0,
                                              child: Container(
                                                width: 12,
                                                height: 12,
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                      0xFF1A1A24),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                      color: const Color(
                                                          0xFF6C63FF),
                                                      width: 1),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    _getEmojiIcon(widget
                                                        .emojiReactions[
                                                    i]['emoji_type']),
                                                    style:
                                                    const TextStyle(
                                                        fontSize: 6),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (widget.emojiReactions.length > 3) ...[
                                const SizedBox(width: 4),
                                Text(
                                  "+${widget.emojiReactions.length - 3}",
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey.shade400,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      // 4. Tepki Ver Butonu
                      GestureDetector(
                        onTap: () async {
                          final result = await widget
                              .onShowPhotoEmojiPicker(context);
                          if (result != null) {
                            widget.onSendEmojiReaction(
                                result['path']!, result['type']!);
                          }
                        },
                        child: Container(
                          color: Colors.transparent,
                          child: Row(
                            children: [
                              Icon(
                                Icons.add_reaction_outlined,
                                color: Colors.grey.shade400,
                                size: 26,
                              ),
                            ],
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
    );
  }
}