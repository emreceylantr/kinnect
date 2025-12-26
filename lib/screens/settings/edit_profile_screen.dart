// Kinnect - Profil düzenleme ekranı

import 'dart:io';
import 'dart:ui'; // Blur efekti için
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:country_code_picker/country_code_picker.dart';
// 🔥 YENİ EKLENEN IMPORTLAR
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

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
  String _selectedCountryCode = "+90"; // Varsayılan Türkiye

  bool _isLoading = false;
  File? _imageFile;
  File? _videoFile; // 🎥 Live Video Dosyası

  // 🔥 RENK PALETİ
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

    _is2FAEnabled = widget.currentProfile['is_2fa_enabled'] ?? false;
    _verifiedPhone = widget.currentProfile['phone'];

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

  // FOTOĞRAF SEÇME - 🔥 GÜNCELLENDİ: Video varsa siler
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image =
    await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
        _videoFile = null; // 🔥 ÖNEMLİ: Yeni foto seçilince videoyu iptal et
      });
    }
  }

  // 🎥 VİDEO (LIVE PHOTO) SEÇME
  Future<void> _pickVideo() async {
    final ImagePicker picker = ImagePicker();
    // Live photo'nun video kısmını seçtirmek için
    final XFile? video = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 10) // Çok uzun videoları engelle
    );

    if (video != null) {
      // 1. Videodan Thumbnail Üretme
      final tempDir = await getTemporaryDirectory();
      final String? thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: video.path,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 512, // Profil fotosu için yeterli kalite
        quality: 75,
      );

      // 2. State'i Güncelleme
      setState(() {
        _videoFile = File(video.path); // Videoyu kaydet
        // Eğer thumbnail başarıyla oluştuysa, profil fotoğrafını da o yap!
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

  // --- 2FA İŞLEMLERİ ---

  // 1. Telefon Numarası İste
  void _showPhoneInputDialog() {
    final phoneController = TextEditingController();
    String tempCountryCode = _selectedCountryCode;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setStateDialog) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Telefon Doğrulama",
              style: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Lütfen telefon numaranızı girin. Giriş yaparken bu numaraya kod gönderilecektir.",
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 20),

              // 🔥 ÜLKE KODU VE NUMARA ALANI 🔥
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    // Sol Taraf: Ülke Seçici
                    CountryCodePicker(
                      onChanged: (country) {
                        tempCountryCode = country.dialCode!;
                      },
                      initialSelection: 'TR', // Varsayılan Türkiye
                      favorite: const ['+90', 'US', 'GB'],
                      showCountryOnly: false,
                      showOnlyCountryWhenClosed: false,
                      alignLeft: false,
                      textStyle: GoogleFonts.poppins(color: Colors.white),
                      dialogBackgroundColor: const Color(0xFF2A2A2A),
                      barrierColor: Colors.black87,
                      searchDecoration: InputDecoration(
                        hintText: "Ülke Ara...",
                        hintStyle: const TextStyle(color: Colors.white30),
                        fillColor: const Color(0xFF1A1A1A),
                        filled: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none),
                      ),
                    ),

                    // Dikey Çizgi
                    Container(width: 1, height: 30, color: Colors.white24),

                    // Sağ Taraf: Numara Girişi
                    Expanded(
                      child: TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: "555 123 45 67",
                          hintStyle: GoogleFonts.poppins(color: Colors.white30),
                          border: InputBorder.none,
                          contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("İptal",
                  style: TextStyle(color: Colors.redAccent)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _colorGreen,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                String rawNumber = phoneController.text.trim();
                if (rawNumber.startsWith('0')) {
                  rawNumber = rawNumber.substring(1);
                }
                final fullNumber = "$tempCountryCode$rawNumber";
                Navigator.pop(context);
                _sendSmsCode(fullNumber);
              },
              child: const Text("Kod Gönder",
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }),
    );
  }

  // 2. SMS Gönder
  Future<void> _sendSmsCode(String fullPhone) async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(phone: fullPhone),
      );

      if (mounted) {
        setState(() => _isLoading = false);
        _showOtpInputDialog(fullPhone);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("SMS Gönderilemedi: $e"),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  // 3. Kodu İste
  void _showOtpInputDialog(String phone) {
    final otpController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Doğrulama Kodu",
            style: GoogleFonts.poppins(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("$phone numarasına gelen kodu girin.",
                style:
                GoogleFonts.poppins(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 20),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontSize: 24, letterSpacing: 5),
              decoration: InputDecoration(
                hintText: "------",
                hintStyle: const TextStyle(color: Colors.white24),
                counterText: "",
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _colorGreen)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("İptal",
                  style: TextStyle(color: Colors.redAccent))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _colorGreen),
              onPressed: () {
                Navigator.pop(context);
                _verifyOtpAndEnable2FA(phone, otpController.text.trim());
              },
              child:
              const Text("Onayla", style: TextStyle(color: Colors.black))),
        ],
      ),
    );
  }

  // 4. Kodu Doğrula ve 2FA'yı Aç
  Future<void> _verifyOtpAndEnable2FA(String phone, String token) async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.auth.verifyOTP(
        phone: phone,
        token: token,
        type: OtpType.phoneChange,
      );

      if (response.user != null) {
        final userId = Supabase.instance.client.auth.currentUser!.id;

        await Supabase.instance.client.from('profiles').update({
          'is_2fa_enabled': true,
          'phone': phone,
        }).eq('id', userId);

        setState(() {
          _is2FAEnabled = true;
          _verifiedPhone = phone;
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text("2FA ve Telefon Başarıyla Eklendi! 🔒"),
              backgroundColor: _colorGreen));
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Hatalı Kod: $e"), backgroundColor: Colors.red));
      }
    }
  }

  // 5. 2FA Kapatma
  Future<void> _disable2FA() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('profiles').update({
        'is_2fa_enabled': false,
      }).eq('id', userId);

      setState(() {
        _is2FAEnabled = false;
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("2FA Kapatıldı.")));
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // PROFİLİ KAYDET - 🔥 GÜNCELLENDİ: Video iptal mantığı eklendi
  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    final userId = Supabase.instance.client.auth.currentUser!.id;

    try {
      if (_usernameController.text.contains(' '))
        throw 'Kullanıcı adında boşluk olamaz.';
      if (_nameController.text.isEmpty) throw 'İsim alanı boş bırakılamaz.';

      String? avatarUrl = widget.currentProfile['avatar_url'];
      String? videoUrl = widget.currentProfile['avatar_video_url'];

      // 🔥 YENİ MANTIK:
      // Eğer kullanıcı YENİ bir resim seçtiyse (_imageFile != null)
      // VE yeni bir video seçmediyse (_videoFile == null)
      // Demek ki statik fotoğrafa dönmek istiyor. Videoyu NULL yap.
      if (_imageFile != null && _videoFile == null) {
        videoUrl = null;
      }

      // Resim Yükleme
      if (_imageFile != null) {
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
      }

      // 🎥 Video Yükleme
      if (_videoFile != null) {
        final fileExt = _videoFile!.path.split('.').last;
        final fileName =
            'live_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = 'avatars/$fileName';
        await Supabase.instance.client.storage
            .from('uploads')
            .upload(filePath, _videoFile!);
        videoUrl = Supabase.instance.client.storage
            .from('uploads')
            .getPublicUrl(filePath);
      }

      await Supabase.instance.client.from('profiles').update({
        'full_name': _nameController.text.trim(),
        'username': _usernameController.text.trim(),
        'bio': _bioController.text.trim(),
        'avatar_url': avatarUrl,
        'avatar_video_url': videoUrl, // Veritabanına video linkini yaz (veya null gönder)
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Profil güncellendi! 🚀', style: GoogleFonts.poppins()),
          backgroundColor: _colorGreen,
        ));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
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
        Container(color: const Color(0xFF050505)),
        SlideTransition(
            position: _animOffset1,
            child: Align(
                alignment: Alignment.topLeft,
                child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _colorPurple.withOpacity(0.25))))),
        SlideTransition(
            position: _animOffset2,
            child: Align(
                alignment: Alignment.bottomRight,
                child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _colorBlue.withOpacity(0.25))))),
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
                      GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                      colors: [_colorPurple, _colorBlue]),
                                  boxShadow: [
                                    BoxShadow(
                                        color: _colorPurple.withOpacity(0.3),
                                        blurRadius: 20)
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
                      const SizedBox(height: 16),

                      // 🔥 LIVE VIDEO SEÇME BUTONU
                      InkWell(
                        onTap: _pickVideo,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _videoFile != null
                                ? _colorGreen.withOpacity(0.2)
                                : Colors.white10,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: _videoFile != null
                                    ? _colorGreen
                                    : Colors.white24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                  _videoFile != null
                                      ? Icons.check_circle
                                      : Icons.slow_motion_video,
                                  color: _videoFile != null
                                      ? _colorGreen
                                      : Colors.white,
                                  size: 20),
                              const SizedBox(width: 8),
                              Text(
                                _videoFile != null
                                    ? "Live Video Seçildi"
                                    : "Live Video Ekle (Canlı Foto)",
                                style: GoogleFonts.poppins(
                                    color: _videoFile != null
                                        ? _colorGreen
                                        : Colors.white,
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(30),
                      border:
                      Border.all(color: Colors.white.withOpacity(0.08))),
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

                      const SizedBox(height: 30),
                      // 🔥 GÜVENLİK BÖLÜMÜ 🔥
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.shield_outlined,
                              color: _colorGreen, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("İki Adımlı Doğrulama (2FA)",
                                    style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600)),
                                Text(
                                    _is2FAEnabled
                                        ? "Aktif: $_verifiedPhone"
                                        : "Kapalı - Güvenliği artır",
                                    style: GoogleFonts.poppins(
                                        color: Colors.white54, fontSize: 11)),
                              ],
                            ),
                          ),
                          Switch(
                            value: _is2FAEnabled,
                            activeColor: Colors.black,
                            activeTrackColor: _colorGreen,
                            inactiveThumbColor: Colors.grey,
                            inactiveTrackColor: Colors.white10,
                            onChanged: (val) {
                              if (val)
                                _showPhoneInputDialog();
                              else
                                _disable2FA();
                            },
                          )
                        ],
                      ),
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
                ? Icon(icon, color: _colorBlue.withOpacity(0.7))
                : null,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.05))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: _colorPurple, width: 1.5)),
          ),
        ),
      ],
    );
  }
}