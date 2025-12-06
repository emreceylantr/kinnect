import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Servis ve Ekranlar
import '../services/feed_service.dart';
import '../services/chat_service.dart'; // Chat servisi eklendi
import 'create_post_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'post_detail_screen.dart';
import 'messages_screen.dart';
import 'call_screen.dart'; // Arama ekranı

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FeedService _feedService = FeedService();
  int _currentIndex = 0;

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;
  late final RealtimeChannel _notificationChannel;

  String get _currentUserId => Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    Supabase.instance.client.removeChannel(_notificationChannel);
    super.dispose();
  }

  // --- FLASH BİLDİRİM VE ARAMA YAKALAMA ---
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

  // Gelen bildirimi işle
  void _handleNewNotification(Map<String, dynamic> data) async {
    final type = data['type'];
    final actorId = data['actor_id'];

    // Bildirimi yapan kişiyi bul
    final userRes = await Supabase.instance.client
        .from('profiles')
        .select('username, avatar_url, full_name, id')
        .eq('id', actorId)
        .maybeSingle();

    if (userRes == null || !mounted) return;

    // --- SENARYO 1: ARAMA (CALL) -> DIALOG ---
    if (type == 'call') {
      _showIncomingCallDialog(userRes);
    }
    // --- SENARYO 2: DİĞER BİLDİRİMLER -> BANNER ---
    else {
      _showTopNotification(data, userRes);
    }
  }

  // --- GELEN ARAMA PENCERESİ (DIALOG) ---
  void _showIncomingCallDialog(Map<String, dynamic> callerProfile) {
    showDialog(
      context: context,
      barrierDismissible: false, // Boşluğa basınca kapanmasın
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
                    Navigator.pop(context); // Dialogu kapat

                    // Oda ID'sini oluştur (Aynı mantık: İsimleri birleştir)
                    final myId = _currentUserId;
                    final otherId = callerProfile['id'].toString();
                    List<String> ids = [myId, otherId];
                    ids.sort();
                    final callId = ids.join("_");

                    // Direkt CallScreen'e at
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CallScreen(
                          callId: callId,
                          otherUserName: callerProfile['full_name'] ?? 'Kullanıcı',
                          isVideo: false, // Sesli olarak katıl
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

  // --- FLASH BİLDİRİM (BANNER) ---
  void _showTopNotification(Map<String, dynamic> data, Map<String, dynamic> userProfile) {
    final type = data['type'];
    final postId = data['post_id'];

    String message = '';
    IconData icon = Icons.notifications;
    Color iconColor = Colors.white;

    if (type == 'follow') {
      message = 'seni takip etmek istiyor.';
      icon = Icons.person_add;
      iconColor = const Color(0xFF6C63FF);
    } else if (type == 'like') {
      message = 'gönderini beğendi.';
      icon = Icons.favorite;
      iconColor = Colors.redAccent;
    } else if (type == 'comment') {
      message = 'yorum yaptı.';
      icon = Icons.chat_bubble;
      iconColor = Colors.blueAccent;
    } else if (type == 'message') { // MESAJ BİLDİRİMİ EKLENDİ ✅
      message = 'sana bir mesaj gönderdi 💬';
      icon = Icons.mail_outline;
      iconColor = Colors.cyanAccent;
    } else {
      return;
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

                    // --- TIKLAMA YÖNLENDİRMELERİ ---
                    if (type == 'message') {
                      // Mesajsa: Odayı bul ve Chate git
                      try {
                        final roomId = await ChatService().createOrGetChatRoom(userProfile['id'].toString());
                        if (mounted) {
                          Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ChatScreen(
                                roomId: roomId,
                                otherUser: userProfile,
                              ))
                          );
                        }
                      } catch (e) {
                        // Hata olursa en azından mesajlar listesine git
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const MessagesScreen()));
                      }
                    } else if (postId != null) {
                      // Post Bildirimi
                      final postRes = await Supabase.instance.client
                          .from('posts')
                          .select('*, profiles(*), likes(user_id), comments(id)')
                          .eq('id', postId)
                          .maybeSingle();
                      if (postRes != null && mounted) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: postRes)));
                      }
                    } else {
                      // Takip vb.
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E).withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 5))
                      ],
                      border: Border.all(color: Colors.white12, width: 1),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFF333333),
                          backgroundImage: userProfile['avatar_url'] != null ? NetworkImage(userProfile['avatar_url']) : null,
                          child: userProfile['avatar_url'] == null ? Icon(icon, size: 16, color: iconColor) : null,
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

  // --- ARAMA (STANDART) ---
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.trim().isEmpty) {
        setState(() { _isSearching = false; _searchResults = []; });
        return;
      }
      setState(() => _isSearching = true);
      try {
        final response = await Supabase.instance.client
            .from('profiles')
            .select()
            .ilike('username', '%$query%')
            .neq('id', _currentUserId)
            .limit(10);
        if (mounted) {
          setState(() {
            _searchResults = List<Map<String, dynamic>>.from(response as List);
          });
        }
      } catch (e) {
        debugPrint('Arama hatası: $e');
      }
    });
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
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: const Color(0xFF050505),
        appBar: _currentIndex == 4
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
              icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
              },
            ),
            IconButton(
              icon: const Icon(Icons.near_me_outlined, color: Colors.white),
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MessagesScreen()));
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.white),
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

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0: return _buildFeed(false);
      case 1: return _buildSearchAndExplore();
      case 3: return _buildAiTab();
      case 4: return ProfileScreen(userId: _currentUserId, showBackButton: false);
      default: return _buildFeed(false);
    }
  }

  Widget _buildFeed(bool isExplore) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: isExplore ? _feedService.getExploreFeed() : _feedService.getFriendsFeed(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)));
        }
        final posts = snapshot.data ?? [];
        if (posts.isEmpty) {
          return Center(
            child: Text(
              isExplore ? 'Keşfedilecek gönderi yok.' : 'Akış boş.',
              style: GoogleFonts.poppins(color: Colors.white54),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 20),
          itemCount: posts.length,
          itemBuilder: (context, index) => PostCard(
            post: posts[index],
            onRefresh: () => setState(() {}),
          ),
        );
      },
    );
  }

  Widget _buildSearchAndExplore() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Arkadaş ara...',
              hintStyle: TextStyle(color: Colors.grey.shade600),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF6C63FF)),
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
            ),
          ),
        ),
        Expanded(child: _searchController.text.isNotEmpty ? _buildUserSearchResults() : _buildFeed(true)),
      ],
    );
  }

  Widget _buildUserSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(child: Text('Kullanıcı bulunamadı', style: GoogleFonts.poppins(color: Colors.white54)));
    }
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: user['avatar_url'] != null ? NetworkImage(user['avatar_url']) : null,
            backgroundColor: const Color(0xFF6C63FF),
            child: user['avatar_url'] == null ? const Icon(Icons.person, color: Colors.white) : null,
          ),
          title: Text(user['username'] ?? 'Adsız', style: GoogleFonts.poppins(color: Colors.white)),
          subtitle: Text(user['full_name'] ?? '', style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12)),
          trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: user['id'])));
          },
        );
      },
    );
  }

  Widget _buildAiTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(FontAwesomeIcons.robot, size: 60, color: Color(0xFF6C63FF)),
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
          _searchController.clear();
          _isSearching = false;
        });
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: ''),
        BottomNavigationBarItem(icon: Icon(Icons.search), label: ''),
        BottomNavigationBarItem(icon: Icon(Icons.add_box_outlined), label: ''),
        BottomNavigationBarItem(icon: Icon(Icons.smart_toy_outlined), label: ''),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: ''),
      ],
    );
  }
}

