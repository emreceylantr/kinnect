import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/matching_service.dart';
import '../../profile/screens/profile_screen.dart';
import '../../create_post/screens/create_post_screen.dart';
import 'quiz_screen.dart';

class AiMatchingScreen extends StatefulWidget {
  const AiMatchingScreen({super.key});

  @override
  State<AiMatchingScreen> createState() => _AiMatchingScreenState();
}

class _AiMatchingScreenState extends State<AiMatchingScreen>
    with TickerProviderStateMixin {
  final MatchingService _matchingService = MatchingService();
  late AnimationController _shimmerController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Cache — widget yeniden oluşturulsa bile korunur
  static List<Map<String, dynamic>>? _cachedMatches;
  static DateTime? _lastFetchTime;
  static const _cacheDuration = Duration(minutes: 5);
  static const int _minPostsRequired = 5;

  bool _isRefreshing = false;
  bool _fetchFailed = false;
  int _myPostCount = -1; // -1 = henüz yüklenmedi

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _checkMyPostCount();

    // Cache geçerliyse API çağırma
    final cacheValid = _cachedMatches != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration;

    if (!cacheValid) {
      _fetchMatches();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _checkQuizStatus());
  }

  Future<void> _checkMyPostCount() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final result = await Supabase.instance.client
          .from('posts')
          .select('id')
          .eq('user_id', userId);
      if (mounted) setState(() => _myPostCount = (result as List).length);
    } catch (e) {
      debugPrint('Post count check error: $e');
    }
  }

  Future<void> _checkQuizStatus() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final row = await Supabase.instance.client
          .from('user_profiles')
          .select('quiz_answers')
          .eq('user_id', userId)
          .maybeSingle();
      final done = row != null && row['quiz_answers'] != null;
      if (!done && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => QuizScreen(onCompleted: () {
              _fetchMatches(forceRefresh: true);
            }),
          ),
        );
      }
    } catch (e) {
      debugPrint('Quiz status check error: $e');
    }
  }

  Future<void> _fetchMatches({bool forceRefresh = false}) async {
    if (_isRefreshing && !forceRefresh) return;
    setState(() { _isRefreshing = true; _fetchFailed = false; });
    try {
      final results = await _matchingService.getMatchedUsers();
      if (mounted) {
        setState(() {
          _cachedMatches = results;
          _lastFetchTime = DateTime.now();
          _isRefreshing = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _isRefreshing = false; _fetchFailed = true; });
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Yeterli post yoksa özel ekran göster
    if (_myPostCount >= 0 && _myPostCount < _minPostsRequired) {
      return _buildInsufficientPostsState();
    }

    // Cache yoksa loading göster
    if (_cachedMatches == null) {
      if (_fetchFailed) return _buildErrorState();
      return _buildLoadingState();
    }

    final matches = _cachedMatches!;

    if (matches.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.bgCard,
          onRefresh: () => _fetchMatches(forceRefresh: true),
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
                Row(
                  children: [
                    Text(
                      'Yapay zeka $count kişiyle ortak yönler buldu',
                      style: GoogleFonts.poppins(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    if (_isRefreshing) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 1.5,
                        ),
                      ),
                    ],
                  ],
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
    final interests = List<String>.from(match['interests'] ?? []);
    final matchReasons = List<String>.from(match['match_reasons'] ?? []);
    final profileSummary = (match['profile_summary'] as String?) ?? '';
    final bestSummary = interests.isNotEmpty ? interests.take(3).join(' · ') : profileSummary;
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
                  if (matchReasons.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: matchReasons.take(2).map((reason) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                        ),
                        child: Text(
                          reason,
                          style: GoogleFonts.poppins(
                            color: AppColors.primary.withOpacity(0.9),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )).toList(),
                    ),
                  ] else if (bestSummary.isNotEmpty) ...[
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

    final otherProfile   = (match['profile_summary'] as String?) ?? '';
    final otherInterests = List<String>.from(match['interests'] ?? []);
    final matchReasons   = List<String>.from(match['match_reasons'] ?? []);

    final Future<String> explanationFuture = _matchingService.getAiExplanation(
      otherUserId:      userId,
      otherUserName:    fullName,
      otherUserProfile: otherProfile,
      otherInterests:   otherInterests,
      matchReasons:     matchReasons,
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
                  if (matchReasons.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Ortak Noktalarınız',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: matchReasons.map((reason) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: Text(
                          reason,
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )).toList(),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // AI Açıklaması
                  Row(
                    children: [
                      const Icon(FontAwesomeIcons.robot,
                          color: Colors.blueAccent, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        'Yapay Zeka Analizi',
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

                  // İlgi alanları
                  if (otherInterests.isNotEmpty) ...[
                    Text(
                      '🎯 İlgi Alanları',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: otherInterests.map((interest) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                        ),
                        child: Text(
                          interest,
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 13,
                          ),
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Profil özeti
                  if (otherProfile.isNotEmpty) ...[
                    Text(
                      '👤 Profil',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Text(
                        otherProfile,
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.6,
                        ),
                      ),
                    ),
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

  // ============ INSUFFICIENT POSTS STATE ============
  Widget _buildInsufficientPostsState() {
    final remaining = _minPostsRequired - _myPostCount;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animasyonlu ikon
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.25),
                      AppColors.primary.withOpacity(0.05),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    FontAwesomeIcons.wandMagicSparkles,
                    color: AppColors.primary,
                    size: 40,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Başlık
            Text(
              'Ruh İkizini Bulmak İçin...',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),

            // Açıklama
            Text(
              'Yapay zekanın seni analiz edebilmesi ve en uyumlu kişileri bulabilmesi için en az $_minPostsRequired gönderi paylaşman gerekiyor.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white54,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),

            // İlerleme göstergesi
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$_myPostCount / $_minPostsRequired gönderi',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '$remaining tane daha',
                        style: GoogleFonts.poppins(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _myPostCount / _minPostsRequired,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // CTA butonu
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreatePostScreen()),
              ).then((_) => _checkMyPostCount()),
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
                      color: AppColors.primary.withOpacity(0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(FontAwesomeIcons.plus, color: Colors.white, size: 16),
                    const SizedBox(width: 10),
                    Text(
                      'Gönderi Paylaş',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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

  // ============ ERROR STATE ============
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white24, size: 48),
            const SizedBox(height: 20),
            Text(
              'Bağlantı hatası',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Eşleşmeler yüklenemedi. Tekrar deneyin.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => _fetchMatches(forceRefresh: true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF9D89D9)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Tekrar Dene',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
