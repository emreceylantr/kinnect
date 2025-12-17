import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Servis ve Ekranlar
import '../services/feed_service.dart';
import '../services/chat_service.dart';
import 'create_post_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'post_detail_screen.dart';
import 'messages_screen.dart';
import 'call_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FeedService _feedService = FeedService();
  int _currentIndex = 0;

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
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
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
          _handleNewNotification(payload.newRecord);
        }
      },
    )
        .subscribe();
  }

  void _handleNewNotification(Map<String, dynamic> data) async {
    final type = data['type'];
    final actorId = data['actor_id'];

    final userRes = await Supabase.instance.client
        .from('profiles')
        .select('username, avatar_url, full_name, id')
        .eq('id', actorId)
        .maybeSingle();

    if (userRes == null || !mounted) return;

    if (type == 'call') {
      _showIncomingCallDialog(userRes);
    } else {
      _showTopNotification(data, userRes);
    }
  }

  void _showIncomingCallDialog(Map<String, dynamic> callerProfile) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              CircleAvatar(
                radius: 45,
                backgroundImage: callerProfile['avatar_url'] != null
                    ? NetworkImage(callerProfile['avatar_url'])
                    : null,
                backgroundColor: const Color(0xFF6C63FF),
                child: callerProfile['avatar_url'] == null
                    ? const Icon(Icons.person, size: 40, color: Colors.white)
                    : null,
              ),
              const SizedBox(height: 20),
              Text(
                "${callerProfile['full_name'] ?? 'Biri'} seni bekliyor...",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "Sohbet odasına katılmak ister misin?",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 20),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            Column(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  iconSize: 50,
                  icon: const CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.redAccent,
                    child: Icon(Icons.call_end, color: Colors.white, size: 28),
                  ),
                ),
                Text("Reddet", style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12))
              ],
            ),
            Column(
              children: [
                IconButton(
                  onPressed: () {
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
                        isVideo: false,
                      )),
                    );
                  },
                  iconSize: 50,
                  icon: const CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.greenAccent,
                    child: Icon(Icons.phone, color: Colors.white, size: 28),
                  ),
                ),
                Text("Katıl", style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12))
              ],
            ),
          ],
        );
      },
    );
  }

  void _showTopNotification(Map<String, dynamic> data, Map<String, dynamic> userProfile) {
    final type = data['type'];
    final postId = data['post_id'];

    String message = '';
    IconData icon = FontAwesomeIcons.bell;
    Color iconColor = Colors.white;

    if (type == 'follow') {
      message = 'seni takip etmek istiyor.';
      icon = FontAwesomeIcons.userPlus;
      iconColor = const Color(0xFF6C63FF);
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
                        final roomId = await ChatService().createOrGetChatRoom(userProfile['id'].toString());
                        if (mounted) {
                          Navigator.push(context, _createSlideRoute(ChatScreen(roomId: roomId, otherUser: userProfile)));
                        }
                      } catch (e) {
                        Navigator.push(context, _createSlideRoute(const MessagesScreen()));
                      }
                    } else if (postId != null) {
                      final postRes = await Supabase.instance.client
                          .from('posts')
                          .select('*, profiles(*), likes(user_id), comments(id)')
                          .eq('id', postId)
                          .maybeSingle();
                      if (postRes != null && mounted) {
                        Navigator.push(context, _createSlideRoute(PostDetailScreen(post: postRes)));
                      }
                    } else {
                      Navigator.push(context, _createSlideRoute(const NotificationsScreen()));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E).withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 5))],
                      border: Border.all(color: Colors.white12, width: 1),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFF333333),
                          backgroundImage: userProfile['avatar_url'] != null ? NetworkImage(userProfile['avatar_url']) : null,
                          child: userProfile['avatar_url'] == null ? Icon(icon, size: 14, color: iconColor) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(userProfile['username'] ?? 'Birisi', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(message, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
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
    Future.delayed(const Duration(seconds: 4), () { if (mounted && !isRemoved) removeOverlay(); });
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0: return 'Ana Akış';
      case 1: return 'Keşfet';
      case 3: return 'AI Asistan';
      case 4: return 'Profilim';
      default: return 'Kinnect';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hideAppBar = _currentIndex == 1 || _currentIndex == 4;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: const Color(0xFF050505),
        appBar: hideAppBar
            ? null
            : AppBar(
          backgroundColor: const Color(0xFF050505),
          elevation: 0,
          title: Text(
            _getAppBarTitle(),
            style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5),
          ),
          actions: [
            IconButton(
              icon: const Icon(FontAwesomeIcons.bell, color: Colors.white, size: 20),
              onPressed: () {
                Navigator.of(context).push(_createSlideRoute(const NotificationsScreen()));
              },
            ),
            IconButton(
              icon: const Icon(FontAwesomeIcons.paperPlane, color: Colors.white, size: 20),
              onPressed: () {
                Navigator.of(context).push(_createSlideRoute(const MessagesScreen()));
              },
            ),
            // 🔥 ÇIKIŞ YAP BUTONU KALDIRILDI
          ],
        ),
        body: _buildBody(),
        bottomNavigationBar: _buildBottomNavBar(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0: return _buildFeed();
      case 1: return const SearchScreen();
      case 3: return _buildAiTab();
      case 4: return ProfileScreen(userId: _currentUserId, showBackButton: false);
      default: return _buildFeed();
    }
  }

  Widget _buildFeed() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _feedFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)));
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
          color: const Color(0xFF6C63FF),
          backgroundColor: const Color(0xFF1E1E1E),
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
          const Icon(FontAwesomeIcons.wandMagicSparkles, size: 60, color: Color(0xFF6C63FF)),
          const SizedBox(height: 20),
          Text('Yapay Zeka Asistanı', style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text('Yakında burada senin için\nöneriler hazırlayacağım!', textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      backgroundColor: const Color(0xFF050505),
      type: BottomNavigationBarType.fixed,
      currentIndex: _currentIndex,
      selectedItemColor: const Color(0xFF6C63FF),
      unselectedItemColor: Colors.grey.shade700,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      iconSize: 24,
      elevation: 0,
      onTap: (index) {
        if (index == 2) {
          Navigator.of(context).push(_createSlideRoute(const CreatePostScreen()));
          return;
        }
        setState(() {
          _currentIndex = index;
        });
      },
      items: const [
        BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.house),
            activeIcon: Icon(FontAwesomeIcons.house, shadows: [Shadow(blurRadius: 10, color: Color(0xFF6C63FF))]),
            label: ''
        ),
        BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.fire),
            activeIcon: Icon(FontAwesomeIcons.fire, shadows: [Shadow(blurRadius: 10, color: Color(0xFF6C63FF))]),
            label: ''
        ),
        BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.circlePlus, size: 32),
            activeIcon: Icon(FontAwesomeIcons.circlePlus, size: 32, shadows: [Shadow(blurRadius: 15, color: Color(0xFF6C63FF))]),
            label: ''
        ),
        BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.wandMagicSparkles),
            activeIcon: Icon(FontAwesomeIcons.wandMagicSparkles, shadows: [Shadow(blurRadius: 10, color: Color(0xFF6C63FF))]),
            label: ''
        ),
        BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.user),
            activeIcon: Icon(FontAwesomeIcons.user, shadows: [Shadow(blurRadius: 10, color: Color(0xFF6C63FF))]),
            label: ''
        ),
      ],
    );
  }
}

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
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }

  void _toggleLike() async {
    setState(() => isLiked = !isLiked);
    await FeedService().toggleLike(widget.post['id']);
  }

  void _goToDetail() async {
    final result = await Navigator.push(context, _createSlideRoute(PostDetailScreen(post: widget.post)));
    if (result == true || mounted) {
      widget.onRefresh();
    }
  }

  void _goToProfile(String userId) {
    Navigator.push(context, _createSlideRoute(ProfileScreen(userId: userId)));
  }

  void _openFullScreen(String url) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.transparent, leading: const BackButton(color: Colors.white)), body: Center(child: InteractiveViewer(child: Image.network(url))))));
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
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ÜST KISIM
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
                          colors: [Color(0xFF6C63FF), Color(0xFF4834D4)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF121212),
                        backgroundImage: profile['avatar_url'] != null ? NetworkImage(profile['avatar_url']) : null,
                        child: profile['avatar_url'] == null ? const Icon(Icons.person, color: Colors.white54, size: 20) : null,
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
                            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                        ),
                        Text(
                          '@${profile['username']}',
                          style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Text(dateStr, style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            ),

            // İÇERİK METNİ
            if (p['content'] != null && p['content'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  p['content'],
                  style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.9), fontSize: 14, height: 1.5),
                ),
              ),

            // GÖRSEL
            if (p['image_url'] != null)
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
                      child: Image.network(p['image_url'], fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),

            // AKSİYON BUTONLARI (PAYLAŞ VE SPACER SİLİNDİ)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Beğen
                  GestureDetector(
                    onTap: _toggleLike,
                    child: Container(
                      color: Colors.transparent,
                      child: Row(
                        children: [
                          Icon(
                            isLiked ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart,
                            color: isLiked ? const Color(0xFF6C63FF) : Colors.grey.shade400,
                            size: 22,
                          ),
                          if (likeCount > 0) ...[
                            const SizedBox(width: 6),
                            Text("$likeCount", style: GoogleFonts.poppins(color: isLiked ? const Color(0xFF6C63FF) : Colors.grey.shade400, fontWeight: FontWeight.w600)),
                          ]
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Yorum
                  GestureDetector(
                    onTap: _goToDetail,
                    child: Container(
                      color: Colors.transparent,
                      child: Row(
                        children: [
                          Icon(FontAwesomeIcons.comment, color: Colors.grey.shade400, size: 22),
                          if (commentCount > 0) ...[
                            const SizedBox(width: 6),
                            Text("$commentCount", style: GoogleFonts.poppins(color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
                          ]
                        ],
                      ),
                    ),
                  ),
                  // 🔥 PAYLAŞ BUTONU VE SPACER KALDIRILDI
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}