import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import '../screens/auth_screen.dart';

// 🎨 EXTRA COLORS (Not in AuthScreen)
const Color kAccentBlue = Color(0xFF3B82F6);
const Color kAccentCyan = Color(0xFF06B6D4);
const Color kAccentGreen = Color(0xFF10B981);

class WelcomeBackgroundGlow extends StatefulWidget {
  final int currentPage;
  const WelcomeBackgroundGlow({super.key, required this.currentPage});

  @override
  State<WelcomeBackgroundGlow> createState() => _WelcomeBackgroundGlowState();
}

class _WelcomeBackgroundGlowState extends State<WelcomeBackgroundGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = [
      [kAccentPurple, kAccentViolet],
      [kAccentCyan, kAccentBlue],
      [kAccentPink, kAccentPurple],
      [kAccentGreen, kAccentCyan],
    ];
    final current = colors[widget.currentPage];

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
                  current[0].withValues(alpha: 0.25),
                  current[1].withValues(alpha: 0.1),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class WelcomeBadge extends StatelessWidget {
  final String text;
  final Color color;
  const WelcomeBadge({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
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
}

class WelcomeFeatureTag extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const WelcomeFeatureTag({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 8,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class WelcomeFeatureHub extends StatefulWidget {
  const WelcomeFeatureHub({super.key});

  @override
  State<WelcomeFeatureHub> createState() => _WelcomeFeatureHubState();
}

class _WelcomeFeatureHubState extends State<WelcomeFeatureHub>
    with TickerProviderStateMixin {
  late AnimationController _streamController;
  late AnimationController _entranceController;

  final inputWords = [
    "Keşfeti gördün mü?",
    "Selam!",
    "Fotoğrafın harika",
    "Naber?",
    "Konum neresi?",
    "Bu şarkı ne?",
    "Tanışalım mı?",
    "Harika!"
  ];
  final outputWords = [
    "Bağ",
    "Dostluk",
    "Güven",
    "Anlam",
    "Kabile",
    "Samimiyet",
    "Gerçek",
    "His"
  ];

  final features = [
    {
      'title': 'Yapay Zeka',
      'icon': FontAwesomeIcons.wandMagicSparkles,
      'align': const Alignment(-0.95, -0.75),
      'slideBegin': const Offset(-0.5, -0.5),
    },
    {
      'title': 'Yenilikçi ve Eğlenceli',
      'icon': FontAwesomeIcons.faceSmileBeam,
      'align': const Alignment(0.95, -0.75),
      'slideBegin': const Offset(0.5, -0.5),
    },
    {
      'title': 'Derin Analiz',
      'icon': FontAwesomeIcons.chartPie,
      'align': const Alignment(-0.95, 0.75),
      'slideBegin': const Offset(-0.5, 0.5),
    },
    {
      'title': 'Gizli ve Güvenli',
      'icon': FontAwesomeIcons.shieldHeart,
      'align': const Alignment(0.95, 0.75),
      'slideBegin': const Offset(0.5, 0.5),
    },
  ];

  @override
  void initState() {
    super.initState();
    _streamController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        _entranceController.forward();
      }
    });
  }

  @override
  void dispose() {
    _streamController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      width: 320,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _streamController,
            builder: (context, child) {
              return Stack(
                clipBehavior: Clip.none,
                children: List.generate(12, (index) {
                  final offset = index * (1.0 / 12.0);
                  final rawProgress = (_streamController.value + offset) % 1.0;
                  final isInput = rawProgress < 0.5;

                  double top, left, scale, opacity;
                  String text;
                  Color bgColor;

                  const center = 160.0;

                  if (isInput) {
                    final t = rawProgress * 2;
                    final curveT = Curves.easeInBack.transform(t);
                    final startX = -50.0 + (index * 35.0);
                    final startY = -120.0 - (index % 3 * 30);

                    left = lerpDouble(startX, center - 25, curveT)!;
                    top = lerpDouble(startY, center - 10, curveT)!;
                    scale = lerpDouble(1.0, 0.0, curveT)!;
                    opacity = lerpDouble(0.8, 0.0, curveT)!;
                    text = inputWords[index % inputWords.length];
                    bgColor = Colors.white.withValues(alpha: 0.12);
                  } else {
                    final t = (rawProgress - 0.5) * 2;
                    final curveT = Curves.elasticOut.transform(t);
                    final directionMultiplier = (index % 3) - 1;
                    final endX = center + (directionMultiplier * 90.0);
                    const endY = 450.0;

                    left = lerpDouble(center - 30, endX - 30, t)!;
                    top = lerpDouble(center, endY, t)!;
                    scale = lerpDouble(0.0, 0.8, curveT)!;
                    opacity = t > 0.8 ? (1.0 - t) * 5 : 1.0;
                    text = outputWords[index % outputWords.length];
                    bgColor = kAccentPurple;
                  }

                  return Positioned(
                    top: top,
                    left: left,
                    child: Transform.scale(
                      scale: scale,
                      child: Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(12),
                              topRight: const Radius.circular(12),
                              bottomLeft: Radius.circular(isInput ? 0 : 12),
                              bottomRight: Radius.circular(isInput ? 12 : 0),
                            ),
                            boxShadow: !isInput
                                ? [
                                    BoxShadow(
                                        color: kAccentPurple.withValues(
                                            alpha: 0.4),
                                        blurRadius: 8)
                                  ]
                                : null,
                          ),
                          child: Text(
                            text,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: !isInput
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
          Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: 160,
              height: 160,
              child: Lottie.asset(
                'assets/animations/iki.json',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kAccentPurple.withValues(alpha: 0.2),
                        border: Border.all(color: kAccentPurple)),
                    child: const Icon(Icons.error, color: kAccentPurple),
                  );
                },
              ),
            ),
          ),
          ...List.generate(features.length, (index) {
            final f = features[index];
            final start = index * 0.25;
            final end = start + 0.25;

            final animation = CurvedAnimation(
              parent: _entranceController,
              curve: Interval(start, end, curve: Curves.easeOutCubic),
            );

            return Align(
              alignment: f['align'] as Alignment,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: f['slideBegin'] as Offset,
                  end: Offset.zero,
                ).animate(animation),
                child: FadeTransition(
                  opacity: animation,
                  child: WelcomeFeatureTag(
                    title: f['title'] as String,
                    icon: f['icon'] as IconData,
                    color: kAccentPurple,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class PhotoAnalysisSection extends StatefulWidget {
  const PhotoAnalysisSection({super.key});

  @override
  State<PhotoAnalysisSection> createState() => _PhotoAnalysisSectionState();
}

class _PhotoAnalysisSectionState extends State<PhotoAnalysisSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 60),
        SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 10,
                child: Transform.rotate(
                  angle: -0.1,
                  child: _buildMiniPhoto(Colors.blue.withValues(alpha: 0.3)),
                ),
              ),
              Positioned(
                right: 10,
                child: Transform.rotate(
                  angle: 0.1,
                  child: _buildMiniPhoto(Colors.purple.withValues(alpha: 0.3)),
                ),
              ),
              Container(
                width: 150,
                height: 190,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      kAccentCyan.withValues(alpha: 0.3),
                      kAccentBlue.withValues(alpha: 0.2),
                    ],
                  ),
                  border: Border.all(
                      color: kAccentCyan.withValues(alpha: 0.5), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: kAccentCyan.withValues(alpha: 0.3),
                      blurRadius: 30,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    const Center(
                      child: Icon(FontAwesomeIcons.image,
                          size: 50, color: Colors.white30),
                    ),
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
                              gradient: const LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  kAccentCyan,
                                  Colors.transparent,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: kAccentCyan.withValues(alpha: 0.8),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
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
        ),
        const SizedBox(height: 40),
        const WelcomeBadge(text: "GÖRSEL ZEKA", color: kAccentCyan),
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
            color: Colors.white.withValues(alpha: 0.6),
            height: 1.6,
          ),
        ),
      ],
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
}

