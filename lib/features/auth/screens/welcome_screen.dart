// Kinnect - Uygulama giriş ekranı (REVİZE - KÜÇÜK LOGO, 0.8 ÇIKIŞ SCALE)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_screen.dart';
import '../widgets/welcome_widgets.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
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
          WelcomeBackgroundGlow(currentPage: _currentPage),

          // 📄 SAYFALAR
          PageView(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            children: [
              _buildWelcomePage(),
              const PhotoAnalysisSection(),
              const TextAnalysisSection(),
              const MatchAnalysisSection(),
            ],
          ),

          // 🔘 ALT BUTONLAR
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: WelcomeBottomSection(
              currentPage: _currentPage,
              onSkip: _goToAuth,
              onContinue: _nextPage,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomePage() {
    return SafeArea(
      child: Stack(
        children: [
          const Align(
            alignment: Alignment(0, -0.5),
            child: WelcomeFeatureHub(),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 140,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                Text(
                  "Sadece fotoğraf değil, anlam paylaş.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.7),
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
