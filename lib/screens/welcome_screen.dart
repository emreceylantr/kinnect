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
  late AnimationController _scannerController;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: "Kinnect'e Hoş Geldin",
      subtitle:
          "Sadece fotoğraf değil, anlam paylaş.\nSeni gerçekten anlayan kabileleri keşfet.",
      icon: FontAwesomeIcons.circleNodes,
      color: kAccentPurple,
      type: PageType.glow,
    ),
    OnboardingPage(
      title: "Görsel Zeka",
      subtitle:
          "Paylaştığın karelerdeki gizli hobileri\nve tarzını yapay zeka ile analiz ediyoruz.",
      icon: FontAwesomeIcons.images,
      color: kAccentCyan,
      type: PageType.scanner,
    ),
    OnboardingPage(
      title: "Kelimelerin Gücü",
      subtitle:
          "Yazılarının satır aralarındaki 'seni' okuyoruz.\nYüzeysel değil, derin bağlar kur.",
      icon: FontAwesomeIcons.wandMagicSparkles,
      color: kAccentPink,
      type: PageType.textAnalysis,
    ),
    OnboardingPage(
      title: "Kabileni Bul",
      subtitle:
          "AI destekli eşleştirme ile sana en uygun\ninsanları keşfet ve bağlan.",
      icon: FontAwesomeIcons.userGroup,
      color: const Color(0xFFFF9800),
      type: PageType.glow,
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

    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    _scannerController.dispose();
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
              return _buildPageContent(_pages[index]);
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
    final currentColor = _pages[_currentPage].color;

    return AnimatedBuilder(
      animation: _rotateController,
      builder: (context, child) {
        return Stack(
          children: [
            // Merkez glow (sabit, hareket etmiyor)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.22,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  width: 250,
                  height: 250,
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
          ],
        );
      },
    );
  }

  // 📄 SAYFA İÇERİĞİ
  Widget _buildPageContent(OnboardingPage page) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            const SizedBox(height: 80),

            // 🎯 MERKEZ İKON (animasyonlu)
            SizedBox(
              height: 220,
              child: _buildCenterWidget(page),
            ),

            const SizedBox(height: 50),

            // 📝 BAŞLIK (SABİT - animasyon yok)
            Text(
              page.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.5,
                height: 1.2,
              ),
            ),

            const SizedBox(height: 16),

            // 📝 ALT YAZI (SABİT - animasyon yok)
            Text(
              page.subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: Colors.white60,
                height: 1.6,
              ),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }

  // 🎯 MERKEZ WİDGET (Tipine göre farklı)
  Widget _buildCenterWidget(OnboardingPage page) {
    switch (page.type) {
      case PageType.scanner:
        return _buildScannerWidget(page);
      case PageType.textAnalysis:
        return _buildTextAnalysisWidget(page);
      case PageType.glow:
      default:
        return _buildGlowWidget(page);
    }
  }

  // 🔆 GLOW WİDGET (Sayfa 1 ve 4)
  Widget _buildGlowWidget(OnboardingPage page) {
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
                width: 100 + (value * 50) + (index * 25),
                height: 100 + (value * 50) + (index * 25),
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
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: page.color.withOpacity(0.08),
            boxShadow: [
              BoxShadow(
                color: page.color.withOpacity(0.3),
                blurRadius: 50,
                spreadRadius: 5,
              ),
            ],
          ),
        ),

        // İkon
        Icon(
          page.icon,
          size: 55,
          color: page.color,
        ),
      ],
    );
  }

  // 🔍 SCANNER WİDGET (Sayfa 2 - Görsel Zeka)
  Widget _buildScannerWidget(OnboardingPage page) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Arka plan glow
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: page.color.withOpacity(0.08),
              boxShadow: [
                BoxShadow(
                  color: page.color.withOpacity(0.15),
                  blurRadius: 50,
                ),
              ],
            ),
          ),

          // İkon
          Icon(page.icon, size: 70, color: page.color),

          // Tarama çizgisi
          AnimatedBuilder(
            animation: _scannerController,
            builder: (context, child) {
              return Positioned(
                top: 30 + (_scannerController.value * 140),
                child: Container(
                  width: 120,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(
                      colors: [
                        page.color.withOpacity(0.0),
                        page.color.withOpacity(0.8),
                        page.color.withOpacity(0.0),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: page.color.withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // 📝 TEXT ANALYSIS WİDGET (Sayfa 3 - Kelimeler)
  Widget _buildTextAnalysisWidget(OnboardingPage page) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Arka plan glow
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: page.color.withOpacity(0.08),
              boxShadow: [
                BoxShadow(
                  color: page.color.withOpacity(0.15),
                  blurRadius: 50,
                ),
              ],
            ),
          ),

          // Belge kartı
          Container(
            width: 110,
            height: 130,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A24),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: page.color.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Başlık satırı
                Container(
                  width: 35,
                  height: 6,
                  decoration: BoxDecoration(
                    color: page.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 14),

                // Animasyonlu satırlar
                ...List.generate(3, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final widths = [55.0, 70.0, 45.0];
                        final offset = index * 0.3;
                        final value = (_pulseController.value + offset) % 1.0;
                        final width = widths[index] + (value * 15) - 7.5;

                        return Container(
                          width: width,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white30,
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        );
                      },
                    ),
                  );
                }),
              ],
            ),
          ),

          // AI ikonu
          Positioned(
            top: 25,
            right: 35,
            child: Icon(
              FontAwesomeIcons.wandMagicSparkles,
              size: 18,
              color: page.color,
            ),
          ),
        ],
      ),
    );
  }

  // 🔘 ALT KONTROLLER
  Widget _buildBottomControls() {
    final isLast = _currentPage == _pages.length - 1;
    final currentColor = _pages[_currentPage].color;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ATLA BUTONU
          GestureDetector(
            onTap: _goToAuth,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  color: isActive ? currentColor : Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: currentColor.withOpacity(0.5),
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
                horizontal: isLast ? 24 : 20,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                gradient: isLast
                    ? LinearGradient(
                        colors: [currentColor, currentColor.withOpacity(0.7)],
                      )
                    : null,
                color: isLast ? null : currentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(25),
                border: isLast
                    ? null
                    : Border.all(color: currentColor.withOpacity(0.5)),
                boxShadow: isLast
                    ? [
                        BoxShadow(
                          color: currentColor.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : [],
              ),
              child: Text(
                isLast ? "Başla" : "İleri",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 📦 SAYFA TİPLERİ
enum PageType { glow, scanner, textAnalysis }

// 📦 ONBOARDING SAYFA MODELİ
class OnboardingPage {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final PageType type;

  OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.type,
  });
}
