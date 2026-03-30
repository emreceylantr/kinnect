// Kinnect - Ana sayfa ve feed ekranı

import 'dart:async';
import 'dart:ui'; // 🔥 Buzlu Cam için (ImageFilter)
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Servis ve Ekranlar
import '../../../core/language/app_l10n.dart';
import '../../../data/services/feed_service.dart';
import '../../../data/services/chat_service.dart';
import '../../../data/services/friend_service.dart'; // 🆕 FriendService eklendi
import '../../create_post/screens/create_post_screen.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../post/screens/post_detail_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../chat/screens/messages_screen.dart';
import '../../chat/screens/chat_screen.dart';
import '../../chat/screens/call_screen.dart';
import '../../search/screens/search_screen.dart';
import '../../ai_matching/screens/ai_matching_screen.dart';

// Widget'lar
import '../../../shared/widgets/shimmer/post_card_shimmer.dart';
import '../widgets/appbar_buttons.dart';
import '../widgets/post_card.dart';
import '../../../core/theme/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final FeedService _feedService = FeedService();
  final FriendService _friendService =
      FriendService(); // 🆕 FriendService eklendi
  int _currentIndex = 0;

  // 🔥 Bildirim Sayacı
  int _unreadCount = 0;

  late Future<List<Map<String, dynamic>>> _feedFuture;

  late final RealtimeChannel _notificationChannel;
  String get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 🆕 Observer eklendi
    _setupRealtimeSubscription();
    _refreshFeed();
    _fetchUnreadCount(); // 🆕 Başlangıçta sayıyı çek
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Uygulama öne geldiğinde okunmamış bildirim sayısını güncelle
      _fetchUnreadCount();
      // Feed'i de yenilemek istersen: _refreshFeed();
    }
  }

  Future<void> _fetchUnreadCount() async {
    if (_currentUserId.isEmpty) return;
    try {
      final count =
          await _friendService.getUnreadNotificationCount(_currentUserId);
      if (mounted) {
        setState(() {
          _unreadCount = count;
        });
      }
    } catch (e) {
      debugPrint("Bildirim sayısı alınamadı: $e");
    }
  }

  void _refreshFeed() {
    setState(() {
      _feedFuture = _feedService.getFriendsFeed();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // 🆕 Observer kaldırıldı
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
                otherUserName: callerProfile['full_name'] ?? AppL10n.user,
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
      message = AppL10n.notifFollowRequest;
      icon = FontAwesomeIcons.userPlus;
      iconColor = AppColors.primary;
    } else if (type == 'like') {
      message = AppL10n.notifLikedPost;
      icon = FontAwesomeIcons.heart;
      iconColor = Colors.redAccent;
    } else if (type == 'comment') {
      message = AppL10n.notifCommentedPost;
      icon = FontAwesomeIcons.comment;
      iconColor = Colors.blueAccent;
    } else if (type == 'message') {
      message = AppL10n.notifSentMessage;
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
                        if (mounted) {
                          Navigator.push(context,
                              _createSlideRoute(const MessagesScreen()));
                        }
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
                      if (mounted) {
                        Navigator.push(context,
                            _createSlideRoute(const NotificationsScreen()));
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
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
                              Text(userProfile['username'] ?? AppL10n.someone,
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
        return AppL10n.homeFeed;
      case 1:
        return AppL10n.explore;
      case 3:
        return AppL10n.aiAssistant;
      case 4:
        return AppL10n.myProfile;
      default:
        return 'Kinnect';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hideAppBar =
        _currentIndex == 1 || _currentIndex == 3 || _currentIndex == 4;

    return PopScope(
      canPop: false,
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
                  // --- 🔥 BİLDİRİM ÇANI (Padding kalktı, birbirine yanaştı) 🔥 ---
                  LottieBellButton(
                    notificationCount: _unreadCount,
                    onTap: () async {
                      setState(() => _unreadCount = 0);
                      await Navigator.of(context)
                          .push(_createSlideRoute(const NotificationsScreen()));
                      // Geri dönünce garanti olsun diye tekrar çek
                      _fetchUnreadCount();
                    },
                  ),

                  // 🔥 MESAJ İKONU (Sadece sağa margin var, sola yok) 🔥
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
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
              AppL10n.feedEmpty,
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
    return const AiMatchingScreen();
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

// 🆕 LottieBellButton, CyberMessageButton ve PostCard artık ayrı dosyalarda:
// - lib/widgets/appbar_buttons.dart
// - lib/widgets/post_card.dart

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
    final callerName = widget.callerProfile['full_name'] ?? AppL10n.someone;
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
                      widget.isVideo ? AppL10n.incomingVideoCall : AppL10n.incomingVoiceCall,
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
                    AppL10n.wantsToJoinRoom,
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
                      label: AppL10n.decline,
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
                      label: AppL10n.join,
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