// --- POST CARD ---
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
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: p['user_id']))),
                child: CircleAvatar(radius: 18, backgroundColor: const Color(0xFF6C63FF), backgroundImage: profile['avatar_url'] != null ? NetworkImage(profile['avatar_url']) : null, child: profile['avatar_url'] == null ? const Icon(Icons.person, color: Colors.white) : null),
              ),
              title: GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: p['user_id']))), child: Text(profile['full_name'] ?? 'Bilinmiyor', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14))),
              subtitle: Text('@${profile['username']}', style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12)),
              trailing: Text(dateStr, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11)),
            ),
            if (p['content'] != null && p['content'].toString().isNotEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Text(p['content'], style: GoogleFonts.poppins(color: Colors.white, fontSize: 14))),
            if (p['image_url'] != null) GestureDetector(onTap: () => _openFullScreen(p['image_url']), child: Container(margin: const EdgeInsets.only(top: 8), width: double.infinity, height: 300, child: Hero(tag: p['image_url'], child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(p['image_url'], fit: BoxFit.cover))))),
            Padding(padding: const EdgeInsets.all(12), child: Row(children: [GestureDetector(onTap: _toggleLike, child: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : Colors.white70, size: 26)), if (likeCount > 0) Padding(padding: const EdgeInsets.only(left: 6), child: Text("$likeCount", style: const TextStyle(color: Colors.white70))), const SizedBox(width: 16), GestureDetector(onTap: _goToDetail, child: const Icon(Icons.chat_bubble_outline, color: Colors.white70, size: 24)), if (commentCount > 0) Padding(padding: const EdgeInsets.only(left: 6), child: Text("$commentCount", style: const TextStyle(color: Colors.white70))), const Spacer(), const Icon(Icons.share_outlined, color: Colors.white70, size: 24)])),
          ],
        ),
      ),
    );
  }
}