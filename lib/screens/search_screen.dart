import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../widgets/fuel_button.dart';
import '../services/feed_service.dart';
import 'profile_screen.dart';
import 'post_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final SupabaseClient client = Supabase.instance.client;
  final FeedService feedService = FeedService();

  final String myId = Supabase.instance.client.auth.currentUser!.id;
  final TextEditingController searchController = TextEditingController();

  bool isExpanded = false; // Dynamic Island durumu
  String selectedFilter = "Harlanan";

  List<Map<String, dynamic>> searchResults = [];
  List<Map<String, dynamic>> explorePosts = [];
  bool loadingExplore = true;

  @override
  void initState() {
    super.initState();
    _fetchExplore();
  }

  // *********************************************************
  // 🔍 ARAMA İŞLEMI
  // *********************************************************

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

    setState(() {
      searchResults = List<Map<String, dynamic>>.from(res as List);
    });
  }

  // *********************************************************
  // 🔥 KEŞFET (ATEŞ AKIŞI)
  // *********************************************************

  Future<void> _fetchExplore() async {
    setState(() => loadingExplore = true);

    final data = await feedService.getExploreFeed();

    // FİLTRELEME
    if (selectedFilter == "Harlanan") {
      data.sort((a, b) => (b['likes'] as List).length.compareTo((a['likes'] as List).length));
    } else {
      data.sort((a, b) => b['created_at'].compareTo(a['created_at']));
    }

    setState(() {
      explorePosts = data;
      loadingExplore = false;
    });
  }

  // *********************************************************
  // 🔥 OPTIMISTIC FUEL UPDATE
  // *********************************************************

  void _toggleFuel(int index, String postId) async {
    final post = explorePosts[index];
    final likes = List<dynamic>.from(post["likes"] ?? []);

    final isFueled = likes.any((l) => l["user_id"] == myId);

    if (isFueled) {
      likes.removeWhere((l) => l["user_id"] == myId);
    } else {
      likes.add({"user_id": myId, "post_id": postId});
    }

    setState(() {
      explorePosts[index] = {...post, "likes": likes};
    });

    await feedService.toggleLike(postId);
  }

  // *********************************************************
  // ✨ UI BAŞLANGICI
  // *********************************************************

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // ALTTAKİ BÜTÜN İÇERİK
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: isExpanded || searchController.text.isNotEmpty
                  ? _buildSearchList()
                  : _buildExploreFeed(),
            ),

            // ÜST DYNAMIC ISLAND SEARCH BAR
            _buildSearchBar(),
          ],
        ),
      ),
    );
  }

  // *********************************************************
  // 🟥 DYNAMIC ISLAND SEARCH BAR
  // *********************************************************

  Widget _buildSearchBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
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

          // KAPALI HAL
          if (!isExpanded)
            GestureDetector(
              onTap: () => setState(() => isExpanded = true),
              child: Text(
                "Ara",
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
              ),
            )

          // AÇIK HAL
          else
            Expanded(
              child: TextField(
                controller: searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    hintText: "Kullanıcı ara...",
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none),
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

  // *********************************************************
  // 🔍 ARAMA SONUÇLARI
  // *********************************************************

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
          title: Text(user["username"],
              style: const TextStyle(color: Colors.white)),
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

  // *********************************************************
  // 🔥 KEŞFET AKIŞI
  // *********************************************************

  Widget _buildExploreFeed() {
    return Column(
      children: [
        const SizedBox(height: 5),

        // FİLTRE
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
              ? const Center(
              child: CircularProgressIndicator(color: Colors.orange))
              : ListView.builder(
            padding: const EdgeInsets.only(top: 5, bottom: 80),
            itemCount: explorePosts.length,
            itemBuilder: (_, i) =>
                _buildExplorePostCard(explorePosts[i], i),
          ),
        )
      ],
    );
  }

  // *********************************************************
  // 🔥 FİLTRE CHIP
  // *********************************************************

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

  // *********************************************************
  // 🔥 HOME TARZI KART + FUEL BUTTON
  // *********************************************************

  Widget _buildExplorePostCard(Map<String, dynamic> post, int index) {
    final profile = post["profiles"] ?? {};
    final likes = post["likes"] as List? ?? [];
    final comments = post["comments"] as List? ?? [];

    final isFueled = likes.any((l) => l["user_id"] == myId);
    final likeCount = likes.length;
    final commentCount = comments.length;

    final content = post["content"] ?? "";
    final imageUrl = post["image_url"];

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PostDetailScreen(
            post: post,
            isExploreMode: true, // 🔥 BURASI ÖNEMLİ
          ),
        ),
      ),
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
            // PROFIL KISMI
            ListTile(
              leading: CircleAvatar(
                radius: 20,
                backgroundImage: profile["avatar_url"] != null
                    ? NetworkImage(profile["avatar_url"])
                    : null,
                backgroundColor: Colors.grey[900],
              ),
              title: Text(
                profile["full_name"] ?? "İsimsiz",
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.bold),
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
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(imageUrl),
              ),

            // ALT BAR
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Row(
                children: [
                  FuelButton(
                    isFueled: isFueled,
                    count: likeCount,
                    onTap: () => _toggleFuel(index, post["id"]),
                  ),

                  const SizedBox(width: 12),

                  Text(
                    "$likeCount Odun",
                    style: GoogleFonts.poppins(
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
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
