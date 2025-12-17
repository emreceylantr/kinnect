import 'dart:math';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_screen.dart';

// 🎨 TEMA RENKLERİ
const Color kBgColor = Color(0xFF0A0A0F);
const Color kAccentPurple = Color(0xFF6C63FF);
const Color kAccentBlue = Color(0xFF4834D4);
const Color kAccentPink = Color(0xFFE040FB);
const Color kAccentCyan = Color(0xFF00E5FF);

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late AnimationController _floatController;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: "Kinnect'e Hoş Geldin",
      subtitle:
          "Sadece fotoğraf değil, anlam paylaş.\nSeni gerçekten anlayan kabileleri keşfet.",
      icon: FontAwesomeIcons.circleNodes,
      color: kAccentPurple,
    ),
    OnboardingPage(
      title: "Görsel Zeka",
      subtitle:
          "Paylaştığın karelerdeki gizli hobileri\nve tarzını yapay zeka ile analiz ediyoruz.",
      icon: FontAwesomeIcons.wandMagicSparkles,
      color: kAccentCyan,
    ),
    OnboardingPage(
      title: "Kelimelerin Gücü",
      subtitle:
          "Yazılarının satır aralarındaki 'seni' okuyoruz.\nYüzeysel değil, derin bağlar kur.",
      icon: FontAwesomeIcons.brain,
      color: kAccentPink,
    ),
    OnboardingPage(
      title: "Kabileni Bul",
      subtitle:
          "AI destekli eşleştirme ile sana en uygun\ninsanları keşfet ve bağlan.",
      icon: FontAwesomeIcons.userGroup,
      color: Color(0xFFFF9800),
    ),
  ];

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
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
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      body: Stack(
        children: [
          // 🌌 ARKA PLAN EFEKTLERİ
          _buildBackgroundEffects(),

          // 📄 SAYFA İÇERİĞİ
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              return _buildPageContent(_pages[index], index);
            },
          ),

          // 🔘 ALT KONTROLLER
          Positioned(
            left: 0,
            right: 0,
            bottom: 50,
            child: _buildBottomControls(),
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
        final currentColor = _pages[_currentPage].color;

        return Stack(
          children: [
            // Dönen gradient orb - sol üst
            Positioned(
              top: -100,
              left: -100,
              child: Transform.rotate(
                angle: _rotateController.value * 2 * pi,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        currentColor.withOpacity(0.3),
                        currentColor.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Dönen gradient orb - sağ alt
            Positioned(
              bottom: -150,
              right: -150,
              child: Transform.rotate(
                angle: -_rotateController.value * 2 * pi,
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        currentColor.withOpacity(0.2),
                        currentColor.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Merkez glow
            Positioned(
              top: MediaQuery.of(context).size.height * 0.25,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 200 + (_pulseController.value * 50),
                      height: 200 + (_pulseController.value * 50),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            currentColor.withOpacity(0.15),
                            currentColor.withOpacity(0.0),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // 📄 SAYFA İÇERİĞİ
  Widget _buildPageContent(OnboardingPage page, int index) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            const Spacer(flex: 2),

            // 🎯 MERKEZ İKON
            AnimatedBuilder(
              animation: _floatController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, sin(_floatController.value * pi) * 10),
                  child: _buildCenterIcon(page),
                );
              },
            ),

            const Spacer(flex: 1),

            // 📝 BAŞLIK
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Text(
                page.title,
                key: ValueKey(page.title),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 📝 ALT YAZI
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Text(
                page.subtitle,
                key: ValueKey(page.subtitle),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white60,
                  height: 1.6,
                ),
              ),
            ),

            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }

  // 🎯 MERKEZ İKON
  Widget _buildCenterIcon(OnboardingPage page) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Dış halkalar
        ...List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final delay = index * 0.2;
              final value = (_pulseController.value + delay) % 1.0;

              return Container(
                width: 120 + (value * 60) + (index * 30),
                height: 120 + (value * 60) + (index * 30),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: page.color.withOpacity(0.3 - (value * 0.3)),
                    width: 1.5,
                  ),
                ),
              );
            },
          );
        }),

        // Gradient halka
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                page.color.withOpacity(0.2),
                page.color.withOpacity(0.05),
              ],
            ),
            border: Border.all(
              color: page.color.withOpacity(0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: page.color.withOpacity(0.3),
                blurRadius: 40,
                spreadRadius: 5,
              ),
            ],
          ),
        ),

        // İkon
        Icon(
          page.icon,
          size: 50,
          color: page.color,
        ),
      ],
    );
  }

  // 🔘 ALT KONTROLLER
  Widget _buildBottomControls() {
    final isLast = _currentPage == _pages.length - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ATLA BUTONU
          GestureDetector(
            onTap: _goToAuth,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text(
                "Atla",
                style: GoogleFonts.poppins(
                  color: Colors.white38,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ),
          ),

          // SAYFA İNDİKATÖRÜ
          Row(
            children: List.generate(_pages.length, (index) {
              final isActive = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 28 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive ? _pages[_currentPage].color : Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: _pages[_currentPage].color.withOpacity(0.5),
                            blurRadius: 8,
                          ),
                        ]
                      : [],
                ),
              );
            }),
          ),

          // İLERİ / BAŞLA BUTONU
          GestureDetector(
            onTap: _nextPage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: EdgeInsets.symmetric(
                horizontal: isLast ? 28 : 24,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isLast
                      ? [
                          _pages[_currentPage].color,
                          _pages[_currentPage].color.withOpacity(0.7)
                        ]
                      : [
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0.05)
                        ],
                ),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isLast
                      ? Colors.transparent
                      : _pages[_currentPage].color.withOpacity(0.5),
                ),
                boxShadow: isLast
                    ? [
                        BoxShadow(
                          color: _pages[_currentPage].color.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                children: [
                  Text(
                    isLast ? "Başla" : "İleri",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (!isLast) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: _pages[_currentPage].color,
                      size: 18,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 📦 ONBOARDING SAYFA MODELİ
class OnboardingPage {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
