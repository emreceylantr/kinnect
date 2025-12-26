// Kinnect - Ana sayfa ve feed ekranı

import 'dart:async';
import 'dart:math'; // 🔥 Matematiksel çizimler için
import 'dart:ui'; // 🔥 Buzlu Cam için
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Servis ve Ekranlar
import '../../services/feed_service.dart';
import '../../services/chat_service.dart';
import '../content/create_post_screen.dart';
import '../social/notifications_screen.dart';
import 'profile_screen.dart';
import '../social/post_detail_screen.dart';
import '../social/messages_screen.dart';
import '../content/call_screen.dart';
import 'search_screen.dart';
import '../../widgets/image_carousel.dart';

import '../../widgets/location_display_sheet.dart';
import '../../widgets/shimmer/post_card_shimmer.dart';
import '../../widgets/double_tap_overlay.dart';
import '../../theme/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FeedService _feedService = FeedService();
  int _currentIndex = 0;

  // 🔥 Bildirim Sayacı
  int _unreadCount = 0;

  late Future<List<Map<String, dynamic>>> _feedFuture;

  late final RealtimeChannel _notificationChannel;
  String get _currentUserId => Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _setupRealtimeSubscription();
    _refreshFeed();
  }

  void _refreshFeed() {
    setState(() {
      _feedFuture = _feedService.getFriendsFeed();
    });
  }

  @override
  void dispose() {
    Supabase.instance.client.removeChannel(_notificationChannel);
    super.dispose();
  }

  Route _createSlideRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeOutQuart;
        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }

  // --- BİLDİRİM VE ARAMA DİNLEME ---
  void _setupRealtimeSubscription() {
    _notificationChannel = Supabase.instance.client
        .channel('public:notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: _currentUserId,
          ),
          callback: (payload) {
            if (mounted) {
              // Bildirim geldiğinde sayacı artır
              setState(() {
                _unreadCount++;
              });
              _handleNewNotification(payload.newRecord);
            }
          },
        )
        .subscribe();
  }

  void _handleNewNotification(Map<String, dynamic> data) async {
    final type = data['type'];
    final actorId = data['actor_id'];
    final isVideo = data['is_video'] ?? false; // 🆕 Video mu sesli mi?

    final userRes = await Supabase.instance.client
        .from('profiles')
        .select('username, avatar_url, full_name, id')
        .eq('id', actorId)
        .maybeSingle();

    if (userRes == null || !mounted) return;

    if (type == 'call') {
      _showIncomingCallDialog(userRes, isVideo); // 🆕 isVideo parametresi
    } else {
      _showTopNotification(data, userRes);
    }
  }

  void _showIncomingCallDialog(
      Map<String, dynamic> callerProfile, bool isVideo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (context) {
        return _IncomingCallPopup(
          callerProfile: callerProfile,
          isVideo: isVideo, // 🆕 Video mu sesli mi göster
          onAccept: () {
            Navigator.pop(context);
            final myId = _currentUserId;
            final otherId = callerProfile['id'].toString();
            List<String> ids = [myId, otherId];
            ids.sort();
            final callId = ids.join("_");

            Navigator.push(
              context,
              _createSlideRoute(CallScreen(
                callId: callId,
                otherUserName: callerProfile['full_name'] ?? 'Kullanıcı',
                isVideo: isVideo, // 🆕 Artık doğru değer!
                otherUserAvatar: callerProfile['avatar_url']?.toString(),
              )),
            );
          },
          onDecline: () => Navigator.pop(context),
        );
      },
    );
  }

  void _showTopNotification(
      Map<String, dynamic> data, Map<String, dynamic> userProfile) {
    final type = data['type'];
    final postId = data['post_id'];

    String message = '';
    IconData icon = FontAwesomeIcons.bell;
    Color iconColor = Colors.white;

    if (type == 'follow') {
      message = 'seni takip etmek istiyor.';
      icon = FontAwesomeIcons.userPlus;
      iconColor = AppColors.primary;
    } else if (type == 'like') {
      message = 'gönderini beğendi.';
      icon = FontAwesomeIcons.heart;
      iconColor = Colors.redAccent;
    } else if (type == 'comment') {
      message = 'yorum yaptı.';
      icon = FontAwesomeIcons.comment;
      iconColor = Colors.blueAccent;
    } else if (type == 'message') {
      message = 'sana bir mesaj gönderdi 💬';
      icon = FontAwesomeIcons.envelope;
      iconColor = Colors.cyanAccent;
    }

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    bool isRemoved = false;

    void removeOverlay() {
      if (!isRemoved && overlayEntry.mounted) {
        isRemoved = true;
        overlayEntry.remove();
      }
    }

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 60,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: -100, end: 0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, value),
                child: GestureDetector(
                  onTap: () async {
                    removeOverlay();
                    if (type == 'message') {
                      try {
                        final roomId = await ChatService()
                            .createOrGetChatRoom(userProfile['id'].toString());
                        if (mounted) {
                          Navigator.push(
                              context,
                              _createSlideRoute(ChatScreen(
                                  roomId: roomId, otherUser: userProfile)));
                        }
                      } catch (e) {
                        Navigator.push(
                            context, _createSlideRoute(const MessagesScreen()));
                      }
                    } else if (postId != null) {
                      final postRes = await Supabase.instance.client
                          .from('posts')
                          .select(
                              '*, profiles(*), likes(user_id), comments(id)')
                          .eq('id', postId)
                          .maybeSingle();
                      if (postRes != null && mounted) {
                        Navigator.push(context,
                            _createSlideRoute(PostDetailScreen(post: postRes)));
                      }
                    } else {
                      Navigator.push(context,
                          _createSlideRoute(const NotificationsScreen()));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 5))
                      ],
                      border: Border.all(color: Colors.white12, width: 1),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFF333333),
                          backgroundImage: userProfile['avatar_url'] != null
                              ? NetworkImage(userProfile['avatar_url'])
                              : null,
                          child: userProfile['avatar_url'] == null
                              ? Icon(icon, size: 14, color: iconColor)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(userProfile['username'] ?? 'Birisi',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              Text(message,
                                  style: GoogleFonts.poppins(
                                      color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && !isRemoved) removeOverlay();
    });
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Ana Akış';
      case 1:
        return 'Keşfet';
      case 3:
        return 'AI Asistan';
      case 4:
        return 'Profilim';
      default:
        return 'Kinnect';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hideAppBar = _currentIndex == 1 || _currentIndex == 4;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: AppColors.bgDark,
        appBar: hideAppBar
            ? null
            : AppBar(
                backgroundColor: AppColors.bgDark,
                elevation: 0,
                title: Text(
                  _getAppBarTitle(),
                  style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5),
                ),
                actions: [
                  // --- HİZALI KAWAII ÇAN ---
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4.0),
                      child: KawaiiBellIcon(
                        notificationCount: _unreadCount,
                        onTap: () {
                          setState(() => _unreadCount = 0);
                          Navigator.of(context).push(
                              _createSlideRoute(const NotificationsScreen()));
                        },
                      ),
                    ),
                  ),

                  // 🔥 YENİ: PARLAMAYAN, DÜZ YEŞİL MESAJ İKONU 🔥
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0, left: 4.0),
                    child: CyberMessageButton(
                      onTap: () {
                        Navigator.of(context)
                            .push(_createSlideRoute(const MessagesScreen()));
                      },
                    ),
                  ),
                ],
              ),
        body: _buildBody(),
        bottomNavigationBar: _buildBottomNavBar(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildFeed();
      case 1:
        return const SearchScreen();
      case 3:
        return _buildAiTab();
      case 4:
        return ProfileScreen(userId: _currentUserId, showBackButton: false);
      default:
        return _buildFeed();
    }
  }

  Widget _buildFeed() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _feedFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 3,
            itemBuilder: (context, index) => const PostCardShimmer(),
          );
        }
        final posts = snapshot.data ?? [];
        if (posts.isEmpty) {
          return Center(
            child: Text(
              'Akış boş.',
              style: GoogleFonts.poppins(color: Colors.white54),
            ),
          );
        }
        return RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.bgCard,
          onRefresh: () async {
            _refreshFeed();
            await _feedFuture;
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 30),
            itemCount: posts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) => PostCard(
              post: posts[index],
              onRefresh: _refreshFeed,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAiTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(FontAwesomeIcons.wandMagicSparkles,
              size: 60, color: AppColors.primary),
          const SizedBox(height: 20),
          Text('Yapay Zeka Asistanı',
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text('Yakında burada senin için\nöneriler hazırlayacağım!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      backgroundColor: AppColors.bgDark,
      type: BottomNavigationBarType.fixed,
      currentIndex: _currentIndex,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: Colors.grey.shade700,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      iconSize: 24,
      elevation: 0,
      onTap: (index) {
        if (index == 2) {
          Navigator.of(context)
              .push(_createSlideRoute(const CreatePostScreen()));
          return;
        }
        setState(() {
          _currentIndex = index;
        });
      },
      items: const [
        BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.house),
            activeIcon: Icon(FontAwesomeIcons.house,
                shadows: [Shadow(blurRadius: 10, color: AppColors.primary)]),
            label: ''),
        BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.fire),
            activeIcon: Icon(FontAwesomeIcons.fire,
                shadows: [Shadow(blurRadius: 10, color: AppColors.primary)]),
            label: ''),
        BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.circlePlus, size: 32),
            activeIcon: Icon(FontAwesomeIcons.circlePlus,
                size: 32,
                shadows: [Shadow(blurRadius: 15, color: AppColors.primary)]),
            label: ''),
        BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.wandMagicSparkles),
            activeIcon: Icon(FontAwesomeIcons.wandMagicSparkles,
                shadows: [Shadow(blurRadius: 10, color: AppColors.primary)]),
            label: ''),
        BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.user),
            activeIcon: Icon(FontAwesomeIcons.user,
                shadows: [Shadow(blurRadius: 10, color: AppColors.primary)]),
            label: ''),
      ],
    );
  }
}

