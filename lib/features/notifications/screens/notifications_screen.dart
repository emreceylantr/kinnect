// Kinnect - Bildirimler ekranı (Premium UX)

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/language/app_l10n.dart';
import '../../../data/services/friend_service.dart';
import '../../../data/services/chat_service.dart';
import '../../profile/screens/profile_screen.dart';
import '../../post/screens/post_detail_screen.dart';
import '../../profile/screens/user_list_screen.dart';
import '../../chat/screens/messages_screen.dart';
import '../../chat/screens/chat_screen.dart';

// 🎨 TEMA RENKLERİ
const Color kBgColor = Color(0xFF0A0A0F);
const Color kCardColor = Color(0xFF13131A);
const Color kCardColorAlt = Color(0xFF16161F);
const Color kAccentPurple = Color(0xFF7C6EFA);
const Color kAccentGreen = Color(0xFF4ADE80);
const Color kAccentRed = Color(0xFFFF5252);
const Color kAccentBlue = Color(0xFF60A5FA);
const Color kAccentOrange = Color(0xFFFB923C);
const Color kAccentCyan = Color(0xFF22D3EE);

String _formatTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return AppL10n.justNow;
  if (diff.inMinutes < 60) return AppL10n.timeMinShort(diff.inMinutes);
  if (diff.inHours < 24) return AppL10n.timeHourShort(diff.inHours);
  if (diff.inDays < 7) return AppL10n.timeDayShort(diff.inDays);
  if (diff.inDays < 30) return AppL10n.timeWeekShort((diff.inDays / 7).floor());
  return AppL10n.timeMonthShort((diff.inDays / 30).floor());
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with WidgetsBindingObserver {
  late final String _currentUserId;
  late final FriendService _friendService;
  late Stream<List<FollowNotification>> _notificationsStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
    _friendService = FriendService();
    _markNotificationsAsRead();
    _refreshNotifications();
  }

  Future<void> _markNotificationsAsRead() async {
    if (_currentUserId.isEmpty) return;
    try {
      await _friendService.markAllNotificationsAsRead(_currentUserId);
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshNotifications();
  }

  void _refreshNotifications() {
    setState(() {
      _notificationsStream =
          _friendService.getNotificationsStream(_currentUserId);
    });
  }

  List<GroupedNotification> _groupNotifications(
      List<FollowNotification> rawList) {
    final Map<String, List<FollowNotification>> postGroups = {};
    final Map<String, List<FollowNotification>> messageGroups = {};
    final Map<String, List<FollowNotification>> callGroups = {};
    final List<FollowNotification> others = [];

    for (var n in rawList) {
      if (n.postId != null &&
          (n.type == 'like' || n.type == 'comment' || n.type == 'fuel')) {
        final key = '${n.postId}_${n.type}';
        postGroups.putIfAbsent(key, () => []).add(n);
      } else if (n.type == 'message') {
        messageGroups.putIfAbsent(n.userId, () => []).add(n);
      } else if (n.type == 'call') {
        callGroups.putIfAbsent(n.userId, () => []).add(n);
      } else {
        others.add(n);
      }
    }

    final List<GroupedNotification> grouped = [
      ...postGroups.values.map((list) => GroupedNotification(
            type: list.first.type,
            notifications: list,
            postId: list.first.postId,
            postImage: list.first.postImage,
            createdAt: list.first.createdAt,
            isRead: list.every((n) => n.isRead),
          )),
      ...messageGroups.values.map((list) => GroupedNotification(
            type: 'message',
            notifications: list,
            createdAt: list.first.createdAt,
            isRead: list.every((n) => n.isRead),
          )),
      ...callGroups.values.map((list) => GroupedNotification(
            type: 'call',
            notifications: list,
            createdAt: list.first.createdAt,
            isRead: list.every((n) => n.isRead),
          )),
      ...others.map((n) => GroupedNotification(
            type: n.type,
            notifications: [n],
            createdAt: n.createdAt,
            isRead: n.isRead,
          )),
    ];

    grouped.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return grouped;
  }

  String? _sectionLabel(GroupedNotification g, GroupedNotification? prev) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));

    String label(DateTime dt) {
      final local = dt.toLocal();
      final d = DateTime(local.year, local.month, local.day);
      if (!d.isBefore(today)) return AppL10n.today;
      if (d.isAfter(weekAgo)) return AppL10n.thisWeek;
      return AppL10n.earlier;
    }

    final current = label(g.createdAt);
    if (prev == null) return current;
    return current != label(prev.createdAt) ? current : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── APP BAR ──
          SliverAppBar(
            backgroundColor: kBgColor,
            elevation: 0,
            pinned: true,
            expandedHeight: 100,
            leading: Padding(
              padding: const EdgeInsets.all(10),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white70, size: 16),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShaderMask(
                    shaderCallback: (r) => LinearGradient(
                      colors: [kAccentPurple, kAccentCyan],
                    ).createShader(r),
                    child: const Icon(FontAwesomeIcons.bell,
                        color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    AppL10n.notifications,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
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
                      kAccentPurple.withValues(alpha: 0.15),
                      kBgColor,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── TAKİP İSTEKLERİ ──
          SliverToBoxAdapter(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _friendService.getPendingRequests(_currentUserId),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const SizedBox();
                }
                final requests = snapshot.data!;
                return _FollowRequestsBanner(
                  requests: requests,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserListScreen(
                          title: AppL10n.followRequests,
                          users: requests,
                          listType: 'requests',
                          isOwnList: true,
                        ),
                      ),
                    );
                    if (mounted) setState(() {});
                  },
                );
              },
            ),
          ),

          // ── BİLDİRİM LİSTESİ ──
          StreamBuilder<List<FollowNotification>>(
            stream: _notificationsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: kAccentPurple,
                      strokeWidth: 2,
                    ),
                  ),
                );
              }

              final rawList = snapshot.data ?? [];
              final filteredList = rawList
                  .where((n) =>
                      !(n.type == 'follow' && n.friendshipStatus == 'pending'))
                  .toList();

              if (filteredList.isEmpty) {
                return SliverFillRemaining(
                  child: _EmptyState(),
                );
              }

              final groupedList = _groupNotifications(filteredList);
              final List<dynamic> items = [];
              for (int i = 0; i < groupedList.length; i++) {
                final label =
                    _sectionLabel(groupedList[i], i > 0 ? groupedList[i - 1] : null);
                if (label != null) items.add(label);
                items.add(groupedList[i]);
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = items[index];
                      if (item is String) {
                        return _SectionHeader(label: item);
                      }
                      final group = item as GroupedNotification;
                      final cardIndex = items
                          .sublist(0, index)
                          .whereType<GroupedNotification>()
                          .length;
                      return _NotificationCard(
                        group: group,
                        index: cardIndex,
                        onTap: () => _handleNotificationTap(group),
                      );
                    },
                    childCount: items.length,
                  ),
                ),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  void _handleNotificationTap(GroupedNotification group) async {
    final notif = group.notifications.first;

    if (group.type == 'message' || group.type == 'call') {
      try {
        final roomId = await ChatService().createOrGetChatRoom(notif.userId);
        if (!mounted) return;
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    ChatScreen(roomId: roomId, otherUser: notif.userProfile)));
      } catch (_) {
        if (!mounted) return;
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const MessagesScreen()));
      }
    } else if (group.postId != null) {
      final postRes = await Supabase.instance.client
          .from('posts')
          .select('*, profiles(*), likes(user_id), comments(id)')
          .eq('id', group.postId!)
          .maybeSingle();
      if (!mounted) return;
      if (postRes != null) {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => PostDetailScreen(post: postRes)));
      }
    } else {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => ProfileScreen(userId: notif.userId)));
    }
  }
}

