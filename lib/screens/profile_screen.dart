// lib/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../repositories/profile_repository.dart';
import '../services/profile_service.dart';
import '../services/friend_service.dart';
import 'user_list_screen.dart';
import 'post_detail_screen.dart';

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
  late final String _currentUserId;
  late final ProfileService _profileService;
  late final FriendService _friendService;

  Map<String, dynamic>? _profile;
  bool _isProfileLoading = true;
  int _postCount = 0;
  int _followersCount = 0;
  int _followingCount = 0;
  List<Map<String, dynamic>> _posts = [];
  bool _isPostsLoading = true;
  FollowStatus _followStatus = FollowStatus.notFollowing;
  bool _isRelationshipLoading = true;

  @override
  void initState() {
    super.initState();
    final session = Supabase.instance.client.auth.currentSession;
    _currentUserId = session?.user.id ?? '';
    final client = Supabase.instance.client;
    _profileService = ProfileService(ProfileRepository(client));
    _friendService = FriendService();
    if (_currentUserId.isNotEmpty) _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadProfile();
    await _loadFollowStatus();
    await Future.wait([_loadStats(), _loadPosts()]);
  }

  // ... (Loaders aynen kalıyor, kısaltıyorum yer kaplamasın diye)
  Future<void> _loadProfile() async {
    try { final data = await _profileService.fetchProfile(widget.userId); if (mounted) setState(() { _profile = data; _isProfileLoading = false; }); } catch (e) { if (mounted) setState(() => _isProfileLoading = false); }
  }
  Future<void> _loadFollowStatus() async { if (_currentUserId.isEmpty) return; try { final status = await _friendService.getFollowStatus(currentUserId: _currentUserId, targetUserId: widget.userId); if (mounted) setState(() { _followStatus = status; _isRelationshipLoading = false; }); } catch (e) { if (mounted) setState(() => _isRelationshipLoading = false); } }
  Future<void> _loadStats() async { try { final p = await Supabase.instance.client.from('posts').count(CountOption.exact).eq('user_id', widget.userId); final f1 = await _friendService.getFollowerCount(widget.userId); final f2 = await _friendService.getFollowingCount(widget.userId); if (mounted) setState(() { _postCount = p; _followersCount = f1; _followingCount = f2; }); } catch (e) {} }

  Future<void> _loadPosts() async {
    setState(() => _isPostsLoading = true);
    try {
      final posts = await _friendService.getProfilePosts(targetUserId: widget.userId, status: _followStatus);
      if (mounted) setState(() { _posts = posts; _isPostsLoading = false; });
    } catch (e) { if (mounted) setState(() => _isPostsLoading = false); }
  }

  // --- LİSTE AÇMA ---
  Future<void> _openFollowList(String type) async {
    if (_profile == null) return;
    List<Map<String, dynamic>> users = [];
    String title = '';
    if (type == 'followers') { title = 'Takipçiler'; users = await _friendService.getFollowersList(widget.userId); }
    else { title = 'Takip Edilenler'; users = await _friendService.getFollowingList(widget.userId); }
    final bool isOwnProfile = widget.userId == _currentUserId;
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => UserListScreen(title: title, users: users, listType: type, isOwnList: isOwnProfile)));
  }

  Future<void> _handleFollowAction() async {
    if (_currentUserId.isEmpty) return;
    setState(() => _isRelationshipLoading = true);
    try {
      if (_followStatus == FollowStatus.notFollowing) {
        await _friendService.sendFollowRequest(currentUserId: _currentUserId, targetUserId: widget.userId);
        _followStatus = FollowStatus.pendingOutgoing;
      } else if (_followStatus == FollowStatus.pendingOutgoing || _followStatus == FollowStatus.following) {
        await _friendService.unfollowOrCancel(currentUserId: _currentUserId, targetUserId: widget.userId);
        _followStatus = FollowStatus.notFollowing;
        if (_followStatus == FollowStatus.following) _followersCount--;
      } else if (_followStatus == FollowStatus.pendingIncoming) {
        await _friendService.acceptFollowRequest(currentUserId: _currentUserId, targetUserId: widget.userId);
        _followStatus = FollowStatus.following;
        _followersCount++;
      }
      await _loadStats(); await _loadPosts();
    } catch (e) {} finally { setState(() => _isRelationshipLoading = false); }
  }

  // --- PROFİL POST KARTI (ANA SAYFA İLE AYNISI - LİSTE GÖRÜNÜMÜ) ---
  Widget _buildPostCard(Map<String, dynamic> post) {
    final content = post['content']?.toString() ?? '';
    final imageUrl = post['image_url']?.toString();
    final createdAt = DateTime.tryParse(post['created_at'] ?? '');
    String dateText = createdAt != null ? '${createdAt.day}/${createdAt.month}/${createdAt.year}' : '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dateText.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(dateText, style: GoogleFonts.poppins(color: Colors.white24, fontSize: 11))),

          if (content.isNotEmpty)
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: post))),
              child: Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(content, style: GoogleFonts.poppins(color: Colors.white))),
            ),

          if (imageUrl != null)
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.transparent, leading: const BackButton(color: Colors.white)), body: Center(child: InteractiveViewer(child: Image.network(imageUrl)))))),
              child: Container(
                margin: const EdgeInsets.only(top: 5),
                height: 250, // Sabit yükseklik, eski tarz
                width: double.infinity,
                child: Hero(tag: 'profile_$imageUrl', child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(imageUrl, fit: BoxFit.cover))),
              ),
            ),

          const SizedBox(height: 10),
          GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: post))), child: const Icon(Icons.mode_comment_outlined, color: Colors.white70, size: 20)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = widget.userId == _currentUserId;
    final fullName = _profile?['full_name'] ?? (isOwnProfile ? 'Profilim' : 'Profil');
    final username = _profile?['username'] ?? '';
    final avatarUrl = _profile?['avatar_url'] as String?;
    final bio = _profile?['bio'] as String? ?? '';
    final bool canViewLists = isOwnProfile || (_followStatus == FollowStatus.following);

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(backgroundColor: const Color(0xFF050505), elevation: 0, title: Text(isOwnProfile ? 'Profilim' : fullName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)), centerTitle: true, leading: widget.showBackButton ? IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), onPressed: () => Navigator.pop(context)) : null),
      body: RefreshIndicator(
        color: const Color(0xFF6C63FF), backgroundColor: const Color(0xFF1A1A1A), onRefresh: _loadInitialData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 20),
              CircleAvatar(radius: 50, backgroundColor: const Color(0xFF6C63FF), backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null, child: avatarUrl == null ? const Icon(Icons.person, size: 50, color: Colors.white) : null),
              const SizedBox(height: 12),
              Text(fullName, style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              Text('@$username', style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14)),
              const SizedBox(height: 20),
              // --- İSTATİSTİKLER (TIKLANABİLİR) ---
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _buildStatItem('Gönderi', _postCount, null),
                _buildStatItem('Takipçi', _followersCount, canViewLists ? () => _openFollowList('followers') : null),
                _buildStatItem('Takip', _followingCount, canViewLists ? () => _openFollowList('following') : null)
              ]),
              const SizedBox(height: 20),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _buildActionButton()),
              if (bio.isNotEmpty) Padding(padding: const EdgeInsets.all(20), child: Text(bio, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.white70))),
              const SizedBox(height: 30),
              if (_posts.isNotEmpty) ...[
                Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Align(alignment: Alignment.centerLeft, child: Text('Gönderiler', style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)))),
                // LIST VIEW (Izgara Değil)
                ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: _posts.length, itemBuilder: (context, index) => _buildPostCard(_posts[index])),
              ] else
                Padding(padding: const EdgeInsets.all(40), child: Text(canViewLists ? 'Henüz gönderi yok.' : 'Hesap Gizli', style: GoogleFonts.poppins(color: Colors.white38))),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int value, VoidCallback? onTap) {
    return GestureDetector(onTap: onTap, child: Column(children: [Text(value.toString(), style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)), const SizedBox(height: 4), Text(label, style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12))]));
  }

  Widget _buildActionButton() {
    if (widget.userId == _currentUserId) {
      return SizedBox(width: double.infinity, child: OutlinedButton(onPressed: (){}, style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Profili Düzenle', style: GoogleFonts.poppins(color: Colors.white))));
    }
    String label = 'Takip Et'; Color bg = const Color(0xFF6C63FF); Color txt = Colors.white;
    if (_followStatus == FollowStatus.following) { label = 'Takiptesin'; bg = const Color(0xFF1A1A1A); }
    else if (_followStatus == FollowStatus.pendingOutgoing) { label = 'İstek Gönderildi'; bg = Colors.grey.shade800; txt = Colors.white54; }
    else if (_followStatus == FollowStatus.pendingIncoming) { label = 'Kabul Et'; bg = Colors.green; }
    return SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _isRelationshipLoading ? null : _handleFollowAction, style: ElevatedButton.styleFrom(backgroundColor: bg, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _isRelationshipLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(label, style: GoogleFonts.poppins(color: txt, fontWeight: FontWeight.w600))));
  }
}