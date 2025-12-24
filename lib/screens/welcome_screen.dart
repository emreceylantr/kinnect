import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_screen.dart';

// 🎨 PREMIUM TEMA
const Color kBgDark = Color(0xFF06060A);
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

  late AnimationController _scanController;
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late AnimationController _typeController;

  @override
  void initState() {
    super.initState();

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _typeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scanController.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
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
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      body: Stack(
        children: [
          // 🔮 ARKA PLAN GLOW
          _buildBackgroundGlow(),

          // 📄 SAYFALAR
          PageView(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            children: [
              _buildWelcomePage(),
              _buildPhotoAnalysisPage(),
              _buildTextAnalysisPage(),
              _buildMatchPage(),
            ],
          ),

          // 🔘 ALT BUTONLAR
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

  Widget _buildBackgroundGlow() {
    final colors = [
      [kAccentPurple, kAccentViolet],
      [kAccentCyan, kAccentBlue],
      [kAccentPink, kAccentPurple],
      [kAccentGreen, kAccentCyan],
    ];
    final current = colors[_currentPage];

    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return Positioned(
          top: -150,
          left: -100,
          right: -100,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            height: 450,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 0.7 + _glowController.value * 0.1,
                colors: [
                  current[0].withOpacity(0.25),
                  current[1].withOpacity(0.1),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 📱 SAYFA 1: HOŞ GELDİN
  // ═══════════════════════════════════════════════════════════════
  Widget _buildWelcomePage() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            const SizedBox(height: 80),

            // Logo
            _buildPulsingIcon(FontAwesomeIcons.infinity, kAccentPurple),

            const SizedBox(height: 50),

            // Badge
            _buildBadge("YAPAY ZEKA DESTEKLİ", kAccentPurple),

            const SizedBox(height: 20),

            // Başlık
            Text(
              "Kinnect'e\nHoş Geldin",
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 42,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.1,
                letterSpacing: -1,
              ),
            ),

            const SizedBox(height: 20),

            // Açıklama
            Text(
              "Sadece fotoğraf değil, anlam paylaş.\nSeni gerçekten anlayan kabileleri keşfet.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.white.withOpacity(0.6),
                height: 1.6,
              ),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 📸 SAYFA 2: FOTOĞRAF ANALİZİ
  // ═══════════════════════════════════════════════════════════════
  Widget _buildPhotoAnalysisPage() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            const SizedBox(height: 60),

            // 📸 FOTOĞRAF TARAMA SİMÜLASYONU
            _buildPhotoScanner(),

            const SizedBox(height: 40),

            _buildBadge("GÖRSEL ZEKA", kAccentCyan),

            const SizedBox(height: 20),

            Text(
              "Fotoğraflarını\nAnaliz Ediyoruz",
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 38,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.1,
                letterSpacing: -1,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              "Paylaştığın karelerdeki gizli hobileri,\ntarzını ve ilgi alanlarını AI ile keşfediyoruz.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: Colors.white.withOpacity(0.6),
                height: 1.6,
              ),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoScanner() {
    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Arka fotoğraflar (blur)
          Positioned(
            left: 10,
            child: Transform.rotate(
              angle: -0.1,
              child: _buildMiniPhoto(Colors.blue.withOpacity(0.3)),
            ),
          ),
          Positioned(
            right: 10,
            child: Transform.rotate(
              angle: 0.1,
              child: _buildMiniPhoto(Colors.purple.withOpacity(0.3)),
            ),
          ),

          // Ana fotoğraf
          Container(
            width: 150,
            height: 190,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  kAccentCyan.withOpacity(0.3),
                  kAccentBlue.withOpacity(0.2),
                ],
              ),
              border: Border.all(color: kAccentCyan.withOpacity(0.5), width: 2),
              boxShadow: [
                BoxShadow(
                  color: kAccentCyan.withOpacity(0.3),
                  blurRadius: 30,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Fotoğraf ikonu
                const Center(
                  child: Icon(FontAwesomeIcons.image,
                      size: 50, color: Colors.white30),
                ),

                // Tarama çizgisi
                AnimatedBuilder(
                  animation: _scanController,
                  builder: (context, child) {
                    return Positioned(
                      top: _scanController.value * 170 + 10,
                      left: 10,
                      right: 10,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              kAccentCyan,
                              Colors.transparent,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: kAccentCyan.withOpacity(0.8),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // AI etiketi
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: kAccentCyan,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(FontAwesomeIcons.wandMagicSparkles,
                            size: 10, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          "AI",
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
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

  Widget _buildMiniPhoto(Color color) {
    return Container(
      width: 100,
      height: 130,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color,
        border: Border.all(color: Colors.white10),
      ),
      child: const Center(
        child: Icon(FontAwesomeIcons.image, size: 30, color: Colors.white24),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 📝 SAYFA 3: YAZI ANALİZİ
  // ═══════════════════════════════════════════════════════════════
  Widget _buildTextAnalysisPage() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            const SizedBox(height: 60),

            // 📝 YAZI ANALİZİ
            _buildTextAnalyzer(),

            const SizedBox(height: 40),

            _buildBadge("DOĞAL DİL İŞLEME", kAccentPink),

            const SizedBox(height: 20),

            Text(
              "Yazılarını\nDeşifre Ediyoruz",
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 38,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.1,
                letterSpacing: -1,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              "Tweetlerin ve yazılarının satır aralarındaki\n'seni' okuyoruz. Yüzeysel değil, derin bağlar kur.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: Colors.white.withOpacity(0.6),
                height: 1.6,
              ),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildTextAnalyzer() {
    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  kAccentPink.withOpacity(0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // Yazı kartı
          Container(
            width: 200,
            height: 160,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF15151F),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kAccentPink.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: kAccentPink.withOpacity(0.2),
                  blurRadius: 30,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profil satırı
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [kAccentPink, kAccentPurple],
                        ),
                      ),
                      child: const Icon(FontAwesomeIcons.user,
                          size: 12, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 60,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 40,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Analiz edilen satırlar
                ...List.generate(3, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AnimatedBuilder(
                      animation: _typeController,
                      builder: (context, child) {
                        final widths = [140.0, 100.0, 120.0];
                        final baseWidth = widths[index];
                        final animatedWidth =
                            baseWidth * (0.7 + _typeController.value * 0.3);

                        return Row(
                          children: [
                            Container(
                              width: animatedWidth,
                              height: 8,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    kAccentPink.withOpacity(0.6),
                                    kAccentPink.withOpacity(0.2),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  );
                }),
              ],
            ),
          ),

          // AI Badge
          Positioned(
            top: 20,
            right: 60,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kAccentPink,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: kAccentPink.withOpacity(0.5),
                    blurRadius: 15,
                  ),
                ],
              ),
              child: const Icon(FontAwesomeIcons.brain,
                  size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 👥 SAYFA 4: EŞLEŞTİRME
  // ═══════════════════════════════════════════════════════════════
  Widget _buildMatchPage() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            const SizedBox(height: 80),
            _buildMatchVisual(),
            const SizedBox(height: 50),
            _buildBadge("AI EŞLEŞTİRME", kAccentGreen),
            const SizedBox(height: 20),
            Text(
              "Kabileni Bul",
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 42,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.1,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Fotoğraf ve yazı analizlerine göre sana\nen uygun insanları keşfet ve bağlan.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: Colors.white.withOpacity(0.6),
                height: 1.6,
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchVisual() {
    return SizedBox(
      height: 180,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Pulsing circles
              ...List.generate(3, (index) {
                final value = ((_pulseController.value + index * 0.2) % 1.0);
                return Container(
                  width: 100 + (value * 40) + (index * 25),
                  height: 100 + (value * 40) + (index * 25),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: kAccentGreen.withOpacity(0.3 - value * 0.3),
                      width: 1.5,
                    ),
                  ),
                );
              }),

              // Center icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [kAccentGreen, kAccentCyan],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: kAccentGreen.withOpacity(0.4),
                      blurRadius: 30,
                    ),
                  ],
                ),
                child: const Icon(FontAwesomeIcons.peopleGroup,
                    size: 35, color: Colors.white),
              ),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 🔧 YARDIMCI WİDGETLER
  // ═══════════════════════════════════════════════════════════════
  Widget _buildPulsingIcon(IconData icon, Color color) {
    return SizedBox(
      height: 180,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              ...List.generate(3, (index) {
                final value = ((_pulseController.value + index * 0.2) % 1.0);
                return Container(
                  width: 100 + (value * 40) + (index * 25),
                  height: 100 + (value * 40) + (index * 25),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withOpacity(0.3 - value * 0.3),
                      width: 1.5,
                    ),
                  ),
                );
              }),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient:
                      LinearGradient(colors: [color, color.withOpacity(0.7)]),
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.4), blurRadius: 30),
                  ],
                ),
                child: Icon(icon, size: 40, color: Colors.white),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FontAwesomeIcons.wandMagicSparkles, size: 12, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.spaceGrotesk(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    final isLast = _currentPage == 3;
    final colors = [
      [kAccentPurple, kAccentViolet],
      [kAccentCyan, kAccentBlue],
      [kAccentPink, kAccentPurple],
      [kAccentGreen, kAccentCyan],
    ];
    final current = colors[_currentPage];

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(
              28, 24, 28, MediaQuery.of(context).padding.bottom + 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [kBgDark.withOpacity(0.0), kBgDark.withOpacity(0.95)],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // İndikatörler
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isActive = index == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: isActive ? 32 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient:
                          isActive ? LinearGradient(colors: current) : null,
                      color: isActive ? null : Colors.white24,
                    ),
                  );
                }),
              ),

              const SizedBox(height: 28),

              // Butonlar
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _goToAuth,
                      child: Container(
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Center(
                          child: Text(
                            "Atla",
                            style: GoogleFonts.inter(
                              color: Colors.white60,
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _nextPage,
                      child: Container(
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: current),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: current[0].withOpacity(0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isLast ? "Başlayalım" : "Devam Et",
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isLast
                                  ? Icons.rocket_launch_rounded
                                  : Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 18,
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