// 🔔 KAWAII ÇAN WIDGET 🔔
class KawaiiBellIcon extends StatefulWidget {
  final int notificationCount;
  final VoidCallback onTap;

  const KawaiiBellIcon({
    super.key,
    required this.notificationCount,
    required this.onTap,
  });

  @override
  State<KawaiiBellIcon> createState() => _KawaiiBellIconState();
}

class _KawaiiBellIconState extends State<KawaiiBellIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool hasNotification = widget.notificationCount > 0;

    if (hasNotification) {
      _controller.stop();
    } else {
      if (!_controller.isAnimating) _controller.repeat();
    }

    final Color bellColor = AppColors.primary; // TEMA MORU
    final Color faceColor = Colors.white; // BEYAZ YÜZ

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 40,
        height: 40,
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!hasNotification)
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Positioned(
                    top: 0 + (3 * (1 - _controller.value)),
                    right: 2 + (3 * _controller.value),
                    child: Opacity(
                      opacity: 1 - _controller.value,
                      child: Transform.scale(
                        scale: 0.6 + (_controller.value * 0.4),
                        child: Text(
                          "zZz",
                          style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  );
                },
              ),
            Icon(FontAwesomeIcons.solidBell, size: 26, color: bellColor),
            Positioned(
              top: hasNotification ? 18 : 16,
              child: hasNotification
                  ? _buildAwakeFace(faceColor)
                  : _buildSleepingFace(faceColor),
            ),
            if (hasNotification)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 14, minHeight: 14),
                  child: Text(
                    widget.notificationCount > 9
                        ? '9+'
                        : widget.notificationCount.toString(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepingFace(Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.keyboard_arrow_down_rounded, size: 9, color: color),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down_rounded, size: 9, color: color),
          ],
        ),
        const SizedBox(height: 1),
        _buildSnoreBubble(color),
      ],
    );
  }

  Widget _buildSnoreBubble(Color color) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        double scale = 0.6 + (sin(_controller.value * pi) * 0.4);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
                color: color.withOpacity(0.5),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 0.8)),
          ),
        );
      },
    );
  }

  Widget _buildAwakeFace(Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildEye(color),
            const SizedBox(width: 6),
            _buildEye(color),
          ],
        ),
        const SizedBox(height: 2),
        Container(
          width: 9,
          height: 4,
          decoration: BoxDecoration(
              color: Colors.transparent,
              border: Border(bottom: BorderSide(color: color, width: 1.5)),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(8))),
        ),
      ],
    );
  }

  Widget _buildEye(Color color) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
            width: 5.5,
            height: 5.5,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle)),
        Container(
            width: 3,
            height: 3,
            decoration: const BoxDecoration(
                color: Colors.black, shape: BoxShape.circle)),
      ],
    );
  }
}

