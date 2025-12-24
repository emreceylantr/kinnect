// Kinnect - Yeni kullanıcı kayıt ekranı

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../services/auth_service.dart';

// 🎨 TEMA
const Color kBgDark = Color(0xFF06060A);
const Color kCardDark = Color(0xFF12121A);
const Color kAccentPurple = Color(0xFF7C3AED);
const Color kAccentViolet = Color(0xFF8B5CF6);
const Color kAccentGreen = Color(0xFF10B981);

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  final AuthService _authService = AuthService();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      await _authService.signUpWithEmail(email, password);

      if (mounted) {
        _showSuccessDialog(email);
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Hata: ${e.message}"),
              backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Beklenmedik bir hata oluştu."),
              backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: kCardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kAccentGreen.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(FontAwesomeIcons.check,
                  color: kAccentGreen, size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              "Kayıt Başarılı! 🎉",
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "E-posta adresine ($email) onay linki gönderdik. Lütfen kontrol et.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  color: Colors.white60, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [kAccentPurple, kAccentViolet]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    "Tamam",
                    style: GoogleFonts.inter(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      body: Stack(
        children: [
          // Glow
          Positioned(
            top: -150,
            left: -100,
            right: -100,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  height: 400,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 0.6 + _pulseController.value * 0.1,
                      colors: [
                        kAccentViolet.withOpacity(0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // AppBar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.1)),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),

                          // Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: kAccentPurple.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: kAccentPurple.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(FontAwesomeIcons.wandMagicSparkles,
                                    size: 12, color: kAccentPurple),
                                const SizedBox(width: 8),
                                Text(
                                  "YENİ HESAP",
                                  style: GoogleFonts.spaceGrotesk(
                                    color: kAccentPurple,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Header
                          Text(
                            "Hesap\nOluştur",
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 38,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Kinnect dünyasına adım at ve kabileni bul.",
                            style: GoogleFonts.inter(
                                fontSize: 15,
                                color: Colors.white.withOpacity(0.5)),
                          ),

                          const SizedBox(height: 40),

                          // E-posta
                          _buildTextField(
                            controller: _emailController,
                            label: "E-posta Adresi",
                            icon: FontAwesomeIcons.envelope,
                            validator: (value) {
                              if (value == null || value.isEmpty)
                                return 'E-posta gerekli';
                              if (!value.contains('@'))
                                return 'Geçerli bir e-posta girin';
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          // Şifre
                          _buildTextField(
                            controller: _passwordController,
                            label: "Şifre",
                            icon: FontAwesomeIcons.lock,
                            isPassword: true,
                            useConfirmObscure: false,
                            validator: (value) {
                              if (value == null || value.isEmpty)
                                return 'Şifre gerekli';
                              if (value.length < 8)
                                return 'En az 8 karakter olmalı';
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          // Şifre tekrar
                          _buildTextField(
                            controller: _confirmPasswordController,
                            label: "Şifre Tekrar",
                            icon: FontAwesomeIcons.shieldHalved,
                            isPassword: true,
                            useConfirmObscure: true,
                            validator: (value) {
                              if (value != _passwordController.text)
                                return 'Şifreler eşleşmiyor';
                              return null;
                            },
                          ),

                          const SizedBox(height: 40),

                          // Kayıt butonu
                          GestureDetector(
                            onTap: _isLoading ? null : _signUp,
                            child: Container(
                              width: double.infinity,
                              height: 58,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                    colors: [kAccentPurple, kAccentViolet]),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: kAccentPurple.withOpacity(0.4),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _isLoading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2.5)
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            "Kayıt Ol",
                                            style: GoogleFonts.inter(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(
                                              Icons.arrow_forward_rounded,
                                              color: Colors.white,
                                              size: 20),
                                        ],
                                      ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool useConfirmObscure = false,
    String? Function(String?)? validator,
  }) {
    final obscure = useConfirmObscure ? _obscureConfirm : _obscurePassword;

    return TextFormField(
      controller: controller,
      obscureText: isPassword ? obscure : false,
      style: GoogleFonts.inter(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: Colors.white.withOpacity(0.4)),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(14),
          child: FaIcon(icon, color: kAccentPurple, size: 18),
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: FaIcon(
                  obscure ? FontAwesomeIcons.eyeSlash : FontAwesomeIcons.eye,
                  color: Colors.white38,
                  size: 18,
                ),
                onPressed: () {
                  setState(() {
                    if (useConfirmObscure) {
                      _obscureConfirm = !_obscureConfirm;
                    } else {
                      _obscurePassword = !_obscurePassword;
                    }
                  });
                },
              )
            : null,
        filled: true,
        fillColor: kCardDark,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: kAccentPurple, width: 1.5),
        ),
        errorStyle: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12),
      ),
    );
  }
}
