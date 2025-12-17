import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../services/friend_service.dart';
import '../services/chat_service.dart';
import 'profile_screen.dart';
import 'post_detail_screen.dart';
import 'user_list_screen.dart';
import 'messages_screen.dart';

// 🎨 TEMA RENKLERİ
const Color kBgColor = Color(0xFF0A0A0F);
const Color kCardColor = Color(0xFF16161F);
const Color kAccentPurple = Color(0xFF6C63FF);
const Color kAccentGreen = Color(0xFF69F0AE);
const Color kAccentRed = Color(0xFFFF5252);
const Color kAccentBlue = Color(0xFF448AFF);
const Color kAccentOrange = Color(0xFFFF9800);
const Color kAccentCyan = Color(0xFF00E5FF);

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

  List<GroupedNotification> _groupNotifications(
      List<FollowNotification> rawList) {
    List<GroupedNotification> grouped = [];
    Map<String, List<FollowNotification>> postGroups = {};
    Map<String, List<FollowNotification>> messageGroups = {};
    List<FollowNotification> others = [];

    for (var n in rawList) {
      if (n.postId != null &&
          (n.type == 'like' || n.type == 'comment' || n.type == 'fuel')) {
        String key = "${n.postId}_${n.type}";
        if (!postGroups.containsKey(key)) postGroups[key] = [];
        postGroups[key]!.add(n);
      } else if (n.type == 'message') {
        String key = n.userId;
        if (!messageGroups.containsKey(key)) messageGroups[key] = [];
        messageGroups[key]!.add(n);
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

    messageGroups.forEach((key, list) {
      grouped.add(GroupedNotification(
        type: 'message',
        notifications: list,
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

  Future<void> _refresh() async {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // 🔥 PREMIUM APP BAR
          SliverAppBar(
            backgroundColor: kBgColor,
            elevation: 0,
            pinned: true,
            expandedHeight: 120,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 18),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          kAccentPurple.withOpacity(0.3),
                          kAccentPurple.withOpacity(0.1)
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(FontAwesomeIcons.bell,
                        color: kAccentPurple, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Bildirimler",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      kAccentPurple.withOpacity(0.15),
                      kBgColor,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 🔔 TAKİP İSTEKLERİ
          SliverToBoxAdapter(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _friendService.getPendingRequests(_currentUserId),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty)
                  return const SizedBox();
                final requests = snapshot.data!;
                final firstUser = requests[0];

                return GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserListScreen(
                          title: 'Takip İstekleri',
                          users: requests,
                          listType: 'requests',
                          isOwnList: true,
                        ),
                      ),
                    );
                    setState(() {});
                  },
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          kAccentPurple.withOpacity(0.2),
                          kAccentPurple.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kAccentPurple.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        // Avatar Stack
                        SizedBox(
                          width: 56,
                          height: 40,
                          child: Stack(
                            children: [
                              if (requests.length > 1)
                                Positioned(
                                  left: 20,
                                  child: _buildMiniAvatar(
                                      requests[1]['avatar_url'], 18),
                                ),
                              _buildMiniAvatar(firstUser['avatar_url'], 20,
                                  hasBorder: true),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    "Takip İstekleri",
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: kAccentPurple,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      "${requests.length}",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                requests.length == 1
                                    ? "${firstUser['username']} seni takip etmek istiyor"
                                    : "${firstUser['username']} ve ${requests.length - 1} diğer kişi",
                                style: GoogleFonts.poppins(
                                    color: Colors.white54, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: kAccentPurple.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.arrow_forward_ios,
                              size: 14, color: kAccentPurple),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 📋 BİLDİRİM LİSTESİ
          StreamBuilder<List<FollowNotification>>(
            stream: _friendService.getNotificationsStream(_currentUserId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(
                      child: CircularProgressIndicator(color: kAccentPurple)),
                );
              }

              final rawList = snapshot.data ?? [];
              final filteredList = rawList
                  .where((n) =>
                      !(n.type == 'follow' && n.friendshipStatus == 'pending'))
                  .toList();

              if (filteredList.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(FontAwesomeIcons.bellSlash,
                              size: 40, color: Colors.white24),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Henüz bildirim yok",
                          style: GoogleFonts.poppins(
                              color: Colors.white38, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Yeni etkileşimler burada görünecek",
                          style: GoogleFonts.poppins(
                              color: Colors.white24, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final groupedList = _groupNotifications(filteredList);

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return _NotificationCard(
                        group: groupedList[index],
                        index: index,
                        onTap: () => _handleNotificationTap(groupedList[index]),
                      );
                    },
                    childCount: groupedList.length,
                  ),
                ),
              );
            },
          ),

          // Alt boşluk
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildMiniAvatar(String? avatarUrl, double radius,
      {bool hasBorder = false}) {
    return Container(
      decoration: hasBorder
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: kBgColor, width: 2),
            )
          : null,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: kCardColor,
        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
        child: avatarUrl == null
            ? Icon(Icons.person, size: radius, color: Colors.white54)
            : null,
      ),
    );
  }

  void _handleNotificationTap(GroupedNotification group) async {
    final notif = group.notifications.first;

    if (group.type == 'message' || group.type == 'call') {
      try {
        final roomId = await ChatService().createOrGetChatRoom(notif.userId);
        if (mounted) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ChatScreen(
                      roomId: roomId, otherUser: notif.userProfile)));
        }
      } catch (_) {
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const MessagesScreen()));
      }
    } else if (group.postId != null) {
      final postRes = await Supabase.instance.client
          .from('posts')
          .select('*, profiles(*), likes(user_id), comments(id)')
          .eq('id', group.postId!)
          .maybeSingle();
      if (postRes != null && mounted) {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => PostDetailScreen(post: postRes)));
      }
    } else {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ProfileScreen(userId: notif.userId)));
    }
  }
}

