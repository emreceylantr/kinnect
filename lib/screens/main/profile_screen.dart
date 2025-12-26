// Kinnect - Kullanıcı profil ekranı

import 'dart:async';
import 'dart:io';
import 'dart:ui'; // 🔥 BUZLU CAM İÇİN GEREKLİ
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:video_player/video_player.dart'; // 🎥 LIVE VIDEO OYNATICI

// --- SERVİSLER ---
import '../../services/feed_service.dart';
import '../../services/chat_service.dart';
import '../../services/safety_service.dart';

// --- WIDGET IMPORTU ---
import '../../widgets/music_player_card.dart';
import '../../widgets/image_carousel.dart';
import '../../theme/app_colors.dart';

// --- EKRANLAR ---
import '../social/messages_screen.dart';
import '../social/post_detail_screen.dart';
import '../social/follow_list_screen.dart';
import '../settings/edit_profile_screen.dart';
import '../../widgets/shimmer/profile_header_shimmer.dart';
import '../auth/login_screen.dart';

// 🔥🔥🔥 ÖZEL "ALTIN NEON TAÇ" ADMIN ROZETİ WIDGET'I 🔥🔥🔥
class AdminBadge extends StatelessWidget {
  final double size;
  const AdminBadge({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFF6D00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFAB00).withOpacity(0.6),
            blurRadius: 12.0,
            spreadRadius: 2.0,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          FontAwesomeIcons.crown,
          color: Colors.white,
          size: size * 0.55,
        ),
      ),
    );
  }
}
// 🔥🔥🔥 ROZET WIDGET SONU 🔥🔥🔥

class ProfileScreen extends StatefulWidget {
  final String userId;
  final bool showBackButton;

  const ProfileScreen({
    super.key,
    required this.userId,
    this.showBackButton = true,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Mevcut kullanıcı ID'si
  final String _currentUserId = Supabase.instance.client.auth.currentUser!.id;

  // Servisler
  final ChatService _chatService = ChatService();
  final SafetyService _safetyService = SafetyService();

  // Veri Değişkenleri
  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _userPosts = [];

  // Sayaçlar
  int _followersCount = 0;
  int _followingCount = 0;
  int _postCount = 0;

  // Durum Kontrolleri
  bool _isLoading = true;
  String _friendshipStatus = 'none';
  bool _isBlockedByMe = false;

  // 🎥 LIVE VIDEO DEĞİŞKENLERİ
  VideoPlayerController? _videoController;
  bool _isPlayingLiveVideo = false; // Ekrana basılı tutuluyor mu?
  bool _hasLiveVideo = false; // Video yüklenmiş mi?

  // Auth Dinleyicisi
  late final StreamSubscription<AuthState> _authSubscription;
  final Color _accentBlue = const Color(0xFF1E88E5);

  // 🔴 Session Kontrolü
  Future<void> _restoreSessionIfAny() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      await _loadProfileData();
    }
  }

