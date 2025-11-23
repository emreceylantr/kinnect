// lib/screens/user_list_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/friend_service.dart';
import 'profile_screen.dart';

class UserListScreen extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> users;
  final String listType; // 'followers', 'following', 'requests'
  final bool isOwnList;

  const UserListScreen({
    super.key,
    required this.title,
    required this.users,
    required this.listType,
    required this.isOwnList,
  });

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final String _currentUserId = Supabase.instance.client.auth.currentUser!.id;
  late final FriendService _friendService;
  late List<Map<String, dynamic>> _users;

  @override
  void initState() {
    super.initState();
    _friendService = FriendService();
    _users = widget.users;
  }

  void _removeUserFromList(String targetId) {
    setState(() {
      _users.removeWhere((user) => user['id'] == targetId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        title: Text(widget.title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF050505),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _users.isEmpty
          ? Center(child: Text('Liste boş.', style: GoogleFonts.poppins(color: Colors.white54)))
          : ListView.builder(
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          return _UserListItem(
            user: user,
            currentUserId: _currentUserId,
            friendService: _friendService,
            listType: widget.listType,
            isOwnList: widget.isOwnList,
            onUserRemoved: () => _removeUserFromList(user['id']),
          );
        },
      ),
    );
  }
}

class _UserListItem extends StatefulWidget {
  final Map<String, dynamic> user;
  final String currentUserId;
  final FriendService friendService;
  final String listType;
  final bool isOwnList;
  final VoidCallback onUserRemoved;

  const _UserListItem({
    required this.user,
    required this.currentUserId,
    required this.friendService,
    required this.listType,
    required this.isOwnList,
    required this.onUserRemoved,
  });

  @override
  State<_UserListItem> createState() => _UserListItemState();
}

class _UserListItemState extends State<_UserListItem> {
  FollowStatus _status = FollowStatus.notFollowing;
  bool _isLoading = false;
  bool _statusChecked = false;

  @override
  void initState() {
    super.initState();
    // İSTEK LİSTESİYSE DURUM KONTROLÜNE GEREK YOK, ZATEN İSTEKTİR
    if (widget.listType == 'requests') {
      _status = FollowStatus.pendingIncoming;
      _statusChecked = true;
    } else if (!widget.isOwnList && widget.user['id'] != widget.currentUserId) {
      _checkStatus();
    }
  }

  Future<void> _checkStatus() async {
    setState(() => _isLoading = true);
    final status = await widget.friendService.getFollowStatus(currentUserId: widget.currentUserId, targetUserId: widget.user['id']);
    if (mounted) setState(() { _status = status; _isLoading = false; _statusChecked = true; });
  }

  // --- İŞLEMLER ---
  Future<void> _acceptRequest() async {
    setState(() => _isLoading = true);
    await widget.friendService.acceptFollowRequest(currentUserId: widget.currentUserId, targetUserId: widget.user['id']);
    widget.onUserRemoved(); // Listeden sil (çünkü artık takipçi oldu, istek değil)
  }

  Future<void> _declineRequest() async {
    setState(() => _isLoading = true);
    await widget.friendService.removeFollowerOrDecline(currentUserId: widget.currentUserId, targetUserId: widget.user['id']);
    widget.onUserRemoved();
  }

  Future<void> _removeFollower() async {
    setState(() => _isLoading = true);
    await widget.friendService.removeFollower(currentUserId: widget.currentUserId, targetUserId: widget.user['id']);
    widget.onUserRemoved();
  }

  Future<void> _unfollow() async {
    setState(() => _isLoading = true);
    await widget.friendService.unfollowOrCancel(currentUserId: widget.currentUserId, targetUserId: widget.user['id']);
    widget.onUserRemoved();
  }

  Future<void> _toggleFollow() async {
    setState(() => _isLoading = true);
    try {
      if (_status == FollowStatus.notFollowing) {
        await widget.friendService.sendFollowRequest(currentUserId: widget.currentUserId, targetUserId: widget.user['id']);
        _status = FollowStatus.pendingOutgoing;
      } else if (_status == FollowStatus.following || _status == FollowStatus.pendingOutgoing) {
        await widget.friendService.unfollowOrCancel(currentUserId: widget.currentUserId, targetUserId: widget.user['id']);
        _status = FollowStatus.notFollowing;
      }
    } catch (e) {} finally { if (mounted) setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final fullName = widget.user['full_name'] ?? 'Kullanıcı';
    final username = widget.user['username'] ?? 'anonim';
    final avatarUrl = widget.user['avatar_url'];

    if (widget.user['id'] == widget.currentUserId) return _buildListTile(fullName, username, avatarUrl, null);

    Widget trailing;

    // 1. İSTEK LİSTESİ (KABUL ET / SİL)
    if (widget.listType == 'requests') {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildButton(text: 'Kabul', color: Colors.green, onTap: _acceptRequest),
          const SizedBox(width: 8),
          _buildButton(text: 'Sil', color: Colors.redAccent, isOutline: true, onTap: _declineRequest),
        ],
      );
    }
    // 2. KENDİ TAKİPÇİLERİM (ÇIKAR)
    else if (widget.isOwnList && widget.listType == 'followers') {
      trailing = _buildButton(text: 'Çıkar', color: const Color(0xFF1E1E1E), onTap: _removeFollower);
    }
    // 3. KENDİ TAKİP ETTİKLERİM (TAKİPTESİN -> ÇIK)
    else if (widget.isOwnList && widget.listType == 'following') {
      trailing = _buildButton(text: 'Takiptesin', color: const Color(0xFF1E1E1E), onTap: _unfollow);
    }
    // 4. BAŞKASININ LİSTESİ (GENEL TAKİP BUTONU)
    else {
      if (!_statusChecked && _isLoading) return _buildListTile(fullName, username, avatarUrl, const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)));

      String t = 'Takip Et'; Color c = const Color(0xFF6C63FF);
      if (_status == FollowStatus.following) { t = 'Takiptesin'; c = const Color(0xFF1E1E1E); }
      else if (_status == FollowStatus.pendingOutgoing) { t = 'İstek yollandı'; c = Colors.grey.shade800; }

      trailing = _buildButton(text: t, color: c, onTap: _toggleFollow);
    }

    return _buildListTile(fullName, username, avatarUrl, trailing);
  }

  Widget _buildButton({required String text, required Color color, required VoidCallback onTap, bool isOutline = false}) {
    return SizedBox(
      height: 32,
      child: isOutline
          ? OutlinedButton(
        onPressed: _isLoading ? null : onTap,
        style: OutlinedButton.styleFrom(side: BorderSide(color: color), padding: const EdgeInsets.symmetric(horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        child: Text(text, style: GoogleFonts.poppins(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      )
          : ElevatedButton(
        onPressed: _isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
        child: _isLoading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(text, style: GoogleFonts.poppins(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildListTile(String name, String username, String? avatarUrl, Widget? trailing) {
    return ListTile(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: widget.user['id']))),
      leading: CircleAvatar(backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null, backgroundColor: const Color(0xFF6C63FF), child: avatarUrl == null ? const Icon(Icons.person, color: Colors.white) : null),
      title: Text(name, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text('@$username', style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12)),
      trailing: trailing,
    );
  }
}