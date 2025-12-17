import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import 'signup_screen.dart';
import 'login_screen.dart';
import 'create_profile_screen.dart';
import 'home_screen.dart';

import '../services/auth_service.dart';

// 🎨 TEMA RENKLERİ
const Color kBgColor = Color(0xFF0A0A0F);
const Color kAccentPurple = Color(0xFF6C63FF);
const Color kAccentBlue = Color(0xFF4834D4);

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  bool _animateLogo = false;
  bool _animateText = false;
  bool _animateButtons = false;
  bool _isLoading = false;

  final AuthService _authService = AuthService();

  late AnimationController _pulseController;
  late AnimationController _rotateController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();

    Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _animateLogo = true);
    });
    Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _animateText = true);
    });
    Timer(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _animateButtons = true);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final result = await _authService.signInWithGoogle();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Google ile Giriş Başarılı!"),
          backgroundColor: kAccentPurple,
        ),
      );

      if (result.hasProfile) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
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
      backgroundColor: kBgColor,
      body: Stack(
        children: [
          // 🌌 ARKA PLAN EFEKTLERİ
          _buildBackgroundEffects(),

          // 📄 İÇERİK
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // 1. LOGO
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 600),
                    opacity: _animateLogo ? 1.0 : 0.0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutBack,
                      transform: Matrix4.translationValues(
                        0,
                        _animateLogo ? 0 : -40,
                        0,
                      ),
                      child: _buildLogo(),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // 2. METİN
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 600),
                    opacity: _animateText ? 1.0 : 0.0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 800),
                      transform: Matrix4.translationValues(
                        0,
                        _animateText ? 0 : 30,
                        0,
                      ),
                      child: Column(
                        children: [
                          Text(
                            "Kabileye Katıl",
                            style: GoogleFonts.poppins(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Gerçek bağlar kurmak için\nşimdi aramıza katıl.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: Colors.white54,
                              fontSize: 15,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // 3. BUTONLAR
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 600),
                    opacity: _animateButtons ? 1.0 : 0.0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutQuart,
                      transform: Matrix4.translationValues(
                        0,
                        _animateButtons ? 0 : 60,
                        0,
                      ),
                      child: Column(
                        children: [
                          // GOOGLE BUTONU
                          _buildSocialButton(
                            icon: FontAwesomeIcons.google,
                            text: "Google ile Devam Et",
                            onTap: _isLoading ? null : _googleSignIn,
                            isPrimary: false,
                          ),
                          const SizedBox(height: 14),

                          // E-POSTA BUTONU
                          _buildSocialButton(
                            icon: FontAwesomeIcons.envelope,
                            text: "E-posta ile Kayıt Ol",
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const SignUpScreen()),
                              );
                            },
                            isPrimary: true,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // GİRİŞ YAP LİNKİ
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 800),
                    opacity: _animateButtons ? 1.0 : 0.0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Zaten hesabın var mı? ",
                          style: GoogleFonts.poppins(
                              color: Colors.white38, fontSize: 14),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const LoginScreen()),
                            );
                          },
                          child: Text(
                            "Giriş Yap",
                            style: GoogleFonts.poppins(
                              color: kAccentPurple,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
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
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16161F),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: kAccentPurple.withOpacity(0.2),
                        blurRadius: 30,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: kAccentPurple),
                      const SizedBox(height: 16),
                      Text(
                        "Giriş yapılıyor...",
                        style: GoogleFonts.poppins(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 🌌 ARKA PLAN EFEKTLERİ
  Widget _buildBackgroundEffects() {
    return AnimatedBuilder(
      animation: _rotateController,
      builder: (context, child) {
        return Stack(
          children: [
            // Dönen gradient orb - sol üst
            Positioned(
              top: -120,
              left: -120,
              child: Transform.rotate(
                angle: _rotateController.value * 2 * pi,
                child: Container(
                  width: 350,
                  height: 350,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        kAccentPurple.withOpacity(0.25),
                        kAccentPurple.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Dönen gradient orb - sağ alt
            Positioned(
              bottom: -180,
              right: -180,
              child: Transform.rotate(
                angle: -_rotateController.value * 2 * pi,
                child: Container(
                  width: 450,
                  height: 450,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        kAccentBlue.withOpacity(0.2),
                        kAccentBlue.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // 🎯 LOGO
  Widget _buildLogo() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing halkalar
        ...List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final delay = index * 0.2;
              final value = (_pulseController.value + delay) % 1.0;

              return Container(
                width: 100 + (value * 50) + (index * 25),
                height: 100 + (value * 50) + (index * 25),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: kAccentPurple.withOpacity(0.25 - (value * 0.25)),
                    width: 1.5,
                  ),
                ),
              );
            },
          );
        }),

        // Ana halka
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                kAccentPurple.withOpacity(0.2),
                kAccentPurple.withOpacity(0.05),
              ],
            ),
            border: Border.all(
              color: kAccentPurple.withOpacity(0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: kAccentPurple.withOpacity(0.3),
                blurRadius: 40,
                spreadRadius: 5,
              ),
            ],
          ),
        ),

        // İkon
        const Icon(
          FontAwesomeIcons.fingerprint,
          size: 48,
          color: kAccentPurple,
        ),
      ],
    );
  }

  // 🔘 SOSYAL BUTON
  Widget _buildSocialButton({
    required IconData icon,
    required String text,
    required VoidCallback? onTap,
    required bool isPrimary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  colors: [kAccentPurple, kAccentBlue],
                )
              : null,
          color: isPrimary ? null : const Color(0xFF16161F),
          borderRadius: BorderRadius.circular(18),
          border: isPrimary
              ? null
              : Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: kAccentPurple.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 12),
            Text(
              text,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
