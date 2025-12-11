import 'dart:io';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../services/feed_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  final String _currentUserId = Supabase.instance.client.auth.currentUser!.id;

  File? _imageFile;
  bool _isLoading = false;
  String _visibility = 'public';
  String? _avatarUrl;
  String _currentHint = "";

  // --- ANİMASYON STATE'LERİ ---
  bool _isShareButtonPressed = false;
  double _hintOpacity = 0.0;

  late AnimationController _auroraController;

  // 🔥 ORTALANACAK KISA SÖZLER
  final Set<String> _centeredHints = {
    "Neler düşünüyorsun?",
    "Bugün nasılsın?",
    "Aklında ne var?",
    "Nasıl hissediyorsun?",
    "Günün nasıl geçti?",
    "Ne paylaşsam acaba…",
    "Kendime bir not bırakıyorum.",
    "Dur bak şimdi bir şey paylaşacağım…",
    "Takipçilerine bir mesajın var mı?",
    "İlham verici bir şeyler yaz...",
    "Paylaşmak istediğin bir şey mi var?",
  };

  // 🔥 TÜM LİSTE
  final List<String> _hintList = [
    "Neler düşünüyorsun?",
    "Bugün nasılsın?",
    "Aklında ne var?",
    "Nasıl hissediyorsun?",
    "Günün nasıl geçti?",
    "Ne paylaşsam acaba…",
    "Kendime bir not bırakıyorum.",
    "Dur bak şimdi bir şey paylaşacağım…",
    "Takipçilerine bir mesajın var mı?",
    "İlham verici bir şeyler yaz...",
    "Paylaşmak istediğin bir şey mi var?",
    "Bir şey yazacaktım… unuttum. Neyse yazıyorum.",
    "Düşündüğüm bazı şeyleri paylaşmam gerekiyor sanki.",
    "Buraya düşüncelerimden bir parça bırakıyorum.",
    "Bugün biraz fazla iyi görünüyorum, paylaşayım dedim 👀",
    "Şimdi öyle bir şey paylaşacağım ki… biri üstüne alınacak.",
    "Post seçmek bu kadar zorsa, kod yazmayı düşünemiyorum bile… kahve getiriyorum.",
    "Developerlarımız kadar yorulmadım ama post seçerken bile enerji tükendi, kahve şart."
  ];

  @override
  void initState() {
    super.initState();
    _fetchMyAvatar();
    _setRandomHint();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _hintOpacity = 1.0;
        });
      }
    });

    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  void _setRandomHint() {
    setState(() {
      _currentHint = _hintList[Random().nextInt(_hintList.length)];
    });
  }

  Future<void> _fetchMyAvatar() async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('avatar_url')
          .eq('id', _currentUserId)
          .single();
      if (mounted) {
        setState(() {
          _avatarUrl = data['avatar_url'];
        });
      }
    } catch (_) {}
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 70);
    if (image != null) setState(() => _imageFile = File(image.path));
  }

  Future<void> _sharePost() async {
    if (_isLoading) return;
    final content = _textController.text.trim();
    if (content.isEmpty && _imageFile == null) return;

    setState(() => _isLoading = true);

    try {
      String? imageUrl;

      if (_imageFile != null) {
        final fileExt = _imageFile!.path.split('.').last;
        final fileName = '$_currentUserId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

        await Supabase.instance.client.storage
            .from('uploads')
            .uploadBinary(
          fileName,
          await _imageFile!.readAsBytes(),
          fileOptions: const FileOptions(upsert: true),
        );

        imageUrl = Supabase.instance.client.storage.from('uploads').getPublicUrl(fileName);
      }

      await Supabase.instance.client.from('posts').insert({
        'user_id': _currentUserId,
        'content': content,
        'image_url': imageUrl,
        'visibility': _visibility,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Gönderildi! 🚀"),
            backgroundColor: Color(0xFF6C63FF),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _auroraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 DÜZELTME: Yazı boyutu 16'ya çekildi (Daha dengeli)
    final TextStyle commonTextStyle = GoogleFonts.poppins(
        color: Colors.white,
        fontSize: 16,
        height: 1.5
    );

    final TextStyle hintTextStyle = commonTextStyle.copyWith(
        color: Colors.white54
    );

    // 🔥 HİZALAMA MATEMATİĞİ:
    // Avatar (Radius 22) => Height 44px
    // Yazı (Font 16 * 1.5) => Height 24px
    // Fark = 20px. Ortalamak için üstten 10px boşluk gerekir.
    final double topPadding = _centeredHints.contains(_currentHint) ? 10.0 : 0.0;

    final bool showAurora = _textController.text.isEmpty && _imageFile == null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. AURORA
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: showAurora ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 2000),
              curve: Curves.easeInOut,
              child: AnimatedBuilder(
                animation: _auroraController,
                builder: (context, child) {
                  final double t = _auroraController.value;
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-1.0 + t * 0.5, -1.0),
                        end: Alignment(1.0 - t * 0.5, 1.0),
                        colors: [
                          Color.lerp(Colors.black, const Color(0xFF004D40), t)!,
                          Color.lerp(const Color(0xFF1A237E), const Color(0xFF311B92), t)!,
                          Color.lerp(Colors.black, const Color(0xFF4A148C), t)!,
                        ],
                        stops: [0.0 + t * 0.2, 0.5, 1.0 - t * 0.2],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 2. İÇERİK
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 70), // Üst bar boşluğu

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 🔥 DÜZELTME: Avatarın üzerindeki fazlalık padding kaldırıldı
                            CircleAvatar(
                              radius: 22, // Standart boyut
                              backgroundColor: const Color(0xFF1F1F1F),
                              backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                              child: _avatarUrl == null ? const Icon(Icons.person, color: Colors.white54) : null,
                            ),
                            const SizedBox(width: 15),

                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(top: topPadding),
                                child: Stack(
                                  alignment: Alignment.topLeft,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.zero,
                                      child: AnimatedOpacity(
                                        opacity: _textController.text.isEmpty ? _hintOpacity : 0.0,
                                        duration: const Duration(milliseconds: 800),
                                        curve: Curves.easeOut,
                                        child: Text(
                                          _currentHint,
                                          style: hintTextStyle,
                                          maxLines: null,
                                        ),
                                      ),
                                    ),
                                    TextField(
                                      controller: _textController,
                                      style: commonTextStyle,
                                      maxLines: null,
                                      cursorColor: const Color(0xFF6C63FF),
                                      onChanged: (val) => setState(() {}),
                                      decoration: const InputDecoration(
                                        hintText: null,
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (_imageFile != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 25, left: 60),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.file(
                                    _imageFile!,
                                    height: 250,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: GestureDetector(
                                    onTap: () => setState(() => _imageFile = null),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white24, width: 1),
                                      ),
                                      child: const Icon(Icons.close, color: Colors.white, size: 18),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. ÜST BAR (FLOATING)
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // KAPAT BUTONU
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                    ),

                    // GİZLİLİK SEÇİMİ
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Row(
                            children: [
                              _buildVisibilityOption('public', 'Herkes'),
                              const SizedBox(width: 4),
                              _buildVisibilityOption('friends', 'Arkadaşlar'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. ALT BAR (PAYLAŞ VE MEDYA)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 30, left: 16, right: 16),
              height: 70,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(35),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E).withOpacity(0.7),
                      borderRadius: BorderRadius.circular(35),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(FontAwesomeIcons.image, color: Colors.greenAccent, size: 24),
                          tooltip: 'Galeri',
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(FontAwesomeIcons.camera, color: Colors.blueAccent, size: 24),
                          tooltip: 'Kamera',
                        ),

                        const Spacer(),

                        GestureDetector(
                          onTapDown: (_) => setState(() => _isShareButtonPressed = true),
                          onTapUp: (_) {
                            setState(() => _isShareButtonPressed = false);
                            if (!_isLoading) _sharePost();
                          },
                          onTapCancel: () => setState(() => _isShareButtonPressed = false),
                          child: AnimatedScale(
                            scale: _isShareButtonPressed ? 0.95 : 1.0,
                            duration: const Duration(milliseconds: 100),
                            curve: Curves.easeInOut,
                            child: Container(
                              height: 42,
                              padding: const EdgeInsets.symmetric(horizontal: 28),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF6C63FF), Color(0xFF448AFF), Color(0xFF69F0AE)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(21),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6C63FF).withOpacity(0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _isLoading
                                    ? const SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : Text("Paylaş", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilityOption(String value, String label) {
    final isSelected = _visibility == value;
    return GestureDetector(
      onTap: () => setState(() => _visibility = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6C63FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: isSelected ? Colors.white : Colors.grey[400],
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}