// 🔥🔥 YENİ: PARLAMAYAN, YEŞİL CYBER MESAJ İKONU 🔥🔥
class CyberMessageButton extends StatelessWidget {
  final VoidCallback onTap;

  const CyberMessageButton({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 🔥 RENK: Neon Yeşil
    const neonGreen = Color(0xFF69F0AE);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            // 🔥 SHADOW/GLOW KALDIRILDI
          ),
          child: CustomPaint(
            painter: _ChatBubblePainter(neonGreen),
          ),
        ),
      ),
    );
  }
}

class _ChatBubblePainter extends CustomPainter {
  final Color color;

  _ChatBubblePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color; // 🔥 YEŞİL RENK

    // --- 1. BALONCUK ŞEKLİ (KÜÇÜK) ---
    const double padding = 7.0;
    const double cornerRadius = 6.0;

    final Path path = Path();

    path.moveTo(padding + cornerRadius, padding);
    path.lineTo(size.width - padding - cornerRadius, padding);
    path.arcToPoint(Offset(size.width - padding, padding + cornerRadius),
        radius: const Radius.circular(cornerRadius));
    path.lineTo(size.width - padding, size.height - padding - 6);

    // 🔥 KUYRUK
    path.lineTo(size.width - padding + 1.5, size.height - padding + 1.5);
    path.lineTo(size.width - padding - 5, size.height - padding);

