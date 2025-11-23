// lib/screens/create_profile_screen.dart

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:math' as math;

import '../services/profile_service.dart';
import '../repositories/profile_repository.dart';
import 'home_screen.dart';

class CreateProfileScreen extends StatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _bioController = TextEditingController();

  File? _imageFile;
  bool _isLoading = false;
  late AnimationController _rotationController;

  // 🔹 BURAYA EKLİYORUZ
  late final ProfileService _profileService;

  @override
  void initState() {
    super.initState();

    // ✅ DOĞRU BAĞLANTI: önce repository, sonra service
    _profileService = ProfileService(
      ProfileRepository(Supabase.instance.client),
    );

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }


  @override
  void dispose() {
    _rotationController.dispose();
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
    // 1. Form validation
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
            Text("Kimlik oluşturuldu. Ana sayfaya yönlendiriliyorsun..."),
            backgroundColor: Color(0xFF6C63FF),
          ),
        );

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

  Widget _buildCyberTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            style: GoogleFonts.poppins(color: Colors.white),
            validator: validator,
            decoration: InputDecoration(
              labelText: label,
              labelStyle:
              GoogleFonts.poppins(color: Colors.white54, fontSize: 14),
              alignLabelWithHint: true,
              prefixIcon: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 15,
                  top: 15,
                  bottom: maxLines > 1 ? 50 : 15,
                ),
                child: FaIcon(
                  icon,
                  color: const Color(0xFF6C63FF),
                  size: 18,
                ),
              ),
              border: InputBorder.none,
              contentPadding:
              const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6C63FF).withOpacity(0.15),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blueAccent.withOpacity(0.1),
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding:
              const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      "KİMLİK OLUŞTUR",
                      style: GoogleFonts.orbitron(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "Dijital varlığını tanımla.",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 50),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _rotationController,
                              builder: (_, child) => Transform.rotate(
                                angle: _rotationController.value * 2 * math.pi,
                                child: child,
                              ),
                              child: Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF6C63FF)
                                        .withOpacity(0.5),
                                    width: 2,
                                  ),
                                  gradient: const SweepGradient(
                                    colors: [
                                      Colors.transparent,
                                      Color(0xFF6C63FF),
                                      Colors.transparent,
                                    ],
                                    stops: [0.0, 0.5, 1.0],
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF101010),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6C63FF)
                                        .withOpacity(0.3),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  )
                                ],
                                image: _imageFile != null
                                    ? DecorationImage(
                                  image: FileImage(_imageFile!),
                                  fit: BoxFit.cover,
                                )
                                    : null,
                              ),
                              child: _imageFile == null
                                  ? const Icon(
                                FontAwesomeIcons.userAstronaut,
                                color: Colors.white24,
                                size: 50,
                              )
                                  : null,
                            ),
                            Positioned(
                              bottom: 5,
                              right: 5,
                              child: Container(
                                width: 45,
                                height: 45,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF6C63FF),
                                      Color(0xFF4834D4),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  border:
                                  Border.all(color: Colors.black, width: 3),
                                ),
                                child: const Center(
                                  child: FaIcon(
                                    FontAwesomeIcons.camera,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 50),
                    _buildCyberTextField(
                      controller: _usernameController,
                      label: "Kullanıcı Adı",
                      icon: FontAwesomeIcons.at,
                      validator: (value) =>
                      (value == null || value.isEmpty)
                          ? 'Kullanıcı adı gerekli'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    _buildCyberTextField(
                      controller: _fullNameController,
                      label: "Görünen İsim",
                      icon: FontAwesomeIcons.idCard,
                      validator: (value) =>
                      (value == null || value.isEmpty)
                          ? 'İsim gerekli'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    _buildCyberTextField(
                      controller: _bioController,
                      label: "Biyografi (Yapay Zeka Analizi İçin)",
                      icon: FontAwesomeIcons.fingerprint,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 50),
                    Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF4834D4)],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6C63FF).withOpacity(0.5),
                            blurRadius: 25,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                          color: Colors.white,
                        )
                            : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Sistemi Başlat",
                              style: GoogleFonts.orbitron(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(Icons.arrow_forward,
                                color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
