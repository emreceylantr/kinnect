import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/language/app_l10n.dart';
import '../../../data/services/matching_service.dart';
import '../../../data/services/chat_service.dart';
import '../../../data/services/spotify_service.dart';
import '../../../data/services/apple_music_service.dart';
import '../../profile/screens/profile_screen.dart';
import '../../create_post/screens/create_post_screen.dart';
import '../../chat/screens/chat_screen.dart';
import 'quiz_screen.dart';
import 'match_evidence_screen.dart';

class AiMatchingScreen extends StatefulWidget {
  const AiMatchingScreen({super.key});

  @override
  State<AiMatchingScreen> createState() => _AiMatchingScreenState();
}

class _AiMatchingScreenState extends State<AiMatchingScreen> with TickerProviderStateMixin {
  final MatchingService _matchingService = MatchingService();
  final ChatService _chatService = ChatService();
  final SpotifyService _spotifyService = SpotifyService();
  final AppleMusicService _appleMusicService = AppleMusicService();

  late AnimationController _shimmerController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Cache
  static List<Map<String, dynamic>>? _cachedMatches;
  static DateTime? _lastFetchTime;
  static String? _cacheLanguage;
  static const _cacheDuration = Duration(minutes: 5);
  static const int _minPostsRequired = 5;

  bool _isRefreshing = false;
  bool _fetchFailed = false;
  int _myPostCount = -1;
  Set<String> _hiddenUserIds = {};
  int _selectedMatchIndex = 0;

  // My AI Profile state
  Map<String, dynamic>? _myProfile;
  bool _myProfileLoading = true;
  String _myFullName = '';
  String? _myAvatarUrl;
  bool _spotifyConnected = false;
  bool _appleMusicConnected = false;
  bool _spotifySyncing = false;
  bool _appleMusicSyncing = false;

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

    _loadHiddenUsers();
    _loadMyProfile();
    _checkMyPostCountThenQuiz();

    final currentLang = AppL10n.currentLanguageCode;
    if (_cacheLanguage != null && _cacheLanguage != currentLang) {
      _cachedMatches = null;
      _lastFetchTime = null;
    }
    _cacheLanguage = currentLang;

    final cacheValid = _cachedMatches != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration;

