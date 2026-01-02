// Kinnect - Kullanıcı profil ekranı

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart'; // 🎥 LIVE VIDEO OYNATICI

// --- SERVİSLER ---
import '../../../data/services/feed_service.dart';
import '../../../data/services/chat_service.dart';
import '../../../data/services/safety_service.dart';

// --- WIDGET'LAR ---
import '../../../shared/widgets/music_player_card.dart';
import '../../../shared/widgets/shimmer/profile_header_shimmer.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/profile_header.dart';
import '../../home/widgets/post_card.dart';

// --- EKRANLAR ---
import '../../chat/screens/chat_screen.dart';
import 'follow_list_screen.dart';
import 'edit_profile_screen.dart';
import '../../auth/screens/login_screen.dart';

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
        }
      }).catchError((e) {
        // Hata durumunda sessizce devam et
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
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
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
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (image == null) {
      return;
    }
    if (!mounted) {
      return;
    }

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
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Şikayet edildi."), backgroundColor: Colors.green));
      }
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
                if (mounted) {
                  setState(() {
                    _isBlockedByMe = true;
                    _profileData = null;
                    _userPosts = [];
                    _isLoading = false;
                  });
                }
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
                    // HEADER WIDGET
                    ProfileHeader(
                      profileData: _profileData,
                      isMe: isMe,
                      isAdmin: isAdmin,
                      friendshipStatus: _friendshipStatus,
                      postCount: _postCount,
                      followersCount: _followersCount,
                      followingCount: _followingCount,
                      showBackButton: widget.showBackButton,
                      hasLiveVideo: _hasLiveVideo,
                      isPlayingLiveVideo: _isPlayingLiveVideo,
                      videoController: _videoController,
                      onUpdateCoverPhoto: _updateCoverPhoto,
                      onLogout: _logout,
                      onBack: () => Navigator.pop(context),
                      onMenuAction: (val) {
                        if (val == 'report') _showReportDialog();
                        if (val == 'block') _confirmBlockAction();
                      },
                      onLiveVideoStateChange: (isPlaying) {
                        if (!_hasLiveVideo || _videoController == null) return;
                        setState(() => _isPlayingLiveVideo = isPlaying);
                        if (isPlaying) {
                          _videoController!.play();
                        } else {
                          _videoController!.pause();
                          _videoController!.seekTo(Duration.zero);
                        }
                      },
                      onOpenFollowList: _openFollowList,
                      onEditProfile: () async {
                        if (_profileData == null) return;
                        final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => EditProfileScreen(
                                    currentProfile: _profileData!)));
                        if (result == true) _loadProfileData();
                      },
                      onFollowAction: _handleFollowAction,
                      onMessage: _startMessage,
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
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
                            : ListView.separated(
                                shrinkWrap: true,
                                // Alt kısma ekstra boşluk ekledik
                                padding: const EdgeInsets.only(bottom: 24),
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: visiblePosts.length,
                                // Elemanlar arası boşluk (16px)
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 16),
                                itemBuilder: (context, index) => PostCard(
                                  post: visiblePosts[index],
                                  onRefresh: _loadProfileData,
                                ),
                              )),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}
