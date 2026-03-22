import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/language/app_l10n.dart';
import '../../post/screens/post_detail_screen.dart';

/// Bir eşleşme sebebinin kanıt postlarını gösteren ekran.
class MatchEvidenceScreen extends StatefulWidget {
  final String reason;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatarUrl;
  final List<Map<String, dynamic>> myPosts;
  final List<Map<String, dynamic>> otherPosts;

  const MatchEvidenceScreen({
    super.key,
    required this.reason,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatarUrl,
    required this.myPosts,
    required this.otherPosts,
  });

  @override
  State<MatchEvidenceScreen> createState() => _MatchEvidenceScreenState();
}

class _MatchEvidenceScreenState extends State<MatchEvidenceScreen> {
  final _client = Supabase.instance.client;

  List<Map<String, dynamic>> _myPosts = [];
  List<Map<String, dynamic>> _otherPosts = [];
  bool _loading = true;

  static const _postSelect =
      'id, image_urls, video_url, video_frame_urls, content, spotify_track_name, spotify_artist_name, spotify_album_image, location';

  @override
  void initState() {
    super.initState();
    if (widget.myPosts.isNotEmpty || widget.otherPosts.isNotEmpty) {
      _myPosts = widget.myPosts;
      _otherPosts = widget.otherPosts;
      _loading = false;
    } else {
      _fetchEvidencePosts();
    }
  }

  String get _myUserId => _client.auth.currentUser?.id ?? '';

  _ReasonType _detectReasonType() {
    final r = widget.reason.toLowerCase();
    if (r.contains('yorum')) return _ReasonType.comment;
    if (r.contains('harl')) return _ReasonType.like;
    if (r.contains('görünüyor') || r.contains('etiket')) return _ReasonType.mention;
    if (r.contains('dinliyorsunuz') || r.contains('sanatçı')) return _ReasonType.music;
    if (r.contains('ortam') || r.contains('benzer') && r.contains('fotoğraf')) return _ReasonType.scene;
    if (r.contains("'dan paylaşım") || r.contains('şehri paylaşıyor')) return _ReasonType.location;
    if (r.contains('ilginiz örtüşüyor')) return _ReasonType.interest;
    // social_style reasons
    if (r.contains('bağımsız') ||
        r.contains('yakın çevre') ||
        r.contains('kalabalık ortam') ||
        r.contains('sessiz anlara') ||
        r.contains('sosyal hem')) return _ReasonType.social;
    return _ReasonType.profile;
  }

