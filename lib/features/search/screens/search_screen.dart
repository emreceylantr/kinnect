import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 🔥 EKLENDİ: Kayıt için gerekli paket

// Importları kendi proje yapına göre kontrol et
import '../../../shared/widgets/fuel_button.dart';
import '../../../shared/widgets/image_carousel.dart';
import '../../../data/services/feed_service.dart';
import '../../../data/services/safety_service.dart';
import '../../profile/screens/profile_screen.dart';
import '../../post/screens/post_detail_screen.dart';
import '../../../shared/widgets/shimmer/post_card_shimmer.dart';
import '../../../shared/widgets/double_tap_overlay.dart';
import '../../../shared/widgets/kinnect_image.dart';
import '../../../core/theme/app_colors.dart';

// 🎨 TEMA RENKLERİ
Color kBgColor = AppColors.bgDark; // Derin Siyah
Color kCardColor = AppColors.bgCardExplore; // Kart Rengi
Color kAccentPurple = AppColors.primary; // Mistik Mor
Color kAccentOrange = AppColors.accentOrange; // Alev Turuncusu
Color kAmberGlow = AppColors.accentAmber; // Kor Rengi

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // --- DEĞİŞKENLER ---
  final SupabaseClient client = Supabase.instance.client;
  final FeedService feedService = FeedService();
  final SafetyService _safetyService = SafetyService();

  String myId = ''; // 🔧 Değiştirildi: late final yerine boş string ile başlat
  final TextEditingController searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool isExpanded = false;

  List<Map<String, dynamic>> searchResults = [];
  List<Map<String, dynamic>> explorePosts = [];
  bool loadingExplore = true;

  // 🔥 SLIDER AYARI
  final PageController _pageController = PageController(
    viewportFraction: 0.8,
    initialPage: 999, // 999 % 3 = 0, so Gündem #1 starts first
  );

  double _currentPage = 999.0;

  // 🎭 AVATAR AYARLARI
  final Map<String, String> avatarOptions = {
    'Guy': 'assets/animations/guy.json',
    'Girl': 'assets/animations/girl.json',
    'Robot': 'assets/animations/robot.json',
    'Cat': 'assets/animations/cat.json',
    'Mor': 'assets/animations/mor.json',
  };

  String selectedAvatarKey = 'Guy'; // Varsayılan seçim

  @override
  void initState() {
    super.initState();
    _loadAvatarPreference(); // 🔥 EKLENDİ: Uygulama açılınca kayıtlı karakteri yükle

    final user = client.auth.currentUser;
    myId = user?.id ?? ''; // 🔧 Null-safe: boş string fallback

    if (user != null) {
      _fetchExplore();
    }

    _pageController.addListener(() {
      if (mounted &&
          _pageController.hasClients &&
          _pageController.page != null) {
        setState(() {
          _currentPage = _pageController.page!;
        });
      }
    });

    _searchFocusNode.addListener(() {
      if (mounted) {
        setState(() {
          // Klavye açılıp kapanınca arayüz güncellensin
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // 🔥 EKLENDİ: Kayıtlı avatarı hafızadan okuyan fonksiyon
  Future<void> _loadAvatarPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Eğer daha önce seçilmediyse 'Guy' varsayılan olur
      selectedAvatarKey = prefs.getString('selected_avatar') ?? 'Guy';
    });
  }

  // 🔥 EKLENDİ: Seçilen avatarı hafızaya kaydeden fonksiyon
  Future<void> _saveAvatarPreference(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_avatar', key);
  }

  // --- AVATAR SEÇİCİ MENÜ ---
  void _showAvatarSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kBgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 280,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Text("Yoldaşını Seç",
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text("Keşfet ekranında sana eşlik edecek karakteri seç.",
                  style:
                      GoogleFonts.poppins(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: avatarOptions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    String key = avatarOptions.keys.elementAt(index);
                    String? path = avatarOptions.values.elementAt(index);
                    bool isSelected = key == selectedAvatarKey;

                    // 🔥 KARTLARDA YÖN AYARI:
                    // Girl hariç hepsi ters dönsün (true).
                    // Girl düz kalsın (false).
                    bool flipInCard = (key != 'Girl');

                    return GestureDetector(
                      onTap: () async {
                        // 🔥 GÜNCELLENDİ: Hem state'i güncelle hem hafızaya kaydet
                        setState(() {
                          selectedAvatarKey = key;
                        });
                        await _saveAvatarPreference(key); // Kaydetme işlemi
                        if (mounted) Navigator.pop(context);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 100,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? kAccentOrange.withValues(alpha: 0.2)
                              : kCardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: isSelected
                                  ? kAccentOrange
                                  : Colors.transparent,
                              width: 2),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 60,
                              child: Transform.flip(
                                // 🔥 KART ÖZELİ YÖNÜ BURADA UYGULUYORUZ
                                flipX: flipInCard,
                                child: Lottie.asset(path, fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.error,
                                      color: Colors.white24);
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- ARAMA VE VERİ ÇEKME ---
  Future<void> _performSearch(String text) async {
    if (text.trim().isEmpty) {
      setState(() => searchResults = []);
      return;
    }
    final blockedMeIds = await _safetyService.getIdsThatBlockedMe();
    blockedMeIds.add(myId);
    final res = await client
        .from("profiles")
        .select()
        .ilike("username", "%$text%")
        .not('id', 'in', blockedMeIds)
        .limit(15);
    if (mounted)
      setState(
          () => searchResults = List<Map<String, dynamic>>.from(res as List));
  }

  Future<void> _fetchExplore() async {
    if (explorePosts.isEmpty) setState(() => loadingExplore = true);
    try {
      final data = await feedService.getExploreFeed();
      data.sort((a, b) {
        final dateA = DateTime.tryParse(a['created_at']) ?? DateTime(2000);
        final dateB = DateTime.tryParse(b['created_at']) ?? DateTime(2000);
        return dateB.compareTo(dateA);
      });

      if (mounted)
        setState(() {
          explorePosts = data;
          loadingExplore = false;
        });
    } catch (e) {
      if (mounted) setState(() => loadingExplore = false);
    }
  }

  void _toggleFuel(int index, String postId) async {
    final int realIndex = explorePosts.indexWhere((p) => p['id'] == postId);
    if (realIndex == -1) return;
    final post = explorePosts[realIndex];
    final date = DateTime.tryParse(post["created_at"] ?? "")?.toLocal();
    final isAlive =
        date != null && DateTime.now().difference(date).inHours < 24;
    if (!isAlive) return;
    final likes = List<dynamic>.from(post["likes"] ?? []);
    final isFueled = likes.any((l) => l["user_id"] == myId);
    setState(() {
      if (isFueled)
        likes.removeWhere((l) => l["user_id"] == myId);
      else
        likes.add({"user_id": myId, "post_id": postId});
      explorePosts[realIndex] = {...post, "likes": likes};
    });
    await feedService.toggleLike(postId, isFuel: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
                child: isExpanded || searchController.text.isNotEmpty
                    ? _buildSearchList()
                    : _buildExploreFeed()),
          ],
        ),
      ),
    );
  }

  // --- HEADER ---
  Widget _buildHeader() {
    // 🔥 ÖZEL AYARLAR: Mor, Cat, Girl ve Robot
    double currentPadding = 0.0;
    double currentSize = 100.0; // Varsayılan boyut
    bool isFlipped = true; // Varsayılan yön (flipX: true)

    if (selectedAvatarKey == 'Mor') {
      currentPadding = 24.0; // Mor: 24px yukarı
      currentSize = 65.0; // Mor: küçük
    } else if (selectedAvatarKey == 'Cat') {
      currentPadding = 20.0; // Cat: 20px yukarı
      currentSize = 75.0; // Cat: 75 boyut
    } else if (selectedAvatarKey == 'Girl') {
      currentPadding = 25.0; // Girl: 25px yukarı
      currentSize = 75.0; // Girl: 75 boyut
      isFlipped = false; // Girl: Ters yön
    } else if (selectedAvatarKey == 'Robot') {
      currentPadding = 28.0; // 🔥 Robot: 28px yukarı
      currentSize = 68.0; // 🔥 Robot: 68 boyut
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      decoration: BoxDecoration(color: kBgColor, boxShadow: [
        BoxShadow(
            color: kAccentOrange.withValues(alpha: 0.05),
            blurRadius: 30,
            spreadRadius: 0,
            offset: const Offset(0, 10))
      ]),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // 1. KATMAN: Görünür İçerik (Başlık + Search Bar)
          Column(
            children: [
              Row(children: [
                Icon(FontAwesomeIcons.fire, color: kAccentOrange, size: 22),
                const SizedBox(width: 8),
                Text("Keşfet",
                    style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white))
              ]),
              const SizedBox(height: 20),
              _buildAnimatedSearchBar(),
              const SizedBox(height: 10), // Search bar alt boşluğu
            ],
          ),

          // 2. KATMAN: Lottie ve Geniş Tıklama Alanı
          Positioned(
            right: 15,
            bottom: 10,
            child: IgnorePointer(
              ignoring: isExpanded || searchController.text.isNotEmpty,
              child: GestureDetector(
                onTap: _showAvatarSelector,
                behavior: HitTestBehavior.opaque,
                child: Transform.flip(
                  flipX: isFlipped,
                  // 🔥 TIKLAMA KULESİ
                  child: Container(
                    height: 250, // Yüksek tıklama alanı
                    width: 100, // Genişlik
                    alignment: Alignment.bottomCenter, // Taban hizala

                    // 🔥 KONUMLANDIRMA: Dinamik Padding
                    child: Padding(
                      padding: EdgeInsets.only(bottom: currentPadding),
                      child: SizedBox(
                        // 🔥 BOYUTLANDIRMA: Dinamik Boyut
                        height: currentSize,
                        width: currentSize,
                        child: Lottie.asset(
                          avatarOptions[selectedAvatarKey]!,
                          fit: BoxFit.contain,
                          key: ValueKey(selectedAvatarKey),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedSearchBar() {
    final bool isFocused = _searchFocusNode.hasFocus;
    final bool hasText = searchController.text.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 36,
      decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isExpanded
                  ? kAccentOrange.withValues(alpha: 0.5)
                  : Colors.white10),
          boxShadow: isExpanded
              ? [
                  BoxShadow(
                      color: kAccentOrange.withValues(alpha: 0.15),
                      blurRadius: 15)
                ]
              : []),
      child: Row(children: [
        const SizedBox(width: 12),
        const Icon(Icons.search, color: Colors.white38, size: 18),
        const SizedBox(width: 10),
        Expanded(
            child: TextField(
                controller: searchController,
                focusNode: _searchFocusNode,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                textAlignVertical: TextAlignVertical.center,
                textAlign:
                    (isFocused || hasText) ? TextAlign.start : TextAlign.center,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: isFocused ? "" : "Kullanıcı ara...",
                  hintStyle:
                      GoogleFonts.poppins(color: Colors.white30, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.only(bottom: 4),
                ),
                onTap: () => setState(() => isExpanded = true),
                onChanged: _performSearch)),
        if (isExpanded || hasText)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                setState(() {
                  isExpanded = false;
                  searchController.clear();
                  searchResults = [];
                  FocusScope.of(context).unfocus();
                });
              },
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.close, color: Colors.white54, size: 18),
              ),
            ),
          )
        else
          const SizedBox(width: 40),
      ]),
    );
  }

  // --- ANA AKIŞ ---
  Widget _buildExploreFeed() {
    if (loadingExplore)
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        itemBuilder: (context, index) => const PostCardShimmer(),
      );
    if (explorePosts.isEmpty) return _buildEmptyState();

    final now = DateTime.now();
    List<Map<String, dynamic>> alivePosts = explorePosts.where((p) {
      final date = DateTime.tryParse(p['created_at'] ?? "")?.toLocal();
      if (date == null) return false;
      return now.difference(date).inHours < 24;
    }).toList();

    alivePosts.sort((a, b) =>
        (b['likes'] as List).length.compareTo((a['likes'] as List).length));

    final List<Map<String, dynamic>> sliderPosts = alivePosts.take(3).toList();
    final List<Map<String, dynamic>> listPosts = explorePosts;

    return RefreshIndicator(
      onRefresh: _fetchExplore,
      color: kAccentOrange,
      backgroundColor: kCardColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(children: [
          const SizedBox(height: 20),

          // GÜNDEM SLIDER'I
          if (sliderPosts.isNotEmpty) ...[
            _build3DTrendSlider(sliderPosts),
            const SizedBox(height: 20),
          ],

          // NORMAL LİSTE
          if (listPosts.isEmpty)
            _buildEmptyState()
          else
            ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: listPosts.length,
                itemBuilder: (_, i) => _buildPostCard(listPosts[i], i)),
        ]),
      ),
    );
  }

  Widget _build3DTrendSlider(List<Map<String, dynamic>> posts) {
    if (myId.isEmpty) {
      return const SizedBox();
    }
    if (posts.isEmpty) return const SizedBox();
    return SizedBox(
      height: 360,
      child: PageView.builder(
        controller: _pageController,
        itemBuilder: (context, index) {
          final int realIndex = index % posts.length;
          double value = (_currentPage - index);
          double scale = (1 - (value.abs() * 0.2)).clamp(0.85, 1.0);
          double opacity = (1 - (value.abs() * 0.5)).clamp(0.5, 1.0);
          double translateY = (1 - scale) * -40;
          return Transform.translate(
            offset: Offset(0, translateY),
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child:
                    _buildFeaturedCard(posts[realIndex], rank: realIndex + 1),
              ),
            ),
          );
        },
      ),
    );
  }

  // 🏆 VİTRİN KARTI
  Widget _buildFeaturedCard(Map<String, dynamic> post, {required int rank}) {
    final likes = post["likes"] as List? ?? [];
    final likeCount = likes.length;
    final profile = post["profiles"] ?? {};
    final content = post["content"] ?? "";
    final imageUrl = post["image_url"];

    final date = DateTime.tryParse(post["created_at"] ?? "")?.toLocal();
    final now = DateTime.now();
    final isAlive = date != null && now.difference(date).inHours < 24;
    final bool isRank1 = rank == 1;

    Color statusColor = Colors.grey;
    String statusText = "";
    IconData statusIcon = FontAwesomeIcons.wind;

    if (!isAlive) {
      statusColor = Colors.blueGrey;
      statusText = "KÜL OLDU";
    } else {
      if (likeCount > 10) {
        statusColor = Colors.redAccent;
        statusText = "CEHENNEM";
        statusIcon = FontAwesomeIcons.fire;
      } else if (likeCount > 5) {
        statusColor = kAccentOrange;
        statusText = "ALEVLİ";
        statusIcon = FontAwesomeIcons.fire;
      } else if (likeCount > 0) {
        statusColor = kAmberGlow;
        statusText = "ISINIYOR";
        statusIcon = FontAwesomeIcons.fireFlameSimple;
      }
    }

    Color headerBgColor =
        isRank1 ? kAccentOrange : AppColors.bgBlack.withValues(alpha: 0.6);

    return GestureDetector(
      onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      PostDetailScreen(post: post, isExploreMode: true)))
          .then((_) => _fetchExplore()),
      child: Container(
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: isAlive
                  ? statusColor.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.1),
              width: 1.2),
          boxShadow: [
            if (isAlive)
              BoxShadow(
                  color: statusColor.withValues(alpha: isRank1 ? 0.3 : 0.15),
                  blurRadius: isRank1 ? 30 : 20,
                  spreadRadius: 0),
            BoxShadow(
                color: AppColors.bgBlack.withValues(alpha: 0.6),
                blurRadius: 15,
                offset: const Offset(0, 8))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // 🔥 GÖRSEL KATMANI - Önbellekli ve Optimize
              if (imageUrl != null)
                Positioned.fill(
                  child: KinnectImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [kCardColor, kCardColor.withValues(alpha: 0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              if (imageUrl != null)
                Container(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                  Colors.transparent,
                  AppColors.bgBlack.withValues(alpha: 0.9)
                ], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                      color: headerBgColor,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(22))),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isRank1) ...[
                          const Icon(FontAwesomeIcons.crown,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 8)
                        ],
                        Text(isRank1 ? "GÜNDEM #1" : "GÜNDEM #$rank",
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                                letterSpacing: 1.0)),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 50,
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  mainAxisAlignment: imageUrl != null
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imageUrl == null) const SizedBox(height: 60),
                    Row(
                      children: [
                        KinnectImage(
                          imageUrl: profile["avatar_url"] ?? "",
                          width: isRank1 ? 40 : 32,
                          height: isRank1 ? 40 : 32,
                          isCircle: true,
                          useShimmer: false,
                          backgroundColor: Colors.white24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                              Text(profile["full_name"] ?? "Anonim",
                                  style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: imageUrl != null
                                          ? (isRank1 ? 14 : 12)
                                          : (isRank1 ? 16 : 14),
                                      fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              Text("@${profile["username"]}",
                                  style: GoogleFonts.poppins(
                                      color: Colors.white70,
                                      fontSize: imageUrl != null ? 11 : 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)
                            ])),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (content.isNotEmpty)
                      Text(content,
                          maxLines: imageUrl == null ? 6 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                              color: Colors.white.withValues(
                                  alpha: imageUrl != null ? 0.9 : 1.0),
                              fontWeight: imageUrl == null
                                  ? FontWeight.normal
                                  : FontWeight.w500,
                              fontSize: imageUrl == null ? 18 : 12,
                              shadows: imageUrl != null
                                  ? [
                                      Shadow(
                                          blurRadius: 2,
                                          color: AppColors.bgBlack,
                                          offset: Offset(0, 1))
                                    ]
                                  : [])),
                    if (imageUrl == null)
                      const Spacer()
                    else
                      const SizedBox(height: 12),
                    Row(children: [
                      Icon(FontAwesomeIcons.fire, color: statusColor, size: 16),
                      const SizedBox(width: 6),
                      Text("$likeCount Harlama",
                          style: GoogleFonts.poppins(
                              color: statusColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      if (statusText.isNotEmpty) ...[
                        Icon(statusIcon,
                            color: statusColor.withValues(alpha: 0.8),
                            size: 12),
                        const SizedBox(width: 4),
                        Text(statusText,
                            style: GoogleFonts.poppins(
                                color: statusColor.withValues(alpha: 0.8),
                                fontSize: 11,
                                fontWeight: FontWeight.w500))
                      ]
                    ])
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 📝 NORMAL LİSTE KARTI
  Widget _buildPostCard(Map<String, dynamic> post, int index) {
    final profile = post["profiles"] ?? {};
    final likes = post["likes"] as List? ?? [];
    final comments = post["comments"] as List? ?? [];
    final likeCount = likes.length;
    final isFueled = likes.any((l) => l["user_id"] == myId);
    final date = DateTime.tryParse(post["created_at"] ?? "")?.toLocal();
    final now = DateTime.now();
    final isAlive = date != null && now.difference(date).inHours < 24;

    Color statusColor = Colors.grey;
    String statusText = "";
    IconData statusIcon = FontAwesomeIcons.wind;

    if (!isAlive) {
      statusText = "KÜL OLDU";
      statusColor = Colors.blueGrey;
    } else {
      if (likeCount > 10) {
        statusText = "CEHENNEM";
        statusColor = Colors.redAccent;
        statusIcon = FontAwesomeIcons.fire;
      } else if (likeCount > 5) {
        statusText = "ALEVLİ";
        statusColor = kAccentOrange;
        statusIcon = FontAwesomeIcons.fire;
      } else if (likeCount > 0) {
        statusText = "ISINIYOR";
        statusColor = kAmberGlow;
        statusIcon = FontAwesomeIcons.fireFlameSimple;
      }
    }

    return GestureDetector(
      onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      PostDetailScreen(post: post, isExploreMode: true)))
          .then((_) => _fetchExplore()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
            color: kCardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            boxShadow: [
              if (isAlive && likeCount > 0)
                BoxShadow(
                    color: statusColor.withValues(alpha: 0.15),
                    blurRadius: 20,
                    spreadRadius: 0,
                    offset: const Offset(0, 4))
            ]),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white10,
                  backgroundImage: profile["avatar_url"] != null
                      ? NetworkImage(profile["avatar_url"])
                      : null,
                  child: profile["avatar_url"] == null
                      ? const Icon(Icons.person, color: Colors.white54)
                      : null),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(profile["full_name"] ?? "Anonim",
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    Text("@${profile["username"]}",
                        style: GoogleFonts.poppins(
                            color: Colors.white38, fontSize: 12))
                  ])),
              if (statusText.isNotEmpty)
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: statusColor.withValues(alpha: 0.2))),
                    child: Row(children: [
                      Icon(statusIcon, color: statusColor, size: 10),
                      const SizedBox(width: 4),
                      Text(statusText,
                          style: GoogleFonts.poppins(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold))
                    ]))
            ]),
            const SizedBox(height: 12),
            if (post["content"] != null && post["content"].isNotEmpty)
              Text(post["content"],
                  style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      height: 1.5)),
            if (post["image_url"] != null ||
                (post["image_urls"] as List?)?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final List<String> imageUrls =
                      (post["image_urls"] as List?)?.cast<String>() ??
                          (post["image_url"] != null
                              ? [post["image_url"] as String]
                              : []);
                  return DoubleTapOverlay(
                    onDoubleTap: () => _toggleFuel(index, post["id"]),
                    icon: Icons.local_fire_department,
                    iconColor: kAccentOrange,
                    child: ImageCarousel(
                      imageUrls: imageUrls,
                      height: 380,
                      borderRadius: BorderRadius.circular(16),
                      postId: post["id"],
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FuelButton(
                  isFueled: isFueled,
                  count: likeCount,
                  isExpired: !isAlive,
                  onTap: () => _toggleFuel(index, post["id"]),
                  size: 28),
              Padding(
                  padding: EdgeInsets.only(left: 2, top: isAlive ? 32.0 : 38.0),
                  child: Text("$likeCount",
                      style: GoogleFonts.poppins(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15))),
              const Spacer(),
              Padding(
                  padding: EdgeInsets.only(top: isAlive ? 32.0 : 38.0),
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        const Icon(FontAwesomeIcons.comment,
                            size: 16, color: Colors.white38),
                        const SizedBox(width: 6),
                        Text("${comments.length}",
                            style: GoogleFonts.poppins(
                                color: Colors.white38, fontSize: 13))
                      ])))
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(FontAwesomeIcons.fireFlameCurved, size: 50, color: Colors.white10),
      const SizedBox(height: 16),
      Text("Henüz ateş yok.", style: GoogleFonts.poppins(color: Colors.white38))
    ]));
  }

  Widget _buildSearchList() {
    return ListView.builder(
        itemCount: searchResults.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (_, i) {
          final u = searchResults[i];
          return ListTile(
              leading: CircleAvatar(
                  backgroundImage: u["avatar_url"] != null
                      ? NetworkImage(u["avatar_url"])
                      : null,
                  child: u["avatar_url"] == null
                      ? const Icon(Icons.person)
                      : null),
              title: Text(u["username"],
                  style: GoogleFonts.poppins(color: Colors.white)),
              subtitle: Text(u["full_name"] ?? "",
                  style: GoogleFonts.poppins(color: Colors.white54)),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ProfileScreen(userId: u["id"]))));
        });
  }
}
