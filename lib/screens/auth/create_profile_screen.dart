import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // SystemChrome için
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';

// Dosya yollarının doğruluğundan emin olun
import '../auth/login_screen.dart';
import '../../services/profile_service.dart';
import '../../repositories/profile_repository.dart';
import '../main/home_screen.dart';

class CreateProfileScreen extends StatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _bioController = TextEditingController();

  File? _imageFile;
  bool _isLoading = false;

  late final ProfileService _profileService;

  // 3'lü Renk Paleti
  final List<Color> _liveGradientColors = const [
    Color(0xFF6C63FF),
    Color(0xFF448AFF),
    Color(0xFF69F0AE),
  ];

  @override
  void initState() {
    super.initState();
    _profileService = ProfileService(
      ProfileRepository(Supabase.instance.client),
    );

    // ANDROID STATUS BAR & NAV BAR AYARI (Şeffaflık için)
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _imageFile = File(image.path));
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      await _profileService.createOrUpdateProfile(
        userId: userId,
        username: _usernameController.text.trim(),
        fullName: _fullNameController.text.trim(),
        bio: _bioController.text.trim(),
        avatarFile: _imageFile,
      );

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Profil kaydedilirken hata: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🔹 Navigasyon: Login Ekranına Dönüş
  void _navigateToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Widget _buildOvalTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      height: maxLines == 1 ? 65 : null,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(35),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Center(
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 15),
          validator: validator,
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            labelText: label,
            labelStyle:
            GoogleFonts.poppins(color: Colors.white60, fontSize: 14),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            alignLabelWithHint: true,
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 20, right: 15),
              child: Icon(
                icon,
                color: const Color(0xFF6C63FF),
                size: 20,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 55,
              minHeight: 55,
            ),
            border: InputBorder.none,

            // 🔹 Padding Ayarları
            contentPadding: maxLines == 1
                ? const EdgeInsets.only(bottom: 18)
                : const EdgeInsets.fromLTRB(20, 25, 20, 10),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: [
          // 1. ARKA PLAN EFEKTLERİ
          Positioned(
            top: -50,
            right: -50,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6C63FF).withOpacity(0.2),
                ),
              ),
            ),
          ),

          // 2. PPL ANIMASYONU (EN ALTTA, ARKADA)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: 0.6,
              child: Lottie.asset(
                'assets/animations/ppl.json',
                fit: BoxFit.fitWidth,
                height: 200,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
            ),
          ),

          // 3. ÖN PLAN İÇERİĞİ
          Column(
            children: [
              // Üst Status Bar Boşluğu
              SizedBox(height: topPadding + 10),

              // HEADER
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 22),
                      onPressed: _navigateToLogin,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: _liveGradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: Text(
                          "PROFİL OLUŞTUR",
                          style: GoogleFonts.syne(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 5),
                      width: 70,
                      height: 70,
                      child: Lottie.asset(
                        'assets/animations/prof.json',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.star, color: Colors.white24);
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // ORTA ALAN (FORM - Scrollable)
              Expanded(
                child: SingleChildScrollView(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        // PROFİL FOTOĞRAFI ALANI
                        GestureDetector(
                          onTap: _pickImage,
                          child: Center(
                            child: Stack(
                              children: [
                                Container(
                                  width: 130,
                                  height: 130,
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: _imageFile == null
                                        ? LinearGradient(
                                      colors: _liveGradientColors,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                        : null,
                                    color: _imageFile != null
                                        ? Colors.transparent
                                        : null,
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF1A1A1A),
                                      border: _imageFile != null
                                          ? Border.all(
                                          color: Colors.white24, width: 1)
                                          : null,
                                      image: _imageFile != null
                                          ? DecorationImage(
                                        image: FileImage(_imageFile!),
                                        fit: BoxFit.cover,
                                      )
                                          : null,
                                    ),
                                    child: _imageFile == null
                                        ? const Icon(
                                      Icons.person_outline_rounded,
                                      color: Color(0xFF6C63FF),
                                      size: 50,
                                    )
                                        : null,
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2C2C2C),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: const Color(0xFF6C63FF),
                                          width: 2),
                                    ),
                                    child: const Icon(
                                      Icons.add_a_photo_rounded,
                                      color: Color(0xFF69F0AE),
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // TEXT FIELDS
                        _buildOvalTextField(
                          controller: _usernameController,
                          label: "Kullanıcı Adı",
                          icon: FontAwesomeIcons.at,
                          validator: (value) =>
                          (value == null || value.isEmpty)
                              ? 'Gerekli alan'
                              : null,
                        ),
                        _buildOvalTextField(
                          controller: _fullNameController,
                          label: "Görünen İsim",
                          icon: FontAwesomeIcons.user,
                          validator: (value) =>
                          (value == null || value.isEmpty)
                              ? 'Gerekli alan'
                              : null,
                        ),
                        _buildOvalTextField(
                          controller: _bioController,
                          label: "Biyografi",
                          icon: FontAwesomeIcons.alignLeft,
                          maxLines: 2,
                        ),

                        // 🔹 BAŞLAYALIM BUTONU (YUKARI YAKLAŞTIRILDI)
                        const SizedBox(height: 15), // 20'den 15'e çekildi (Daha yakın)

                        Align(
                          // 0.85 ile tam sağ yerine çok az sola kaydırdık
                          alignment: const Alignment(0.85, 0.0),
                          child: Container(
                            height: 45,
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _liveGradientColors,
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _saveProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(horizontal: 25),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                                  : Text(
                                "BAŞLAYALIM",
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 50), // Alttan biraz boşluk
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}