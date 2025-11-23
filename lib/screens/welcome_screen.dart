import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _scannerController;
  late AnimationController _textPulseController;

  @override
  void initState() {
    super.initState();

    // 1. GÖRSEL İÇİN TARAMA (SCANNER)
    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // 2. METİN İÇİN NABIZ/İŞLEME (PULSE)
    _textPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _textPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IntroductionScreen(
      globalBackgroundColor: const Color(0xFF050505),
      allowImplicitScrolling: true,

      pages: [
        // 1. SAYFA: AĞ
        _buildPage(
          title: "Kinnect'e Hoş Geldin",
          body:
          "Sadece fotoğraf değil, anlam paylaş. Seni gerçekten anlayan kabileleri keşfet.",
          customWidget: _buildGlowIcon(
              FontAwesomeIcons.circleNodes, const Color(0xFF6C63FF)),
        ),

        // 2. SAYFA: GÖRSEL ZEKA (Fotoğraf + Scanner Efekti)
        _buildPage(
          title: "Görsel Zeka",
          body:
          "Paylaştığın karelerdeki gizli hobileri ve tarzını yapay zeka ile analiz ediyoruz.",
          customWidget: _ScannerWidget(
            controller: _scannerController,
            icon: FontAwesomeIcons.images,
            color: Colors.blueAccent,
          ),
        ),

        // 3. SAYFA: KELİME GÜCÜ (YENİ EFEKT: PROCESSING / ANALİZ)
        _buildPage(
          title: "Kelimelerin Gücü",
          body:
          "Tweetlerin ve yazıların satır aralarındaki 'seni' okuyoruz. Yüzeysel değil, derin bağlar kur.",
          customWidget: _TextAnalysisWidget(
            controller: _textPulseController,
            color: Colors.pinkAccent,
          ),
        ),
      ],

      // --- BUTONLAR ---
      onDone: () => _goToAuth(context),
      onSkip: () => _goToAuth(context),
      showSkipButton: true,

      skip: Text(
        "Atla",
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: Colors.white54,
        ),
      ),

      next: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF6C63FF).withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF6C63FF), width: 1),
        ),
        child: Text(
          "İleri",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),

      done: Container(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF4834D4)],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C63FF).withOpacity(0.4),
              blurRadius: 15,
            )
          ],
        ),
        child: Text(
          "Başla",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),

      dotsDecorator: DotsDecorator(
        size: const Size.square(8.0),
        activeSize: const Size(30.0, 8.0),
        activeColor: const Color(0xFF6C63FF),
        color: Colors.white24,
        spacing: const EdgeInsets.symmetric(horizontal: 4.0),
        activeShape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.0)),
      ),
    );
  }

  void _goToAuth(BuildContext context) {
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

  PageViewModel _buildPage({
    required String title,
    required String body,
    required Widget customWidget,
  }) {
    return PageViewModel(
      title: title,
      body: body,
      image: Center(child: customWidget),
      decoration: PageDecoration(
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        bodyTextStyle: GoogleFonts.poppins(
          fontSize: 16,
          color: Colors.white70,
          height: 1.6,
        ),
        imagePadding: const EdgeInsets.only(top: 100),
        contentMargin: const EdgeInsets.symmetric(horizontal: 20),
        pageColor: const Color(0xFF050505),
      ),
    );
  }

  Widget _buildGlowIcon(IconData icon, Color color) {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.05),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 60,
            spreadRadius: 5,
          )
        ],
      ),
      child: Icon(icon, size: 80, color: color),
    );
  }
}

// --- SCANNER WIDGET (Görsel Zeka İçin) ---
class _ScannerWidget extends StatelessWidget {
  final AnimationController controller;
  final IconData icon;
  final Color color;

  const _ScannerWidget({
    required this.controller,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.05),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.1),
                  blurRadius: 40,
                )
              ],
            ),
          ),
          Icon(icon, size: 80, color: color),
          AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              return Positioned(
                top: controller.value * 140 + 30,
                child: Container(
                  width: 120,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        color.withOpacity(0.0),
                        color.withOpacity(0.6),
                        color.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// --- TEXT ANALYSIS WIDGET (Kelime Gücü İçin) ---
class _TextAnalysisWidget extends StatelessWidget {
  final AnimationController controller;
  final Color color;

  const _TextAnalysisWidget({
    required this.controller,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Arkadaki Glow Efekti
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.05),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.15),
                  blurRadius: 50,
                )
              ],
            ),
          ),

          // Belge / Post Kartı Görünümü
          Container(
            width: 120,
            height: 140,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Başlık Satırı (Sabit)
                Container(
                  width: 40,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 20),

                // 1. Hareketli Satır (Analiz ediliyor)
                AnimatedBuilder(
                  animation: controller,
                  builder: (context, child) {
                    return Container(
                      width: 60 + (controller.value * 20), // Uzayıp kısalır
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white38,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),

                // 2. Hareketli Satır (Ters hareket)
                AnimatedBuilder(
                  animation: controller,
                  builder: (context, child) {
                    return Container(
                      width: 70 - (controller.value * 20), // Kısalıp uzar
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white38,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),

                // 3. Hareketli Satır
                AnimatedBuilder(
                  animation: controller,
                  builder: (context, child) {
                    return Container(
                      width: 50 + (controller.value * 10),
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white38,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Köşedeki İkon (Sanki AI etiketi gibi)
          Positioned(
            top: 20,
            right: 30,
            child: Icon(
              FontAwesomeIcons.wandMagicSparkles,
              size: 20,
              color: color,
            ),
          )
        ],
      ),
    );
  }
}