// ── FOLLOW REQUESTS BANNER ──
class _FollowRequestsBanner extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final VoidCallback onTap;

  const _FollowRequestsBanner({required this.requests, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const maxAvatars = 3;
    final displayCount = requests.length.clamp(0, maxAvatars);
    final stackWidth = 36.0 + (displayCount - 1) * 22.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              kAccentPurple.withValues(alpha: 0.22),
              kAccentPurple.withValues(alpha: 0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: kAccentPurple.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            // Stacked avatars
            SizedBox(
              width: stackWidth,
              height: 38,
              child: Stack(
                children: List.generate(displayCount, (i) {
                  final user = requests[displayCount - 1 - i];
                  return Positioned(
                    left: i * 22.0,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: kAccentPurple.withValues(alpha: 0.4),
                            width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: kCardColor,
                        backgroundImage: user['avatar_url'] != null
                            ? NetworkImage(user['avatar_url'])
                            : null,
                        child: user['avatar_url'] == null
                            ? const Icon(Icons.person,
                                color: Colors.white54, size: 16)
                            : null,
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        AppL10n.followRequests,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [kAccentPurple, Color(0xFF9D8BFF)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${requests.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    requests.length == 1
                        ? AppL10n.wantsToFollow(requests[0]['username'] ?? AppL10n.someone)
                        : '${requests[0]['username'] ?? AppL10n.someone} ${AppL10n.andNMorePeople(requests.length - 1)}',
                    style: GoogleFonts.poppins(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: kAccentPurple.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: kAccentPurple.withValues(alpha: 0.3), width: 1),
              ),
              child: const Icon(Icons.chevron_right_rounded,
                  color: kAccentPurple, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

// ── SECTION HEADER ──
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.08),
                ]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label.toUpperCase(),
              style: GoogleFonts.poppins(
                color: Colors.white30,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── EMPTY STATE ──
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: RadialGradient(colors: [
                kAccentPurple.withValues(alpha: 0.15),
                Colors.transparent,
              ]),
              shape: BoxShape.circle,
            ),
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08), width: 1),
              ),
              child: const Icon(FontAwesomeIcons.bellSlash,
                  size: 26, color: Colors.white24),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            AppL10n.noNotifications,
            style: GoogleFonts.poppins(
              color: Colors.white38,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppL10n.noNotificationsSubtitle,
            style: GoogleFonts.poppins(color: Colors.white24, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── BİLDİRİM KARTI ──
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

    final uniqueUsers = group.notifications
        .map((n) => n.userId)
        .toSet()
        .map((id) => group.notifications.firstWhere((n) => n.userId == id))
        .toList();
    final count = uniqueUsers.length;
    final config = _getNotificationConfig(group.type, count);
    final isUnread = !group.isRead;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration:
          Duration(milliseconds: 300 + (index * 35).clamp(0, 250)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, 20 * (1 - value)),
        child: Opacity(opacity: value, child: child),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isUnread
                ? config.color.withValues(alpha: 0.06)
                : kCardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isUnread
                  ? config.color.withValues(alpha: 0.28)
                  : Colors.white.withValues(alpha: 0.06),
              width: isUnread ? 1.2 : 1,
            ),
            boxShadow: isUnread
                ? [
                    BoxShadow(
                      color: config.color.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Unread accent line
                if (isUnread)
                  Container(
                    width: 3,
                    height: 44,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          config.color,
                          config.color.withValues(alpha: 0.3),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  )
                else
                  const SizedBox(width: 0),

                // Avatar stack
                _buildAvatarStack(uniqueUsers, avatarUrl, config, isUnread),
                const SizedBox(width: 14),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              count > 1
                                  ? '$fullName ${AppL10n.andNMorePeople(count - 1)}'
                                  : fullName,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: isUnread
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                fontSize: 13.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(group.createdAt),
                            style: GoogleFonts.poppins(
                              color: isUnread
                                  ? config.color.withValues(alpha: 0.7)
                                  : Colors.white30,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        config.text,
                        style: GoogleFonts.poppins(
                          color: isUnread
                              ? Colors.white60
                              : Colors.white38,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Trailing
                const SizedBox(width: 10),
                _buildTrailing(group, config, isUnread),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarStack(
    List<FollowNotification> users,
    String? primaryAvatarUrl,
    _NotificationConfig config,
    bool isUnread,
  ) {
    const double r = 24.0;
    final bool hasSecond = users.length > 1;
    final double totalWidth = hasSecond ? r * 2 + 14 : r * 2;

    return SizedBox(
      width: totalWidth,
      height: r * 2 + 4,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Second avatar (behind, offset right-bottom)
          if (hasSecond)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isUnread
                        ? config.color.withValues(alpha: 0.3)
                        : kBgColor,
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: r - 6,
                  backgroundColor: kCardColorAlt,
                  backgroundImage:
                      users[1].userProfile['avatar_url'] != null
                          ? NetworkImage(users[1].userProfile['avatar_url'])
                          : null,
                  child: users[1].userProfile['avatar_url'] == null
                      ? const Icon(Icons.person,
                          color: Colors.white54, size: 16)
                      : null,
                ),
              ),
            ),

          // Primary avatar with gradient ring
          Positioned(
            left: 0,
            top: 0,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Gradient ring
                Container(
                  width: r * 2 + 4,
                  height: r * 2 + 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isUnread
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              config.color,
                              config.color.withValues(alpha: 0.3),
                            ],
                          )
                        : LinearGradient(colors: [
                            Colors.white.withValues(alpha: 0.1),
                            Colors.white.withValues(alpha: 0.04),
                          ]),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: CircleAvatar(
                    radius: r,
                    backgroundColor: kCardColorAlt,
                    backgroundImage: primaryAvatarUrl != null
                        ? NetworkImage(primaryAvatarUrl)
                        : null,
                    child: primaryAvatarUrl == null
                        ? Icon(Icons.person, color: Colors.white54, size: r)
                        : null,
                  ),
                ),
                // Type icon badge
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: config.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: kBgColor, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: config.color.withValues(alpha: 0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child:
                        Icon(config.icon, size: 8, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrailing(
      GroupedNotification group, _NotificationConfig config, bool isUnread) {
    if (group.postImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          group.postImage!,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.image, color: Colors.white24, size: 18),
          ),
        ),
      );
    }

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: isUnread ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: config.color.withValues(alpha: isUnread ? 0.35 : 0.15),
          width: 1,
        ),
      ),
      child: Icon(
        group.type == 'follow'
            ? Icons.person_rounded
            : group.type == 'message'
                ? Icons.send_rounded
                : group.type == 'call'
                    ? Icons.phone_rounded
                    : Icons.chevron_right_rounded,
        size: 18,
        color: config.color,
      ),
    );
  }

  _NotificationConfig _getNotificationConfig(String type, int count) {
    switch (type) {
      case 'like':
        return _NotificationConfig(
          icon: FontAwesomeIcons.heart,
          color: kAccentRed,
          text: AppL10n.notifLiked(count),
        );
      case 'comment':
        return _NotificationConfig(
          icon: FontAwesomeIcons.comment,
          color: kAccentBlue,
          text: AppL10n.notifCommented(count),
        );
      case 'fuel':
        return _NotificationConfig(
          icon: FontAwesomeIcons.fire,
          color: kAccentOrange,
          text: AppL10n.notifFueled(count),
        );
      case 'follow':
        return _NotificationConfig(
          icon: FontAwesomeIcons.userPlus,
          color: kAccentPurple,
          text: AppL10n.notifFollowed,
        );
      case 'message':
        return _NotificationConfig(
          icon: FontAwesomeIcons.envelope,
          color: kAccentCyan,
          text: AppL10n.notifMessaged,
        );
      case 'call':
        return _NotificationConfig(
          icon: FontAwesomeIcons.phone,
          color: kAccentGreen,
          text: AppL10n.notifCalled(count),
        );
      default:
        return _NotificationConfig(
          icon: FontAwesomeIcons.bell,
          color: Colors.grey,
          text: AppL10n.newNotification,
        );
    }
  }
}

class _NotificationConfig {
  final IconData icon;
  final Color color;
  final String text;

  _NotificationConfig({
    required this.icon,
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
  final bool isRead;

  GroupedNotification({
    required this.type,
    required this.notifications,
    required this.createdAt,
    required this.isRead,
    this.postId,
    this.postImage,
  });
}
