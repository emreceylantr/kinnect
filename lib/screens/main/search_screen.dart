import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../widgets/fuel_button.dart';
import '../../services/feed_service.dart';
import '../../services/safety_service.dart';
import 'profile_screen.dart';
import '../social/post_detail_screen.dart';

// 🎨 TEMA RENKLERİ
const Color kBgColor = Color(0xFF0A0A0F);
const Color kCardColor = Color(0xFF16161F);
const Color kAccentPurple = Color(0xFF6C63FF);
const Color kAccentOrange = Color(0xFFFF9800);

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // --- DEĞİŞKENLER (AYNEN KORUNDU) ---
  final SupabaseClient client = Supabase.instance.client;
  final FeedService feedService = FeedService();
  final SafetyService _safetyService = SafetyService();

  final String myId = Supabase.instance.client.auth.currentUser!.id;
  final TextEditingController searchController = TextEditingController();

  bool isExpanded = false;
  String selectedFilter = "Harlanan";

  List<Map<String, dynamic>> searchResults = [];
  List<Map<String, dynamic>> explorePosts = [];
  bool loadingExplore = true;

  @override
  void initState() {
    super.initState();
    _fetchExplore();
  }

  // ---------------------------------------------------------
  // 1. ARAMA İŞLEMİ (AYNEN KORUNDU)
  // ---------------------------------------------------------
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

    if (mounted) {
      setState(() {
        searchResults = List<Map<String, dynamic>>.from(res as List);
      });
    }
  }

  // ---------------------------------------------------------
  // 2. KEŞFET VERİLERİ (AYNEN KORUNDU)
  // ---------------------------------------------------------
  Future<void> _fetchExplore() async {
    if (explorePosts.isEmpty) setState(() => loadingExplore = true);

    try {
      final data = await feedService.getExploreFeed();
      final now = DateTime.now();

      if (selectedFilter == "Harlanan") {
        data.sort((a, b) {
          final dateA =
              DateTime.tryParse(a['created_at'])?.toLocal() ?? DateTime(2000);
          final dateB =
              DateTime.tryParse(b['created_at'])?.toLocal() ?? DateTime(2000);

          final isAliveA = now.difference(dateA).inHours < 24;
          final isAliveB = now.difference(dateB).inHours < 24;

          if (isAliveA && !isAliveB) return -1;
          if (!isAliveA && isAliveB) return 1;

          int countA = (a['likes'] as List).length;
          int countB = (b['likes'] as List).length;
          return countB.compareTo(countA);
        });
      } else {
        data.sort((a, b) => b['created_at'].compareTo(a['created_at']));
      }

      if (mounted) {
        setState(() {
          explorePosts = data;
          loadingExplore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => loadingExplore = false);
      debugPrint("Keşfet hatası: $e");
    }
  }

  // ---------------------------------------------------------
  // 3. HARLAMA (AYNEN KORUNDU)
  // ---------------------------------------------------------
  void _toggleFuel(int index, String postId) async {
    final post = explorePosts[index];

    final date = DateTime.tryParse(post["created_at"] ?? "")?.toLocal();
    final isAlive =
        date != null && DateTime.now().difference(date).inHours < 24;

    if (!isAlive) return;

    final likes = List<dynamic>.from(post["likes"] ?? []);
    final isFueled = likes.any((l) => l["user_id"] == myId);

    setState(() {
      if (isFueled) {
        likes.removeWhere((l) => l["user_id"] == myId);
      } else {
        likes.add({"user_id": myId, "post_id": postId});
      }
      explorePosts[index] = {...post, "likes": likes};
    });

    await feedService.toggleLike(postId, isFuel: true);
  }

  // ---------------------------------------------------------
  // EKRAN YAPISI (YENİ TASARIM)
  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      body: SafeArea(
        child: Column(
          children: [
            // 🔥 PREMIUM HEADER
            _buildHeader(),

            // İÇERİK
            Expanded(
              child: isExpanded || searchController.text.isNotEmpty
                  ? _buildSearchList()
                  : _buildExploreFeed(),
            ),
          ],
        ),
      ),
    );
  }

  // --- PREMIUM HEADER ---
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            kAccentOrange.withOpacity(0.15),
            kBgColor,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      kAccentOrange.withOpacity(0.3),
                      kAccentOrange.withOpacity(0.1)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(FontAwesomeIcons.fire,
                    color: kAccentOrange, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                "Keşfet",
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Arama Çubuğu
          _buildSearchBar(),
        ],
      ),
    );
  }

  // --- ARAMA ÇUBUĞU (YENİ TASARIM) ---
  Widget _buildSearchBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded ? kAccentPurple.withOpacity(0.5) : Colors.white10,
        ),
        boxShadow: isExpanded
            ? [
                BoxShadow(
                  color: kAccentPurple.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: isExpanded ? kAccentPurple : Colors.white38,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: searchController,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: "Kullanıcı ara...",
                hintStyle:
                    GoogleFonts.poppins(color: Colors.white30, fontSize: 15),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onTap: () => setState(() => isExpanded = true),
              onChanged: _performSearch,
            ),
          ),
          if (isExpanded || searchController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                setState(() {
                  isExpanded = false;
                  searchController.clear();
                  searchResults = [];
                  FocusScope.of(context).unfocus();
                });
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.close, color: Colors.white54, size: 16),
              ),
            ),
        ],
      ),
    );
  }

  // --- ARAMA LİSTESİ (YENİ TASARIM) ---
  Widget _buildSearchList() {
    if (searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(FontAwesomeIcons.magnifyingGlass,
                  size: 32, color: Colors.white24),
            ),
            const SizedBox(height: 16),
            Text(
              searchController.text.isEmpty
                  ? "Kullanıcı aramaya başla"
                  : "Sonuç bulunamadı",
              style: GoogleFonts.poppins(color: Colors.white38, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: searchResults.length,
      itemBuilder: (_, i) {
        final user = searchResults[i];
        return _buildUserCard(user, i);
      },
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ProfileScreen(userId: user["id"])),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kCardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [kAccentPurple, kAccentPurple.withOpacity(0.5)],
                  ),
                ),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: kCardColor,
                  backgroundImage: user["avatar_url"] != null
                      ? NetworkImage(user["avatar_url"])
                      : null,
                  child: user["avatar_url"] == null
                      ? const Icon(Icons.person,
                          color: Colors.white54, size: 24)
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user["full_name"] ?? user["username"] ?? "İsimsiz",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      "@${user["username"] ?? ""}",
                      style: GoogleFonts.poppins(
                          color: Colors.white38, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kAccentPurple.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_forward_ios,
                    size: 14, color: kAccentPurple),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- KEŞFET AKIŞI (YENİ TASARIM) ---
  Widget _buildExploreFeed() {
    return Column(
      children: [
        // FİLTRELER
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildChip("Harlanan", FontAwesomeIcons.fire),
              const SizedBox(width: 10),
              _buildChip("Yeni", FontAwesomeIcons.clock),
            ],
          ),
        ),

        const SizedBox(height: 12),

        Expanded(
          child: loadingExplore
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: kAccentOrange),
                      const SizedBox(height: 16),
                      Text(
                        "Keşfediliyor...",
                        style: GoogleFonts.poppins(color: Colors.white38),
                      ),
                    ],
                  ),
                )
              : explorePosts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(FontAwesomeIcons.fireFlameCurved,
                                size: 40, color: Colors.white24),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Henüz keşfedilecek post yok",
                            style: GoogleFonts.poppins(
                                color: Colors.white38, fontSize: 15),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchExplore,
                      color: kAccentOrange,
                      backgroundColor: kCardColor,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        itemCount: explorePosts.length,
                        itemBuilder: (_, i) =>
                            _buildExplorePostCard(explorePosts[i], i),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildChip(String text, IconData icon) {
    final selected = selectedFilter == text;
    return GestureDetector(
      onTap: () {
        setState(() => selectedFilter = text);
        _fetchExplore();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [kAccentOrange, kAccentOrange.withOpacity(0.7)],
                )
              : null,
          color: selected ? null : kCardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Colors.transparent : Colors.white10,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: kAccentOrange.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? Colors.white : Colors.white54,
            ),
            const SizedBox(width: 8),
            Text(
              text,
              style: GoogleFonts.poppins(
                color: selected ? Colors.white : Colors.white54,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- POST KARTI (YENİ TASARIM) ---
  Widget _buildExplorePostCard(Map<String, dynamic> post, int index) {
    final profile = post["profiles"] ?? {};
    final likes = post["likes"] as List? ?? [];
    final comments = post["comments"] as List? ?? [];

    final isFueled = likes.any((l) => l["user_id"] == myId);
    final likeCount = likes.length;
    final commentCount = comments.length;

    final content = post["content"] ?? "";
    final imageUrl = post["image_url"];

    // 24 SAAT KONTROLÜ
    final date = DateTime.tryParse(post["created_at"] ?? "")?.toLocal();
    final now = DateTime.now();
    final isAlive = date != null && now.difference(date).inHours < 24;

    // DURUM RENKLERİ VE METNİ
    Color statusColor = Colors.grey;
    String statusText = "";
    IconData? statusIcon;

    if (!isAlive) {
      statusColor = Colors.blueGrey;
      statusText = "KÜL OLDU";
      statusIcon = FontAwesomeIcons.wind;
    } else {
      if (likeCount > 9) {
        statusColor = Colors.redAccent;
        statusText = "CEHENNEM";
        statusIcon = FontAwesomeIcons.fire;
      } else if (likeCount > 3) {
        statusColor = kAccentOrange;
        statusText = "ALEVLİ";
        statusIcon = FontAwesomeIcons.fire;
      } else if (likeCount > 0) {
        statusColor = Colors.amber;
        statusText = "YANIYOR";
        statusIcon = FontAwesomeIcons.fire;
      }
    }

    // GÜNDEM ROZETİ
    final isTop = selectedFilter == "Harlanan" && index == 0 && isAlive;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + (index * 50)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PostDetailScreen(post: post, isExploreMode: true),
          ),
        ).then((_) => _fetchExplore()),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: kCardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isTop
                  ? kAccentOrange.withOpacity(0.5)
                  : Colors.white.withOpacity(0.05),
              width: isTop ? 1.5 : 1,
            ),
            boxShadow: isTop
                ? [
                    BoxShadow(
                      color: kAccentOrange.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ÜSTTE GÜNDEM ROZETİ
              if (isTop)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [kAccentOrange, kAccentOrange.withOpacity(0.7)],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(19),
                      topRight: Radius.circular(19),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(FontAwesomeIcons.crown,
                          size: 12, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        "#1 GÜNDEM",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),

              // PROFİL
              Padding(
                padding: EdgeInsets.fromLTRB(16, isTop ? 12 : 16, 16, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                ProfileScreen(userId: post['user_id'])),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: isAlive
                                ? [
                                    kAccentOrange,
                                    kAccentOrange.withOpacity(0.5)
                                  ]
                                : [
                                    Colors.blueGrey,
                                    Colors.blueGrey.withOpacity(0.5)
                                  ],
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: kCardColor,
                          backgroundImage: profile["avatar_url"] != null
                              ? NetworkImage(profile["avatar_url"])
                              : null,
                          child: profile["avatar_url"] == null
                              ? const Icon(Icons.person,
                                  color: Colors.white54, size: 20)
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile["full_name"] ?? "İsimsiz",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            "@${profile["username"]}",
                            style: GoogleFonts.poppins(
                                color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (statusText.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            if (statusIcon != null) ...[
                              Icon(statusIcon, size: 10, color: statusColor),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              statusText,
                              style: GoogleFonts.poppins(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // YAZI
              if (content.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    content,
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontSize: 14, height: 1.4),
                  ),
                ),

              // FOTO
              if (imageUrl != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      imageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 200,
                          color: Colors.white.withOpacity(0.05),
                          child: const Center(
                            child: CircularProgressIndicator(
                                color: kAccentOrange, strokeWidth: 2),
                          ),
                        );
                      },
                    ),
                  ),
                ),

              // ALT BAR
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // 🔥 ATEŞ BUTONU
                    FuelButton(
                      isFueled: isFueled,
                      count: likeCount,
                      isExpired: !isAlive,
                      onTap: () => _toggleFuel(index, post["id"]),
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    if (likeCount > 0)
                      Text(
                        "$likeCount",
                        style: GoogleFonts.poppins(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),

                    const Spacer(),

                    // YORUM
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(FontAwesomeIcons.comment,
                              color: Colors.white54, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            "$commentCount",
                            style: GoogleFonts.poppins(
                                color: Colors.white54, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
