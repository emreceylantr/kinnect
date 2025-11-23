import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import 'signup_screen.dart';
import 'login_screen.dart';
import 'create_profile_screen.dart';
import 'home_screen.dart';

import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _animateLogo = false;
  bool _animateText = false;
  bool _animateButtons = false;
  bool _isLoading = false;

  // YENİ: AuthService kullanıyoruz
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _animateLogo = true);
    });
    Timer(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _animateText = true);
    });
    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _animateButtons = true);
    });
  }

  // --- GOOGLE GİRİŞ FONKSİYONU (SERVICE ÜZERİNDEN) ---
  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final result = await _authService.signInWithGoogle();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Google ile Giriş Başarılı!"),
          backgroundColor: Color(0xFF6C63FF),
        ),
      );

      if (result.hasProfile) {
        // Profil VARSA -> Direkt Ana Sayfa
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        // Profil YOKSA -> Profil Oluşturma
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const CreateProfileScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Giriş Hatası: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: [
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF6C63FF),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // 1. LOGO
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 800),
                  opacity: _animateLogo ? 1.0 : 0.0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutBack,
                    transform: Matrix4.translationValues(
                      0,
                      _animateLogo ? 0 : -50,
                      0,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF6C63FF).withOpacity(0.1),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6C63FF).withOpacity(0.3),
                            blurRadius: 60,
                            spreadRadius: 5,
                          )
                        ],
                      ),
                      child: const Icon(
                        FontAwesomeIcons.fingerprint,
                        size: 70,
                        color: Color(0xFF6C63FF),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // 2. METİN
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 800),
                  opacity: _animateText ? 1.0 : 0.0,
                  child: Column(
                    children: [
                      Text(
                        "Kabileye Katıl",
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Gerçek bağlar kurmak için\nşimdi aramıza katıl.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: Colors.white54,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 2),

                // 3. BUTONLAR
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 800),
                  opacity: _animateButtons ? 1.0 : 0.0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutQuart,
                    transform: Matrix4.translationValues(
                      0,
                      _animateButtons ? 0 : 100,
                      0,
                    ),
                    child: Column(
                      children: [
                        // GOOGLE BUTONU
                        _SocialButton(
                          icon: FontAwesomeIcons.google,
                          text: "Google ile Devam Et",
                          bgColor: const Color(0xFF1E1E1E),
                          textColor: Colors.white,
                          onTap: _isLoading ? () {} : _googleSignIn,
                        ),
                        const SizedBox(height: 15),

                        // E-POSTA BUTONU
                        Container(
                          width: double.infinity,
                          height: 55,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF6C63FF),
                                Color(0xFF4834D4),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6C63FF).withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 5),
                              )
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SignUpScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: Text(
                              "E-posta ile Kayıt Ol",
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // GİRİŞ YAP LİNKİ
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 1000),
                  opacity: _animateButtons ? 1.0 : 0.0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Zaten hesabın var mı? ",
                        style: GoogleFonts.poppins(color: Colors.white54),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );
                        },
                        child: Text(
                          "Giriş Yap",
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF6C63FF),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// BUTON TASARIMI
class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color bgColor;
  final Color textColor;
  final VoidCallback onTap;

  const _SocialButton({
    required this.icon,
    required this.text,
    required this.bgColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: textColor, size: 20),
        label: Text(
          text,
          style: GoogleFonts.poppins(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
