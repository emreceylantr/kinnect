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
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchList();
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
        if (ids.isNotEmpty) response = await client.from('profiles').select().inFilter('id', ids);

      } else {
        final friendships = await client
            .from('friendships')
            .select('friend_id')
            .eq('user_id', widget.userId)
            .eq('status', 'accepted');

        final ids = (friendships as List).map((e) => e['friend_id']).toList();
        if (ids.isNotEmpty) response = await client.from('profiles').select().inFilter('id', ids);
      }

      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- TAKİPÇİYİ ÇIKAR ---
  Future<void> _removeFollower(String targetUserId) async {
    try {
      await Supabase.instance.client
          .from('friendships')
          .delete()
          .eq('friend_id', _currentUserId) // Ben (Takip edilen)
          .eq('user_id', targetUserId);    // O (Takip eden)

      setState(() {
        _users.removeWhere((u) => u['id'] == targetUserId);
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kişi çıkarıldı.')));
    } catch (e) {
      print(e);
    }
  }

  // --- TAKİPTEN ÇIK ---
  Future<void> _unfollowUser(String targetUserId) async {
    try {
      await Supabase.instance.client
          .from('friendships')
          .delete()
          .eq('user_id', _currentUserId) // Ben (Takip eden)
          .eq('friend_id', targetUserId); // O (Takip edilen)

      setState(() {
        _users.removeWhere((u) => u['id'] == targetUserId);
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Takipten çıkıldı.')));
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listeye bakan kişi, listenin sahibi mi? (Örn: Ben kendi takipçilerime mi bakıyorum?)
    final isOwnList = widget.userId == _currentUserId;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: const BackButton(color: Colors.white),
        title: Text(widget.title, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : _users.isEmpty
          ? Center(child: Text('Liste boş.', style: GoogleFonts.poppins(color: Colors.white54)))
          : ListView.builder(
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          final isMe = user['id'] == _currentUserId; // Listede kendimi görürsem buton olmasın

          return ListTile(
            leading: CircleAvatar(
              backgroundImage: user['avatar_url'] != null ? NetworkImage(user['avatar_url']) : null,
              child: user['avatar_url'] == null ? const Icon(Icons.person) : null,
            ),
            title: Text(user['username'] ?? '', style: GoogleFonts.poppins(color: Colors.white)),
            subtitle: Text(user['full_name'] ?? '', style: GoogleFonts.poppins(color: Colors.white54)),

            // BUTONLAR (SADECE KENDİ LİSTEMSE GÖZÜKSÜN)
            trailing: (isOwnList && !isMe)
                ? (widget.type == 'followers'
                ? OutlinedButton(
              onPressed: () => _removeFollower(user['id']),
              style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.grey.shade800), padding: const EdgeInsets.symmetric(horizontal: 12)),
              child: Text('Çıkar', style: GoogleFonts.poppins(color: Colors.white, fontSize: 12)),
            )
                : OutlinedButton(
              onPressed: () => _unfollowUser(user['id']),
              style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.grey.shade800), padding: const EdgeInsets.symmetric(horizontal: 12)),
              child: Text('Takipten Çık', style: GoogleFonts.poppins(color: Colors.white, fontSize: 12)),
            )
            )
                : null,

            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: user['id'])));
            },
          );
        },
      ),
    );
  }
}