  Future<void> _fetchEvidencePosts() async {
    if (_myUserId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      switch (_detectReasonType()) {
        case _ReasonType.comment:
          await _fetchCommentPosts();
        case _ReasonType.like:
          await _fetchLikePosts();
        case _ReasonType.mention:
          await _fetchMentionPosts();
        case _ReasonType.music:
          await _fetchMusicPosts();
        case _ReasonType.scene:
          await _fetchScenePosts();
        case _ReasonType.location:
          await _fetchLocationPosts();
        case _ReasonType.interest:
          await _fetchInterestPosts();
        case _ReasonType.social:
          await _fetchSocialPosts();
        case _ReasonType.profile:
          break;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  // ─── Comment ─────────────────────────────────────────────────────────────
  Future<void> _fetchCommentPosts() async {
    final myCommentedRes = await _client
        .from('comments')
        .select('post_id')
        .eq('user_id', widget.otherUserId);
    final likedMyIds =
        (myCommentedRes as List).map((r) => r['post_id'] as String).toSet().toList();

    final otherCommentedRes = await _client
        .from('comments')
        .select('post_id')
        .eq('user_id', _myUserId);
    final myCommentedIds =
        (otherCommentedRes as List).map((r) => r['post_id'] as String).toSet().toList();

    await Future.wait([
      _loadMyPostsByIds(likedMyIds),
      _loadOtherPostsByIds(myCommentedIds),
    ]);
  }

  // ─── Like ─────────────────────────────────────────────────────────────────
  Future<void> _fetchLikePosts() async {
    final myLikesRes = await _client
        .from('likes')
        .select('post_id')
        .eq('user_id', widget.otherUserId);
    final likedMyPostIds =
        (myLikesRes as List).map((r) => r['post_id'] as String).toSet().toList();

    final otherLikesRes = await _client
        .from('likes')
        .select('post_id')
        .eq('user_id', _myUserId);
    final myLikedOtherIds =
        (otherLikesRes as List).map((r) => r['post_id'] as String).toSet().toList();

    await Future.wait([
      _loadMyPostsByIds(likedMyPostIds),
      _loadOtherPostsByIds(myLikedOtherIds),
    ]);
  }

  // ─── Mention ──────────────────────────────────────────────────────────────
  Future<void> _fetchMentionPosts() async {
    final myProfile = await _client
        .from('profiles')
        .select('username')
        .eq('id', _myUserId)
        .maybeSingle();
    final otherProfile = await _client
        .from('profiles')
        .select('username')
        .eq('id', widget.otherUserId)
        .maybeSingle();

    final myUsername = myProfile?['username'] as String? ?? '';
    final otherUsername = otherProfile?['username'] as String? ?? '';

    final results = await Future.wait([
      if (otherUsername.isNotEmpty)
        _client
            .from('posts')
            .select(_postSelect)
            .eq('user_id', _myUserId)
            .contains('mentioned_usernames', [otherUsername])
            .limit(4)
      else
        Future.value(<dynamic>[]),
      if (myUsername.isNotEmpty)
        _client
            .from('posts')
            .select(_postSelect)
            .eq('user_id', widget.otherUserId)
            .contains('mentioned_usernames', [myUsername])
            .limit(4)
      else
        Future.value(<dynamic>[]),
    ]);

    _myPosts = List<Map<String, dynamic>>.from(results[0]);
    _otherPosts = List<Map<String, dynamic>>.from(results[1]);
  }

  // ─── Music ────────────────────────────────────────────────────────────────
  Future<void> _fetchMusicPosts() async {
    final match = RegExp(r'Her ikiniz de (.+?) dinliyorsunuz').firstMatch(widget.reason);
    final artist = match?.group(1);
    if (artist == null) return;

    final results = await Future.wait([
      _client
          .from('posts')
          .select(_postSelect)
          .eq('user_id', _myUserId)
          .ilike('spotify_artist_name', artist)
          .limit(4),
      _client
          .from('posts')
          .select(_postSelect)
          .eq('user_id', widget.otherUserId)
          .ilike('spotify_artist_name', artist)
          .limit(4),
    ]);

    _myPosts = (results[0] as List).cast<Map<String, dynamic>>();
    _otherPosts = (results[1] as List).cast<Map<String, dynamic>>();
  }

  // ─── Scene tags ───────────────────────────────────────────────────────────
  Future<void> _fetchScenePosts() async {
    final results = await Future.wait([
      _client
          .from('posts')
          .select('$_postSelect, photo_scene_tags')
          .eq('user_id', _myUserId)
          .not('photo_scene_tags', 'is', null)
          .limit(20),
      _client
          .from('posts')
          .select('$_postSelect, photo_scene_tags')
          .eq('user_id', widget.otherUserId)
          .not('photo_scene_tags', 'is', null)
          .limit(20),
    ]);

    final myAll = (results[0] as List).cast<Map<String, dynamic>>();
    final otherAll = (results[1] as List).cast<Map<String, dynamic>>();

    final myTags = myAll
        .expand((p) => (p['photo_scene_tags'] as List? ?? []).cast<String>())
        .map((t) => t.toLowerCase())
        .toSet();
    final otherTags = otherAll
        .expand((p) => (p['photo_scene_tags'] as List? ?? []).cast<String>())
        .map((t) => t.toLowerCase())
        .toSet();
    final commonTags = myTags.intersection(otherTags);

    _myPosts = myAll
        .where((p) => (p['photo_scene_tags'] as List? ?? [])
            .any((t) => commonTags.contains((t as String).toLowerCase())))
        .take(4)
        .toList();
    _otherPosts = otherAll
        .where((p) => (p['photo_scene_tags'] as List? ?? [])
            .any((t) => commonTags.contains((t as String).toLowerCase())))
        .take(4)
        .toList();
  }

  // ─── Location ─────────────────────────────────────────────────────────────
  Future<void> _fetchLocationPosts() async {
    final locMatch = RegExp(r"İkiniz de (.+?)'[dD]").firstMatch(widget.reason);
    final location = locMatch?.group(1);
    if (location == null) return;

    final results = await Future.wait([
      _client
          .from('posts')
          .select(_postSelect)
          .eq('user_id', _myUserId)
          .ilike('location', location)
          .limit(4),
      _client
          .from('posts')
          .select(_postSelect)
          .eq('user_id', widget.otherUserId)
          .ilike('location', location)
          .limit(4),
    ]);

    _myPosts = (results[0] as List).cast<Map<String, dynamic>>();
    _otherPosts = (results[1] as List).cast<Map<String, dynamic>>();
  }

  // ─── Interest: "X ilginiz örtüşüyor ✨" ─────────────────────────────────
  Future<void> _fetchInterestPosts() async {
    final interestMatch = RegExp(r'^(.+?) ilginiz').firstMatch(widget.reason);
    final interest = interestMatch?.group(1)?.trim().toLowerCase();
    if (interest == null) return;

    final keywords = _interestKeywords(interest);
    final isMusicInterest = ['müzik', 'music', 'şarkı', 'konser', 'festival', 'playlist', 'albüm']
        .any((k) => interest.contains(k));

    final results = await Future.wait([
      _fetchPostsByKeywords(_myUserId, keywords),
      _fetchPostsByKeywords(widget.otherUserId, keywords),
    ]);

    _myPosts = results[0];
    _otherPosts = results[1];

    // Müzik ilgisi için içerikte eşleşme yoksa Spotify postlarına bak
    if (isMusicInterest) {
      if (_myPosts.isEmpty) {
        final res = await _client
            .from('posts')
            .select(_postSelect)
            .eq('user_id', _myUserId)
            .not('spotify_track_name', 'is', null)
            .order('created_at', ascending: false)
            .limit(4);
        _myPosts = (res as List).cast<Map<String, dynamic>>();
      }
      if (_otherPosts.isEmpty) {
        final res = await _client
            .from('posts')
            .select(_postSelect)
            .eq('user_id', widget.otherUserId)
            .not('spotify_track_name', 'is', null)
            .order('created_at', ascending: false)
            .limit(4);
        _otherPosts = (res as List).cast<Map<String, dynamic>>();
      }
    }
  }

  // ─── Social style: recent posts ───────────────────────────────────────────
  Future<void> _fetchSocialPosts() async {
    final results = await Future.wait([
      _client
          .from('posts')
          .select(_postSelect)
          .eq('user_id', _myUserId)
          .order('created_at', ascending: false)
          .limit(4),
      _client
          .from('posts')
          .select(_postSelect)
          .eq('user_id', widget.otherUserId)
          .order('created_at', ascending: false)
          .limit(4),
    ]);

    _myPosts = (results[0] as List).cast<Map<String, dynamic>>();
    _otherPosts = (results[1] as List).cast<Map<String, dynamic>>();
  }

  // ─── Keyword arama yardımcısı ─────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> _fetchPostsByKeywords(
      String userId, List<String> keywords) async {
    // Her keyword için OR filtresi — content ILIKE ya da photo_scene_tags içeriyor
    if (keywords.isEmpty) {
      final res = await _client
          .from('posts')
          .select(_postSelect)
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(4);
      return (res as List).cast<Map<String, dynamic>>();
    }

    // Supabase .or() ile content içindeki keyword arama
    final orFilter = keywords
        .map((k) => 'content.ilike.%$k%')
        .join(',');

    final res = await _client
        .from('posts')
        .select(_postSelect)
        .eq('user_id', userId)
        .or(orFilter)
        .limit(4);

    return (res as List).cast<Map<String, dynamic>>();
  }

  // ─── İlgi alanı → anahtar kelimeler ─────────────────────────────────────
  List<String> _interestKeywords(String interest) {
    final map = {
      'seyahat': ['seyahat', 'tatil', 'gezi', 'yolculuk', 'keşif', 'uçak', 'otel'],
      'arkadaşlık': ['arkadaş', 'arkadaşlar', 'bff', 'dostlar', 'birlikte'],
      'müzik': ['müzik', 'konser', 'festival', 'şarkı', 'playlist', 'albüm'],
      'spor': ['spor', 'futbol', 'basketbol', 'voleybol', 'antrenman', 'gym', 'fitness'],
      'doğa': ['doğa', 'kamp', 'dağ', 'orman', 'yürüyüş', 'hiking', 'deniz'],
      'yemek': ['yemek', 'restoran', 'kafe', 'kahve', 'coffee', 'food', 'brunch'],
      'film': ['film', 'sinema', 'dizi', 'netflix', 'izliyorum'],
      'fotoğrafçılık': ['fotoğraf', 'photo', 'çekim', 'lens'],
      'kitap': ['kitap', 'okuma', 'roman', 'okuyor'],
      'sanat': ['sanat', 'sergi', 'galeri', 'müze', 'art'],
      'teknoloji': ['teknoloji', 'kod', 'yazılım', 'uygulama', 'tech'],
      'moda': ['moda', 'stil', 'kıyafet', 'outfit', 'fashion'],
      'oyun': ['oyun', 'gaming', 'valorant', 'cs2', 'pubg', 'lol'],
      'dans': ['dans', 'dance', 'koreografi'],
    };

    // Direkt eşleşme
    for (final entry in map.entries) {
      if (interest.contains(entry.key) || entry.key.contains(interest)) {
        return entry.value;
      }
    }

    // Eşleşme yoksa interest kelimesini direkt kullan
    return [interest];
  }

  // ─── Post ID listesinden benim postlarımı yükle ──────────────────────────
  Future<void> _loadMyPostsByIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final res = await _client
        .from('posts')
        .select(_postSelect)
        .eq('user_id', _myUserId)
        .inFilter('id', ids)
        .limit(4);
    _myPosts = (res as List).cast<Map<String, dynamic>>();
  }

  Future<void> _loadOtherPostsByIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final res = await _client
        .from('posts')
        .select(_postSelect)
        .eq('user_id', widget.otherUserId)
        .inFilter('id', ids)
        .limit(4);
    _otherPosts = (res as List).cast<Map<String, dynamic>>();
  }