  @override
  void initState() {
    super.initState();

    _restoreSessionIfAny();
    _loadProfileData();

    // Blok kontrolü
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBlockStatusBg();
    });

    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      // Profili yeniden yükle (sadece önemli değişikliklerde)
      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.tokenRefreshed ||
          data.event == AuthChangeEvent.userUpdated) {
        if (mounted) {
          _loadProfileData();
        }
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _videoController?.dispose(); // Videoyu temizle
    super.dispose();
  }

  // 🎥 VİDEO YÜKLEME VE HAZIRLAMA
  void _initializeVideo(String videoUrl) {
    print("🎥 LIVE VIDEO URL BULUNDU: $videoUrl");
    // Eski controller varsa temizle
    _videoController?.dispose();

    _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _hasLiveVideo = true;
            _videoController!.setLooping(true); // Döngü
            _videoController!.setVolume(0); // Ses kapalı
          });
          print("✅ VİDEO HAZIRLANDI!");
        }
      }).catchError((e) {
        print("❌ VİDEO YÜKLEME HATASI: $e");
      });
  }

  // --- 1. VERİ YÜKLEME ---
  Future<void> _loadProfileData() async {
    if (_profileData == null) setState(() => _isLoading = true);

    try {
      await Future.wait([
        _fetchProfile(),
        _checkFollowStatus(),
        _fetchStats(),
      ]);
      await _fetchPosts();

      if (_isBlockedByMe) return;

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 2. GÜVENLİK KONTROLÜ ---
  Future<void> _checkBlockStatusBg() async {
    if (widget.userId == _currentUserId) return;
    try {
      final isBlocked = await _safetyService.isUserBlocked(widget.userId);
      if (mounted && isBlocked) {
        setState(() {
          _isBlockedByMe = true;
          _profileData = null;
          _userPosts = [];
          _isLoading = false;
        });
      }
    } catch (_) {}
  }

  // --- YARDIMCI FONKSİYONLAR ---

  Future<void> _logout() async {
    // Onay dialogu göster
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Çıkış Yap',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Çıkış yapmak istediğinizden emin misiniz?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Çıkış Yap',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', widget.userId)
          .single();

      if (mounted) {
        setState(() => _profileData = data);

        // 🎥 EĞER PROFİLDE VİDEO VARSA YÜKLE
        if (data['avatar_video_url'] != null &&
            data['avatar_video_url'].toString().isNotEmpty) {
          _initializeVideo(data['avatar_video_url']);
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchPosts() async {
    try {
      final posts = await FeedService().getProfilePosts(widget.userId);
      if (mounted) setState(() => _userPosts = posts);
    } catch (_) {}
  }

  Future<void> _fetchStats() async {
    try {
      final posts = await Supabase.instance.client
          .from('posts')
          .count(CountOption.exact)
          .eq('user_id', widget.userId);
      final followers = await Supabase.instance.client
          .from('friendships')
          .count(CountOption.exact)
          .eq('friend_id', widget.userId)
          .eq('status', 'accepted');
      final following = await Supabase.instance.client
          .from('friendships')
          .count(CountOption.exact)
          .eq('user_id', widget.userId)
          .eq('status', 'accepted');

      if (mounted) {
        setState(() {
          _postCount = posts;
          _followersCount = followers;
          _followingCount = following;
        });
      }
    } catch (_) {}
  }

  Future<void> _checkFollowStatus() async {
    if (widget.userId == _currentUserId) return;
    try {
      final res = await Supabase.instance.client
          .from('friendships')
          .select('status')
          .eq('user_id', _currentUserId)
          .eq('friend_id', widget.userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _friendshipStatus = res == null ? 'none' : res['status'];
        });
      }
    } catch (_) {}
  }

  Future<void> _updateCoverPhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;

    try {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Kapak yükleniyor...')));
      final fileExt = image.path.split('.').last;
      final fileName =
          'cover_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'covers/$fileName';

      await Supabase.instance.client.storage
          .from('uploads')
          .upload(filePath, File(image.path));
      final imageUrl = Supabase.instance.client.storage
          .from('uploads')
          .getPublicUrl(filePath);

      await Supabase.instance.client
          .from('profiles')
          .update({'cover_url': imageUrl}).eq('id', _currentUserId);

      if (!mounted) return;
      setState(() {
        _profileData?['cover_url'] = imageUrl;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Güncellendi!')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  void _openFollowList(String type, String title) {
    bool canView =
        (widget.userId == _currentUserId) || (_friendshipStatus == 'accepted');
    if (canView) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => FollowListScreen(
                  userId: widget.userId,
                  title: title,
                  type: type))).then((_) => _fetchStats());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Listeyi görmek için takip etmelisin.')));
    }
  }

  Future<void> _handleFollowAction() async {
    String previousStatus = _friendshipStatus;
    setState(() {
      if (_friendshipStatus == 'none') {
        _friendshipStatus = 'pending';
      } else {
        _friendshipStatus = 'none';
        if (previousStatus == 'accepted') _followersCount--;
      }
    });

    try {
      if (previousStatus == 'none') {
        await Supabase.instance.client.from('friendships').insert({
          'user_id': _currentUserId,
          'friend_id': widget.userId,
          'status': 'pending',
        });
        try {
          await Supabase.instance.client.from('notifications').insert({
            'user_id': widget.userId,
            'actor_id': _currentUserId,
            'type': 'follow',
            'is_read': false
          });
        } catch (_) {}
      } else {
        await Supabase.instance.client
            .from('friendships')
            .delete()
            .eq('user_id', _currentUserId)
            .eq('friend_id', widget.userId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _friendshipStatus = previousStatus;
          if (previousStatus == 'accepted') _followersCount++;
        });
      }
    }
  }

  void _startMessage() async {
    if (_profileData == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Veriler yükleniyor...')));
      return;
    }
    try {
      final roomId = await _chatService.createOrGetChatRoom(widget.userId);
      if (!mounted) return;
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  ChatScreen(roomId: roomId, otherUser: _profileData!)));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _deletePost(String postId) async {
    try {
      await Supabase.instance.client.from('posts').delete().eq('id', postId);
      setState(() {
        _userPosts.removeWhere((p) => p['id'] == postId);
        _postCount--;
      });
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Gönderi silindi.')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Silinemedi.')));
    }
  }

  void _confirmDelete(String postId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text("Sil", style: TextStyle(color: Colors.white)),
        content: const Text("Bu gönderiyi silmek istediğine emin misin?",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("İptal", style: TextStyle(color: Colors.grey))),
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _deletePost(postId);
              },
              child: Text("Sil",
                  style: TextStyle(
                      color: _accentBlue, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  // --- GÜVENLİK ---

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final reasons = [
          "Spam veya Yanıltıcı",
          "Taklit veya Sahte Hesap",
          "Nefret Söylemi",
          "Şiddet veya Tehlikeli",
          "Zorbalık veya Taciz",
          "Diğer"
        ];
        return AlertDialog(
          backgroundColor: AppColors.bgCard,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("Kullanıcıyı Şikayet Et",
              style: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: reasons.length,
              separatorBuilder: (c, i) => const Divider(color: Colors.white12),
              itemBuilder: (c, i) => ListTile(
                title: Text(reasons[i],
                    style: GoogleFonts.poppins(color: Colors.white70)),
                onTap: () {
                  Navigator.pop(ctx);
                  _submitReport(widget.userId, 'user', reasons[i]);
                },
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text("İptal",
                    style: GoogleFonts.poppins(color: Colors.grey)))
          ],
        );
      },
    );
  }

  Future<void> _submitReport(
      String targetId, String type, String reason) async {
    try {
      await _safetyService.reportContent(
          targetId: targetId, type: type, reason: reason);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Şikayet edildi."), backgroundColor: Colors.green));
    } catch (_) {}
  }

  void _confirmBlockAction() {
    final isBlocking = !_isBlockedByMe;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text(isBlocking ? "Engelle" : "Engeli Kaldır",
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
            isBlocking
                ? "Bu kullanıcıyı engellemek istediğine emin misin?"
                : "Engeli kaldırmak istiyor musun?",
            style: GoogleFonts.poppins(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("İptal",
                  style: GoogleFonts.poppins(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (isBlocking) {
                await _safetyService.blockUser(widget.userId);
                if (mounted)
                  setState(() {
                    _isBlockedByMe = true;
                    _profileData = null;
                    _userPosts = [];
                    _isLoading = false;
                  });
              } else {
                await _safetyService.unblockUser(widget.userId);
                if (mounted) {
                  setState(() {
                    _isBlockedByMe = false;
                    _isLoading = true;
                  });
                  _loadProfileData();
                }
              }
            },
            child: Text(isBlocking ? "Engelle" : "Kaldır",
                style: GoogleFonts.poppins(
                    color: isBlocking ? Colors.redAccent : Colors.greenAccent,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmUnblockAction() {
    _confirmBlockAction();
  }

  // *********************************************************
  // 🏗️ UI - TASARIM
  // *********************************************************

  @override
  Widget build(BuildContext context) {
    if (_isBlockedByMe) {
      return Scaffold(
        backgroundColor: AppColors.bgBlack,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: widget.showBackButton
              ? const BackButton(color: Colors.white)
              : null,
          title: Text("Kullanıcı Engellendi",
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 16)),
          centerTitle: true,
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              color: AppColors.bgCardLight,
              onSelected: (val) {
                if (val == 'unblock') _confirmUnblockAction();
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                    value: 'unblock',
                    child: Text("Engeli Kaldır",
                        style: GoogleFonts.poppins(color: Colors.white)))
              ],
            )
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.block, size: 80, color: Colors.white24),
              const SizedBox(height: 20),
              Text("Bu kullanıcıyı engelledin.",
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _confirmUnblockAction,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.bgCardLight,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20))),
                child: Text("Engeli Kaldır",
                    style: GoogleFonts.poppins(color: Colors.white)),
              )
            ],
          ),
        ),
      );
    }

    final isMe = widget.userId == _currentUserId;
    final isFriend = _friendshipStatus == 'accepted';

    // ✅ ADMIN KONTROLÜ
    final bool isAdmin = _profileData?['is_admin'] == true;

    final visiblePosts = _userPosts.where((post) {
      if (isMe || isFriend) return true;
      return post['visibility'] == 'public';
    }).toList();

    final showLockScreen = !isMe && !isFriend && visiblePosts.isEmpty;
    final coverUrl = _profileData?['cover_url'];

    return Scaffold(
      backgroundColor: AppColors.bgBlack,
      body: _isLoading
          ? const ProfileHeaderShimmer()
          : RefreshIndicator(
              onRefresh: _loadProfileData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        // KAPAK FOTOĞRAFI
                        Container(
                          height: 380,
                          width: double.infinity,
                          foregroundDecoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.transparent,
                                Color(0xAA000000),
                                Color(0xFF000000)
                              ],
                              stops: [0.0, 0.4, 0.7, 1.0],
                            ),
                          ),
                          child: coverUrl != null
                              ? Image.network(coverUrl, fit: BoxFit.cover)
                              : Container(
                                  decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                      Colors.grey.shade900,
                                      AppColors.bgBlack
                                    ]))),
                        ),

                        // BUTONLAR
                        if (isMe) ...[
                          Positioned(
                              top: 50,
                              right: 70,
                              child: GestureDetector(
                                  onTap: _updateCoverPhoto,
                                  child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.white24)),
                                      child: const Icon(Icons.add_a_photo,
                                          color: Colors.white, size: 18)))),
                          Positioned(
                              top: 50,
                              right: 16,
                              child: GestureDetector(
                                  onTap: _logout,
                                  child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.white24)),
                                      child: const Icon(Icons.logout,
                                          color: Colors.white, size: 18)))),
                        ] else ...[
                          if (widget.showBackButton)
                            Positioned(
                                top: 50,
                                left: 16,
                                child: IconButton(
                                    icon: const Icon(Icons.arrow_back_ios_new,
                                        color: Colors.white),
                                    onPressed: () => Navigator.pop(context))),
                          Positioned(
                            top: 50,
                            right: 16,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                                child: Container(
                                  height: 36,
                                  width: 36,
                                  decoration: BoxDecoration(
                                      color:
                                          AppColors.bgBlack.withOpacity(0.25),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white.withOpacity(0.15),
                                          width: 1)),
                                  child: PopupMenuButton<String>(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(Icons.more_horiz,
                                        color: Colors.white, size: 20),
                                    color: AppColors.bgCardLight,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                    onSelected: (value) {
                                      if (value == 'report')
                                        _showReportDialog();
                                      if (value == 'block')
                                        _confirmBlockAction();
                                    },
                                    itemBuilder: (ctx) => [
                                      PopupMenuItem(
                                          value: 'report',
                                          child: Row(children: [
                                            const Icon(Icons.flag_outlined,
                                                color: Colors.white70,
                                                size: 18),
                                            const SizedBox(width: 10),
                                            Text("Şikayet Et",
                                                style: GoogleFonts.poppins(
                                                    color: Colors.white,
                                                    fontSize: 13))
                                          ])),
                                      PopupMenuItem(
                                          value: 'block',
                                          child: Row(children: [
                                            const Icon(Icons.block,
                                                color: Colors.redAccent,
                                                size: 18),
                                            const SizedBox(width: 10),
                                            Text("Engelle",
                                                style: GoogleFonts.poppins(
                                                    color: Colors.redAccent,
                                                    fontSize: 13))
                                          ])),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],

                        // PROFİL DETAYLARI
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 🔥 AVATAR + LIVE PHOTO 🔥
                              GestureDetector(
                                onLongPressStart: (_) {
                                  if (_hasLiveVideo &&
                                      _videoController != null &&
                                      _videoController!.value.isInitialized) {
                                    setState(() => _isPlayingLiveVideo = true);
                                    _videoController!.play();
                                  }
                                },
                                onLongPressEnd: (_) {
                                  if (_hasLiveVideo &&
                                      _videoController != null) {
                                    _videoController!.pause();
                                    _videoController!.seekTo(Duration.zero);
                                    setState(() => _isPlayingLiveVideo = false);
                                  }
                                },
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Simple CircleAvatar
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.primary,
                                          width: 3,
                                        ),
                                      ),
                                      child: CircleAvatar(
                                        radius: 50,
                                        backgroundColor: AppColors.bgCard,
                                        backgroundImage: _isPlayingLiveVideo
                                            ? null
                                            : (_profileData?['avatar_url'] !=
                                                    null
                                                ? NetworkImage(
                                                    _profileData!['avatar_url'])
                                                : null),
                                        child: _profileData?['avatar_url'] ==
                                                    null &&
                                                !_isPlayingLiveVideo
                                            ? const Icon(Icons.person,
                                                size: 50, color: Colors.white30)
                                            : null,
                                      ),
                                    ),
                                    // Live video overlay when pressed
                                    if (_hasLiveVideo &&
                                        _isPlayingLiveVideo &&
                                        _videoController!.value.isInitialized)
                                      SizedBox(
                                        width: 100,
                                        height: 100,
                                        child: ClipOval(
                                          child: FittedBox(
                                            fit: BoxFit.cover,
                                            child: SizedBox(
                                              width: _videoController!
                                                  .value.size.width,
                                              height: _videoController!
                                                  .value.size.height,
                                              child: VideoPlayer(
                                                  _videoController!),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              // Level display kaldırıldı - daha temiz görünüm

                              // 🔥 PROFİL İSMİ VE ADMIN ROZETİ
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(_profileData?['full_name'] ?? 'İsimsiz',
                                      style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          shadows: [
                                            Shadow(
                                                offset: Offset(0, 1),
                                                blurRadius: 4,
                                                color: AppColors.bgBlack)
                                          ])),
                                  if (isAdmin) ...[
                                    const AdminBadge(size: 24),
                                  ]
                                ],
                              ),

                              if (_profileData?['username'] != null)
                                Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text('@${_profileData!['username']}',
                                        style: GoogleFonts.poppins(
                                            color: Colors.white60,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            shadows: [
                                              Shadow(
                                                  offset: Offset(0, 1),
                                                  blurRadius: 3,
                                                  color: AppColors.bgBlack)
                                            ]))),
                              if (_profileData?['bio'] != null)
                                Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 8),
                                    child: Text(_profileData!['bio'],
                                        style: GoogleFonts.poppins(
                                            color: Colors.white70,
                                            fontSize: 13,
                                            shadows: [
                                              Shadow(
                                                  offset: Offset(0, 1),
                                                  blurRadius: 3,
                                                  color: AppColors.bgBlack)
                                            ]),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis)),

                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildStat(
                                      'Gönderi', _postCount.toString(), null),
                                  Container(
                                      width: 1,
                                      height: 20,
                                      color: Colors.white12),
                                  _buildStat(
                                      'Takipçi',
                                      _followersCount.toString(),
                                      () => _openFollowList(
                                          'followers', 'Takipçiler')),
                                  Container(
                                      width: 1,
                                      height: 20,
                                      color: Colors.white12),
                                  _buildStat(
                                      'Takip',
                                      _followingCount.toString(),
                                      () => _openFollowList(
                                          'following', 'Takip Edilenler')),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          // BUTONLAR (Profili Düzenle vs)
                          isMe
                              ? _buildMyProfileButtons()
                              : _buildOtherProfileButtons(),
                          const SizedBox(height: 5),

                          // 🔥 MÜZİK OYNATICI KARTI
                          MusicPlayerCard(userId: widget.userId, isMe: isMe),

                          const SizedBox(height: 10),
                        ],
                      ),
                    ),

                    // GÖNDERİ LİSTESİ
                    showLockScreen
                        ? Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: Column(children: [
                              const Icon(Icons.lock_outline,
                                  size: 40, color: Colors.white24),
                              const SizedBox(height: 10),
                              Text("Bu hesap gizli.",
                                  style: GoogleFonts.poppins(
                                      color: Colors.white24))
                            ]))
                        : (visiblePosts.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(top: 40),
                                child: Column(children: [
                                  const Icon(Icons.feed_outlined,
                                      size: 40, color: Colors.white24),
                                  const SizedBox(height: 10),
                                  Text("Henüz gönderi yok.",
                                      style: GoogleFonts.poppins(
                                          color: Colors.white24))
                                ]))
                            : ListView.builder(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: visiblePosts.length,
                                itemBuilder: (context, index) =>
                                    _buildHomeStylePost(
                                        visiblePosts[index], index),
                              )),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStat(String label, String value, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(value,
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 4,
                        color: AppColors.bgBlack)
                  ])),
          Text(label,
              style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMyProfileButtons() {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: ElevatedButton(
        onPressed: () async {
          if (_profileData == null) return;
          final result = await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      EditProfileScreen(currentProfile: _profileData!)));
          if (result == true) _loadProfileData();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.bgCardLight,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          side: const BorderSide(color: Colors.white12),
        ),
        child: Text("Profili Düzenle",
            style:
                GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildOtherProfileButtons() {
    String label = "Takip Et";
    Color bgColor = AppColors.primary;
    Color txtColor = Colors.white;
    if (_friendshipStatus == 'accepted') {
      label = "Takip Ediliyor";
      bgColor = AppColors.bgCardLight;
    } else if (_friendshipStatus == 'pending') {
      label = "İstek Gönderildi";
      bgColor = Colors.grey.shade900;
      txtColor = Colors.grey;
    }
    return Row(
      children: [
        Expanded(
            child: SizedBox(
                height: 45,
                child: ElevatedButton(
                    onPressed: _handleFollowAction,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: bgColor,
                        foregroundColor: txtColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0),
                    child: Text(label,
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600))))),
        const SizedBox(width: 10),
        Expanded(
            child: SizedBox(
                height: 45,
                child: ElevatedButton(
                    onPressed: _startMessage,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.bgCardLight,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                        side: const BorderSide(color: Colors.white12)),
                    child: Text("Mesaj",
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600))))),
      ],
    );
  }

  // 🔥 GÜNCELLENEN MODERN VE BUZLU CAM EFEKTLİ POST KARTI
  Widget _buildHomeStylePost(Map<String, dynamic> post, int index) {
    final profile = post['profiles'] ?? {};
    final content = post['content'] ?? '';
    final imageUrl = post['image_url'];
    final date = DateTime.tryParse(post['created_at'] ?? '');
    final dateStr = date != null ? '${date.day}/${date.month}' : '';
    final likeCount = (post['likes'] as List?)?.length ?? 0;
    final commentCount = (post['comments'] as List?)?.length ?? 0;
    final isLiked =
        (post['likes'] as List?)?.any((l) => l['user_id'] == _currentUserId) ??
            false;
    final isMe = widget.userId == _currentUserId;

    // ✅ POST İÇİNDEKİ KULLANICI ADMİN Mİ?
    final bool isPostAdmin = profile['is_admin'] == true;

    final isExplorePost =
        post['visibility'] == 'public'; // 🆕 Keşfet gönderisi mi?

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => PostDetailScreen(
                    post: post,
                    isExploreMode: isExplorePost, // 🆕 Explore modunu aktar
                  ))),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 20),
        color: Colors.transparent, // Arka plan şeffaf
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
                  // --- HEADER
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {},
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
                              backgroundColor: const Color(0xFF121212),
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
                              Row(
                                children: [
                                  Text(
                                    profile['full_name'] ?? 'İsimsiz',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15),
                                  ),
                                  if (isPostAdmin) ...[
                                    const AdminBadge(size: 16),
                                  ]
                                ],
                              ),
                              Text(
                                '@${profile['username']}',
                                style: GoogleFonts.poppins(
                                    color: Colors.grey.shade400, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(dateStr,
                                style: GoogleFonts.poppins(
                                    color: Colors.grey.shade400, fontSize: 12)),
                            if (isMe) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _confirmDelete(post['id']),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: _accentBlue.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.delete_outline,
                                    color: _accentBlue,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ]
                          ],
                        ),
                      ],
                    ),
                  ),

                  // --- İÇERİK
                  if (content.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: Text(
                        content,
                        style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 14,
                            height: 1.5),
                      ),
                    ),

                  // --- GÖRSEL (CAROUSEL DESTEĞİ)
                  if (post['image_urls'] != null &&
                      (post['image_urls'] as List).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: ImageCarousel(
                        imageUrls: (post['image_urls'] as List).cast<String>(),
                        height: 350,
                        borderRadius: BorderRadius.circular(18),
                        musicTrackName: post['spotify_track_name'],
                        musicArtistName: post['spotify_artist_name'],
                        postId: post['id'],
                      ),
                    )
                  else if (imageUrl != null)
                    Container(
                      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 400),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.network(imageUrl, fit: BoxFit.cover),
                      ),
                    ),

                  // --- AKSİYON BAR
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // 🆕 Keşfet gönderisi için FuelButton, normal için Kalp
                        if (isExplorePost) ...[
                          // ATEŞ BUTONU (tıklanabilir değil - read-only)
                          Row(
                            children: [
                              Icon(
                                Icons.local_fire_department,
                                color: isLiked
                                    ? Colors.orange
                                    : Colors.grey.shade400,
                                size: 26,
                              ),
                              if (likeCount > 0) ...[
                                const SizedBox(width: 6),
                                Text(
                                  "$likeCount Odun",
                                  style: GoogleFonts.poppins(
                                    color: isLiked
                                        ? Colors.orange
                                        : Colors.grey.shade400,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const Spacer(),
                          // YORUM
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(FontAwesomeIcons.comment,
                                    color: Colors.grey.shade400, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  "$commentCount",
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey.shade400,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // NORMAL GÖNDERİ - KALP VE YORUM
                          Container(
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
                                  Text(
                                    "$likeCount",
                                    style: GoogleFonts.poppins(
                                      color: isLiked
                                          ? AppColors.primary
                                          : Colors.grey.shade400,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Container(
                            color: Colors.transparent,
                            child: Row(
                              children: [
                                Icon(FontAwesomeIcons.comment,
                                    color: Colors.grey.shade400, size: 22),
                                if (commentCount > 0) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    "$commentCount",
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey.shade400,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
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
