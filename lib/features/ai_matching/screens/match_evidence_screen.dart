import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../post/screens/post_detail_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Bir eşleşme sebebinin kanıt postlarını gösteren ekran.
/// Örn: "İkiniz de seyahat tutkunusunuz ✈️" → bu analyzie yol açan postlar
class MatchEvidenceScreen extends StatefulWidget {
  final String reason;
  final String otherUserName;
  final String? otherUserAvatarUrl;
  final List<Map<String, dynamic>> myPosts;
  final List<Map<String, dynamic>> otherPosts;

  const MatchEvidenceScreen({
    super.key,
    required this.reason,
    required this.otherUserName,
    this.otherUserAvatarUrl,
    required this.myPosts,
    required this.otherPosts,
  });

  @override
  State<MatchEvidenceScreen> createState() => _MatchEvidenceScreenState();
}

class _MatchEvidenceScreenState extends State<MatchEvidenceScreen> {
  // Tıklanan post için tam veriyi DB'den çekeceğiz
  Future<Map<String, dynamic>?> _fetchFullPost(String postId) async {
    try {
      final result = await Supabase.instance.client
          .from('posts')
          .select('*, profiles:user_id(id, username, full_name, avatar_url)')
          .eq('id', postId)
          .maybeSingle();
      return result;
    } catch (_) {
      return null;
    }
  }

  void _openPost(Map<String, dynamic> postSummary) async {
    final postId = postSummary['id'] as String?;
    if (postId == null) return;

    // Loading göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    final fullPost = await _fetchFullPost(postId);
    if (!mounted) return;
    Navigator.pop(context); // Loading kapat

    if (fullPost == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(post: fullPost),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasMyPosts = widget.myPosts.isNotEmpty;
    final hasOtherPosts = widget.otherPosts.isNotEmpty;
    final hasAnyPosts = hasMyPosts || hasOtherPosts;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Analiz Kaynağı',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Sebep kartı ──────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.18),
                    const Color(0xFF9D89D9).withOpacity(0.10),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      FontAwesomeIcons.wandMagicSparkles,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.reason,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Açıklama ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                'Yapay zeka bu analizi aşağıdaki paylaşımlara dayanarak yaptı.',
                style: GoogleFonts.poppins(
                  color: Colors.white54,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),

            if (!hasAnyPosts) ...[
              const SizedBox(height: 40),
              _buildNoPosts(),
            ] else ...[
              // ── Benim postlarım ─────────────────────────────────────────
              if (hasMyPosts) ...[
                const SizedBox(height: 20),
                _buildSectionHeader(
                  icon: Icons.person_rounded,
                  label: 'Senin paylaşımların',
                  color: AppColors.primary,
                ),
                const SizedBox(height: 12),
                _buildPostGrid(widget.myPosts),
              ],

              // ── Diğer kullanıcının postları ──────────────────────────────
              if (hasOtherPosts) ...[
                const SizedBox(height: 24),
                _buildSectionHeader(
                  avatarUrl: widget.otherUserAvatarUrl,
                  label: '${widget.otherUserName}\'ın paylaşımları',
                  color: const Color(0xFF9D89D9),
                ),
                const SizedBox(height: 12),
                _buildPostGrid(widget.otherPosts),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    IconData? icon,
    String? avatarUrl,
    required String label,
    required Color color,
  }) {
    return Row(
      children: [
        if (avatarUrl != null)
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.bgCard,
            backgroundImage: NetworkImage(avatarUrl),
          )
        else if (icon != null)
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 15),
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPostGrid(List<Map<String, dynamic>> posts) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) => _buildPostCard(posts[index]),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final imageUrls = (post['image_urls'] as List?)?.cast<String>() ?? [];
    final firstImage = imageUrls.isNotEmpty ? imageUrls.first : null;
    final content = post['content'] as String? ?? '';
    final artist = post['spotify_artist_name'] as String?;
    final trackName = post['spotify_track_name'] as String?;
    final location = post['location'] as String?;

    return GestureDetector(
      onTap: () => _openPost(post),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Görsel alanı
              Expanded(
                child: firstImage != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            firstImage,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
                          ),
                          // Üst kısım gradient
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.6),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : _buildImagePlaceholder(),
              ),

              // Alt bilgi alanı
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Spotify bilgisi
                    if (artist != null) ...[
                      Row(
                        children: [
                          Icon(FontAwesomeIcons.spotify,
                              size: 11, color: const Color(0xFF1DB954)),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              artist,
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF1DB954),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (trackName != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Text(
                            trackName,
                            style: GoogleFonts.poppins(
                              color: Colors.white38,
                              fontSize: 9,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ] else if (location != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded,
                              size: 11, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: GoogleFonts.poppins(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ] else if (content.isNotEmpty) ...[
                      Text(
                        content,
                        style: GoogleFonts.poppins(
                          color: Colors.white60,
                          fontSize: 10,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.white.withOpacity(0.04),
      child: Center(
        child: Icon(
          Icons.image_rounded,
          color: Colors.white12,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildNoPosts() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                FontAwesomeIcons.wandMagicSparkles,
                color: AppColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Bu analiz profil verilerine dayanıyor',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Belirli bir post değil; ilgi alanları, sosyal tarz veya müzik zevki gibi profil bilgilerinden çıkarılan bir ortak nokta.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white54,
                fontSize: 12,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
