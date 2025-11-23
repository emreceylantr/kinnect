// lib/screens/follow_list_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/friend_service.dart';
import 'profile_screen.dart';

class FollowListScreen extends StatefulWidget {
  final String userId;
  final String type; // 'followers' veya 'following'

  const FollowListScreen({
    super.key,
    required this.userId,
    required this.type,
  });

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  final FriendService _friendService = FriendService();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  final String _currentUserId = Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      List<Map<String, dynamic>> data;

      // DÜZELTME BURADA: Metod isimleri güncellendi (List eklendi)
      if (widget.type == 'followers') {
        data = await _friendService.getFollowersList(widget.userId);
      } else {
        data = await _friendService.getFollowingList(widget.userId);
      }

      if (mounted) {
        setState(() {
          _users = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Liste yükleme hatası: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.type == 'followers' ? 'Takipçiler' : 'Takip Edilenler';

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF050505),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : _users.isEmpty
          ? Center(child: Text('Kimse yok.', style: GoogleFonts.poppins(color: Colors.white54)))
          : ListView.builder(
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          final fullName = user['full_name'] ?? 'Kullanıcı';
          final username = user['username'] ?? 'anonim';
          final avatarUrl = user['avatar_url'];
          final isMe = user['id'] == _currentUserId;

          return ListTile(
            leading: GestureDetector(
              onTap: () {
                // Profile git
                Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProfileScreen(userId: user['id']))
                );
              },
              child: CircleAvatar(
                backgroundColor: const Color(0xFF6C63FF),
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null ? const Icon(Icons.person, color: Colors.white) : null,
              ),
            ),
            title: Text(fullName, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: Text('@$username', style: GoogleFonts.poppins(color: Colors.white54)),
            trailing: isMe
                ? null
                : const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProfileScreen(userId: user['id']))
              );
            },
          );
        },
      ),
    );
  }
}