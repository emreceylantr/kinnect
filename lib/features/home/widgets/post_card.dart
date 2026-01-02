// Kinnect - Feed Post Kartı
// home_screen.dart'tan refactor edildi

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../data/services/feed_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/image_carousel.dart';
import '../../../shared/widgets/location_display_sheet.dart';
import '../../../shared/widgets/double_tap_overlay.dart';
import '../../post/screens/post_detail_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../../shared/widgets/kinnect_image.dart';

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
    final dateStr = date != null ? '${date.day}/${date.month}' : '';
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
                        p['content'],
                        style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 14,
                            height: 1.5),
                      ),
                    ),
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
