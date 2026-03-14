import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/matching_service.dart';
import '../../profile/screens/profile_screen.dart';

class AiMatchingScreen extends StatefulWidget {
  const AiMatchingScreen({super.key});

  @override
  State<AiMatchingScreen> createState() => _AiMatchingScreenState();
}

class _AiMatchingScreenState extends State<AiMatchingScreen>
    with TickerProviderStateMixin {
  final MatchingService _matchingService = MatchingService();
  late Future<List<Map<String, dynamic>>> _matchesFuture;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _matchesFuture = _matchingService.getMatchedUsers();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  void _refreshMatches() {
    setState(() {
      _matchesFuture = _matchingService.getMatchedUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _matchesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        final matches = snapshot.data ?? [];

        if (matches.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.bgCard,
          onRefresh: () async {
            _refreshMatches();
            await _matchesFuture;
          },
          child: CustomScrollView(
            slivers: [
              // Üst Başlık Alanı
              SliverToBoxAdapter(child: _buildHeader(matches.length)),

              // Yatay Avatar Kaydırma
              SliverToBoxAdapter(child: _buildTopAvatarRow(matches)),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Dikey Kart Listesi
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Sana En Yakın Kişiler',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildMatchCard(matches[index], index),
                      );
                    },
                    childCount: matches.length,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        );
      },
    );
  }

  // ============ HEADER ============
  Widget _buildHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF9D89D9)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(FontAwesomeIcons.wandMagicSparkles,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ruh İkizlerin',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Yapay zeka $count kişiyle ortak yönler buldu',
                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============ TOP AVATAR ROW ============
  Widget _buildTopAvatarRow(List<Map<String, dynamic>> matches) {
    final topMatches = matches.take(10).toList();
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: topMatches.length,
        itemBuilder: (context, index) {
          final match = topMatches[index];
          final profile = match['profile'] as Map<String, dynamic>;
          final similarity = ((match['similarity'] as double) * 100).toInt();
          final avatarUrl = profile['avatar_url']?.toString();

          return GestureDetector(
            onTap: () => _showMatchDetail(match),
            child: Container(
              width: 76,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  // Gradient border avatar
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary,
                          const Color(0xFF9D89D9),
                          AppColors.primary.withValues(alpha: 0.6),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.bgDark,
                      backgroundImage:
                          avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null
                          ? const Icon(Icons.person,
                              color: Colors.white38, size: 26)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Yüzde
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '%$similarity',
                      style: GoogleFonts.poppins(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    profile['username'] ?? '',
                    style: GoogleFonts.poppins(
                      color: Colors.white60,
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ============ MATCH CARD ============
  Widget _buildMatchCard(Map<String, dynamic> match, int index) {
    final profile = match['profile'] as Map<String, dynamic>;
    final similarity = (match['similarity'] as double);
    final percent = (similarity * 100).toInt();
    final bestSummary = match['best_match_summary'] ?? '';
    final avatarUrl = profile['avatar_url']?.toString();
    final fullName = profile['full_name'] ?? profile['username'] ?? 'Kullanıcı';
    final username = profile['username'] ?? '';

    // Renk geçişi: yüksek skor = yeşil, düşük = turuncu
    final Color scoreColor = similarity > 0.75
        ? const Color(0xFF69F0AE)
        : similarity > 0.60
            ? AppColors.primary
            : const Color(0xFFFFAB40);

    return GestureDetector(
      onTap: () => _showMatchDetail(match),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(
                      userId: profile['id'],
                      showBackButton: true,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [scoreColor, scoreColor.withValues(alpha: 0.4)],
                  ),
                ),
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.bgDark,
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? const Icon(Icons.person,
                          color: Colors.white38, size: 24)
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // İsim ve açıklama
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          fullName,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Skor badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: scoreColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: scoreColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '%$percent',
                          style: GoogleFonts.poppins(
                            color: scoreColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@$username',
                    style: GoogleFonts.poppins(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                  if (bestSummary.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(FontAwesomeIcons.wandMagicSparkles,
                            size: 10,
                            color: AppColors.primary.withOpacity(0.7)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            bestSummary,
                            style: GoogleFonts.poppins(
                              color: Colors.white54,
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 22),
          ],
        ),
      ),
    );
  }

  // ============ MATCH DETAIL BOTTOM SHEET ============
  void _showMatchDetail(Map<String, dynamic> match) async {
    final profile = match['profile'] as Map<String, dynamic>;
    final userId = profile['id'] as String;
    final similarity = (match['similarity'] as double);
    final percent = (similarity * 100).toInt();
    final avatarUrl = profile['avatar_url']?.toString();
    final fullName = profile['full_name'] ?? profile['username'] ?? 'Kullanıcı';
    final username = profile['username'] ?? '';

    // Veri yapısını MatchingService'den gelen yeni formata göre al
    final matchPairs = (match['match_pairs'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    // AI Açıklamasını asenkron olarak başlat
    final Future<String> explanationFuture = _matchingService.getAiExplanation(
      otherUserId: userId,
      otherUserName: fullName,
      matchPairs: matchPairs,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.6,
        builder: (context, scrollController) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E).withOpacity(0.95),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Profil header
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, Color(0xFF9D89D9)],
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 45,
                            backgroundColor: AppColors.bgDark,
                            backgroundImage: avatarUrl != null
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: avatarUrl == null
                                ? const Icon(Icons.person,
                                    color: Colors.white38, size: 40)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          fullName,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '@$username',
                          style: GoogleFonts.poppins(
                            color: Colors.white38,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Büyük skor göstergesi
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withValues(alpha: 0.6),
                                const Color(0xFF9D89D9).withOpacity(0.2),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color:
                                    AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(FontAwesomeIcons.wandMagicSparkles,
                                  color: AppColors.primary, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                '%$percent Benzerlik',
                                style: GoogleFonts.poppins(
                                  color: AppColors.primary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // AI Açıklaması
                  Row(
                    children: [
                      const Icon(FontAwesomeIcons.robot,
                          color: Colors.blueAccent, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        'Zeki Asistan Analizi',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  FutureBuilder<String>(
                    future: explanationFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.05)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Paylaşımlar analiz ediliyor...',
                                style: GoogleFonts.poppins(
                                    color: Colors.white54, fontSize: 13),
                              ),
                              const SizedBox(height: 10),
                              const LinearProgressIndicator(
                                backgroundColor: Colors.transparent,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        );
                      }

                      final explanation =
                          snapshot.data ?? "Harika bir eşleşme!";

                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.primary.withOpacity(0.2)),
                        ),
                        child: Text(
                          explanation,
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 15,
                            height: 1.6,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // Neden eşleştiniz? (List)
                  Text(
                    '📍 Ortak İlgi Alanları',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Ortak paylaşımlar (ÇİFTLER)
                  if (matchPairs.isNotEmpty) ...[
                    ...matchPairs.take(3).map((p) => Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _buildReasonTile(
                                icon: FontAwesomeIcons.user,
                                title: 'Senin Paylaşımın',
                                subtitle: p['my_summary'],
                                imageUrl: p['my_image'],
                                color: const Color(0xFF69F0AE),
                              ),
                            ),
                            const Center(
                              child: Icon(FontAwesomeIcons.arrowsUpDown,
                                  size: 14, color: Colors.white24),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: _buildReasonTile(
                                icon: FontAwesomeIcons.heart,
                                title: '${fullName} Paylaştı',
                                subtitle: p['other_summary'],
                                imageUrl: p['other_image'],
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        )),
                  ],

                  const SizedBox(height: 32),

                  // Profili Gör butonu
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(
                            userId: userId,
                            showBackButton: true,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, Color(0xFF9D89D9)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'Profiline Git',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReasonTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    String? imageUrl,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(16)),
              ),
              child: Center(
                child: FaIcon(icon, color: color, size: 16),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            if (imageUrl != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 60,
                      height: 60,
                      color: Colors.white.withOpacity(0.05),
                      child: const Icon(Icons.broken_image,
                          size: 20, color: Colors.white24),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============ LOADING STATE ============
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Yapay zeka ruh ikizlerini arıyor...',
            style: GoogleFonts.poppins(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ============ EMPTY STATE ============
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(FontAwesomeIcons.wandMagicSparkles,
                  size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Text(
              'Henüz Eşleşme Yok',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Post paylaştıkça yapay zeka sana benzer ilgi alanlarına sahip kişileri burada gösterecek! 🤖',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