// 🔥 PREMIUM BİLDİRİM KARTI
class _NotificationCard extends StatelessWidget {
  final GroupedNotification group;
  final int index;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.group,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final notif = group.notifications.first;
    final username = notif.userProfile['username'] ?? 'anonim';
    final fullName = notif.userProfile['full_name'] ?? username;
    final avatarUrl = notif.userProfile['avatar_url'];
    final uniqueUserIds = group.notifications.map((n) => n.userId).toSet();
    final count = uniqueUserIds.length;

    // Bildirim tipine göre ayarlar
    final config = _getNotificationConfig(group.type, count);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + (index * 50)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kCardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: config.color.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: config.color.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar ve ikon badge
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [config.color, config.color.withOpacity(0.5)],
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: kCardColor,
                      backgroundImage:
                          avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null
                          ? const Icon(Icons.person,
                              color: Colors.white54, size: 24)
                          : null,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: config.color,
                        shape: BoxShape.circle,
                        border: Border.all(color: kCardColor, width: 2),
                      ),
                      child: Icon(config.icon, size: 10, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // İçerik
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            fullName,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "• ${timeago.format(group.createdAt, locale: 'en_short')}",
                          style: GoogleFonts.poppins(
                              color: Colors.white30, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      config.text,
                      style: GoogleFonts.poppins(
                          color: Colors.white60, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Trailing (post resmi veya ikon)
              if (group.postImage != null) ...[
                const SizedBox(width: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    group.postImage!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.image,
                          color: Colors.white24, size: 20),
                    ),
                  ),
                ),
              ] else if (group.type == 'message' ||
                  group.type == 'call' ||
                  group.type == 'follow') ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: config.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      Icon(config.trailingIcon, size: 18, color: config.color),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  _NotificationConfig _getNotificationConfig(String type, int count) {
    switch (type) {
      case 'like':
        return _NotificationConfig(
          icon: FontAwesomeIcons.heart,
          trailingIcon: FontAwesomeIcons.heart,
          color: kAccentRed,
          text: count == 1
              ? "Gönderini beğendi"
              : "ve ${count - 1} kişi daha beğendi",
        );
      case 'comment':
        return _NotificationConfig(
          icon: FontAwesomeIcons.comment,
          trailingIcon: FontAwesomeIcons.comment,
          color: kAccentBlue,
          text: count == 1
              ? "Yorum yaptı"
              : "ve ${count - 1} kişi daha yorum yaptı",
        );
      case 'fuel':
        return _NotificationConfig(
          icon: FontAwesomeIcons.fire,
          trailingIcon: FontAwesomeIcons.fire,
          color: kAccentOrange,
          text: count == 1
              ? "Gönderini harladı 🔥"
              : "ve ${count - 1} kişi daha harladı 🔥",
        );
      case 'follow':
        return _NotificationConfig(
          icon: FontAwesomeIcons.userPlus,
          trailingIcon: FontAwesomeIcons.arrowRight,
          color: kAccentPurple,
          text: "Seni takip etmeye başladı",
        );
      case 'message':
        return _NotificationConfig(
          icon: FontAwesomeIcons.envelope,
          trailingIcon: FontAwesomeIcons.arrowRight,
          color: kAccentCyan,
          text: "Sana mesaj gönderdi",
        );
      case 'call':
        return _NotificationConfig(
          icon: FontAwesomeIcons.phone,
          trailingIcon: FontAwesomeIcons.arrowRight,
          color: kAccentGreen,
          text: "Seni aramaya çalıştı",
        );
      default:
        return _NotificationConfig(
          icon: FontAwesomeIcons.bell,
          trailingIcon: FontAwesomeIcons.bell,
          color: Colors.grey,
          text: "Yeni bildirim",
        );
    }
  }
}

class _NotificationConfig {
  final IconData icon;
  final IconData trailingIcon;
  final Color color;
  final String text;

  _NotificationConfig({
    required this.icon,
    required this.trailingIcon,
    required this.color,
    required this.text,
  });
}

class GroupedNotification {
  final String type;
  final List<FollowNotification> notifications;
  final String? postId;
  final String? postImage;
  final DateTime createdAt;

  GroupedNotification({
    required this.type,
    required this.notifications,
    required this.createdAt,
    this.postId,
    this.postImage,
  });
}