  // ─── Post aç ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> _fetchFullPost(String postId) async {
    try {
      return await _client
          .from('posts')
          .select('*, profiles:user_id(id, username, full_name, avatar_url)')
          .eq('id', postId)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  void _openPost(Map<String, dynamic> postSummary) async {
    final postId = postSummary['id'] as String?;
    if (postId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    final fullPost = await _fetchFullPost(postId);
    if (!mounted) return;
    Navigator.pop(context);
    if (fullPost == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostDetailScreen(post: fullPost)),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
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
          AppL10n.analysisSource,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Sebep kartı ────────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.18),
                          const Color(0xFF9D89D9).withValues(alpha: 0.10),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
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

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Text(
                      AppL10n.analysisSourceDescription,
                      style: GoogleFonts.poppins(
                        color: Colors.white54,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),

                  if (_myPosts.isEmpty && _otherPosts.isEmpty) ...[
                    const SizedBox(height: 40),
                    _buildNoPosts(),
                  ] else ...[
                    if (_myPosts.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildSectionHeader(
                        icon: Icons.person_rounded,
                        label: AppL10n.myPosts,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 12),
                      _buildPostGrid(_myPosts),
                    ],
                    if (_otherPosts.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                        avatarUrl: widget.otherUserAvatarUrl,
                        label: AppL10n.otherUserPosts(widget.otherUserName),
                        color: const Color(0xFF9D89D9),
                      ),
                      const SizedBox(height: 12),
                      _buildPostGrid(_otherPosts),
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
              color: color.withValues(alpha: 0.15),
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
    final videoUrl = post['video_url'] as String?;
    final videoFrameUrls = (post['video_frame_urls'] as List?)?.cast<String>() ?? [];
    final albumImage = post['spotify_album_image'] as String?;
    final firstImage = imageUrls.isNotEmpty ? imageUrls.first : null;
    // Video thumbnail: frame > image
    final thumbnail = videoFrameUrls.isNotEmpty ? videoFrameUrls.first : firstImage;
    // Görsel için Spotify albüm kapağını fallback olarak kullan
    final displayImage = firstImage ?? albumImage;
    final content = post['content'] as String? ?? '';
    final artist = post['spotify_artist_name'] as String?;
    final trackName = post['spotify_track_name'] as String?;
    final location = post['location'] as String?;
    final isTextOnly = videoUrl == null && displayImage == null && content.isNotEmpty;

    return GestureDetector(
      onTap: () => _openPost(post),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // ── Görsel / Video / Yazı ──────────────────────────────
                    if (videoUrl != null)
                      _EvidenceVideoBackground(
                        videoUrl: videoUrl,
                        thumbnailUrl: thumbnail,
                      )
                    else if (isTextOnly)
                      // Yazı-only post: gradient arka plan + metin
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primary.withValues(alpha: 0.18),
                              const Color(0xFF9D89D9).withValues(alpha: 0.10),
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.format_quote_rounded,
                                color: AppColors.primary.withValues(alpha: 0.4), size: 20),
                            const SizedBox(height: 6),
                            Text(
                              content,
                              style: GoogleFonts.poppins(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 11,
                                height: 1.4,
                              ),
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else if (displayImage != null)
                      Image.network(
                        displayImage,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
                      )
                    else
                      _buildImagePlaceholder(),

                    // ── Video rozeti ───────────────────────────────────────
                    if (videoUrl != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow_rounded, color: Colors.white, size: 12),
                              SizedBox(width: 2),
                              Text('VIDEO',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),

                    // ── Spotify albüm rozeti (fotoğraf yoksa albüm image kullanıldı) ──
                    if (!isTextOnly && videoUrl == null && firstImage == null && albumImage != null)
                      Positioned(
                        top: 8, right: 8,
                        child: Container(
                          width: 18, height: 18,
                          decoration: const BoxDecoration(color: Color(0xFF1DB954), shape: BoxShape.circle),
                          child: const Icon(FontAwesomeIcons.spotify, color: Colors.white, size: 10),
                        ),
                      ),

                    // ── Alt gradient (görsel varsa) ────────────────────────
                    if (!isTextOnly)
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.6),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Alt bilgi ─────────────────────────────────────────────────
              if (!isTextOnly)
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (artist != null) ...[
                      Row(
                        children: [
                          const Icon(FontAwesomeIcons.spotify,
                              size: 11, color: Color(0xFF1DB954)),
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
      color: Colors.white.withValues(alpha: 0.04),
      child: const Center(
        child: Icon(Icons.image_rounded, color: Colors.white12, size: 32),
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
                color: AppColors.primary.withValues(alpha: 0.1),
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

// ─── Mute otomatik oynayan video widget ───────────────────────────────────────
class _EvidenceVideoBackground extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;

  const _EvidenceVideoBackground({required this.videoUrl, this.thumbnailUrl});

  @override
  State<_EvidenceVideoBackground> createState() => _EvidenceVideoBackgroundState();
}

class _EvidenceVideoBackgroundState extends State<_EvidenceVideoBackground> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await controller.initialize();
      controller.setLooping(true);
      controller.setVolume(0);
      await controller.play();
      if (mounted) setState(() => _controller = controller);
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      // Yüklenirken thumbnail veya siyah arka plan
      if (widget.thumbnailUrl != null) {
        return Image.network(widget.thumbnailUrl!, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: Colors.black));
      }
      return Container(color: Colors.black);
    }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: _controller!.value.size.width,
        height: _controller!.value.size.height,
        child: VideoPlayer(_controller!),
      ),
    );
  }
}

enum _ReasonType { comment, like, mention, music, scene, location, interest, social, profile }
