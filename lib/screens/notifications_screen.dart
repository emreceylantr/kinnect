// lib/screens/notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../services/friend_service.dart';
import 'profile_screen.dart';
import 'post_detail_screen.dart';
import 'user_list_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final String _currentUserId;
  late final FriendService _friendService;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser!.id;
    _friendService = FriendService();
  }

  List<GroupedNotification> _groupNotifications(List<FollowNotification> rawList) {
    List<GroupedNotification> grouped = [];
    Map<String, List<FollowNotification>> postGroups = {};
    List<FollowNotification> others = [];

    for (var n in rawList) {
      if (n.postId != null && (n.type == 'like' || n.type == 'comment')) {
        String key = "${n.postId}_${n.type}";
        if (!postGroups.containsKey(key)) postGroups[key] = [];
        postGroups[key]!.add(n);
      } else {
        others.add(n);
      }
    }

    postGroups.forEach((key, list) {
      grouped.add(GroupedNotification(
        type: list.first.type,
        notifications: list,
        postId: list.first.postId,
        postImage: list.first.postImage,
        createdAt: list.first.createdAt,
      ));
    });

    for (var n in others) {
      grouped.add(GroupedNotification(
        type: n.type,
        notifications: [n],
        createdAt: n.createdAt,
      ));
    }
    grouped.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(backgroundColor: const Color(0xFF050505), elevation: 0, title: Text("Bildirimler", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)), leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), onPressed: () => Navigator.pop(context))),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. TAKİP İSTEKLERİ KUTUSU (Varsa)
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _friendService.getPendingRequests(_currentUserId),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox();
                final requests = snapshot.data!;
                final firstUser = requests[0];

                return GestureDetector(
                  onTap: () async {
                    // Listeye git ve 'requests' tipini gönder
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => UserListScreen(
                        title: 'Takip İstekleri',
                        users: requests,
                        listType: 'requests',
                        isOwnList: false
                    )));
                    setState(() {}); // Geri dönünce güncelle
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      SizedBox(width: 40, child: Stack(children: [if (requests.length > 1) Positioned(left: 10, child: CircleAvatar(radius: 16, backgroundColor: Colors.grey, backgroundImage: requests[1]['avatar_url'] != null ? NetworkImage(requests[1]['avatar_url']) : null)), CircleAvatar(radius: 16, backgroundColor: const Color(0xFF6C63FF), backgroundImage: firstUser['avatar_url'] != null ? NetworkImage(firstUser['avatar_url']) : null)])),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Takip İstekleri", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)), Text(requests.length == 1 ? "${firstUser['username']}" : "${firstUser['username']} + ${requests.length - 1} diğer", style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12))]),
                      const Spacer(), const Icon(Icons.circle, size: 8, color: Color(0xFF6C63FF)), const SizedBox(width: 8), const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white38)
                    ]),
                  ),
                );
              },
            ),

            Padding(padding: const EdgeInsets.only(left: 16, top: 10, bottom: 6), child: Text("Bu Hafta", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),

            // 2. BİLDİRİM LİSTESİ
            StreamBuilder<List<FollowNotification>>(
              stream: _friendService.getNotificationsStream(_currentUserId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)));
                final rawList = snapshot.data ?? [];

                // Bekleyen istekleri buradan filtrele
                final filteredList = rawList.where((n) => !(n.type == 'follow' && n.friendshipStatus == 'pending')).toList();

                if (filteredList.isEmpty) return Padding(padding: const EdgeInsets.all(40), child: Center(child: Text("Henüz bildirim yok.", style: GoogleFonts.poppins(color: Colors.white54))));

                final groupedList = _groupNotifications(filteredList);

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: groupedList.length,
                  itemBuilder: (context, index) => _buildGroupCard(groupedList[index]),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupCard(GroupedNotification group) {
    final notif = group.notifications.first;
    final username = notif.userProfile['username'] ?? 'anonim';
    final avatarUrl = notif.userProfile['avatar_url'];
    final count = group.notifications.length;

    String text = "";
    Widget? trailing;

    if (group.type == 'like') {
      text = count == 1 ? "gönderini beğendi." : "ve ${count - 1} diğer kişi gönderini beğendi.";
      if (group.postImage != null) trailing = Container(width: 44, height: 44, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), image: DecorationImage(image: NetworkImage(group.postImage!), fit: BoxFit.cover)));
    } else if (group.type == 'comment') {
      text = count == 1 ? "yorum yaptı." : "ve ${count - 1} diğer kişi yorum yaptı.";
      if (group.postImage != null) trailing = Container(width: 44, height: 44, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), image: DecorationImage(image: NetworkImage(group.postImage!), fit: BoxFit.cover)));
    } else if (group.type == 'follow') {
      text = "seni takip etmeye başladı.";
      trailing = SizedBox(height: 30, child: ElevatedButton(onPressed: (){}, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E1E1E)), child: const Text("Takiptesin", style: TextStyle(fontSize: 12, color: Colors.white70))));
    }

    final dt = group.createdAt;
    final diff = DateTime.now().difference(dt);
    String timeStr = "${dt.day}g";
    if(diff.inHours < 24) timeStr = "${diff.inHours}s";

    return InkWell(
      onTap: () async {
        if (group.postId != null) {
          // Beğeni veya Yorumsa -> POSTU ÇEK VE GİT
          final postRes = await Supabase.instance.client
              .from('posts')
              .select('*, profiles(*), likes(user_id), comments(id)')
              .eq('id', group.postId!)
              .maybeSingle();

          if (postRes != null && mounted) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: postRes)));
          }
        } else {
          // Takipse -> Profile Git
          Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: notif.userId)));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          CircleAvatar(radius: 22, backgroundColor: const Color(0xFF333333), backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null, child: avatarUrl == null ? const Icon(Icons.person, color: Colors.white) : null),
          const SizedBox(width: 12),
          Expanded(child: RichText(text: TextSpan(style: GoogleFonts.poppins(color: Colors.white, fontSize: 14), children: [TextSpan(text: username, style: const TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: " $text", style: const TextStyle(color: Colors.white70))]))),
          Text(timeStr, style: GoogleFonts.poppins(color: Colors.grey, fontSize: 11)),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ]),
      ),
    );
  }
}

class GroupedNotification {
  final String type;
  final List<FollowNotification> notifications;
  final String? postId;
  final String? postImage;
  final DateTime createdAt;

  GroupedNotification({required this.type, required this.notifications, required this.createdAt, this.postId, this.postImage});
}