    path.lineTo(padding + cornerRadius, size.height - padding);
    path.arcToPoint(Offset(padding, size.height - padding - cornerRadius),
        radius: const Radius.circular(cornerRadius));
    path.lineTo(padding, padding + cornerRadius);
    path.arcToPoint(Offset(padding + cornerRadius, padding),
        radius: const Radius.circular(cornerRadius));

    canvas.drawPath(path, paint);

    // --- 2. İÇERİK ÇİZGİLERİ ---
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..color = color;

    final centerX = size.width / 2;
    final centerY = (padding + (size.height - padding)) / 2 - 1;

    canvas.drawLine(
      Offset(centerX - 5, centerY - 2.5),
      Offset(centerX + 5, centerY - 2.5),
      linePaint,
    );

    canvas.drawLine(
      Offset(centerX - 5, centerY + 2.5),
      Offset(centerX, centerY + 2.5),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// 🔥 BUZLU CAM (GLASSMORPHISM) EFEKTLİ POST KARTI 🔥
class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback onRefresh;
  const PostCard({super.key, required this.post, required this.onRefresh});
  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool isLiked = false;
  final String myId = Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    final likes = widget.post['likes'] as List<dynamic>? ?? [];
    isLiked = likes.any((l) => l['user_id'] == myId);
  }

