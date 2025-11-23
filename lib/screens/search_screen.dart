// lib/screens/search_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../services/feed_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final SupabaseClient _client = Supabase.instance.client;
  final FeedService _feedService = FeedService();

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  // Arama fonksiyonu (Kullanıcıları arar)
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final response = await _client
          .from('profiles')
          .select()
          .ilike('username', '%$query%') // Kullanıcı adında ara
          .limit(20);

      if (mounted) {
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(response as List);
        });
      }
    } catch (e) {
      debugPrint('Arama hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050505),
        elevation: 0,
        title: Container(
          height: 45,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Kullanıcı ara...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.white54),
                onPressed: () {
                  _searchController.clear();
                  _performSearch('');
                },
              )
                  : null,
            ),
            onChanged: (val) {
              _performSearch(val);
            },
          ),
        ),
      ),
      body: _searchController.text.isNotEmpty
          ? _buildSearchResults() // Arama yapılıyorsa sonuçları göster
          : _buildExploreContent(), // Arama yoksa Keşfet akışını göster
    );
  }

  // Arama Sonuçları Listesi
  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          'Kullanıcı bulunamadı.',
          style: GoogleFonts.poppins(color: Colors.white54),
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF6C63FF),
            backgroundImage: (user['avatar_url'] != null)
                ? NetworkImage(user['avatar_url'])
                : null,
            child: (user['avatar_url'] == null)
                ? Text((user['username'] as String)[0].toUpperCase())
                : null,
          ),
          title: Text(
            user['username'] ?? 'Bilinmiyor',
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            user['full_name'] ?? '',
            style: const TextStyle(color: Colors.white54),
          ),
          onTap: () {
            // Profil sayfasına gitme eklenebilir
          },
        );
      },
    );
  }

  // Keşfet İçeriği (HATA ALDIĞIN KISIM BURASIYDI - DÜZELTİLDİ)
  Widget _buildExploreContent() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      // BURADA StreamBuilder YERİNE FutureBuilder KULLANDIK
      future: _feedService.getExploreFeed(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Hata oluştu: ${snapshot.error}',
              style: const TextStyle(color: Colors.white54),
            ),
          );
        }

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(FontAwesomeIcons.compass,
                    size: 50, color: Colors.white24),
                const SizedBox(height: 16),
                Text(
                  'Keşfedilecek gönderi yok.',
                  style: GoogleFonts.poppins(color: Colors.white54),
                ),
              ],
            ),
          );
        }

        // Grid Görünümü (Instagram Keşfet Tarzı)
        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, // Yan yana 3 resim
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 1, // Kare resimler
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            final imageUrl = post['image_url'];

            if (imageUrl == null || imageUrl.toString().isEmpty) {
              return Container(color: Colors.grey[900]);
            }

            return GestureDetector(
              onTap: () => _showImageDialog(imageUrl),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey[900],
                  child: const Icon(Icons.error, color: Colors.white24),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: InteractiveViewer(
          child: Image.network(imageUrl),
        ),
      ),
    );
  }
}