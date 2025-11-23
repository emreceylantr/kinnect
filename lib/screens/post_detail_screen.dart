// lib/screens/post_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/feed_service.dart';

class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final FeedService _feedService = FeedService();
  final TextEditingController _commentController = TextEditingController();
  final String _currentUserId = Supabase.instance.client.auth.currentUser!.id;

  bool isLiked = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    final likes = widget.post['likes'] as List<dynamic>? ?? [];
    isLiked = likes.any((l) => l['user_id'] == _currentUserId);
  }

  void _toggleLike() async {
    setState(() { isLiked = !isLiked; _hasChanges = true; });
    await _feedService.toggleLike(widget.post['id']);
  }

  void _onBack() { Navigator.pop(context, _hasChanges); }

  Future<void> _deletePost() async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(backgroundColor: const Color(0xFF1E1E1E), title: const Text('Sil?', style: TextStyle(color: Colors.white)), content: const Text('Bu gönderi silinecek.', style: TextStyle(color: Colors.white70)), actions: [TextButton(child: const Text('İptal'), onPressed: () => Navigator.pop(ctx, false)), TextButton(child: const Text('Sil', style: TextStyle(color: Colors.red)), onPressed: () => Navigator.pop(ctx, true))]));
    if (confirm == true) {
      try {
        await _feedService.deletePost(widget.post['id']);
        if (mounted) { Navigator.pop(context, true); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Silindi."))); }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Silinemedi: $e")));
      }
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await _feedService.deleteComment(commentId);
      // StreamBuilder otomatik günceller
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Yorum silinemedi.")));
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    _commentController.clear(); FocusScope.of(context).unfocus();
    try { await _feedService.addComment(widget.post['id'], text); } catch (e) {}
  }

  void _openHeroImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.transparent, leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))), body: Center(child: Hero(tag: 'detail_$imageUrl', child: InteractiveViewer(child: Image.network(imageUrl)))))));
  }

  @override
  Widget build(BuildContext context) {
    final profile = (widget.post['profiles'] ?? {}) as Map<String, dynamic>;
    final fullName = profile['full_name'] ?? 'Bilinmiyor';
    final username = profile['username'] ?? 'anonim';
    final content = widget.post['content'] ?? '';
    final imageUrl = widget.post['image_url'];
    final profilePic = profile['avatar_url'];
    final createdAt = DateTime.tryParse(widget.post['created_at'] ?? '');
    final String dateText = createdAt != null ? '${createdAt.day}/${createdAt.month} ${createdAt.hour}:${createdAt.minute}' : '';

    return WillPopScope(
      onWillPop: () async { _onBack(); return false; },
      child: Scaffold(
        backgroundColor: const Color(0xFF050505),
        appBar: AppBar(title: Text('Gönderi', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: const Color(0xFF050505), leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: _onBack), actions: [if (widget.post['user_id'] == _currentUserId) IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: _deletePost)]),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // POST KARTI
                    Container(
                      padding: const EdgeInsets.only(bottom: 16),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white12))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(leading: CircleAvatar(backgroundColor: const Color(0xFF6C63FF), backgroundImage: profilePic != null ? NetworkImage(profilePic) : null, child: profilePic == null ? const Icon(Icons.person, color: Colors.white) : null), title: Text(fullName, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)), subtitle: Text('@$username', style: GoogleFonts.poppins(color: Colors.white54))),
                          if (content.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Text(content, style: GoogleFonts.poppins(color: Colors.white, fontSize: 16))),
                          if (imageUrl != null) GestureDetector(onTap: () => _openHeroImage(context, imageUrl), child: Container(width: double.infinity, constraints: const BoxConstraints(maxHeight: 500), color: Colors.black, margin: const EdgeInsets.only(top: 8), child: Hero(tag: 'detail_$imageUrl', child: Image.network(imageUrl, fit: BoxFit.contain)))),
                          Padding(padding: const EdgeInsets.all(12), child: Row(children: [GestureDetector(onTap: _toggleLike, child: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : Colors.white, size: 26)), const SizedBox(width: 16), const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 24), const SizedBox(width: 16), const Icon(Icons.send_outlined, color: Colors.white, size: 24)])),
                          Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text(dateText, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12))),
                        ],
                      ),
                    ),
                    // YORUMLAR LİSTESİ
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _feedService.getCommentsStream(widget.post['id']),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox();
                        final comments = snapshot.data!;
                        if (comments.isEmpty) return Padding(padding: const EdgeInsets.only(top: 40), child: Center(child: Text("Henüz yorum yok. İlk sen yaz!", style: GoogleFonts.poppins(color: Colors.white38))));

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: comments.length,
                          itemBuilder: (context, index) {
                            final c = comments[index];
                            final cp = c['profile'] ?? {};
                            final isMyComment = c['user_id'] == _currentUserId;

                            return ListTile(
                              leading: CircleAvatar(radius: 16, backgroundImage: cp['avatar_url'] != null ? NetworkImage(cp['avatar_url']) : null, backgroundColor: Colors.grey[800], child: cp['avatar_url'] == null ? const Icon(Icons.person, size: 16, color: Colors.white) : null),
                              title: RichText(text: TextSpan(children: [TextSpan(text: "${cp['username'] ?? 'anonim'} ", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), TextSpan(text: c['content'], style: const TextStyle(color: Colors.white))])),
                              // SİLME BUTONU (Sadece kendi yorumunsa)
                              trailing: isMyComment
                                  ? IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey), onPressed: () => _deleteComment(c['id']))
                                  : null,
                            );
                          },
                        );
                      },
                    )
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              color: const Color(0xFF1A1A1A),
              child: Row(children: [Expanded(child: TextField(controller: _commentController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Yorum ekle...', hintStyle: TextStyle(color: Colors.white38), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16)))), IconButton(icon: const Icon(Icons.send, color: Color(0xFF6C63FF)), onPressed: _sendComment)]),
            ),
          ],
        ),
      ),
    );
  }
}