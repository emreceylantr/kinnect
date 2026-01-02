// Kinnect - Takipçi listesi ekranı

import 'dart:ui'; // Buzlu cam efekti için gerekli
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_screen.dart';

class FollowListScreen extends StatefulWidget {
  final String userId;
  final String title;
  final String type; // 'followers' veya 'following'

  const FollowListScreen({
    super.key,
    required this.userId,
    required this.title,
    required this.type,
  });

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  final String _currentUserId = Supabase.instance.client.auth.currentUser!.id;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchList();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _allUsers.where((user) {
        final username = (user['username'] ?? '').toString().toLowerCase();
        final fullname = (user['full_name'] ?? '').toString().toLowerCase();
        return username.contains(query) || fullname.contains(query);
      }).toList();
    });
  }

  Future<void> _fetchList() async {
    try {
      final client = Supabase.instance.client;
      List<dynamic> response = [];

      if (widget.type == 'followers') {
        final friendships = await client
            .from('friendships')
            .select('user_id')
            .eq('friend_id', widget.userId)
            .eq('status', 'accepted');

        final ids = (friendships as List).map((e) => e['user_id']).toList();
        if (ids.isNotEmpty) {
          response = await client.from('profiles').select().inFilter('id', ids);
        }
      } else {
        final friendships = await client
            .from('friendships')
            .select('friend_id')
            .eq('user_id', widget.userId)
            .eq('status', 'accepted');

        final ids = (friendships as List).map((e) => e['friend_id']).toList();
        if (ids.isNotEmpty) {
          response = await client.from('profiles').select().inFilter('id', ids);
        }
      }

      if (mounted) {
        setState(() {
          _allUsers = List<Map<String, dynamic>>.from(response);
          _filteredUsers = _allUsers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeFollower(String targetUserId) async {
    try {
      await Supabase.instance.client
          .from('friendships')
          .delete()
          .eq('friend_id', _currentUserId)
          .eq('user_id', targetUserId);

      setState(() {
        _allUsers.removeWhere((u) => u['id'] == targetUserId);
        _onSearchChanged();
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Kişi çıkarıldı.')));
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _unfollowUser(String targetUserId) async {
    try {
      await Supabase.instance.client
          .from('friendships')
          .delete()
          .eq('user_id', _currentUserId)
          .eq('friend_id', targetUserId);

      setState(() {
        _allUsers.removeWhere((u) => u['id'] == targetUserId);
        _onSearchChanged();
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Takipten çıkıldı.')));
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  // --- ONAY EKRANI (Buzlu Cam & Çizgisel Butonlar) ---
  void _showRemoveDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF252525).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white10,
                    child: Icon(Icons.person_remove,
                        color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Emin misin?",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "@${user['username']} adlı kişiyi takipçilerinden çıkarmak üzeresin.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 24),

                  // BUTONLAR (Çizgisel ve Daha Küçük)
                  Row(
                    children: [
                      // --- VAZGEÇ (YEŞİL ÇİZGİLİ) ---
                      Expanded(
                        child: SizedBox(
                          height: 38, // Yükseklik küçültüldü
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                  color: Colors.greenAccent.shade400,
                                  width: 1.5 // Çerçeve kalınlığı
                                  ),
                              foregroundColor:
                                  Colors.greenAccent.shade400, // Yazı rengi
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              "Vazgeç",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 13, // Fontu da bir tık küçülttük
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // --- SİL (MAVİ ÇİZGİLİ) ---
                      Expanded(
                        child: SizedBox(
                          height: 38, // Yükseklik küçültüldü
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _removeFollower(user['id']);
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: Colors.blueAccent, width: 1.5),
                              foregroundColor: Colors.blueAccent, // Yazı rengi
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              "Sil",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwnList = widget.userId == _currentUserId;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: Colors.white),
        title: Text(
          widget.title,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.white.withValues(alpha: 0.1),
            height: 1.0,
          ),
        ),
      ),
      body: Column(
        children: [
          // --- SLIM SEARCH BAR ---
          if (!_isLoading && _allUsers.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: Colors.black,
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF262626),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                  cursorColor: const Color(0xFF6C63FF),
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Ara...',
                    hintStyle: GoogleFonts.poppins(
                        color: Colors.grey[500], fontSize: 14),
                    prefixIcon:
                        Icon(Icons.search, color: Colors.grey[500], size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),

          // --- USER LIST ---
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
                : _filteredUsers.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          final isMe = user['id'] == _currentUserId;
                          return _buildUserCard(user, isOwnList, isMe);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.type == 'followers'
                ? Icons.group_off_rounded
                : Icons.person_off_rounded,
            size: 50,
            color: Colors.white12,
          ),
          const SizedBox(height: 12),
          Text(
            _searchController.text.isNotEmpty ? 'Sonuç yok' : 'Liste boş',
            style: GoogleFonts.poppins(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, bool isOwnList, bool isMe) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ProfileScreen(userId: user['id'])));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        color: Colors.transparent,
        child: Row(
          children: [
            Hero(
              tag: 'avatar_${user['id']}',
              child: CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFF333333),
                backgroundImage: user['avatar_url'] != null
                    ? NetworkImage(user['avatar_url'])
                    : null,
                child: user['avatar_url'] == null
                    ? const Icon(Icons.person, color: Colors.white54, size: 28)
                    : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user['username'] ?? 'Kullanıcı',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (user['full_name'] != null)
                    Text(
                      user['full_name'],
                      style: GoogleFonts.poppins(
                        color: Colors.grey[500],
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (isOwnList && !isMe)
              SizedBox(
                height: 32,
                child: OutlinedButton(
                  onPressed: () {
                    if (widget.type == 'followers') {
                      _showRemoveDialog(user);
                    } else {
                      _unfollowUser(user['id']);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: widget.type == 'followers'
                            ? Colors.blueAccent.withValues(alpha: 0.5)
                            : Colors.grey.shade800,
                        width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: Text(
                    widget.type == 'followers' ? 'Sil' : 'Takipten Çık',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: widget.type == 'followers'
                          ? Colors.blueAccent
                          : Colors.white70,
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