  Route _createSlideRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeOutQuart;
        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }

  void _toggleLike() async {
    setState(() => isLiked = !isLiked);
    await FeedService().toggleLike(widget.post['id']);
  }

  void _goToDetail() async {
    final result = await Navigator.push(
        context, _createSlideRoute(PostDetailScreen(post: widget.post)));
    if (result == true || mounted) {
      widget.onRefresh();
    }
  }

  void _goToProfile(String userId) {
    Navigator.push(context, _createSlideRoute(ProfileScreen(userId: userId)));
  }

  void _openFullScreen(String url) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => Scaffold(
                backgroundColor: Colors.black,
                appBar: AppBar(
                    backgroundColor: Colors.transparent,
                    leading: const BackButton(color: Colors.white)),
                body: Center(
                    child: InteractiveViewer(child: Image.network(url))))));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final profile = p['profiles'] ?? {};
    final date = DateTime.tryParse(p['created_at'] ?? '');
    final dateStr = date != null ? '${date.day}/${date.month}' : '';
    final likeCount = (p['likes'] as List?)?.length ?? 0;
    final commentCount = (p['comments'] as List?)?.length ?? 0;

    return GestureDetector(
      onTap: _goToDetail,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(24),
                border:
                    Border.all(color: Colors.white.withOpacity(0.1), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => _goToProfile(p['user_id']),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.primaryDark
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.bgCardDark,
                              backgroundImage: profile['avatar_url'] != null
                                  ? NetworkImage(profile['avatar_url'])
                                  : null,
                              child: profile['avatar_url'] == null
                                  ? const Icon(Icons.person,
                                      color: Colors.white54, size: 20)
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () => _goToProfile(p['user_id']),
                                child: Text(
                                  profile['full_name'] ?? 'Bilinmiyor',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15),
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    '@${profile['username']}',
                                    style: GoogleFonts.poppins(
                                        color: Colors.grey.shade400,
                                        fontSize: 13),
                                  ),
                                  if (p['location'] != null &&
                                      p['location'].toString().isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    const Icon(Icons.location_on,
                                        color: AppColors.primary, size: 12),
                                    const SizedBox(width: 2),
                                    GestureDetector(
                                      onTap: () => showLocationDisplaySheet(
                                          context, p['location']),
                                      child: Container(
                                        constraints:
                                            const BoxConstraints(maxWidth: 120),
                                        color: Colors
                                            .transparent, // Tıklama alanı için
                                        child: Text(
                                          p['location'],
                                          style: GoogleFonts.poppins(
                                              color: AppColors.primary,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        Text(dateStr,
                            style: GoogleFonts.poppins(
                                color: Colors.grey.shade400, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (p['content'] != null &&
                      p['content'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: Text(
                        p['content'],
                        style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 14,
                            height: 1.5),
                      ),
                    ),
                  if (p['image_urls'] != null &&
                      (p['image_urls'] as List).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: DoubleTapOverlay(
                        onDoubleTap: _toggleLike,
                        icon: Icons.favorite,
                        iconColor: Colors.red,
                        child: ImageCarousel(
                          imageUrls: (p['image_urls'] as List).cast<String>(),
                          height: 350,
                          borderRadius: BorderRadius.circular(18),
                          onImageTap: (url) => _openFullScreen(url),
                          musicTrackName: p['spotify_track_name'],
                          musicArtistName: p['spotify_artist_name'],
                          postId: p['id'],
                        ),
                      ),
                    )
                  else if (p['image_url'] != null)
                    GestureDetector(
                      onTap: () => _openFullScreen(p['image_url']),
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                        width: double.infinity,
                        constraints: const BoxConstraints(maxHeight: 400),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Hero(
                          tag: p['image_url'],
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.network(p['image_url'],
                                fit: BoxFit.cover),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _toggleLike,
                          child: Container(
                            color: Colors.transparent,
                            child: Row(
                              children: [
                                Icon(
                                  isLiked
                                      ? FontAwesomeIcons.solidHeart
                                      : FontAwesomeIcons.heart,
                                  color: isLiked
                                      ? AppColors.primary
                                      : Colors.grey.shade400,
                                  size: 22,
                                ),
                                if (likeCount > 0) ...[
                                  const SizedBox(width: 6),
                                  Text("$likeCount",
                                      style: GoogleFonts.poppins(
                                          color: isLiked
                                              ? AppColors.primary
                                              : Colors.grey.shade400,
                                          fontWeight: FontWeight.w600)),
                                ]
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        GestureDetector(
                          onTap: _goToDetail,
                          child: Container(
                            color: Colors.transparent,
                            child: Row(
                              children: [
                                Icon(FontAwesomeIcons.comment,
                                    color: Colors.grey.shade400, size: 22),
                                if (commentCount > 0) ...[
                                  const SizedBox(width: 6),
                                  Text("$commentCount",
                                      style: GoogleFonts.poppins(
                                          color: Colors.grey.shade400,
                                          fontWeight: FontWeight.w600)),
                                ]
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 🔥🔥🔥 PREMIUM GELEN ARAMA POPUP'I 🔥🔥🔥
class _IncomingCallPopup extends StatefulWidget {
  final Map<String, dynamic> callerProfile;
  final bool isVideo; // 🆕 Görüntülü mü sesli mi?
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _IncomingCallPopup({
    required this.callerProfile,
    required this.isVideo,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<_IncomingCallPopup> createState() => _IncomingCallPopupState();
}

class _IncomingCallPopupState extends State<_IncomingCallPopup>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _ringController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _ringAnimation;

  @override
  void initState() {
    super.initState();

    // Pulse animasyonu (avatar etrafındaki halkalar)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    // Ring animasyonu (telefon titremesi)
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..repeat(reverse: true);

    _ringAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callerName = widget.callerProfile['full_name'] ?? 'Biri';
    final callerAvatar = widget.callerProfile['avatar_url'];
    final callerUsername = widget.callerProfile['username'] ?? '';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF2D2638).withOpacity(0.95),
                  const Color(0xFF1A1525).withOpacity(0.98),
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 40,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 📞 Üst başlık
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _ringAnimation,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _ringAnimation.value,
                          child: Icon(
                            widget.isVideo
                                ? Icons.videocam_rounded
                                : Icons.phone_in_talk_rounded,
                            color: const Color(0xFF69F0AE),
                            size: 20,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.isVideo ? "Görüntülü Arama" : "Sesli Arama",
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF69F0AE),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // 🎯 Avatar ve animasyonlu halkalar
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulsing halkalar
                      ...List.generate(3, (index) {
                        return AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            final delay = index * 0.3;
                            final value = (_pulseAnimation.value - 1.0 + delay)
                                .clamp(0.0, 0.5);
                            return Container(
                              width: 100 + (value * 100),
                              height: 100 + (value * 100),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primary
                                      .withOpacity(0.5 - value),
                                  width: 2,
                                ),
                              ),
                            );
                          },
                        );
                      }),

                      // Gradient border
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primary,
                              Color(0xFF9D89D9),
                              AppColors.primary,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(3),
                        child: CircleAvatar(
                          radius: 47,
                          backgroundColor: const Color(0xFF1A1525),
                          backgroundImage: callerAvatar != null
                              ? NetworkImage(callerAvatar)
                              : null,
                          child: callerAvatar == null
                              ? const Icon(Icons.person,
                                  size: 45, color: Colors.white54)
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 👤 İsim ve kullanıcı adı
                Text(
                  callerName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                if (callerUsername.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    "@$callerUsername",
                    style: GoogleFonts.poppins(
                      color: Colors.white38,
                      fontSize: 14,
                    ),
                  ),
                ],
                const SizedBox(height: 8),

                // 💬 Alt metin
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "Sohbet odasına katılmak istiyor",
                    style: GoogleFonts.poppins(
                      color: Colors.white60,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // 🔘 Butonlar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // ❌ Reddet butonu
                    _buildActionButton(
                      icon: Icons.call_end_rounded,
                      label: "Reddet",
                      gradientColors: [
                        const Color(0xFFFF5252),
                        const Color(0xFFD32F2F),
                      ],
                      shadowColor: const Color(0xFFFF5252),
                      onTap: widget.onDecline,
                    ),

                    // ✅ Kabul et butonu
                    _buildActionButton(
                      icon: Icons.phone_rounded,
                      label: "Katıl",
                      gradientColors: [
                        const Color(0xFF69F0AE),
                        const Color(0xFF00C853),
                      ],
                      shadowColor: const Color(0xFF69F0AE),
                      onTap: widget.onAccept,
                      isAccept: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required List<Color> gradientColors,
    required Color shadowColor,
    required VoidCallback onTap,
    bool isAccept = false,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isAccept ? 70 : 60,
            height: isAccept ? 70 : 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              boxShadow: [
                BoxShadow(
                  color: shadowColor.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: isAccept ? 32 : 28,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white60,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
