import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../services/feed_service.dart';
import '../services/chat_service.dart';
import 'messages_screen.dart';
import 'post_detail_screen.dart';
import 'follow_list_screen.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  final bool showBackButton;

  const ProfileScreen({
    super.key,
    required this.userId,
    this.showBackButton = true,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final String _currentUserId = Supabase.instance.client.auth.currentUser!.id;
  final ChatService _chatService = ChatService();

  // Veriler
  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _userPosts = [];

  // İstatistikler
  int _followersCount = 0;
  int _followingCount = 0;
  int _postCount = 0;

  bool _isLoading = true;

  // Takip Durumu
  String _friendshipStatus = 'none';

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // --- ÇIKIŞ YAP FONKSİYONU ---
  Future<void> _logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Çıkış yapılırken hata oluştu: $e')),
        );
      }
    }
  }

  // --- TÜM VERİLERİ YÜKLE ---
  Future<void> _loadAllData() async {
    try {
      await Future.wait([
        _fetchProfile(),
        _checkFollowStatus(),
        _fetchStats(),
      ]);
      await _fetchPosts();
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', widget.userId)
          .single();
      if (mounted) setState(() => _profileData = data);
    } catch (_) {}
  }

  Future<void> _fetchPosts() async {
    try {
      final posts = await FeedService().getProfilePosts(widget.userId);
      if (mounted) setState(() => _userPosts = posts);
    } catch (_) {}
  }

  Future<void> _fetchStats() async {
    try {
      final posts = await Supabase.instance.client
          .from('posts')
          .count(CountOption.exact)
          .eq('user_id', widget.userId);

      final followers = await Supabase.instance.client
          .from('friendships')
          .count(CountOption.exact)
          .eq('friend_id', widget.userId)
          .eq('status', 'accepted');

      final following = await Supabase.instance.client
          .from('friendships')
          .count(CountOption.exact)
          .eq('user_id', widget.userId)
          .eq('status', 'accepted');

      if (mounted) {
        setState(() {
          _postCount = posts;
          _followersCount = followers;
          _followingCount = following;
        });
      }
    } catch (_) {}
  }

  Future<void> _checkFollowStatus() async {
    if (widget.userId == _currentUserId) return;
    try {
      final res = await Supabase.instance.client
          .from('friendships')
          .select('status')
          .eq('user_id', _currentUserId)
          .eq('friend_id', widget.userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          if (res == null) {
            _friendshipStatus = 'none';
          } else {
            _friendshipStatus = res['status'];
          }
        });
      }
    } catch (_) {}
  }

  // --- KAPAK FOTOĞRAFI GÜNCELLEME ---
  Future<void> _updateCoverPhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1920,
        maxHeight: 1080
    );

    if (image == null) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kapak fotoğrafı yükleniyor...')));

      final fileExt = image.path.split('.').last;
      final fileName = 'cover_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'covers/$fileName';

      await Supabase.instance.client.storage.from('uploads').upload(filePath, File(image.path));
      final imageUrl = Supabase.instance.client.storage.from('uploads').getPublicUrl(filePath);

      await Supabase.instance.client.from('profiles').update({
        'cover_url': imageUrl,
      }).eq('id', _currentUserId);

      setState(() {
        _profileData?['cover_url'] = imageUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kapak güncellendi!')));

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  // --- LİSTE EKRANINA GİT ---
  void _openFollowList(String type, String title) {
    bool canView = (widget.userId == _currentUserId) || (_friendshipStatus == 'accepted');

    if (canView) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FollowListScreen(
            userId: widget.userId,
            title: title,
            type: type,
          ),
        ),
      ).then((_) => _fetchStats());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listeyi görmek için takip etmelisin.')),
      );
    }
  }

  // --- TAKİP ET / ÇIKAR ---
  Future<void> _handleFollowAction() async {
    String previousStatus = _friendshipStatus;

    setState(() {
      if (_friendshipStatus == 'none') {
        _friendshipStatus = 'pending';
      } else {
        _friendshipStatus = 'none';
        if (previousStatus == 'accepted') _followersCount--;
      }
    });

    try {
      if (previousStatus == 'none') {
        await Supabase.instance.client.from('friendships').insert({
          'user_id': _currentUserId,
          'friend_id': widget.userId,
          'status': 'pending',
        });

        try {
          await Supabase.instance.client.from('notifications').insert({
            'user_id': widget.userId,
            'actor_id': _currentUserId,
            'type': 'follow',
            'is_read': false
          });
        } catch (_) {}

      } else {
        await Supabase.instance.client
            .from('friendships')
            .delete()
            .eq('user_id', _currentUserId)
            .eq('friend_id', widget.userId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _friendshipStatus = previousStatus;
          if (previousStatus == 'accepted') _followersCount++;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hata oluştu.')));
      }
    }
  }

  void _startMessage() async {
    try {
      final roomId = await _chatService.createOrGetChatRoom(widget.userId);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatScreen(roomId: roomId, otherUser: _profileData ?? {}),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.userId == _currentUserId;
    final isFriend = _friendshipStatus == 'accepted';

    final visiblePosts = _userPosts.where((post) {
      if (isMe || isFriend) return true;
      return post['visibility'] == 'public';
    }).toList();

    final showLockScreen = !isMe && !isFriend && visiblePosts.isEmpty;
    final coverUrl = _profileData?['cover_url'];

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : RefreshIndicator(
        onRefresh: _loadAllData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // --- ÜST BÖLÜM (KAPAK + PROFİL) ---
              Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // 1. ARKA PLAN KAPAK FOTOĞRAFI
                  Container(
                    height: 380,
                    width: double.infinity,
                    foregroundDecoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Color(0xAA000000),
                          Color(0xFF000000),
                        ],
                        stops: [0.0, 0.4, 0.7, 1.0],
                      ),
                    ),
                    child: coverUrl != null
                        ? Image.network(coverUrl, fit: BoxFit.cover)
                        : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.grey.shade900, Colors.black],
                        ),
                      ),
                    ),
                  ),

                  // 2. BUTONLAR (KAMERA ve ÇIKIŞ)
                  if (isMe) ...[
                    Positioned(
                      top: 50,
                      right: 70,
                      child: GestureDetector(
                        onTap: _updateCoverPhoto,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Icon(Icons.add_a_photo, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 50,
                      right: 16,
                      child: GestureDetector(
                        onTap: _logout,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Icon(Icons.logout, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],

                  if (!isMe && widget.showBackButton)
                    Positioned(
                      top: 50,
                      left: 16,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),

                  // 4. PROFİL İÇERİĞİ
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Avatar
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFF6C63FF), Color(0xFF1DB954)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                          ),
                          child: CircleAvatar(
                            radius: 45,
                            backgroundColor: const Color(0xFF1F1F1F),
                            backgroundImage: _profileData?['avatar_url'] != null
                                ? NetworkImage(_profileData!['avatar_url'])
                                : null,
                            child: _profileData?['avatar_url'] == null
                                ? const Icon(Icons.person, size: 40, color: Colors.white54)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // İsim
                        Text(
                          _profileData?['full_name'] ?? 'İsimsiz',
                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, shadows: [const Shadow(offset: Offset(0, 1), blurRadius: 4, color: Colors.black)]),
                        ),

                        // --- YENİ EKLENEN KISIM: KULLANICI ADI ---
                        if (_profileData?['username'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2), // İsimle arasına çok az boşluk
                            child: Text(
                              '@${_profileData!['username']}',
                              style: GoogleFonts.poppins(
                                color: Colors.white60, // Silik gri ton
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                shadows: [const Shadow(offset: Offset(0, 1), blurRadius: 3, color: Colors.black)],
                              ),
                            ),
                          ),

                        // Bio
                        if (_profileData?['bio'] != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            child: Text(
                              _profileData!['bio'],
                              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13, shadows: [const Shadow(offset: Offset(0, 1), blurRadius: 3, color: Colors.black)]),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                        const SizedBox(height: 16),

                        // İstatistikler
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStat('Gönderi', _postCount.toString(), null),
                            Container(width: 1, height: 20, color: Colors.white12),
                            _buildStat('Takipçi', _followersCount.toString(), () => _openFollowList('followers', 'Takipçiler')),
                            Container(width: 1, height: 20, color: Colors.white12),
                            _buildStat('Takip', _followingCount.toString(), () => _openFollowList('following', 'Takip Edilenler')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // --- BUTONLAR ALANI ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    isMe ? _buildMyProfileButtons() : _buildOtherProfileButtons(),
                    const SizedBox(height: 10),
                    _buildSpotifyButton(),
                    const SizedBox(height: 10),
                  ],
                ),
              ),

              // --- İÇERİK ---
              showLockScreen
                  ? Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Column(
                  children: [
                    const Icon(Icons.lock_outline, size: 40, color: Colors.white24),
                    const SizedBox(height: 10),
                    Text("Bu hesap gizli.", style: GoogleFonts.poppins(color: Colors.white24)),
                  ],
                ),
              )
                  : (visiblePosts.isEmpty
                  ? Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Column(
                  children: [
                    const Icon(Icons.feed_outlined, size: 40, color: Colors.white24),
                    const SizedBox(height: 10),
                    Text("Henüz gönderi yok.", style: GoogleFonts.poppins(color: Colors.white24)),
                  ],
                ),
              )
                  : ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: visiblePosts.length,
                itemBuilder: (context, index) => _buildHomeStylePost(visiblePosts[index], index),
              )
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET'LAR ---

  Widget _buildStat(String label, String value, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(value, style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, shadows: [const Shadow(offset: Offset(0, 1), blurRadius: 4, color: Colors.black)])),
          Text(label, style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSpotifyButton() {
    return SizedBox(
      height: 45,
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Spotify servisi bağlanıyor...')));
        },
        icon: const Icon(FontAwesomeIcons.spotify, color: Colors.white, size: 20),
        label: Text("Spotify Hesabını Bağla", style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1DB954),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _buildMyProfileButtons() {
    return SizedBox(
      height: 45,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          if (_profileData == null) return;
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditProfileScreen(currentProfile: _profileData!),
            ),
          );
          if (result == true) {
            _loadAllData();
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF262626),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          side: const BorderSide(color: Colors.white12),
        ),
        child: Text("Profili Düzenle", style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildOtherProfileButtons() {
    String label = "Takip Et";
    Color bgColor = const Color(0xFF6C63FF);
    Color txtColor = Colors.white;

    if (_friendshipStatus == 'accepted') {
      label = "Takip Ediliyor";
      bgColor = const Color(0xFF262626);
    } else if (_friendshipStatus == 'pending') {
      label = "İstek Gönderildi";
      bgColor = Colors.grey.shade900;
      txtColor = Colors.grey;
    }

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 45,
            child: ElevatedButton(
              onPressed: _handleFollowAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: bgColor,
                foregroundColor: txtColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(label, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 45,
            child: ElevatedButton(
              onPressed: _startMessage,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF262626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
                side: const BorderSide(color: Colors.white12),
              ),
              child: Text("Mesaj", style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHomeStylePost(Map<String, dynamic> post, int index) {
    final profile = post['profiles'] ?? {};
    final content = post['content'] ?? '';
    final imageUrl = post['image_url'];
    final date = DateTime.tryParse(post['created_at'] ?? '');
    final dateStr = date != null ? '${date.day}/${date.month}' : '';
    final likeCount = (post['likes'] as List?)?.length ?? 0;
    final commentCount = (post['comments'] as List?)?.length ?? 0;

    final isLiked = (post['likes'] as List?)?.any((l) => l['user_id'] == _currentUserId) ?? false;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: post))),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF1F1F1F),
                backgroundImage: profile['avatar_url'] != null ? NetworkImage(profile['avatar_url']) : null,
                child: profile['avatar_url'] == null ? const Icon(Icons.person, size: 20, color: Colors.white54) : null,
              ),
              title: Text(profile['full_name'] ?? 'İsimsiz', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              subtitle: Text('@${profile['username']}', style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13)),
              trailing: Text(dateStr, style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12)),
            ),
            if (content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(content, style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, height: 1.4)),
              ),
            if (imageUrl != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 350),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(imageUrl, fit: BoxFit.cover),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Icon(isLiked ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart, color: isLiked ? Colors.redAccent : Colors.grey, size: 20),
                  const SizedBox(width: 6),
                  if (likeCount > 0) Text("$likeCount", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13)),
                  const SizedBox(width: 20),
                  const Icon(FontAwesomeIcons.comment, color: Colors.grey, size: 20),
                  const SizedBox(width: 6),
                  if (commentCount > 0) Text("$commentCount", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13)),
                  const Spacer(),
                  const Icon(FontAwesomeIcons.shareFromSquare, color: Colors.grey, size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}