// Kinnect - Profil düzenleme ekranı

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import '../../create_post/screens/photo_editor_screen.dart';
import '../../../core/constants/border_colors.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> currentProfile;

  const EditProfileScreen({super.key, required this.currentProfile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();

  // 2FA Değişkenleri
  bool _is2FAEnabled = false;
  String? _verifiedPhone;
  final String _selectedCountryCode = "+90";

  bool _isLoading = false;
  File? _imageFile;
  File? _videoFile;

  // 🔥 RENK PALETİ
  final Color _colorPurple = const Color(0xFF6C63FF);
  final Color _colorBlue = const Color(0xFF448AFF);
  final Color _colorGreen = const Color(0xFF69F0AE);

  // 🎨 HALKA (BORDER) SEÇENEKLERİ
  int _selectedBorderIndex = 0;
  // BorderColors.options kullanılıyor (lib/core/constants/border_colors.dart)

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

    _is2FAEnabled = widget.currentProfile['is_2fa_enabled'] ?? false;
    _verifiedPhone = widget.currentProfile['phone'];

    // 🎨 Kaydedilen halka rengini yükle
    _selectedBorderIndex = widget.currentProfile['border_color_index'] ?? 0;

    // Animasyonlar
    _animController1 =
        AnimationController(vsync: this, duration: const Duration(seconds: 5))
          ..repeat(reverse: true);
    _animOffset1 = Tween<Offset>(
            begin: const Offset(-0.2, -0.2), end: const Offset(0.2, 0.2))
        .animate(
            CurvedAnimation(parent: _animController1, curve: Curves.easeInOut));

    _animController2 =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat(reverse: true);
    _animOffset2 = Tween<Offset>(
            begin: const Offset(0.2, 0.2), end: const Offset(-0.2, -0.2))
        .animate(
            CurvedAnimation(parent: _animController2, curve: Curves.easeInOut));
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

  // --- RESİM VE VİDEO SEÇME ---
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);

    if (image != null && mounted) {
      final File? editedImage = await Navigator.push<File>(
        context,
        MaterialPageRoute(
          builder: (context) => PhotoEditorScreen(imageFile: File(image.path)),
        ),
      );

      if (editedImage != null && mounted) {
        setState(() {
          _imageFile = editedImage;
          _videoFile = null;
        });
      }
    }
  }

  Future<void> _pickVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(
        source: ImageSource.gallery, maxDuration: const Duration(seconds: 10));

    if (video != null) {
      final tempDir = await getTemporaryDirectory();
      final String? thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: video.path,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 512,
        quality: 75,
      );

      setState(() {
        _videoFile = File(video.path);
        if (thumbnailPath != null) {
          _imageFile = File(thumbnailPath);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Live Video ve Kapak Resmi Ayarlandı! 🎬",
                style: GoogleFonts.poppins()),
            backgroundColor: _colorGreen));
      }
    }
  }

  // --- RENK SEÇİCİ BOTTOM SHEET ---
  void _showColorPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(// BottomSheet içinde anlık güncelleme için
            builder: (context, setSheetState) {
          return Container(
            height: 180,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(25)),
              border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Profil Halka Rengi",
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                SizedBox(
                  height: 50, // Yüksekliği azalttım
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: BorderColors.options.length,
                    itemBuilder: (context, index) {
                      final colors = BorderColors.options[index];
                      final isSelected = _selectedBorderIndex == index;

                      // Açık renkli butonlarda siyah tik, koyu renklerde beyaz tik
                      final bool isLightColor =
                          colors.first.computeLuminance() > 0.5;

                      return GestureDetector(
                        onTap: () {
                          // Hem ana ekranı hem sheet'i güncelle
                          setState(() => _selectedBorderIndex = index);
                          setSheetState(() => _selectedBorderIndex = index);
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          width: 42, // Boyutu küçülttüm
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                                colors: colors,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight),
                            border: Border.all(
                                color:
                                    isSelected ? Colors.white : Colors.white12,
                                width: isSelected ? 2 : 1),
                          ),
                          child: isSelected
                              ? Icon(Icons.check,
                                  size: 20,
                                  color: isLightColor
                                      ? Colors.black
                                      : Colors.white)
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  // --- KAYDET ---
  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    debugPrint('🔄 Profil kaydetme başladı...');

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      String? avatarUrl;
      String? videoUrl;

      // Resim yükleme
      if (_imageFile != null) {
        debugPrint('📷 Resim yükleniyor...');
        final fileExt = _imageFile!.path.split('.').last;
        final fileName =
            'avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = 'avatars/$fileName';

        await Supabase.instance.client.storage
            .from('uploads')
            .upload(filePath, _imageFile!);
        avatarUrl = Supabase.instance.client.storage
            .from('uploads')
            .getPublicUrl(filePath);
        debugPrint('✅ Resim yüklendi: $avatarUrl');
      }

      // Video yükleme
      if (_videoFile != null) {
        debugPrint('🎥 Video yükleniyor...');
        final fileExt = _videoFile!.path.split('.').last;
        final fileName =
            'video_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = 'videos/$fileName';

        await Supabase.instance.client.storage
            .from('uploads')
            .upload(filePath, _videoFile!);
        videoUrl = Supabase.instance.client.storage
            .from('uploads')
            .getPublicUrl(filePath);
        debugPrint('✅ Video yüklendi: $videoUrl');
      }

      // Profil güncelleme
      final updateData = <String, dynamic>{
        'full_name': _nameController.text.trim(),
        'username': _usernameController.text.trim(),
        'bio': _bioController.text.trim(),
        'border_color_index': _selectedBorderIndex,
      };

      if (avatarUrl != null) updateData['avatar_url'] = avatarUrl;
      if (videoUrl != null) updateData['avatar_video_url'] = videoUrl;

      debugPrint('📤 Supabase güncelleniyor: $updateData');

      await Supabase.instance.client
          .from('profiles')
          .update(updateData)
          .eq('id', userId);

      debugPrint('✅ Profil güncellendi!');

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ HATA: $e');
      debugPrint('📍 Stack: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Hata: $e', style: GoogleFonts.poppins()),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ... (2FA Fonksiyonları buraya gelecek - kod kısalığı için gizlendi) ...

  @override
  Widget build(BuildContext context) {
    final currentAvatarUrl = widget.currentProfile['avatar_url'];
    ImageProvider? bgImage;
    if (_imageFile != null) {
      bgImage = FileImage(_imageFile!);
    } else if (currentAvatarUrl != null) {
      bgImage = NetworkImage(currentAvatarUrl);
    }

    final List<Color> activeBorderColors =
        BorderColors.options[_selectedBorderIndex];

    return Stack(
      children: [
        Container(color: const Color(0xFF050505)),
        // Animasyonlar
        SlideTransition(
            position: _animOffset1,
            child: Align(
                alignment: Alignment.topLeft,
                child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _colorPurple.withValues(alpha: 0.25))))),
        SlideTransition(
            position: _animOffset2,
            child: Align(
                alignment: Alignment.bottomRight,
                child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _colorBlue.withValues(alpha: 0.25))))),
        BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 60.0, sigmaY: 60.0),
            child: Container(color: Colors.transparent)),

        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: const BackButton(color: Colors.white),
            centerTitle: true,
            title: Text('Profili Düzenle',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: SizedBox(
                    height: 32,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _colorGreen,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20))),
                      child: _isLoading
                          ? const SizedBox(
                              height: 14,
                              width: 14,
                              child: CircularProgressIndicator(
                                  color: Colors.black, strokeWidth: 2))
                          : Text('Kaydet',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
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
                Center(
                  child: Column(
                    children: [
                      // PROFİL FOTOĞRAFI
                      GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                      colors: activeBorderColors,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight),
                                  boxShadow: [
                                    BoxShadow(
                                        color: activeBorderColors.first
                                            .withValues(alpha: 0.5),
                                        blurRadius: 20,
                                        spreadRadius: 2)
                                  ]),
                              child: CircleAvatar(
                                  radius: 60,
                                  backgroundColor: const Color(0xFF1F1F1F),
                                  backgroundImage: bgImage,
                                  child: bgImage == null
                                      ? const Icon(Icons.person,
                                          size: 60, color: Colors.white24)
                                      : null),
                            ),
                            Positioned(
                                bottom: 5,
                                right: 5,
                                child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                        color: _colorGreen,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.black, width: 2)),
                                    child: const Icon(Icons.camera_alt,
                                        color: Colors.black, size: 18))),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 🔥 BUTON GRUBU (Live Video & Renk Değiştir) 🔥
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 1. LIVE VIDEO BUTONU (Solda)
                          _buildActionButton(
                            icon: _videoFile != null
                                ? Icons.check_circle
                                : Icons.slow_motion_video,
                            label: _videoFile != null
                                ? "Live Seçildi"
                                : "Live Video Ekle", // Metin güncellendi
                            color:
                                _videoFile != null ? _colorGreen : Colors.white,
                            onTap: _pickVideo,
                            isActive: _videoFile != null,
                          ),

                          const SizedBox(width: 16),

                          // 2. HALKA RENGİ BUTONU (Sağda)
                          _buildActionButton(
                            icon: Icons.palette_outlined,
                            label: "Halka Rengi",
                            color: Colors.white,
                            onTap: _showColorPicker,
                            isActive: false,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // FORM ALANLARI
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08))),
                  child: Column(
                    children: [
                      _buildTextField("Adın Soyadın", _nameController,
                          icon: Icons.person_outline),
                      const SizedBox(height: 24),
                      _buildTextField("Kullanıcı Adı", _usernameController,
                          icon: Icons.alternate_email),
                      const SizedBox(height: 24),
                      _buildTextField("Biyografi", _bioController,
                          maxLines: 3, maxLength: 150, icon: Icons.short_text),
                      // ... Switchler buraya gelecek ...
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

  // YARDIMCI WIDGET: BUTON YAPISI
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    bool isActive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? _colorGreen.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? _colorGreen : Colors.white12,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {int maxLines = 1, int? maxLength, IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(label,
                style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500))),
        TextField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1A1A1A),
            prefixIcon: icon != null
                ? Icon(icon, color: _colorBlue.withValues(alpha: 0.7))
                : null,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.05))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: _colorPurple, width: 1.5)),
          ),
        ),
      ],
    );
  }
}
