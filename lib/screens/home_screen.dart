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
import 'search_screen.dart'; // 🔥 YENİ EKRANI İMPORT ETTİK

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FeedService _feedService = FeedService();
  int _currentIndex = 0;

  late final RealtimeChannel _notificationChannel;
  String get _currentUserId => Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    Supabase.instance.client.removeChannel(_notificationChannel);
    super.dispose();
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
            // REDDET
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
            // KATIL
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
                      MaterialPageRoute(
                        builder: (_) => CallScreen(
                          callId: callId,
                          otherUserName: callerProfile['full_name'] ?? 'Kullanıcı',
                          isVideo: false,
                        ),
                      ),
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
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(roomId: roomId, otherUser: userProfile)));
                        }
                      } catch (e) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const MessagesScreen()));
                      }
                    } else if (postId != null) {
                      final postRes = await Supabase.instance.client
                          .from('posts')
                          .select('*, profiles(*), likes(user_id), comments(id)')
                          .eq('id', postId)
                          .maybeSingle();
                      if (postRes != null && mounted) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: postRes)));
                      }
                    } else {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
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
      case 1: return 'Keşfet'; // Artık SearchScreen'in kendi Appbar'ı var ama burası title döndürüyor, sorun değil
      case 3: return 'AI Asistan';
      case 4: return 'Profilim';
      default: return 'Kinnect';
    }
  }

  @override
  Widget build(BuildContext context) {
    // 2. Tab (Keşfet) ve 4. Tab (Profil) kendi Appbar'ını kullanır
    final bool hideAppBar = _currentIndex == 1 || _currentIndex == 4;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: const Color(0xFF050505),
        // Eğer Keşfet (1) veya Profil (4) ise AppBar'ı gizle
        appBar: hideAppBar
            ? null
            : AppBar(
          backgroundColor: const Color(0xFF050505),
          elevation: 0,
          title: Text(
            _getAppBarTitle(),
            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          actions: [
            IconButton(
              icon: const Icon(FontAwesomeIcons.bell, color: Colors.white, size: 22),
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
              },
            ),
            IconButton(
              icon: const Icon(FontAwesomeIcons.paperPlane, color: Colors.white, size: 22),
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MessagesScreen()));
              },
            ),
            IconButton(
              icon: const Icon(FontAwesomeIcons.arrowRightFromBracket, color: Colors.white, size: 22),
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
              },
            ),
          ],
        ),
        body: _buildBody(),
        bottomNavigationBar: _buildBottomNavBar(),
      ),
    );
  }

  // --- BURASI DÜZELTİLDİ: ARTIK ESKİ KOD YOK, DİREKT SEARCH SCREEN VAR ---
  Widget _buildBody() {
    switch (_currentIndex) {
      case 0: return _buildFeed(); // Ana Sayfa
      case 1: return const SearchScreen(); // 🔥 İŞTE BURASI! Yeni ekranı bağlıyoruz.
      case 3: return _buildAiTab();
      case 4: return ProfileScreen(userId: _currentUserId, showBackButton: false);
      default: return _buildFeed();
    }
  }

  Widget _buildFeed() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _feedService.getFriendsFeed(),
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
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 20, top: 10),
          itemCount: posts.length,
          itemBuilder: (context, index) => PostCard(
            post: posts[index],
            onRefresh: () => setState(() {}),
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
      unselectedItemColor: Colors.white54,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      onTap: (index) {
        if (index == 2) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreatePostScreen()));
          return;
        }
        setState(() {
          _currentIndex = index;
        });
      },
      items: const [
        BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.house, size: 22),
            activeIcon: Icon(FontAwesomeIcons.house, size: 24),
            label: ''
        ),
        BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.fire, size: 22), // İkonu ATEŞ yaptık
            activeIcon: Icon(FontAwesomeIcons.fire, size: 24),
            label: ''
        ),
        BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.circlePlus, size: 30),
            activeIcon: Icon(FontAwesomeIcons.circlePlus, size: 30),
            label: ''
        ),
        BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.wandMagicSparkles, size: 22),
            activeIcon: Icon(FontAwesomeIcons.wandMagicSparkles, size: 24),
            label: ''
        ),
        BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.user, size: 22),
            activeIcon: Icon(FontAwesomeIcons.user, size: 24),
            label: ''
        ),
      ],
    );
  }
}

// --- POST CARD (Aynı kalıyor) ---
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

  void _toggleLike() async {
    setState(() => isLiked = !isLiked);
    await FeedService().toggleLike(widget.post['id']);
  }

  void _goToDetail() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: widget.post)));
    if (result == true || mounted) {
      widget.onRefresh();
    }
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
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: p['user_id']))),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF1F1F1F),
                  backgroundImage: profile['avatar_url'] != null ? NetworkImage(profile['avatar_url']) : null,
                  child: profile['avatar_url'] == null ? const Icon(Icons.person, color: Colors.white54) : null,
                ),
              ),
              title: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: p['user_id']))),
                child: Text(profile['full_name'] ?? 'Bilinmiyor', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              subtitle: Text('@${profile['username']}', style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13)),
              trailing: Text(dateStr, style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12)),
            ),
            if (p['content'] != null && p['content'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(p['content'], style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, height: 1.4)),
              ),
            if (p['image_url'] != null)
              GestureDetector(
                onTap: () => _openFullScreen(p['image_url']),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 350),
                  child: Hero(
                    tag: p['image_url'],
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(p['image_url'], fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _toggleLike,
                    child: Row(
                      children: [
                        Icon(isLiked ? FontAwesomeIcons.heart : FontAwesomeIcons.heart,
                            color: isLiked ? Colors.redAccent : Colors.grey,
                            size: 20
                        ),
                        const SizedBox(width: 6),
                        if (likeCount > 0) Text("$likeCount", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: _goToDetail,
                    child: Row(
                      children: [
                        const Icon(FontAwesomeIcons.comment, color: Colors.grey, size: 20),
                        const SizedBox(width: 6),
                        if (commentCount > 0) Text("$commentCount", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const Icon(FontAwesomeIcons.shareFromSquare, color: Colors.grey, size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}