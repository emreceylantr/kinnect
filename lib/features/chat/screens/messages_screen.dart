// Kinnect - Mesajlaşma Listesi Ekranı
// Refactored: ChatScreen ve widget'lar ayrı dosyalara taşındı

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/widgets/kinnect_image.dart';
import '../../profile/screens/profile_screen.dart';

import '../../../data/services/chat_service.dart';
import 'chat_screen.dart';
import '../widgets/flippable_chat_card.dart';

// ==========================================
// 🎨 RENK PALETİ
// ==========================================
const Color kListBgColor = Color(0xFF1B1424);
const Color kSearchBtnColor = Color(0xFF292233);
const Color kTextWhite = Colors.white;
const Color kAccentColor = Color(0xFF6C63FF);

// ==========================================
// 📱 MESAJLAR LİSTESİ EKRANI
// ==========================================
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final ChatService _chatService = ChatService();
  String get _myId => Supabase.instance.client.auth.currentUser!.id;

  late Future<List<Map<String, dynamic>>> _chatsFuture;

  // Arama Durumu
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  // Header Animasyonu
  bool _showGreeting = true;
  String _searchQuery = "";

  // 🔒 GİZLİLİK AYARLARI
  bool _showLastSeen = true;
  bool _showReadReceipts = true;

  String _firstName = "";
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _refreshChats();
    _loadUserData();

    // Greeting animasyonunu daha hızlı kapat (500ms) ya da hemen kapat
    // Kullanıcı çok beklemek istemiyor.
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _showGreeting = false);
      }
    });
  }

  Future<void> _loadUserData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    String name = 'Kullanıcı';
    String? avatar;

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (profile != null) {
        name = profile['full_name'] ?? profile['username'] ?? 'Kullanıcı';
        avatar = profile['avatar_url'];
        _showLastSeen = profile['show_last_seen'] ?? true;
        _showReadReceipts = profile['show_read_receipts'] ?? true;
      }
    } catch (_) {}

    String first = name.split(' ')[0];
    if (first.isNotEmpty) {
      first = "${first[0].toUpperCase()}${first.substring(1)}";
    }

    if (mounted) {
      setState(() {
        _firstName = first;
        _avatarUrl = avatar;
      });
    }
  }

  void _refreshChats() {
    setState(() {
      _chatsFuture = _chatService.getMyChats();
    });
  }

  // 🔥 SOHBETİ SİLME İŞLEMİ
  Future<void> _deleteChat(String roomId) async {
    try {
      await Supabase.instance.client
          .from('messages')
          .delete()
          .eq('room_id', roomId);
      _refreshChats();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Sohbet temizlendi."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Hata: $e")));
      }
    }
  }

  // 🔒 GİZLİLİK AYARLARINI GÜNCELLE
  Future<void> _updatePrivacySetting(String field, bool value) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('profiles').update({
        field: value,
      }).eq('id', userId);

      if (mounted) {
        if (field == 'show_last_seen') _showLastSeen = value;
        if (field == 'show_read_receipts') _showReadReceipts = value;
      }
    } catch (e) {
      debugPrint('Gizlilik ayarı güncelleme hatası: $e');
    }
  }

  // ⚙️ GİZLİLİK AYARLARI MENÜSÜ
  void _showPrivacySettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    "Gizlilik Ayarları",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 👁️ Son Görülme
                  SwitchListTile(
                    activeColor: const Color(0xFF00D26A),
                    activeTrackColor:
                        const Color(0xFF00D26A).withValues(alpha: 0.3),
                    inactiveThumbColor: Colors.grey,
                    inactiveTrackColor: Colors.white10,
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Son Görülme",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      _showLastSeen ? "Herkes görebilir" : "Hiç kimse göremez",
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12),
                    ),
                    value: _showLastSeen,
                    onChanged: (val) {
                      setStateSheet(() => _showLastSeen = val);
                      setState(() => _showLastSeen = val);
                      _updatePrivacySetting('show_last_seen', val);
                    },
                  ),

                  const Divider(color: Colors.white10),

                  // ✅ Okundu Bilgisi
                  SwitchListTile(
                    activeColor: const Color(0xFF53BDEB),
                    activeTrackColor:
                        const Color(0xFF53BDEB).withValues(alpha: 0.3),
                    inactiveThumbColor: Colors.grey,
                    inactiveTrackColor: Colors.white10,
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Okundu Bilgisi",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      _showReadReceipts
                          ? "Okundu bilgisi paylaşılır"
                          : "Mavi tik gizlenir (karşılıklı)",
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12),
                    ),
                    value: _showReadReceipts,
                    onChanged: (val) {
                      setStateSheet(() => _showReadReceipts = val);
                      setState(() => _showReadReceipts = val);
                      _updatePrivacySetting('show_read_receipts', val);
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kListBgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _chatsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: kAccentColor));
                  }

                  final allChats = snapshot.data ?? [];
                  final filteredChats = allChats.where((chat) {
                    final otherUser = chat['other_user'] ?? {};
                    final name =
                        (otherUser['full_name'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery);
                  }).toList();

                  if (filteredChats.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              size: 50, color: Colors.grey[700]),
                          const SizedBox(height: 16),
                          Text(
                              _searchQuery.isEmpty
                                  ? 'Henüz sohbet yok'
                                  : 'Sonuç bulunamadı',
                              style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filteredChats.length,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    itemBuilder: (context, index) {
                      final chat = filteredChats[index];
                      final otherUser = chat['other_user'] ?? {};
                      final lastUpdateRaw = chat['updated_at'];
                      final lastUpdate = lastUpdateRaw != null
                          ? DateTime.parse(lastUpdateRaw).toLocal()
                          : DateTime.now();

                      const unreadCount = 0;

                      return SlideFadeTransition(
                        index: index,
                        child: FlippableChatCard(
                          chat: chat,
                          otherUser: otherUser,
                          lastUpdate: lastUpdate,
                          unreadCount: unreadCount,
                          onDeleteConfirm: () {
                            _deleteChat(chat['id'].toString());
                          },
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  roomId: chat['id'],
                                  otherUser: otherUser,
                                  heroTag: "list_avatar_${otherUser['id']}",
                                  showReadReceipts: _showReadReceipts,
                                ),
                              ),
                            ).then((_) => _refreshChats());
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _isSearching
              ? Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: kSearchBtnColor,
                    borderRadius: BorderRadius.circular(25),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    onChanged: (value) =>
                        setState(() => _searchQuery = value.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: "Sohbet ara...",
                      hintStyle:
                          TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                      prefixIcon:
                          const Icon(Icons.search, color: Colors.white70),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () {
                          setState(() {
                            _isSearching = false;
                            _searchQuery = "";
                            _searchController.clear();
                          });
                        },
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                )
              : Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 22),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const Spacer(),
                    // 🔍 Arama Butonu
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: kSearchBtnColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.search,
                            color: Colors.white70, size: 20),
                        onPressed: () => setState(() => _isSearching = true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // ⚙️ Gizlilik Ayarları Menüsü
                    Theme(
                      data: Theme.of(context).copyWith(
                        cardColor: const Color(0xFF1A1A1A),
                        iconTheme: const IconThemeData(color: Colors.white),
                      ),
                      child: PopupMenuButton<String>(
                        icon:
                            const Icon(Icons.more_vert, color: Colors.white70),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                        onSelected: (value) {
                          if (value == 'privacy') {
                            _showPrivacySettingsBottomSheet();
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          const PopupMenuItem<String>(
                            value: 'privacy',
                            child: Row(
                              children: [
                                Icon(Icons.privacy_tip_outlined,
                                    color: Colors.white, size: 20),
                                SizedBox(width: 10),
                                Text("Gizlilik Ayarları",
                                    style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
          if (!_isSearching) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 80,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 800),
                  child: _showGreeting
                      ? Text(
                          "Merhaba, $_firstName",
                          key: const ValueKey('greeting'),
                          style: const TextStyle(
                              color: kTextWhite,
                              fontSize: 24,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 1.0),
                        )
                      : Container(
                          key: const ValueKey('avatar'),
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: kAccentColor, width: 2),
                              boxShadow: [
                                BoxShadow(
                                    color: kAccentColor.withValues(alpha: 0.3),
                                    blurRadius: 15)
                              ]),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          ProfileScreen(userId: _myId)));
                            },
                            child: CircleAvatar(
                              radius: 35,
                              backgroundColor: Colors.grey[800],
                              child: _avatarUrl != null
                                  ? ClipOval(
                                      child: KinnectImage(
                                        imageUrl: _avatarUrl!,
                                        width: 70,
                                        height: 70,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Text(
                                      _firstName.isNotEmpty
                                          ? _firstName[0]
                                          : "K",
                                      style: const TextStyle(
                                          fontSize: 24,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Sohbetler',
              style: TextStyle(
                  fontFamily: 'Sans',
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                  color: kTextWhite),
            ),
          ]
        ],
      ),
    );
  }
}