class TextAnalysisSection extends StatefulWidget {
  const TextAnalysisSection({super.key});

  @override
  State<TextAnalysisSection> createState() => _TextAnalysisSectionState();
}

class _TextAnalysisSectionState extends State<TextAnalysisSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _typeController;

  @override
  void initState() {
    super.initState();
    _typeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _typeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 60),
        SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      kAccentPink.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Container(
                width: 200,
                height: 160,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF15151F),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kAccentPink.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: kAccentPink.withValues(alpha: 0.2),
                      blurRadius: 30,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
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
                                        kAccentPink.withValues(alpha: 0.6),
                                        kAccentPink.withValues(alpha: 0.2),
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
                        color: kAccentPink.withValues(alpha: 0.5),
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
        ),
        const SizedBox(height: 40),
        const WelcomeBadge(text: "DOĞAL DİL İŞLEME", color: kAccentPink),
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
            color: Colors.white.withValues(alpha: 0.6),
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

class MatchAnalysisSection extends StatefulWidget {
  const MatchAnalysisSection({super.key});

  @override
  State<MatchAnalysisSection> createState() => _MatchAnalysisSectionState();
}

class _MatchAnalysisSectionState extends State<MatchAnalysisSection>
    with SingleTickerProviderStateMixin {
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
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 80),
        SizedBox(
          height: 180,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  ...List.generate(3, (index) {
                    final value =
                        ((_pulseController.value + index * 0.2) % 1.0);
                    return Container(
                      width: 100 + (value * 40) + (index * 25),
                      height: 100 + (value * 40) + (index * 25),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              kAccentGreen.withValues(alpha: 0.3 - value * 0.3),
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
                      gradient: const LinearGradient(
                        colors: [kAccentGreen, kAccentCyan],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: kAccentGreen.withValues(alpha: 0.4),
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
        ),
        const SizedBox(height: 50),
        const WelcomeBadge(text: "AI EŞLEŞTİRME", color: kAccentGreen),
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
            color: Colors.white.withValues(alpha: 0.6),
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

class WelcomeBottomSection extends StatelessWidget {
  final int currentPage;
  final VoidCallback onSkip;
  final VoidCallback onContinue;

  const WelcomeBottomSection({
    super.key,
    required this.currentPage,
    required this.onSkip,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = currentPage == 3;
    final colors = [
      [kAccentPurple, kAccentViolet],
      [kAccentCyan, kAccentBlue],
      [kAccentPink, kAccentPurple],
      [kAccentGreen, kAccentCyan],
    ];
    final current = colors[currentPage];

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
              colors: [
                kBgDark.withValues(alpha: 0.0),
                kBgDark.withValues(alpha: 0.95),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isActive = index == currentPage;
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
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onSkip,
                      child: Container(
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1)),
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
                      onTap: onContinue,
                      child: Container(
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: current),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: current[0].withValues(alpha: 0.4),
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
