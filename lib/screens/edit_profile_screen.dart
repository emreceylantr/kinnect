import 'dart:io';
import 'dart:ui'; // Blur efekti için gerekli
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> currentProfile;

  const EditProfileScreen({super.key, required this.currentProfile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();

  bool _isLoading = false;
  File? _imageFile;

  // 🔥 RENK PALETİN
  final Color _colorPurple = const Color(0xFF6C63FF);
  final Color _colorBlue = const Color(0xFF448AFF);
  final Color _colorGreen = const Color(0xFF69F0AE);

  // 🔥 ANİMASYON KONTROLCÜLERİ
  late AnimationController _animController1;
  late AnimationController _animController2;
  late Animation<Offset> _animOffset1;
  late Animation<Offset> _animOffset2;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.currentProfile['full_name'] ?? '';
    _usernameController.text = widget.currentProfile['username'] ?? '';
    _bioController.text = widget.currentProfile['bio'] ?? '';

    // 1. Mor Işık Animasyonu
    _animController1 = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 5)
    )..repeat(reverse: true);

    _animOffset1 = Tween<Offset>(
        begin: const Offset(-0.2, -0.2),
        end: const Offset(0.2, 0.2)
    ).animate(CurvedAnimation(parent: _animController1, curve: Curves.easeInOut));

    // 2. Mavi Işık Animasyonu
    _animController2 = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 4)
    )..repeat(reverse: true);

    _animOffset2 = Tween<Offset>(
        begin: const Offset(0.2, 0.2),
        end: const Offset(-0.2, -0.2)
    ).animate(CurvedAnimation(parent: _animController2, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _animController1.dispose();
    _animController2.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    final userId = Supabase.instance.client.auth.currentUser!.id;

    try {
      if (_usernameController.text.contains(' ')) {
        throw 'Kullanıcı adında boşluk olamaz.';
      }
      if (_nameController.text.isEmpty) {
        throw 'İsim alanı boş bırakılamaz.';
      }

      String? avatarUrl = widget.currentProfile['avatar_url'];

      if (_imageFile != null) {
        final fileExt = _imageFile!.path.split('.').last;
        final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = 'avatars/$fileName';

        await Supabase.instance.client.storage.from('uploads').upload(filePath, _imageFile!);
        avatarUrl = Supabase.instance.client.storage.from('uploads').getPublicUrl(filePath);
      }

      await Supabase.instance.client.from('profiles').update({
        'full_name': _nameController.text.trim(),
        'username': _usernameController.text.trim(),
        'bio': _bioController.text.trim(),
        'avatar_url': avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Profil başarıyla güncellendi! 🚀', style: GoogleFonts.poppins()),
              backgroundColor: _colorGreen.withOpacity(0.8),
              behavior: SnackBarBehavior.floating,
            )
        );
        Navigator.pop(context, true);
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentAvatarUrl = widget.currentProfile['avatar_url'];
    ImageProvider? bgImage;

    if (_imageFile != null) {
      bgImage = FileImage(_imageFile!);
    } else if (currentAvatarUrl != null) {
      bgImage = NetworkImage(currentAvatarUrl);
    }

    return Stack(
      children: [
        // 1. Arka Plan
        Container(color: const Color(0xFF050505)),

        // 2. Hareketli Mor Işık
        SlideTransition(
          position: _animOffset1,
          child: Align(
            alignment: Alignment.topLeft,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _colorPurple.withOpacity(0.25)),
            ),
          ),
        ),

        // 3. Hareketli Mavi Işık
        SlideTransition(
          position: _animOffset2,
          child: Align(
            alignment: Alignment.bottomRight,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _colorBlue.withOpacity(0.25)),
            ),
          ),
        ),

        // 4. Blur
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 60.0, sigmaY: 60.0),
          child: Container(color: Colors.transparent),
        ),

        // 5. İçerik
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: const BackButton(color: Colors.white),
            centerTitle: true,
            title: Text('Profili Düzenle', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            actions: [
              // 🔥 YENİLENMİŞ KAYDET BUTONU
              Padding(
                padding: const EdgeInsets.only(right: 16), // Sağdan boşluk
                child: Center(
                  child: SizedBox(
                    height: 32, // Buton yüksekliği (Küçültüldü)
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _colorGreen, // Neon Yeşil Arka Plan
                        foregroundColor: Colors.black, // Siyah Yazı (Okunabilirlik için)
                        elevation: 0, // Gölge yok (Flat tasarım)
                        padding: const EdgeInsets.symmetric(horizontal: 16), // Yatay dolgu
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), // Tam yuvarlak köşeler
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                          : Text(
                          'Kaydet',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, // Biraz kalın
                              fontSize: 13, // Font boyutu küçültüldü
                              letterSpacing: 0.5 // Harf aralığı
                          )
                      ),
                    ),
                  ),
                ),
              )
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),

                // --- AVATAR ---
                Center(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: [_colorPurple, _colorBlue], begin: Alignment.topLeft, end: Alignment.bottomRight),
                              boxShadow: [BoxShadow(color: _colorPurple.withOpacity(0.3), blurRadius: 20, spreadRadius: 2)]
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                            child: CircleAvatar(
                              radius: 60,
                              backgroundColor: const Color(0xFF1F1F1F),
                              backgroundImage: bgImage,
                              child: bgImage == null ? const Icon(Icons.person, size: 60, color: Colors.white24) : null,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 5, right: 5,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: _colorGreen,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black, width: 3),
                                boxShadow: [BoxShadow(color: _colorGreen.withOpacity(0.4), blurRadius: 8, spreadRadius: 2)]
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.black, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // --- FORM ---
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.fromLTRB(24, 30, 24, 40),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
                  ),
                  child: Column(
                    children: [
                      _buildTextField("Adın Soyadın", _nameController, icon: Icons.person_outline),
                      const SizedBox(height: 24),
                      _buildTextField("Kullanıcı Adı", _usernameController, icon: Icons.alternate_email),
                      const SizedBox(height: 24),
                      _buildTextField("Biyografi", _bioController, maxLines: 3, maxLength: 150, icon: Icons.short_text),

                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline, color: _colorBlue.withOpacity(0.5), size: 14),
                          const SizedBox(width: 6),
                          Text(
                              "Profilin herkese açık olacaktır.",
                              style: GoogleFonts.poppins(color: Colors.white30, fontSize: 12)
                          ),
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1, int? maxLength, IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
              label,
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)
          ),
        ),
        TextField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 15),
          cursorColor: _colorGreen,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1A1A1A),
            counterStyle: GoogleFonts.poppins(color: Colors.white24),
            prefixIcon: icon != null ? Icon(icon, color: _colorBlue.withOpacity(0.7)) : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: _colorPurple, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}