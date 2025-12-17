import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_screen.dart';

// 🎨 PREMIUM TEMA RENKLERİ
const Color kBgDark = Color(0xFF06060A);
const Color kBgCard = Color(0xFF12121A);
const Color kAccentPurple = Color(0xFF7C3AED);
const Color kAccentViolet = Color(0xFF8B5CF6);
const Color kAccentPink = Color(0xFFEC4899);
const Color kAccentBlue = Color(0xFF3B82F6);
const Color kAccentCyan = Color(0xFF06B6D4);
const Color kAccentGreen = Color(0xFF10B981);

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _particleController;
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late List<Particle> _particles;

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: "Kinnect",
      subtitle: "Bağlantıların ötesinde",
      description:
          "Sadece fotoğraf değil, anlam paylaş.\nSeni gerçekten anlayan kabileleri keşfet.",
      icon: FontAwesomeIcons.infinity,
      gradient: [kAccentPurple, kAccentViolet],
    ),
    OnboardingData(
      title: "AI Destekli",
      subtitle: "Görsel zeka",
      description:
          "Paylaştığın karelerdeki gizli hobileri\nve tarzını yapay zeka ile analiz ediyoruz.",
      icon: FontAwesomeIcons.wandMagicSparkles,
      gradient: [kAccentCyan, kAccentBlue],
    ),
    OnboardingData(
      title: "Derin Bağlar",
      subtitle: "Kelimelerin gücü",
      description:
          "Yazılarının satır aralarındaki 'seni' okuyoruz.\nYüzeysel değil, gerçek bağlar kur.",
      icon: FontAwesomeIcons.brain,
      gradient: [kAccentPink, kAccentPurple],
    ),
    OnboardingData(
      title: "Kabileni Bul",
      subtitle: "Eşleştirme",
      description:
          "AI destekli eşleştirme ile sana en uygun\ninsanları keşfet ve bağlan.",
      icon: FontAwesomeIcons.peopleGroup,
      gradient: [kAccentGreen, kAccentCyan],
    ),
  ];

  @override
  void initState() {
    super.initState();

    // Parçacık animasyonu
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // Pulse animasyonu
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Glow animasyonu
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    // Parçacıkları oluştur
    _particles = List.generate(50, (_) => Particle.random());
  }

  @override
  void dispose() {
    _pageController.dispose();
    _particleController.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutQuint,
      );
    } else {
      _goToAuth();
    }
  }

  void _goToAuth() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (_, __, ___) => const AuthScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final currentGradient = _pages[_currentPage].gradient;

    return Scaffold(
      backgroundColor: kBgDark,
      body: Stack(
        children: [
          // 🌌 PARTİKÜL ARKA PLAN
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, child) {
              return CustomPaint(
                size: size,
                painter: ParticlePainter(
                  particles: _particles,
                  progress: _particleController.value,
                  color: currentGradient[0],
                ),
              );
            },
          ),

          // 🔮 GRADIENT MESH
          Positioned(
            top: -size.height * 0.2,
            left: -size.width * 0.3,
            child: AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  width: size.width * 1.2,
                  height: size.width * 1.2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        currentGradient[0]
                            .withOpacity(0.15 + _glowController.value * 0.1),
                        currentGradient[1].withOpacity(0.05),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),

          // 📄 SAYFA İÇERİĞİ
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              return _PageContent(
                data: _pages[index],
                pulseAnimation: _pulseController,
                isActive: index == _currentPage,
              );
            },
          ),

          // 🔘 ALT KONTROLLER
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    final isLast = _currentPage == _pages.length - 1;
    final currentGradient = _pages[_currentPage].gradient;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            28,
            24,
            28,
            MediaQuery.of(context).padding.bottom + 24,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                kBgDark.withOpacity(0.0),
                kBgDark.withOpacity(0.95),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // İNDİKATÖRLER
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (index) {
                  final isActive = index == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: isActive ? 32 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: isActive
                          ? LinearGradient(colors: currentGradient)
                          : null,
                      color: isActive ? null : Colors.white.withOpacity(0.2),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: currentGradient[0].withOpacity(0.5),
                                blurRadius: 12,
                              ),
                            ]
                          : [],
                    ),
                  );
                }),
              ),

              const SizedBox(height: 32),

              // BUTONLAR
              Row(
                children: [
                  // ATLA
                  Expanded(
                    child: GestureDetector(
                      onTap: _goToAuth,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            "Atla",
                            style: GoogleFonts.poppins(
                              color: Colors.white60,
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // İLERİ / BAŞLA
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _nextPage,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: currentGradient,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: currentGradient[0].withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isLast ? "Başlayalım" : "Devam Et",
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isLast
                                  ? Icons.rocket_launch_rounded
                                  : Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 📄 SAYFA İÇERİĞİ
class _PageContent extends StatelessWidget {
  final OnboardingData data;
  final Animation<double> pulseAnimation;
  final bool isActive;

  const _PageContent({
    required this.data,
    required this.pulseAnimation,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            const Spacer(flex: 2),

            // 🎯 MERKEZ İKON
            AnimatedBuilder(
              animation: pulseAnimation,
              builder: (context, child) {
                return _buildIconSection();
              },
            ),

            const Spacer(),

            // 📝 METİNLER
            _buildTextSection(),

            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildIconSection() {
    final scale = 1.0 + (pulseAnimation.value * 0.05);

    return Transform.scale(
      scale: scale,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Dış halkalar
          ...List.generate(3, (index) {
            final delay = index * 0.25;
            final value = ((pulseAnimation.value + delay) % 1.0);

            return Container(
              width: 140 + (value * 40) + (index * 30),
              height: 140 + (value * 40) + (index * 30),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: data.gradient[0].withOpacity(0.3 - (value * 0.3)),
                  width: 1.5,
                ),
              ),
            );
          }),

          // Glassmorphism container
          ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      data.gradient[0].withOpacity(0.2),
                      data.gradient[1].withOpacity(0.1),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: data.gradient[0].withOpacity(0.3),
                      blurRadius: 40,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  data.icon,
                  size: 50,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextSection() {
    return Column(
      children: [
        // Alt başlık (küçük)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: data.gradient[0].withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: data.gradient[0].withOpacity(0.3),
            ),
          ),
          child: Text(
            data.subtitle.toUpperCase(),
            style: GoogleFonts.poppins(
              color: data.gradient[0],
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Ana başlık
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: data.gradient,
          ).createShader(bounds),
          child: Text(
            data.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -1,
              height: 1.1,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Açıklama
        Text(
          data.description,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: Colors.white.withOpacity(0.6),
            height: 1.7,
          ),
        ),
      ],
    );
  }
}

// 📦 VERİ MODELİ
class OnboardingData {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final List<Color> gradient;

  OnboardingData({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.gradient,
  });
}

// ✨ PARTİKÜL SİSTEMİ
class Particle {
  double x;
  double y;
  double size;
  double speed;
  double opacity;

  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });

  factory Particle.random() {
    final random = Random();
    return Particle(
      x: random.nextDouble(),
      y: random.nextDouble(),
      size: random.nextDouble() * 3 + 1,
      speed: random.nextDouble() * 0.3 + 0.1,
      opacity: random.nextDouble() * 0.5 + 0.1,
    );
  }
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double progress;
  final Color color;

  ParticlePainter({
    required this.particles,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      final y = (particle.y + progress * particle.speed) % 1.0;
      final paint = Paint()
        ..color = color.withOpacity(particle.opacity * 0.5)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(particle.x * size.width, y * size.height),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) => true;
}
