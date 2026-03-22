import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/language/app_l10n.dart';
import '../../../data/services/chat_service.dart';

class SharePostModal extends StatefulWidget {
  final Map<String, dynamic> post;

  const SharePostModal({super.key, required this.post});

  @override
  State<SharePostModal> createState() => _SharePostModalState();
}

class _SharePostModalState extends State<SharePostModal> {
  final ChatService _chatService = ChatService();
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  final Set<String> _sentTo = {};
  final Set<String> _sending = {};
  final TextEditingController _searchCtrl = TextEditingController();

  static const _bg = Color(0xFF0E0E16);
  static const _card = Color(0xFF16161F);
  static const _accent = Color(0xFF7C6EFA);
  static const _border = Color(0xFF1E1E2A);

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _contacts
          : _contacts.where((u) {
              final name = (u['full_name'] ?? '').toString().toLowerCase();
              final uname = (u['username'] ?? '').toString().toLowerCase();
              return name.contains(q) || uname.contains(q);
            }).toList();
    });
  }

  Future<void> _loadContacts() async {
    final friends = await _chatService.getMutualFriends();
    if (!mounted) return;
    setState(() {
      _contacts = friends;
      _filtered = friends;
      _loading = false;
    });
  }

  Future<void> _sendPost(Map<String, dynamic> user) async {
    final userId = user['id'].toString();
    if (_sentTo.contains(userId) || _sending.contains(userId)) return;
    setState(() => _sending.add(userId));

    try {
      final post = widget.post;
      final posterProfile = post['profiles'] as Map<String, dynamic>?;

      String? imageUrl;
      final imageUrls = post['image_urls'] as List?;
      if (imageUrls != null && imageUrls.isNotEmpty) {
        imageUrl = imageUrls.first as String;
      } else {
        imageUrl = post['image_url'] as String?;
      }

      final sharedPostData = {
        'post_id': post['id'],
        'poster_name': posterProfile?['full_name'] ?? posterProfile?['username'] ?? AppL10n.user,
        'poster_username': posterProfile?['username'] ?? '',
        'poster_avatar': posterProfile?['avatar_url'],
        'image_url': imageUrl,
        'video_url': post['video_url'],
        'content': post['content'] ?? '',
      };

      final roomId = await _chatService.createOrGetChatRoom(userId);
      await _chatService.sendSharedPost(
        roomId: roomId,
        receiverId: userId,
        postId: post['id'].toString(),
        sharedPostData: sharedPostData,
      );

      if (mounted) setState(() => _sentTo.add(userId));
    } catch (_) {
    } finally {
      if (mounted) setState(() => _sending.remove(userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  AppL10n.shareWithFriend,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close, color: Colors.white38, size: 15),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: AppL10n.searchUsers,
                  hintStyle: GoogleFonts.poppins(color: Colors.white30, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white30, size: 18),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Contacts
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: CircularProgressIndicator(
                color: _accent,
                strokeWidth: 2,
              ),
            )
          else if (_filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.people_outline_rounded, color: Colors.white24, size: 36),
                  const SizedBox(height: 10),
                  Text(
                    AppL10n.noChatContacts,
                    style: GoogleFonts.poppins(color: Colors.white38, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 108,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final user = _filtered[index];
                  final userId = user['id'].toString();
                  final sent = _sentTo.contains(userId);
                  final sending = _sending.contains(userId);
                  final username = user['username'] as String? ?? '';
                  final fullName = user['full_name'] as String? ?? '';
                  final displayName = fullName.isNotEmpty ? fullName : (username.isNotEmpty ? username : AppL10n.user);
                  final avatar = user['avatar_url'] as String?;

                  return GestureDetector(
                    onTap: (sent || sending) ? null : () => _sendPost(user),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 72,
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          // Avatar
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 60, height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: sent
                                    ? const Color(0xFF30D158)
                                    : sending
                                        ? _accent
                                        : Colors.white12,
                                width: sent || sending ? 2.5 : 1,
                              ),
                            ),
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 27,
                                  backgroundColor: _card,
                                  backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                                  child: avatar == null
                                      ? const Icon(Icons.person_rounded, color: Colors.white38, size: 24)
                                      : null,
                                ),
                                if (sending)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.black.withValues(alpha: 0.5),
                                      ),
                                      child: const Center(
                                        child: SizedBox(
                                          width: 20, height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (sent)
                                  Positioned(
                                    right: 0, bottom: 0,
                                    child: Container(
                                      width: 20, height: 20,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFF30D158),
                                      ),
                                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 13),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            displayName,
                            style: GoogleFonts.poppins(
                              color: sent ? const Color(0xFF30D158) : Colors.white70,
                              fontSize: 10.5,
                              fontWeight: sent ? FontWeight.w600 : FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          if (sent)
                            Text(
                              AppL10n.sent,
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF30D158).withValues(alpha: 0.7),
                                fontSize: 9.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}
