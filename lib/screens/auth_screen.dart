import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'signup_screen.dart';
import 'login_screen.dart';
import 'create_profile_screen.dart';
import 'home_screen.dart';

import '../services/auth_service.dart';

// 🎨 PREMIUM TEMA RENKLERİ
const Color kBgDark = Color(0xFF06060A);
const Color kBgCard = Color(0xFF12121A);
const Color kAccentPurple = Color(0xFF7C3AED);
const Color kAccentViolet = Color(0xFF8B5CF6);
const Color kAccentPink = Color(0xFFEC4899);

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  bool _showContent = false;
  bool _isLoading = false;

  final AuthService _authService = AuthService();

  late AnimationController _pulseController;
  late AnimationController _floatController;
  late List<FloatingOrb> _orbs;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _orbs = List.generate(5, (_) => FloatingOrb.random());

    Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _showContent = true);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final result = await _authService.signInWithGoogle();

      if (!mounted) return;

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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: kBgDark,
      body: Stack(
        children: [
          // 🌌 FLOATING ORBS
          AnimatedBuilder(
            animation: _floatController,
            builder: (context, child) {
              return CustomPaint(
                size: size,
                painter: OrbPainter(
                  orbs: _orbs,
                  progress: _floatController.value,
                ),
              );
            },
          ),

          // 🔮 TOP GRADIENT
          Positioned(
            top: -200,
            left: -100,
            right: -100,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  height: 500,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.8 + _pulseController.value * 0.1,
                      colors: [
                        kAccentPurple.withOpacity(0.2),
                        kAccentViolet.withOpacity(0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 📄 CONTENT
          SafeArea(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 800),
              opacity: _showContent ? 1.0 : 0.0,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 800),
                offset: _showContent ? Offset.zero : const Offset(0, 0.1),
                curve: Curves.easeOutCubic,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      const SizedBox(height: 60),

                      // 🎯 LOGO
                      _buildLogo(),

                      const SizedBox(height: 50),

                      // 📝 TEXT (SABİT)
                      _buildTextSection(),

                      const Spacer(),

                      // 🔘 BUTTONS
                      _buildButtonsSection(),

                      const SizedBox(height: 24),

                      // LOGIN LINK
                      _buildLoginLink(),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ⏳ LOADING
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return SizedBox(
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow rings (sadece halkalar animasyonlu)
              ...List.generate(3, (index) {
                final delay = index * 0.2;
                final value = ((_pulseController.value + delay) % 1.0);

                return Container(
                  width: 110 + (value * 35) + (index * 22),
                  height: 110 + (value * 35) + (index * 22),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: kAccentPurple.withOpacity(0.25 - (value * 0.25)),
                      width: 1.5,
                    ),
                  ),
                );
              }),

              // Main circle + Logo
              ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          kAccentPurple.withOpacity(0.25),
                          kAccentViolet.withOpacity(0.15),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: kAccentPurple.withOpacity(0.35),
                          blurRadius: 50,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/icon/icon.png',
                        width: 55,
                        height: 55,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 📝 TEXT (SABİT - HİÇ ANİMASYON YOK)
  Widget _buildTextSection() {
    return Column(
      children: [
        // Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: kAccentPurple.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: kAccentPurple.withOpacity(0.3),
            ),
          ),
          child: Text(
            "YENİ NESİL SOSYAL AĞ",
            style: GoogleFonts.poppins(
              color: kAccentPurple,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Title
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [kAccentPurple, kAccentViolet, kAccentPink],
          ).createShader(bounds),
          child: Text(
            "Kabileye\nKatıl",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 44,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -1,
              height: 1.1,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Subtitle
        Text(
          "Gerçek bağlar kurmak için\nşimdi aramıza katıl.",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: Colors.white.withOpacity(0.5),
            fontSize: 16,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildButtonsSection() {
    return Column(
      children: [
        // Google Button
        _buildAuthButton(
          icon: 'assets/icon/icon.png',
          text: "Google ile Devam Et",
          onTap: _isLoading ? null : _googleSignIn,
          isPrimary: false,
          useGoogleIcon: true,
        ),

        const SizedBox(height: 14),

        // Email Button
        _buildAuthButton(
          icon: '',
          text: "E-posta ile Kayıt Ol",
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SignUpScreen()),
            );
          },
          isPrimary: true,
          useGoogleIcon: false,
        ),
      ],
    );
  }

  Widget _buildAuthButton({
    required String icon,
    required String text,
    required VoidCallback? onTap,
    required bool isPrimary,
    required bool useGoogleIcon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  colors: [kAccentPurple, kAccentViolet],
                )
              : null,
          color: isPrimary ? null : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(18),
          border: isPrimary
              ? null
              : Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: kAccentPurple.withOpacity(0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (useGoogleIcon)
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.all(3),
                child: Image.network(
                  'https://www.google.com/favicon.ico',
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.g_mobiledata,
                    size: 16,
                    color: Colors.blue,
                  ),
                ),
              )
            else
              const Icon(Icons.email_outlined, color: Colors.white, size: 20),
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

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Zaten hesabın var mı? ",
          style: GoogleFonts.poppins(
            color: Colors.white.withOpacity(0.4),
            fontSize: 14,
          ),
        ),
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [kAccentPurple, kAccentPink],
            ).createShader(bounds),
            child: Text(
              "Giriş Yap",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        color: kBgDark.withOpacity(0.8),
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: kBgCard.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: kAccentPurple.withOpacity(0.2),
                      blurRadius: 40,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 50,
                      height: 50,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(kAccentPurple),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Giriş yapılıyor...",
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 🔮 FLOATING ORB SİSTEMİ
class FloatingOrb {
  double x;
  double y;
  double size;
  double speed;
  Color color;

  FloatingOrb({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.color,
  });

  factory FloatingOrb.random() {
    final random = Random();
    final colors = [kAccentPurple, kAccentViolet, kAccentPink];
    return FloatingOrb(
      x: random.nextDouble(),
      y: random.nextDouble(),
      size: random.nextDouble() * 150 + 80,
      speed: random.nextDouble() * 0.2 + 0.05,
      color: colors[random.nextInt(colors.length)],
    );
  }
}

class OrbPainter extends CustomPainter {
  final List<FloatingOrb> orbs;
  final double progress;

  OrbPainter({required this.orbs, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (var orb in orbs) {
      final x = orb.x * size.width;
      final y = ((orb.y + progress * orb.speed) % 1.2 - 0.1) * size.height;

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            orb.color.withOpacity(0.15),
            orb.color.withOpacity(0.0),
          ],
        ).createShader(Rect.fromCircle(center: Offset(x, y), radius: orb.size));

      canvas.drawCircle(Offset(x, y), orb.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant OrbPainter oldDelegate) => true;
}
