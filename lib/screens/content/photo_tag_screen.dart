// Kinnect - Fotoğrafa Kişi Etiketleme Ekranı

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PhotoTagScreen extends StatefulWidget {
  final File imageFile;

  const PhotoTagScreen({super.key, required this.imageFile});

  @override
  State<PhotoTagScreen> createState() => _PhotoTagScreenState();
}

class _PhotoTagScreenState extends State<PhotoTagScreen> {
  final SupabaseClient client = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  // Etiketler listesi: {user: profile data, x: 0-1, y: 0-1}
  List<Map<String, dynamic>> tags = [];

  // Arama sonuçları
  List<Map<String, dynamic>> searchResults = [];
  bool isSearching = false;

  // Geçici tap pozisyonu (kullanıcı seçerken)
  Offset? pendingTagPosition;

  String get myId => client.auth.currentUser!.id;

  // Kullanıcı ara
  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() => searchResults = []);
      return;
    }

    setState(() => isSearching = true);

    try {
      final res = await client
          .from('profiles')
          .select('id, username, full_name, avatar_url')
          .ilike('username', '%$query%')
          .neq('id', myId)
          .limit(10);

      if (mounted) {
        setState(() {
          searchResults = List<Map<String, dynamic>>.from(res);
          isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isSearching = false);
    }
  }

  // Etiket ekle
  void _addTag(Map<String, dynamic> user) {
    if (pendingTagPosition == null) return;

    // Aynı kullanıcı zaten etiketli mi kontrol et
    if (tags.any((t) => t['user']['id'] == user['id'])) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user['username']} zaten etiketli!')),
      );
      return;
    }

    setState(() {
      tags.add({
        'user': user,
        'x': pendingTagPosition!.dx,
        'y': pendingTagPosition!.dy,
      });
      pendingTagPosition = null;
      searchResults = [];
      _searchController.clear();
    });
  }

  // Etiket kaldır
  void _removeTag(int index) {
    setState(() => tags.removeAt(index));
  }

  // Fotoğrafa dokunuldu
  void _onImageTap(TapDownDetails details, Size imageSize) {
    // Normalize pozisyon (0-1 arası)
    final x = details.localPosition.dx / imageSize.width;
    final y = details.localPosition.dy / imageSize.height;

    setState(() {
      pendingTagPosition = Offset(x.clamp(0.05, 0.95), y.clamp(0.05, 0.95));
    });

    // Arama sheet'i aç
    _showUserSearchSheet();
  }

  // Kullanıcı arama bottom sheet
  void _showUserSearchSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              height: 400,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Kişi Etiketle',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () {
                          setState(() => pendingTagPosition = null);
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Arama kutusu
                  TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: GoogleFonts.poppins(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Kullanıcı ara...',
                      hintStyle: GoogleFonts.poppins(color: Colors.white38),
                      prefixIcon:
                          const Icon(Icons.search, color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) async {
                      await _searchUsers(value);
                      setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 16),

                  // Sonuçlar
                  Expanded(
                    child: isSearching
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF6C63FF)),
                          )
                        : searchResults.isEmpty
                            ? Center(
                                child: Text(
                                  _searchController.text.isEmpty
                                      ? 'Aramaya başla'
                                      : 'Sonuç bulunamadı',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white38),
                                ),
                              )
                            : ListView.builder(
                                itemCount: searchResults.length,
                                itemBuilder: (context, index) {
                                  final user = searchResults[index];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundImage:
                                          user['avatar_url'] != null
                                              ? NetworkImage(user['avatar_url'])
                                              : null,
                                      backgroundColor: Colors.grey[800],
                                      child: user['avatar_url'] == null
                                          ? const Icon(Icons.person,
                                              color: Colors.white54)
                                          : null,
                                    ),
                                    title: Text(
                                      user['full_name'] ?? user['username'],
                                      style: GoogleFonts.poppins(
                                          color: Colors.white),
                                    ),
                                    subtitle: Text(
                                      '@${user['username']}',
                                      style: GoogleFonts.poppins(
                                          color: Colors.white54),
                                    ),
                                    onTap: () {
                                      _addTag(user);
                                      Navigator.pop(context);
                                    },
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).then((_) {
      // Sheet kapandığında pending position'ı temizle
      if (pendingTagPosition != null && tags.isEmpty) {
        setState(() => pendingTagPosition = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050505),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Kişileri Etiketle',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Tags listesini döndür
              Navigator.pop(context, tags);
            },
            child: Text(
              tags.isEmpty ? 'Atla' : 'Devam (${tags.length})',
              style: GoogleFonts.poppins(
                color: const Color(0xFF6C63FF),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Açıklama
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Fotoğrafa dokunarak kişileri etiketle',
              style: GoogleFonts.poppins(color: Colors.white54),
            ),
          ),

          // Fotoğraf ve etiketler
          Expanded(
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    onTapDown: (details) => _onImageTap(
                      details,
                      Size(constraints.maxWidth, constraints.maxHeight),
                    ),
                    child: Stack(
                      children: [
                        // Fotoğraf
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            widget.imageFile,
                            fit: BoxFit.contain,
                            width: constraints.maxWidth,
                          ),
                        ),

                        // Etiketler
                        ...tags.asMap().entries.map((entry) {
                          final index = entry.key;
                          final tag = entry.value;
                          final user = tag['user'];

                          return Positioned(
                            left: tag['x'] * constraints.maxWidth - 50,
                            top: tag['y'] * constraints.maxHeight - 15,
                            child: GestureDetector(
                              onTap: () => _removeTag(index),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFF6C63FF),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 10,
                                      backgroundImage:
                                          user['avatar_url'] != null
                                              ? NetworkImage(user['avatar_url'])
                                              : null,
                                      backgroundColor: Colors.grey[800],
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '@${user['username']}',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.close,
                                      color: Colors.white54,
                                      size: 14,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),

                        // Pending tag position göstergesi
                        if (pendingTagPosition != null)
                          Positioned(
                            left:
                                pendingTagPosition!.dx * constraints.maxWidth -
                                    10,
                            top:
                                pendingTagPosition!.dy * constraints.maxHeight -
                                    10,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C63FF),
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // Alt bilgi - Etiketli kişiler
          if (tags.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Etiketlenen (silmek için dokun):',
                    style: GoogleFonts.poppins(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tags.asMap().entries.map((entry) {
                      final index = entry.key;
                      final tag = entry.value;
                      final user = tag['user'];

                      return GestureDetector(
                        onTap: () => _removeTag(index),
                        child: Chip(
                          avatar: CircleAvatar(
                            backgroundImage: user['avatar_url'] != null
                                ? NetworkImage(user['avatar_url'])
                                : null,
                            backgroundColor: Colors.grey[800],
                          ),
                          label: Text(
                            '@${user['username']}',
                            style: GoogleFonts.poppins(color: Colors.white),
                          ),
                          backgroundColor: const Color(0xFF2A2A2A),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          deleteIconColor: Colors.white54,
                          onDeleted: () => _removeTag(index),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