    if (!cacheValid) {
      _fetchMatches();
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkMyPostCountThenQuiz() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final result = await Supabase.instance.client
          .from('posts')
          .select('id')
          .eq('user_id', userId);
      final count = (result as List).length;
      if (mounted) setState(() => _myPostCount = count);

      if (count >= _minPostsRequired) {
        await _checkQuizStatus();
      }
    } catch (e) {
      debugPrint('Post count check error: $e');
      if (mounted) setState(() => _myPostCount = 0);
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
    setState(() {
      _isRefreshing = true;
      _fetchFailed = false;
    });
    try {
      final results = await _matchingService.getMatchedUsers();
      if (mounted) {
        setState(() {
          _cachedMatches = results;
          _lastFetchTime = DateTime.now();
          _cacheLanguage = AppL10n.currentLanguageCode;
          _selectedMatchIndex = 0;
          _isRefreshing = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _fetchFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;

    if (_myPostCount == -1) {
      bodyContent = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.orange),
            const SizedBox(height: 20),
            Text(
              'Ruh ikizlerini arıyoruz...',
              style: GoogleFonts.poppins(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    } else if (_myPostCount < _minPostsRequired) {
      bodyContent = _buildInsufficientPostsState();
    } else if (_cachedMatches == null) {
      bodyContent = _fetchFailed ? _buildErrorState() : _buildLoadingState();
    } else {
      final matches = _cachedMatches!.where((m) {
        final uid = (m['profile'] as Map<String, dynamic>)['id'] as String?;
        return uid != null && !_hiddenUserIds.contains(uid);
      }).toList()
        ..sort((a, b) {
          final aSimilarity = (a['similarity'] as num?)?.toDouble() ?? 0;
          final bSimilarity = (b['similarity'] as num?)?.toDouble() ?? 0;
          return bSimilarity.compareTo(aSimilarity);
        });

      if (matches.isEmpty) {
        bodyContent = _buildEmptyState();
      } else {
        if (_selectedMatchIndex >= matches.length) {
          _selectedMatchIndex = math.max(0, matches.length - 1);
        }
        bodyContent = LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight;
            final isCompactHeight = availableHeight < 760;
            final isVeryCompactHeight = availableHeight < 700;
            final horizontalPadding = isCompactHeight ? 12.0 : 16.0;

            final bottomPadding = isVeryCompactHeight ? 40.0 : 50.0;
            final cardGap = isVeryCompactHeight ? 11.0 : (isCompactHeight ? 13.0 : 17.0);

            return RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.bgCard,
              onRefresh: () => _fetchMatches(forceRefresh: true),
              child: CustomScrollView(
                physics: const NeverScrollableScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        0,
                        horizontalPadding,
                        bottomPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _buildHeader(
                              matches.length,
                              compact: isCompactHeight,
                            ),
                          ),
                          const Expanded(child: SizedBox(height: 10)),

                          _buildTopAvatarRow(
                            matches,
                            compact: isCompactHeight,
                          ),

                          SizedBox(height: isVeryCompactHeight ? 12 : 20),

                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (Widget child, Animation<double> animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.05, 0.0),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: Dismissible(
                              key: ValueKey(matches[_selectedMatchIndex]['profile']['id']),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.visibility_off_rounded, color: Colors.redAccent, size: 22),
                                    const SizedBox(height: 4),
                                    Text(AppL10n.hide, style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 11)),
                                  ],
                                ),
                              ),
                              onDismissed: (_) {
                                final dismissedId = matches[_selectedMatchIndex]['profile']['id'] as String;
                                _hideUser(dismissedId);
                              },
                              child: _buildMatchCard(
                                matches[_selectedMatchIndex],
                                _selectedMatchIndex,
                                compact: isCompactHeight,
                              ),
                            ),
                          ),
                          SizedBox(height: cardGap),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _buildDragonAction(
                              matches[_selectedMatchIndex],
                              compact: isCompactHeight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const Positioned.fill(
            child: _WarmAuroraBackground(),
          ),
          SafeArea(
            bottom: false,
            child: bodyContent,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int count, {bool compact = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, compact ? 0 : 8, 16, compact ? 8 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(compact ? 8 : 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF5252), Color(0xFFD32F2F)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF5252).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              FontAwesomeIcons.wandMagicSparkles,
              color: Colors.white,
              size: compact ? 16 : 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  AppL10n.soulTwins,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: compact ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                if (_isRefreshing) ...[
                  const SizedBox(width: 10),
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      color: Color(0xFFFF5252),
                      strokeWidth: 2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Colors.orange, Colors.deepOrange],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: compact ? 16 : 18,
                  backgroundColor: const Color(0xFF0F0C1A),
                  backgroundImage: _myAvatarUrl != null ? NetworkImage(_myAvatarUrl!) : null,
                  child: _myAvatarUrl == null
                      ? (_myProfileLoading
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
                  )
                      : const Icon(Icons.person_rounded, color: Colors.white54, size: 18))
                      : null,
                ),
              ),
              if (_hiddenUserIds.isNotEmpty) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _showHiddenUsersSheet,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.visibility_off_rounded, color: Colors.white54, size: 16),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                            child: Center(
                              child: Text(
                                '${_hiddenUserIds.length}',
                                style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopAvatarRow(List<Map<String, dynamic>> matches, {bool compact = false}) {
    if (matches.isEmpty) return const SizedBox.shrink();
    return _CampfireAvatarCarousel(
      matches: matches,
      compact: compact,
      onTap: (match) => _showMatchDetail(match),
      onPageChanged: (index) {
        setState(() {
          _selectedMatchIndex = index;
        });
      },
    );
  }

  Widget _buildMatchCard(
      Map<String, dynamic> match,
      int index, {
        bool compact = false,
      }) {
    final profile = match['profile'] as Map<String, dynamic>;
    final similarity = (match['similarity'] as double);
    final percent = (similarity * 100).toInt();
    final avatarUrl = profile['avatar_url']?.toString();
    final fullName = profile['full_name'] ?? profile['username'] ?? AppL10n.user;
    final username = profile['username'] ?? '';
    final recentPosts = (match['recent_posts'] as List?)
        ?.map((p) => p as Map<String, dynamic>)
        .toList() ?? [];

    final Color scoreColor = percent < 50
        ? const Color(0xFFFFD54F)
        : percent < 80
        ? const Color(0xFFFF9800)
        : const Color(0xFFFF5252);

    final Widget chatBubble = GestureDetector(
      onTap: () => _openChat(context, profile),
      child: ScaleTransition(
        scale: _pulseAnimation,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 28),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 12,
                    height: 1.5,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(1)),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    width: 7,
                    height: 1.5,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(1)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
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
                      child: CircleAvatar(
                        radius: compact ? 21 : 24,
                        backgroundColor: AppColors.bgDark,
                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null
                            ? const Icon(Icons.person, color: Colors.white38, size: 20)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: compact ? 13 : 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '@$username',
                            style: GoogleFonts.poppins(
                              color: Colors.white38,
                              fontSize: compact ? 10 : 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (recentPosts.isNotEmpty) const SizedBox(width: 16),
                  ],
                ),
                if (recentPosts.isNotEmpty) ...[
                  SizedBox(height: compact ? 10 : 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildNewPostGrid(recentPosts, compact: compact),
                      Expanded(
                        child: Center(
                          child: chatBubble,
                        ),
                      ),
                    ],
                  ),
                ],
                SizedBox(height: compact ? 10 : 14),
              ],
            ),
          ),
          if (recentPosts.isEmpty) ...[
            const SizedBox(width: 12),
            chatBubble,
            const SizedBox(width: 16),
          ],
          _LavaScoreBar(
            percent: percent,
            scoreColor: scoreColor,
            compact: compact,
          ),
        ],
      ),
    );
  }

  Widget _buildDragonAction(Map<String, dynamic> match, {bool compact = false}) {
    return GestureDetector(
      onTap: () => _showMatchDetail(match),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          Padding(
            padding: EdgeInsets.only(left: compact ? 34 : 42),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                compact ? 14 : 16,
                compact ? 7 : 8,
                compact ? 10 : 12,
                compact ? 7 : 8,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF5252).withValues(alpha: 0.2),
                    const Color(0xFFD32F2F).withValues(alpha: 0.05),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                  bottomLeft: Radius.circular(4),
                ),
                border: Border.all(color: const Color(0xFFFF5252).withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5252).withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    FontAwesomeIcons.fire,
                    color: const Color(0xFFFF5252),
                    size: compact ? 10 : 11,
                  ),
                  SizedBox(width: compact ? 5 : 6),
                  Text(
                    AppL10n.currentLanguageCode == 'tr' ? 'Ateş ne diyor?' : 'What does the fire say?',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: compact ? 10 : 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: compact ? 5 : 6),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white54,
                    size: compact ? 9 : 10,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: -10,
            top: compact ? -18 : -24,
            bottom: compact ? -14 : -20,
            child: SizedBox(
              width: compact ? 56 : 70,
              height: compact ? 56 : 70,
              child: Lottie.asset(
                'assets/animations/dragon.json',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewPostGrid(List<Map<String, dynamic>> posts, {bool compact = false}) {
    if (posts.isEmpty) return const SizedBox.shrink();

    return Container(
      width: compact ? 190 : 220,
      height: compact ? 92 : 110,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _buildGridPostItem(posts[0]),
          ),
          if (posts.length > 1) ...[
            SizedBox(width: compact ? 3 : 4),
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  Expanded(child: _buildGridPostItem(posts[1])),
                  SizedBox(height: compact ? 3 : 4),
                  Expanded(
                    child: posts.length > 2
                        ? _buildGridPostItem(posts[2])
                        : Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildGridPostItem(Map<String, dynamic> post) {
    final imageUrls = (post['image_urls'] as List?)?.cast<String>() ?? [];
    final videoFrameUrls = (post['video_frame_urls'] as List?)?.cast<String>() ?? [];
    final videoUrl = post['video_url'] as String?;
    final albumImage = post['spotify_album_image'] as String?;
    final content = post['content'] as String? ?? '';

    final thumbnail = imageUrls.isNotEmpty
        ? imageUrls.first
        : videoFrameUrls.isNotEmpty
        ? videoFrameUrls.first
        : albumImage;

    final isVideo = videoUrl != null;
    final isSpotifyOnly = thumbnail == albumImage && imageUrls.isEmpty && videoFrameUrls.isEmpty && albumImage != null;
    final isTextOnly = thumbnail == null && content.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white.withValues(alpha: 0.04),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isTextOnly)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.2),
                      const Color(0xFF9D89D9).withValues(alpha: 0.1),
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(6),
                child: Center(
                  child: Text(
                    content,
                    style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 9,
                      height: 1.3,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else if (thumbnail != null)
              CachedNetworkImage(
                imageUrl: thumbnail,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.white.withValues(alpha: 0.04)),
                errorWidget: (context, url, error) => Container(color: Colors.white.withValues(alpha: 0.04)),
              )
            else
              Container(color: Colors.white.withValues(alpha: 0.04)),

            if (isVideo)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 12),
                ),
              ),
            if (isSpotifyOnly)
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(color: Color(0xFF1DB954), shape: BoxShape.circle),
                  child: const Icon(FontAwesomeIcons.spotify, color: Colors.white, size: 9),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openChat(BuildContext context, Map<String, dynamic> profile) async {
    final otherId = profile['id'] as String;
    try {
      final roomId = await _chatService.createOrGetChatRoom(otherId);
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              roomId: roomId,
              otherUser: profile,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Chat open error: $e');
    }
  }

  Future<void> _loadHiddenUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('hidden_match_ids') ?? [];
    if (mounted) setState(() => _hiddenUserIds = ids.toSet());
  }

  Future<void> _hideUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    _hiddenUserIds.add(userId);
    await prefs.setStringList('hidden_match_ids', _hiddenUserIds.toList());
    if (mounted) setState(() {});
  }

  Future<void> _unhideUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    _hiddenUserIds.remove(userId);
    await prefs.setStringList('hidden_match_ids', _hiddenUserIds.toList());
    if (mounted) setState(() {});
  }

  Future<void> _unhideAll() async {
    final prefs = await SharedPreferences.getInstance();
    _hiddenUserIds.clear();
    await prefs.remove('hidden_match_ids');
    if (mounted) setState(() {});
  }

  void _showHiddenUsersSheet() {
    final hiddenMatches = (_cachedMatches ?? []).where((m) {
      final uid = (m['profile'] as Map<String, dynamic>)['id'] as String?;
      return uid != null && _hiddenUserIds.contains(uid);
    }).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(Icons.visibility_off_rounded, color: Colors.white54, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      AppL10n.hiddenMatches,
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    if (hiddenMatches.isNotEmpty)
                      GestureDetector(
                        onTap: () async {
                          await _unhideAll();
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            AppL10n.showAll,
                            style: GoogleFonts.poppins(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (hiddenMatches.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      AppL10n.noHiddenMatches,
                      style: GoogleFonts.poppins(color: Colors.white38, fontSize: 14),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: hiddenMatches.length,
                      itemBuilder: (_, i) {
                        final match = hiddenMatches[i];
                        final profile = match['profile'] as Map<String, dynamic>;
                        final uid = profile['id'] as String;
                        final name = profile['full_name'] ?? profile['username'] ?? AppL10n.user;
                        final username = profile['username'] ?? '';
                        final avatarUrl = profile['avatar_url'] as String?;
                        final percent = ((match['similarity'] as double) * 100).toInt();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: AppColors.bgCard,
                                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                child: avatarUrl == null ? const Icon(Icons.person, color: Colors.white38, size: 20) : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                                    Text('@$username  ·  %$percent', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12)),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () async {
                                  await _unhideUser(uid);
                                  setSheetState(() => hiddenMatches.removeAt(i));
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    AppL10n.show,
                                    style: GoogleFonts.poppins(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showMatchDetail(Map<String, dynamic> match) async {
    final profile = match['profile'] as Map<String, dynamic>;
    final userId = profile['id'] as String;
    final similarity = (match['similarity'] as double);
    final percent = (similarity * 100).toInt();
    final avatarUrl = profile['avatar_url']?.toString();
    final fullName = profile['full_name'] ?? profile['username'] ?? AppL10n.user;
    final username = profile['username'] ?? '';

    final firstName = fullName.split(' ').first;

    final otherProfile = (match['profile_summary'] as String?) ?? '';
    final otherInterests = List<String>.from(match['interests'] ?? []);
    final matchReasons = List<String>.from(match['match_reasons'] ?? []);
    final matchReasonSources = (match['match_reason_sources'] as List?)
        ?.map((s) => s as Map<String, dynamic>)
        .toList() ?? [];

    final commonSpotify = match['common_spotify'] as Map<String, dynamic>?;
    final commonInterests = List<String>.from(match['common_interests'] ?? []);
    final commonInterestsLower = commonInterests.map((s) => s.toLowerCase().trim()).toSet();

    final Color scoreColor = const Color(0xFFF3BE7A);

    final Future<String> explanationFuture = _matchingService.getAiExplanation(
      otherUserId: userId,
      otherUserName: fullName,
      otherUserProfile: otherProfile,
      otherInterests: otherInterests,
      matchReasons: matchReasons,
    );

    final outerContext = context;
    bool isSheetDisposed = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (builderCtx) {
        bool isReasonsExpanded = false;
        List<bool> visibleReasons = List.generate(matchReasons.length, (i) => false);
        bool isInterestsExpanded = false;
        List<bool> visibleInterests = List.generate(otherInterests.length, (i) => false);

        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) => DraggableScrollableSheet(
            initialChildSize: 0.75,
            maxChildSize: 0.95,
            minChildSize: 0.6,
            builder: (sheetCtx, scrollController) => ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: _EtherealBackground(),
                      ),
                      ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                        children: [
                          Center(
                            child: Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Center(
                            child: Column(
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 130,
                                      height: 130,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [BoxShadow(color: scoreColor.withValues(alpha: 0.22), blurRadius: 36, spreadRadius: 4)],
                                      ),
                                    ),
                                    SizedBox(
                                      width: 118,
                                      height: 118,
                                      child: CircularProgressIndicator(
                                        value: similarity,
                                        strokeWidth: 3.5,
                                        backgroundColor: scoreColor.withValues(alpha: 0.12),
                                        valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                                        strokeCap: StrokeCap.round,
                                      ),
                                    ),
                                    Container(
                                      width: 102,
                                      height: 102,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: const Color(0xFF0F0C1A), width: 3),
                                      ),
                                      child: CircleAvatar(
                                        radius: 48,
                                        backgroundColor: const Color(0xFF1A1035),
                                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                        child: avatarUrl == null ? const Icon(Icons.person, color: Colors.white38, size: 44) : null,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Text(fullName, style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                                Text('@$username', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 13)),
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: scoreColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: scoreColor.withValues(alpha: 0.4), width: 1.2),
                                    boxShadow: [BoxShadow(color: scoreColor.withValues(alpha: 0.15), blurRadius: 12)],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(FontAwesomeIcons.wandMagicSparkles, color: scoreColor, size: 13),
                                      const SizedBox(width: 8),
                                      Text(AppL10n.compatibilityPercent(percent),
                                          style: GoogleFonts.poppins(color: scoreColor, fontSize: 16, fontWeight: FontWeight.w800)),
                                      const SizedBox(width: 8),
                                      Container(width: 1, height: 14, color: scoreColor.withValues(alpha: 0.3)),
                                      const SizedBox(width: 8),
                                      Text(
                                        similarity >= 0.75
                                            ? (AppL10n.currentLanguageCode == 'tr' ? 'Harika Uyum' : 'Great Match')
                                            : similarity >= 0.60
                                            ? (AppL10n.currentLanguageCode == 'tr' ? 'İyi Uyum' : 'Good Match')
                                            : (AppL10n.currentLanguageCode == 'tr' ? 'Uyumlu' : 'Compatible'),
                                        style: GoogleFonts.poppins(
                                            color: scoreColor.withValues(alpha: 0.75), fontSize: 12, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (matchReasons.isNotEmpty) ...[
                            const SizedBox(height: 28),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: GestureDetector(
                                  onTap: () {
                                    if (!isReasonsExpanded) {
                                      setSheetState(() => isReasonsExpanded = true);
                                      for (int i = 0; i < matchReasons.length; i++) {
                                        // GECİKME YAVAŞLATILDI: 100 + (i * 80) -> 300 + (i * 250)
                                        Future.delayed(Duration(milliseconds: 300 + (i * 250)), () {
                                          if (!isSheetDisposed) {
                                            setSheetState(() {
                                              visibleReasons[i] = true;
                                            });
                                          }
                                        });
                                      }
                                    } else {
                                      setSheetState(() {
                                        isReasonsExpanded = false;
                                        for (int i = 0; i < matchReasons.length; i++) {
                                          visibleReasons[i] = false;
                                        }
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.2),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.psychology_rounded, color: Color(0xFFF3BE7A), size: 20),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            AppL10n.currentLanguageCode == 'tr' ? 'Neden eşleştiniz?' : 'Why did you match?',
                                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(color: const Color(0xFFF3BE7A).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                                          child: Text('${matchReasons.length}', style: GoogleFonts.poppins(color: const Color(0xFFF3BE7A), fontSize: 11, fontWeight: FontWeight.w700)),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          isReasonsExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                          color: Colors.white70,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              alignment: Alignment.topCenter,
                              child: isReasonsExpanded
                                  ? Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: List.generate(matchReasons.length, (i) {
                                    final reason = matchReasons[i];
                                    final source = i < matchReasonSources.length ? matchReasonSources[i] : null;
                                    final myPosts = (source?['my_posts'] as List?)?.map((p) => p as Map<String, dynamic>).toList() ?? [];
                                    final otherPosts = (source?['other_posts'] as List?)?.map((p) => p as Map<String, dynamic>).toList() ?? [];
                                    final hasPosts = myPosts.isNotEmpty || otherPosts.isNotEmpty;
                                    final lower = reason.toLowerCase();
                                    final emoji = lower.contains('müzik') || lower.contains('music') || lower.contains('dinl') || lower.contains('listen')
                                        ? '🎵'
                                        : lower.contains('mekan') || lower.contains('environ') || lower.contains('doğa') || lower.contains('nature')
                                        ? '📍'
                                        : lower.contains('seyahat') || lower.contains('travel')
                                        ? '✈️'
                                        : lower.contains('sosyal') || lower.contains('social') || lower.contains('değer') || lower.contains('value')
                                        ? '🤝'
                                        : lower.contains('spor') || lower.contains('sport')
                                        ? '⚡'
                                        : lower.contains('yemek') || lower.contains('food')
                                        ? '🍽️'
                                        : '✨';

                                    return AnimatedScale(
                                      scale: visibleReasons[i] ? 1.0 : 0.8,
                                      // SÜRE YAVAŞLATILDI: 300 -> 800
                                      duration: const Duration(milliseconds: 800),
                                      curve: Curves.easeOutBack,
                                      child: AnimatedOpacity(
                                        opacity: visibleReasons[i] ? 1.0 : 0.0,
                                        // SÜRE YAVAŞLATILDI: 300 -> 800
                                        duration: const Duration(milliseconds: 800),
                                        child: Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: GestureDetector(
                                            onTap: () => Navigator.push(
                                              outerContext,
                                              MaterialPageRoute(
                                                builder: (_) => MatchEvidenceScreen(
                                                  reason: reason,
                                                  otherUserId: userId,
                                                  otherUserName: fullName,
                                                  otherUserAvatarUrl: avatarUrl,
                                                  myPosts: myPosts,
                                                  otherPosts: otherPosts,
                                                ),
                                              ),
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.04),
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                                              ),
                                              child: Row(
                                                children: [
                                                  Text(emoji, style: const TextStyle(fontSize: 16)),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Text(reason,
                                                        style: GoogleFonts.poppins(
                                                            color: Colors.white.withValues(alpha: 0.88), fontSize: 13, fontWeight: FontWeight.w500)),
                                                  ),
                                                  if (hasPosts) ...[
                                                    const SizedBox(width: 6),
                                                    Icon(Icons.chevron_right_rounded, size: 16, color: Colors.white.withValues(alpha: 0.25)),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                          if (commonSpotify != null) ...[
                            const SizedBox(height: 24),
                            Text(AppL10n.commonMusic, style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1DB954).withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: const Color(0xFF1DB954).withValues(alpha: 0.22)),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: commonSpotify['album_image'] != null
                                        ? Image.network(commonSpotify['album_image'] as String, width: 62, height: 62, fit: BoxFit.cover)
                                        : Container(
                                      width: 62,
                                      height: 62,
                                      decoration: BoxDecoration(
                                          color: const Color(0xFF1DB954).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                                      child: const Icon(FontAwesomeIcons.spotify, color: Color(0xFF1DB954), size: 24),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (commonSpotify['track_name'] != null)
                                          Text(
                                            commonSpotify['track_name'] as String,
                                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        Text(
                                          commonSpotify['artist'] as String,
                                          style: GoogleFonts.poppins(color: const Color(0xFF1DB954), fontSize: 12, fontWeight: FontWeight.w500),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.headphones_rounded, color: Colors.white30, size: 12),
                                            const SizedBox(width: 4),
                                            Text(AppL10n.bothListening, style: GoogleFonts.poppins(color: Colors.white30, fontSize: 10)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: const Color(0xFF1DB954).withValues(alpha: 0.12), shape: BoxShape.circle),
                                    child: const Icon(FontAwesomeIcons.spotify, color: Color(0xFF1DB954), size: 16),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3BE7A),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(FontAwesomeIcons.wandMagicSparkles, color: Colors.white, size: 12),
                              ),
                              const SizedBox(width: 10),
                              Text(AppL10n.aiAnalysis, style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          FutureBuilder<String>(
                            future: explanationFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(color: const Color(0xFFF3BE7A).withValues(alpha: 0.15), shape: BoxShape.circle),
                                        child: const Icon(FontAwesomeIcons.robot, color: Color(0xFFF3BE7A), size: 13),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(AppL10n.analyzing, style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13)),
                                      const SizedBox(width: 8),
                                      const _TypingDots(),
                                    ],
                                  ),
                                );
                              }

                              final explanation = snapshot.data ?? AppL10n.greatMatch;

                              return Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                ),
                                child: Text(
                                  explanation,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    fontSize: 14,
                                    height: 1.65,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 28),
                          if (otherInterests.isNotEmpty) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: GestureDetector(
                                  onTap: () {
                                    if (!isInterestsExpanded) {
                                      setSheetState(() => isInterestsExpanded = true);
                                      for (int i = 0; i < otherInterests.length; i++) {
                                        Future.delayed(Duration(milliseconds: 100 + (i * 80)), () {
                                          if (!isSheetDisposed) {
                                            setSheetState(() {
                                              visibleInterests[i] = true;
                                            });
                                          }
                                        });
                                      }
                                    } else {
                                      setSheetState(() {
                                        isInterestsExpanded = false;
                                        for (int i = 0; i < otherInterests.length; i++) {
                                          visibleInterests[i] = false;
                                        }
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.2),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.star_rounded, color: Color(0xFFF3BE7A), size: 20),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            AppL10n.currentLanguageCode == 'tr'
                                                ? '$firstName nelerle ilgilenir?'
                                                : 'What is $firstName interested in?',
                                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(color: const Color(0xFFF3BE7A).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                                          child: Text('${otherInterests.length}', style: GoogleFonts.poppins(color: const Color(0xFFF3BE7A), fontSize: 11, fontWeight: FontWeight.w700)),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          isInterestsExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                          color: Colors.white70,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              alignment: Alignment.topCenter,
                              child: isInterestsExpanded
                                  ? Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: List.generate(otherInterests.length, (index) {
                                    final interest = otherInterests[index];
                                    final isCommon = commonInterestsLower.contains(interest.toLowerCase().trim());
                                    final displayInterest = AppL10n.translateInterest(interest);
                                    return AnimatedScale(
                                      scale: visibleInterests[index] ? 1.0 : 0.8,
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeOutBack,
                                      child: AnimatedOpacity(
                                        opacity: visibleInterests[index] ? 1.0 : 0.0,
                                        duration: const Duration(milliseconds: 300),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                          decoration: BoxDecoration(
                                            color: isCommon ? const Color(0xFFF3BE7A).withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.06),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: isCommon ? const Color(0xFFF3BE7A).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.1),
                                              width: isCommon ? 1.5 : 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (isCommon) ...[
                                                const Icon(Icons.check_circle_rounded, color: Color(0xFFF3BE7A), size: 12),
                                                const SizedBox(width: 5),
                                              ],
                                              Text(
                                                displayInterest,
                                                style: GoogleFonts.poppins(
                                                  color: isCommon ? Colors.white : Colors.white.withValues(alpha: 0.6),
                                                  fontSize: 13,
                                                  fontWeight: isCommon ? FontWeight.w600 : FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              )
                                  : const SizedBox.shrink(),
                            ),
                            const SizedBox(height: 24),
                          ],
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.pop(sheetCtx);
                                    _openChat(outerContext, profile);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 15),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3BE7A),
                                      borderRadius: BorderRadius.circular(18),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFF3BE7A).withValues(alpha: 0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 16),
                                        const SizedBox(width: 8),
                                        Text(AppL10n.sendMessageAction,
                                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.pop(sheetCtx);
                                    Navigator.push(
                                      outerContext,
                                      MaterialPageRoute(
                                        builder: (_) => ProfileScreen(userId: userId, showBackButton: true),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 15),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.person_rounded, color: Colors.white70, size: 16),
                                        const SizedBox(width: 8),
                                        Text(AppL10n.goToProfile,
                                            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ).then((_) => isSheetDisposed = true);
  }

  String _localizedSummary(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final lang = AppL10n.currentLanguageCode;
      return (map[lang] ?? map['tr'] ?? raw) as String;
    } catch (_) {
      return raw;
    }
  }

  Future<void> _loadMyProfile() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _myProfileLoading = false);
      return;
    }
    try {
      final profileFuture = Supabase.instance.client
          .from('user_profiles')
          .select('profile_summary, interests, social_style, analyzed_post_count')
          .eq('user_id', userId)
          .maybeSingle();

      final infoFuture = Supabase.instance.client
          .from('profiles')
          .select('full_name, username, avatar_url')
          .eq('id', userId)
          .maybeSingle();

      final spotifyFuture = _spotifyService.isConnected(userId);
      final appleFuture = Platform.isIOS ? _appleMusicService.isConnected() : Future.value(false);

      final results = await Future.wait<dynamic>([
        profileFuture,
        infoFuture,
        spotifyFuture,
        appleFuture,
      ]);

      if (mounted) {
        setState(() {
          _myProfile = results[0] as Map<String, dynamic>?;
          final info = results[1] as Map<String, dynamic>?;
          _myFullName = (info?['full_name'] ?? info?['username'] ?? '') as String;
          _myAvatarUrl = info?['avatar_url'] as String?;
          _spotifyConnected = results[2] as bool;
          _appleMusicConnected = results[3] as bool;
          _myProfileLoading = false;
        });

        final rawSummary = (_myProfile?['profile_summary'] as String?) ?? '';
        if (rawSummary.isNotEmpty && !rawSummary.trimLeft().startsWith('{')) {
          Supabase.instance.client.functions
              .invoke('analyze-user-profile', body: {'user_id': userId})
              .then((_) => _loadMyProfile())
              .ignore();
        }
      }
    } catch (e) {
      debugPrint('loadMyProfile error: $e');
      if (mounted) setState(() => _myProfileLoading = false);
    }
  }

  Future<void> _connectSpotify() async {
    if (_spotifySyncing) return;
    setState(() => _spotifySyncing = true);

    await _spotifyService.authenticate();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null && mounted) {
      final connected = await _spotifyService.isConnected(userId);
      setState(() {
        _spotifyConnected = connected;
        _spotifySyncing = false;
      });
    }
  }

  Future<void> _connectAppleMusic() async {
    if (_appleMusicSyncing) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _appleMusicSyncing = true);
    final success = await _appleMusicService.syncTopMusic(userId);
    if (mounted) {
      setState(() {
        if (success) _appleMusicConnected = true;
        _appleMusicSyncing = false;
      });
    }
  }

  void _handleOpenMyProfile() {
    if (_myProfileLoading || _myProfile == null) return;

    final summary = _localizedSummary(_myProfile!['profile_summary'] as String?);
    final interests = List<String>.from(_myProfile!['interests'] ?? []);
    final socialStyle = (_myProfile!['social_style'] as String?) ?? '';
    final postCount = (_myProfile!['analyzed_post_count'] as int?) ?? 0;
    final isTr = AppL10n.currentLanguageCode == 'tr';

    final styleLabel = {
      'yalnız': isTr ? 'Bağımsız' : 'Solo',
      'ikili': isTr ? 'İkili' : 'Paired',
      'sosyal': isTr ? 'Sosyal' : 'Social',
      'karma': isTr ? 'Karma' : 'Mixed',
    }[socialStyle];

    final styleIcon = {
      'yalnız': Icons.person_outline_rounded,
      'ikili': Icons.people_outline_rounded,
      'sosyal': Icons.groups_outlined,
      'karma': Icons.shuffle_rounded,
    }[socialStyle] ?? Icons.person_outline_rounded;

    final styleColor = {
      'yalnız': const Color(0xFF9D89D9),
      'ikili': const Color(0xFF64B5F6),
      'sosyal': const Color(0xFF69F0AE),
      'karma': AppColors.primary,
    }[socialStyle] ?? AppColors.primary;

    _showMyProfileSheet(
      summary: summary,
      interests: interests,
      socialStyle: socialStyle,
      postCount: postCount,
      styleLabel: styleLabel ?? '',
      styleIcon: styleIcon,
      styleColor: styleColor,
    );
  }

  void _showMyProfileSheet({
    required String summary,
    required List<String> interests,
    required String socialStyle,
    required int postCount,
    required String styleLabel,
    required IconData styleIcon,
    required Color styleColor,
  }) {
    final isTr = AppL10n.currentLanguageCode == 'tr';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollCtrl) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: _EtherealBackground(),
                  ),
                  ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF9D89D9)]),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(FontAwesomeIcons.wandMagicSparkles, color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isTr ? 'Senin AI Profili' : 'Your AI Profile',
                                style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '$postCount ${isTr ? 'gönderi analiz edildi' : 'posts analyzed'}',
                                style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (styleLabel.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: styleColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: styleColor.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: styleColor.withValues(alpha: 0.15), shape: BoxShape.circle),
                                child: Icon(styleIcon, color: styleColor, size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isTr ? 'Sosyal Stil' : 'Social Style',
                                      style: GoogleFonts.poppins(color: styleColor.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      styleLabel,
                                      style: GoogleFonts.poppins(color: styleColor, fontSize: 16, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (summary.isNotEmpty) ...[
                        Text(
                          isTr ? 'AI Analizi' : 'AI Analysis',
                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            summary,
                            style: GoogleFonts.poppins(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 14,
                              height: 1.6,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (interests.isNotEmpty) ...[
                        Text(
                          isTr ? 'İlgi Alanları' : 'Interests',
                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: interests.map((interest) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                              ),
                              child: Text(
                                AppL10n.translateInterest(interest),
                                style: GoogleFonts.poppins(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],
                      Text(
                        isTr ? 'Müzik Bağlantısı' : 'Music Connection',
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      _buildMusicCards(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMusicCards() {
    final isTr = AppL10n.currentLanguageCode == 'tr';
    return Row(
      children: [
        Expanded(
          child: _buildSingleMusicCard(
            icon: FontAwesomeIcons.spotify,
            label: 'Spotify',
            connected: _spotifyConnected,
            syncing: _spotifySyncing,
            color: const Color(0xFF1DB954),
            isTr: isTr,
            onTap: _spotifyConnected ? null : (_spotifySyncing ? null : _connectSpotify),
          ),
        ),
        if (Platform.isIOS) ...[
          const SizedBox(width: 8),
          Expanded(
            child: _buildSingleMusicCard(
              icon: FontAwesomeIcons.apple,
              label: 'Apple Music',
              connected: _appleMusicConnected,
              syncing: _appleMusicSyncing,
              color: const Color(0xFFFC3C44),
              isTr: isTr,
              onTap: _appleMusicConnected ? null : (_appleMusicSyncing ? null : _connectAppleMusic),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSingleMusicCard({
    required IconData icon,
    required String label,
    required bool connected,
    required bool syncing,
    required Color color,
    required bool isTr,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: connected ? color.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: connected ? color.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.08),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: connected ? color.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: syncing
                  ? SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
              )
                  : Icon(icon, color: connected ? color : Colors.white38, size: 15),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(color: connected ? color : Colors.white60, fontSize: 11.5, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    syncing
                        ? (isTr ? 'Bağlanıyor...' : 'Connecting...')
                        : connected
                        ? (isTr ? 'Bağlı ✓' : 'Connected ✓')
                        : (isTr ? 'Bağla' : 'Connect'),
                    style: GoogleFonts.poppins(
                      color: connected ? color.withValues(alpha: 0.65) : Colors.white30,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            if (!connected && !syncing)
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withValues(alpha: 0.18), size: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              color: Colors.orange,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Ruh ikizlerini arıyoruz...',
            style: GoogleFonts.poppins(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsufficientPostsState() {
    final remaining = _minPostsRequired - _myPostCount;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
            Text(
              AppL10n.toFindSoulTwin,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppL10n.aiNeedsPostsDescription(_minPostsRequired),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white54,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
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
                        AppL10n.postsProgress(_myPostCount, _minPostsRequired),
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        AppL10n.moreNeeded(remaining),
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
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreatePostScreen()),
              ).then((_) => _checkMyPostCountThenQuiz()),
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
                      AppL10n.sharePost,
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
              child: const Icon(FontAwesomeIcons.wandMagicSparkles, size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Text(
              AppL10n.noMatchesYet,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              AppL10n.noMatchesSubtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

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
              AppL10n.connectionError,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              AppL10n.matchesFailedToLoad,
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
                  AppL10n.tryAgain,
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// HELPER CLASSES & WIDGETS
// ==========================================

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          if (mounted) setState(() => _step = (_step + 1) % 4);
          _ctrl.reset();
          _ctrl.forward();
        }
      });
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dots = '.' * _step;
    return Text(
      dots.isEmpty ? '   ' : dots.padRight(3),
      style: GoogleFonts.poppins(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
      ),
    );
  }
}

class _CampfireAvatarCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> matches;
  final bool compact;
  final Function(Map<String, dynamic>) onTap;
  final Function(int) onPageChanged;

  const _CampfireAvatarCarousel({
    Key? key,
    required this.matches,
    this.compact = false,
    required this.onTap,
    required this.onPageChanged,
  }) : super(key: key);

  @override
  State<_CampfireAvatarCarousel> createState() => _CampfireAvatarCarouselState();
}

class _CampfireAvatarCarouselState extends State<_CampfireAvatarCarousel> {
  late PageController _pageController;
  final int _infiniteOffset = 10000;
  late int _basePage;

  int _currentIndex = 0;
  bool _isFlipped = false;
  bool _isFirstLoad = true;
  Timer? _flipToBackTimer;
  Timer? _flipToFrontTimer;

  @override
  void initState() {
    super.initState();
    _basePage = _normalizedBasePage(widget.matches.length);
    _pageController = PageController(
      viewportFraction: 0.35,
      initialPage: _basePage,
    );
    _currentIndex = 0;
    _startFlipSequence();
  }

  @override
  void didUpdateWidget(covariant _CampfireAvatarCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldFirstId = oldWidget.matches.isEmpty
        ? null
        : (oldWidget.matches.first['profile'] as Map<String, dynamic>)['id'];
    final newFirstId = widget.matches.isEmpty
        ? null
        : (widget.matches.first['profile'] as Map<String, dynamic>)['id'];
    if (oldWidget.matches.length != widget.matches.length || oldFirstId != newFirstId) {
      _basePage = _normalizedBasePage(widget.matches.length);
      _currentIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        _pageController.jumpToPage(_basePage);
      });
    }
  }

  int _normalizedBasePage(int length) {
    if (length <= 0) return _infiniteOffset;
    return _infiniteOffset - (_infiniteOffset % length);
  }

  void _startFlipSequence() {
    _flipToBackTimer?.cancel();
    _flipToFrontTimer?.cancel();
    _isFlipped = false;

    int delayMs = _isFirstLoad ? 3000 : 1700;
    _isFirstLoad = false;

    _flipToBackTimer = Timer(Duration(milliseconds: delayMs), () {
      if (mounted) {
        setState(() {
          _isFlipped = true;
        });

        _flipToFrontTimer = Timer(const Duration(milliseconds: 1700), () {
          if (mounted) {
            setState(() {
              _isFlipped = false;
            });
          }
        });
      }
    });
  }

  void _toggleFlip() {
    _flipToBackTimer?.cancel();
    _flipToFrontTimer?.cancel();
    if (mounted) {
      setState(() {
        _isFlipped = !_isFlipped;
      });
    }
  }

  void _focusMatch(int pageIndex, int realIndex) {
    if (!_pageController.hasClients || _currentIndex == realIndex) return;
    _pageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _flipToBackTimer?.cancel();
    _flipToFrontTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.matches.isEmpty) return const SizedBox.shrink();
    final carouselHeight = widget.compact ? 320.0 : 420.0;
    final flameSize = widget.compact ? 280.0 : 360.0;

    final arcWidth = widget.compact ? 115.0 : 140.0;

    final arcDepth = widget.compact ? 60.0 : 85.0;

    return SizedBox(
      height: carouselHeight,
      child: AnimatedBuilder(
        animation: _pageController,
        builder: (context, child) {
          double page = _basePage.toDouble();
          if (_pageController.hasClients) {
            page = _pageController.page ?? _basePage.toDouble();
          }

          List<Map<String, dynamic>> items = [];
          int currentIndex = page.round();

          for (int i = currentIndex - 3; i <= currentIndex + 3; i++) {
            int realIndex = i % widget.matches.length;
            if (realIndex < 0) {
              realIndex += widget.matches.length;
            }

            double diff = i - page;
            double angle = diff * (math.pi / 3.5);
            double translateX = math.sin(angle) * arcWidth;
            double translateZ = math.cos(angle);
            double translateY = (1 - translateZ) * arcDepth;
            double scale = math.max(0.4, 0.65 + (translateZ * 0.35));
            double opacity = math.max(0.0, 0.3 + (translateZ * 0.7));

            items.add({
              'absoluteIndex': i,
              'realIndex': realIndex,
              'scale': scale,
              'opacity': opacity,
              'translateX': translateX,
              'translateY': translateY,
              'translateZ': translateZ,
            });
          }

          items.sort((a, b) => (a['translateZ'] as double).compareTo(b['translateZ'] as double));

          List<Map<String, dynamic>> backItems = items.where((item) => item['translateZ'] < 0.5).toList();
          List<Map<String, dynamic>> frontItems = items.where((item) => item['translateZ'] >= 0.5).toList();

          return Stack(
            alignment: Alignment.center,
            children: [
              ...backItems.map((item) => _buildPositionedItem(item)),

              Positioned(
                top: widget.compact ? -30 : -40,
                child: IgnorePointer(
                  child: Lottie.asset(
                    'assets/animations/alevv.json',
                    width: flameSize,
                    height: flameSize,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              ...frontItems.map((item) => _buildPositionedItem(item)),

              Positioned.fill(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (int infiniteIndex) {
                    int realIndex = infiniteIndex % widget.matches.length;
                    if (realIndex < 0) realIndex += widget.matches.length;

                    if (_currentIndex != realIndex) {
                      setState(() {
                        _currentIndex = realIndex;
                        _isFlipped = false;
                      });
                      _startFlipSequence();
                    }

                    widget.onPageChanged(realIndex);
                  },
                  itemBuilder: (context, infiniteIndex) {
                    int realIndex = infiniteIndex % widget.matches.length;
                    if (realIndex < 0) realIndex += widget.matches.length;

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (_currentIndex == realIndex) {
                          _toggleFlip();
                        } else {
                          _focusMatch(infiniteIndex, realIndex);
                        }
                      },
                      child: Container(color: Colors.transparent),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPositionedItem(Map<String, dynamic> item) {
    int realIndex = item['realIndex'];
    int absoluteIndex = item['absoluteIndex'];
    double translateX = item['translateX'];
    double translateY = item['translateY'];
    double scale = item['scale'];
    double opacity = item['opacity'];

    return Align(
      key: ValueKey(absoluteIndex),
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: widget.compact ? 0 : 0),
        child: Transform.translate(
          offset: Offset(translateX, -translateY),
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.bottomCenter,
            child: Opacity(
              opacity: opacity,
              child: IgnorePointer(
                child: _buildCarouselItem(widget.matches[realIndex], realIndex),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCarouselItem(Map<String, dynamic> match, int realIndex) {
    final profile = match['profile'] as Map<String, dynamic>;
    final similarity = ((match['similarity'] as double) * 100).toInt();
    final avatarUrl = profile['avatar_url']?.toString();
    final fullName = profile['full_name'] ?? profile['username'] ?? '';

    bool isCenter = _currentIndex == realIndex;
    bool showFlip = isCenter && _isFlipped;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder(
          tween: Tween<double>(begin: 0, end: showFlip ? math.pi : 0),
          duration: const Duration(milliseconds: 500),
          builder: (context, double val, child) {
            bool isBack = val >= (math.pi / 2);
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(val),
              child: isBack
                  ? Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()..rotateY(math.pi),
                child: _buildFlipBack(similarity),
              )
                  : _buildFlipFront(avatarUrl),
            );
          },
        ),
        SizedBox(height: widget.compact ? 12 : 16),
        Text(
          fullName,
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: widget.compact ? 10 : 11,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildFlipFront(String? avatarUrl) {
    final avatarSize = widget.compact ? 58.0 : 68.0;
    return Container(
      padding: const EdgeInsets.all(1),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black,
      ),
      child: ClipOval(
        child: Container(
          width: avatarSize,
          height: avatarSize,
          color: const Color(0xFF0F0C1A),
          child: avatarUrl == null
              ? Icon(
            Icons.person,
            color: Colors.white38,
            size: widget.compact ? 24 : 30,
          )
              : CachedNetworkImage(
            imageUrl: avatarUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
            errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.red),
          ),
        ),
      ),
    );
  }

  Widget _buildFlipBack(int similarity) {
    final badgeSize = widget.compact ? 60.0 : 70.0;
    return Container(
      width: badgeSize,
      height: badgeSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.orange.withValues(alpha: 0.25),
        border: Border.all(color: Colors.orange, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        '%$similarity',
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: widget.compact ? 14 : 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _WarmAuroraBackground extends StatelessWidget {
  const _WarmAuroraBackground();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        Container(color: const Color(0xFF08040C)),
        Positioned(
          top: -size.height * 0.1,
          left: -size.width * 0.3,
          child: _buildAuroraBand(const Color(0xFFBF360C), size.width * 1.5, size.height * 0.4, math.pi / 6),
        ),
        Positioned(
          top: size.height * 0.3,
          right: -size.width * 0.4,
          child: _buildAuroraBand(const Color(0xFFFF7043), size.width * 1.5, size.height * 0.3, -math.pi / 8),
        ),
        Positioned(
          bottom: -size.height * 0.1,
          left: -size.width * 0.2,
          child: _buildAuroraBand(const Color(0xFFFFCA28), size.width * 1.5, size.height * 0.35, math.pi / 4),
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
            child: Container(color: Colors.black.withOpacity(0.55)),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(painter: _StarPainter()),
        ),
      ],
    );
  }

  Widget _buildAuroraBand(Color color, double w, double h, double angle) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(h / 2),
          color: color.withOpacity(0.5),
        ),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(42);
    final paint = Paint()..color = Colors.white;

    for (int i = 0; i < 150; i++) {
      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height;
      final radius = rand.nextDouble() * 1.2 + 0.2;
      final opacity = rand.nextDouble() * 0.7 + 0.1;

      paint.color = Colors.white.withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LavaScoreBar extends StatefulWidget {
  final int percent;
  final Color scoreColor;
  final bool compact;

  const _LavaScoreBar({
    required this.percent,
    required this.scoreColor,
    this.compact = false,
  });

  @override
  State<_LavaScoreBar> createState() => _LavaScoreBarState();
}

class _LavaScoreBarState extends State<_LavaScoreBar> with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barHeight = widget.compact ? 108.0 : 140.0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 24,
            height: barHeight,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepOrange.withValues(alpha: 0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: widget.percent / 100.0),
                duration: const Duration(milliseconds: 4000),
                curve: Curves.easeInOutCubic,
                builder: (context, fillValue, child) {
                  return AnimatedBuilder(
                    animation: _waveController,
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          CustomPaint(
                            size: Size(24, barHeight),
                            painter: _LavaPainter(
                              fillPercent: fillValue,
                              animationValue: _waveController.value,
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '%${widget.percent}',
          style: GoogleFonts.poppins(
            color: widget.scoreColor,
            fontSize: widget.compact ? 12 : 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _LavaPainter extends CustomPainter {
  final double fillPercent;
  final double animationValue;

  _LavaPainter({
    required this.fillPercent,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (fillPercent == 0) return;

    canvas.clipRect(Rect.fromLTRB(0, 0, size.width, size.height));

    final fillHeight = size.height * fillPercent;
    final topY = size.height - fillHeight;

    final gradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFFFFEA00),
        Color(0xFFFF5722),
        Color(0xFFBF360C),
      ],
      stops: [0.0, 0.4, 1.0],
    ).createShader(Rect.fromLTRB(0, topY, size.width, size.height));

    final wavePhase = animationValue * 2 * math.pi;
    const waveAmplitude = 4.0;

    Path buildWavePath(double amplitude, double phaseShift, double yOffset) {
      final path = Path();
      path.moveTo(0, size.height);
      path.lineTo(0, yOffset);
      for (double x = 0; x <= size.width; x++) {
        double y = yOffset + math.sin((x / size.width * 2 * math.pi) + wavePhase + phaseShift) * amplitude;
        path.lineTo(x, y);
      }
      path.lineTo(size.width, size.height);
      path.close();
      return path;
    }

    final backWavePaint = Paint()
      ..color = const Color(0xFFE64A19).withOpacity(0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawPath(buildWavePath(waveAmplitude * 1.2, 0, topY), backWavePaint);

    final midWavePaint = Paint()..color = const Color(0xFFFF5722).withOpacity(0.8);
    canvas.drawPath(buildWavePath(waveAmplitude * 0.9, math.pi / 1.5, topY + 2), midWavePaint);

    final frontWavePaint = Paint()
      ..shader = gradient
      ..maskFilter = const MaskFilter.blur(BlurStyle.inner, 1);
    canvas.drawPath(buildWavePath(waveAmplitude * 0.7, math.pi, topY + 4), frontWavePaint);

    final rand = math.Random(42);
    final bubblePaint = Paint()..color = Colors.yellowAccent.withOpacity(0.4);

    for (int i = 0; i < 10; i++) {
      double startX = rand.nextDouble() * size.width;
      double speedOffset = rand.nextDouble() * 0.5 + 0.5;
      double sizeOffset = rand.nextDouble() * 2 + 1;
      double timeOffset = rand.nextDouble();

      double t = (animationValue * speedOffset + timeOffset) % 1.0;
      double y = size.height - (t * fillHeight);

      if (y > topY + waveAmplitude) {
        canvas.drawCircle(Offset(startX, y), sizeOffset, bubblePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LavaPainter oldDelegate) {
    return oldDelegate.fillPercent != fillPercent || oldDelegate.animationValue != animationValue;
  }
}

// ==========================================
// ETHEREAL BACKGROUND WIDGETS
// ==========================================

class _EtherealBackground extends StatefulWidget {
  const _EtherealBackground();

  @override
  State<_EtherealBackground> createState() => _EtherealBackgroundState();
}

class _EtherealBackgroundState extends State<_EtherealBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _EtherealPainter(_controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _EtherealPainter extends CustomPainter {
  final double progress;

  _EtherealPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = const Color(0xFF0C0814));

    void drawBlob(Color color, double xOffset, double yOffset, double radius) {
      final paint = Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);
      canvas.drawCircle(Offset(size.width * xOffset, size.height * yOffset), radius, paint);
    }

    final t = progress * 2 * math.pi;

    drawBlob(const Color(0xFF6E1A37).withOpacity(0.35), 0.5 + 0.3 * math.sin(t), 0.3 + 0.2 * math.cos(t * 0.8), size.width * 0.6);
    drawBlob(const Color(0xFFF3BE7A).withOpacity(0.25), 0.2 + 0.4 * math.cos(t * 1.2), 0.7 + 0.2 * math.sin(t * 1.1), size.width * 0.5);
    drawBlob(const Color(0xFFFEFDDF).withOpacity(0.15), 0.8 + 0.2 * math.sin(t * 0.9), 0.8 + 0.2 * math.cos(t * 1.3), size.width * 0.4);
  }

  @override
  bool shouldRepaint(covariant _EtherealPainter oldDelegate) => oldDelegate.progress != progress;
}