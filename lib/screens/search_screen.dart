import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../widgets/fuel_button.dart';
import '../services/feed_service.dart';
import 'profile_screen.dart';
import 'post_detail_screen.dart'; // Tek ve akıllı detay sayfası

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // --- DEĞİŞKENLER ---
  final SupabaseClient client = Supabase.instance.client;
  final FeedService feedService = FeedService();

  final String myId = Supabase.instance.client.auth.currentUser!.id;
  final TextEditingController searchController = TextEditingController();

  bool isExpanded = false; // Dynamic Island Arama Çubuğu durumu
  String selectedFilter = "Harlanan"; // Varsayılan filtre

  List<Map<String, dynamic>> searchResults = [];
  List<Map<String, dynamic>> explorePosts = [];
  bool loadingExplore = true;

  @override
  void initState() {
    super.initState();
    _fetchExplore();
  }

  // ---------------------------------------------------------
  // 1. ARAMA İŞLEMİ (KULLANICI ARA)
  // ---------------------------------------------------------
  Future<void> _performSearch(String text) async {
    if (text.trim().isEmpty) {
      setState(() => searchResults = []);
      return;
    }

    final res = await client
        .from("profiles")
        .select()
        .ilike("username", "%$text%")
        .limit(15);

    if (mounted) {
      setState(() {
        searchResults = List<Map<String, dynamic>>.from(res as List);
      });
    }
  }

  // ---------------------------------------------------------
  // 2. KEŞFET VERİLERİ (GÜNDEM VE 24 SAAT MANTIĞI)
  // ---------------------------------------------------------
  Future<void> _fetchExplore() async {
    // Sadece liste boşsa yükleniyor göster
    if (explorePosts.isEmpty) setState(() => loadingExplore = true);

    try {
      final data = await feedService.getExploreFeed();
      final now = DateTime.now();

      // --- SIRALAMA ALGORİTMASI ---
      if (selectedFilter == "Harlanan") {
        data.sort((a, b) {
          // Saat dilimi düzeltmesi (.toLocal)
          final dateA = DateTime.tryParse(a['created_at'])?.toLocal() ?? DateTime(2000);
          final dateB = DateTime.tryParse(b['created_at'])?.toLocal() ?? DateTime(2000);

          // 24 Saat Kontrolü: Post hala "Canlı" mı?
          final isAliveA = now.difference(dateA).inHours < 24;
          final isAliveB = now.difference(dateB).inHours < 24;

          // KURAL 1: Canlı olanlar her zaman ölülerden (kül olmuş) üsttedir.
          if (isAliveA && !isAliveB) return -1; // A üstte
          if (!isAliveA && isAliveB) return 1;  // B üstte

          // KURAL 2: İkisi de aynı durumdaysa, Odun sayısına göre sırala (Çoktan aza)
          int countA = (a['likes'] as List).length;
          int countB = (b['likes'] as List).length;
          return countB.compareTo(countA);
        });
      } else {
        // "Yeni" Filtresi: Sadece tarihe göre (En yeni en üstte)
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
  // 3. HARLAMA (OPTIMISTIC UPDATE)
  // ---------------------------------------------------------
  void _toggleFuel(int index, String postId) async {
    final post = explorePosts[index];

    // 24 Saat Kontrolü: Sönmüşse işlem yapma
    final date = DateTime.tryParse(post["created_at"] ?? "")?.toLocal();
    final isAlive = date != null && DateTime.now().difference(date).inHours < 24;

    // Eğer post ölüyse (kül olduysa) harlamaya izin verme
    if (!isAlive) return;

    final likes = List<dynamic>.from(post["likes"] ?? []);
    final isFueled = likes.any((l) => l["user_id"] == myId);

    // Ekranda anında güncelle (Sunucuyu bekleme)
    setState(() {
      if (isFueled) {
        likes.removeWhere((l) => l["user_id"] == myId);
      } else {
        likes.add({"user_id": myId, "post_id": postId});
      }
      explorePosts[index] = {...post, "likes": likes};
    });

    // 🔥 BURASI KRİTİK: isFuel: true gönderiyoruz ki bildirim "Harladı" gitsin
    await feedService.toggleLike(postId, isFuel: true);
  }

  // ---------------------------------------------------------
  // EKRAN YAPISI (UI)
  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // İÇERİK KATMANI
            Padding(
              padding: const EdgeInsets.only(top: 60), // Search bar boşluğu
              child: isExpanded || searchController.text.isNotEmpty
                  ? _buildSearchList()
                  : _buildExploreFeed(),
            ),

            // ÜST KATMAN (Dynamic Island Arama)
            _buildSearchBar(),
          ],
        ),
      ),
    );
  }

  // --- DYNAMIC ISLAND SEARCH BAR ---
  Widget _buildSearchBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: isExpanded ? MediaQuery.of(context).size.width - 32 : 150,
      height: 45,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.white70, size: 18),
          const SizedBox(width: 8),

          // Kapalıyken sadece "Ara" yazısı
          if (!isExpanded)
            GestureDetector(
              onTap: () => setState(() => isExpanded = true),
              child: Text(
                "Arkadaş Ara",
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
              ),
            )
          // Açıkken TextField
          else
            Expanded(
              child: TextField(
                controller: searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    hintText: "Kullanıcı ara...",
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.only(bottom: 2)),
                onChanged: _performSearch,
              ),
            ),

          if (isExpanded)
            GestureDetector(
              onTap: () {
                setState(() {
                  isExpanded = false;
                  searchController.clear();
                  searchResults = [];
                  FocusScope.of(context).unfocus();
                });
              },
              child: const Icon(Icons.close, color: Colors.white54, size: 20),
            ),
        ],
      ),
    );
  }

  // --- ARAMA LİSTESİ ---
  Widget _buildSearchList() {
    if (searchResults.isEmpty) {
      return const Center(
        child: Text("Sonuç yok", style: TextStyle(color: Colors.white54)),
      );
    }
    return ListView.builder(
      itemCount: searchResults.length,
      itemBuilder: (_, i) {
        final user = searchResults[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: user["avatar_url"] != null
                ? NetworkImage(user["avatar_url"])
                : null,
            backgroundColor: Colors.grey[900],
          ),
          title: Text(user["username"], style: const TextStyle(color: Colors.white)),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileScreen(userId: user["id"]),
              ),
            );
          },
        );
      },
    );
  }

  // --- KEŞFET AKIŞI (Filtreler + Liste) ---
  Widget _buildExploreFeed() {
    return Column(
      children: [
        const SizedBox(height: 5),

        // FİLTRELER (Yatay Kaydırma)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _buildChip("Harlanan"),
              const SizedBox(width: 10),
              _buildChip("Yeni"),
            ],
          ),
        ),

        const SizedBox(height: 10),

        Expanded(
          child: loadingExplore
              ? const Center(child: CircularProgressIndicator(color: Colors.orange))
              : ListView.builder(
            padding: const EdgeInsets.only(top: 5, bottom: 80),
            itemCount: explorePosts.length,
            itemBuilder: (_, i) => _buildExplorePostCard(explorePosts[i], i),
          ),
        )
      ],
    );
  }

  Widget _buildChip(String text) {
    final selected = selectedFilter == text;
    return GestureDetector(
      onTap: () {
        setState(() => selectedFilter = text);
        _fetchExplore();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            color: selected ? Colors.black : Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // --- KART TASARIMI ---
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

    if (!isAlive) {
      statusColor = Colors.blueGrey;
      statusText = "KÜL OLDU 💨";
    } else {
      if (likeCount > 9) {
        statusColor = Colors.redAccent;
        statusText = "CEHENNEM 🔥";
      } else if (likeCount > 3) {
        statusColor = Colors.orange;
        statusText = "ALEVLİ";
      } else if (likeCount > 0) {
        statusColor = Colors.amber;
      }
    }

    // GÜNDEM ROZETİ (#1)
    Widget? badge;
    if (selectedFilter == "Harlanan" && index == 0 && isAlive) {
      badge = Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.amber,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          "#1 GÜNDEM",
          style: GoogleFonts.poppins(
              color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10),
        ),
      );
    }

    return GestureDetector(
      // DETAYA GİT: "isExploreMode: true" İLE
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PostDetailScreen(
            post: post,
            isExploreMode: true, // Ateş modu aktif
          ),
        ),
      ).then((_) {
        // Geri dönünce listeyi yenile
        _fetchExplore();
      }),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PROFIL
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              leading: CircleAvatar(
                radius: 20,
                backgroundImage: profile["avatar_url"] != null
                    ? NetworkImage(profile["avatar_url"])
                    : null,
                backgroundColor: Colors.grey[900],
              ),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      profile["full_name"] ?? "İsimsiz",
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (badge != null) badge,
                ],
              ),
              subtitle: Text(
                "@${profile["username"]}",
                style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
              ),
            ),

            // YAZI
            if (content.isNotEmpty)
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Text(
                  content,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                ),
              ),

            // FOTO
            if (imageUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(imageUrl, width: double.infinity, fit: BoxFit.cover),
                ),
              ),

            // ALT BAR
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Row(
                children: [
                  // 🔥 ATEŞ BUTONU (isExpired parametresini düzgün alır)
                  FuelButton(
                    isFueled: isFueled,
                    count: likeCount,
                    isExpired: !isAlive,
                    onTap: () => _toggleFuel(index, post["id"]),
                    size: 30,
                  ),

                  const SizedBox(width: 12),

                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (likeCount > 0)
                          Text(
                            "$likeCount", // Sadece sayı
                            style: GoogleFonts.poppins(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                        if (statusText.isNotEmpty && likeCount > 0)
                          Text(
                            statusText,
                            style: GoogleFonts.poppins(
                                color: statusColor.withOpacity(0.7),
                                fontSize: 10),
                          ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  const Icon(FontAwesomeIcons.comment,
                      color: Colors.white70, size: 20),
                  const SizedBox(width: 6),
                  Text("$commentCount",
                      style:
                      GoogleFonts.poppins(color: Colors.white70, fontSize: 14))
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}