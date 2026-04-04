import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// Kendi projenizdeki importları buraya ekleyin:
// import '../../../core/theme/app_colors.dart';

// ─────────────────────────────────────────────
// Data Model
// ─────────────────────────────────────────────

class _QuizQuestion {
  final String question;
  final String a, b, c, d;
  final String aShort, bShort, cShort, dShort;
  final int section;
  final String sectionTitle;
  final String sectionEmoji;

  const _QuizQuestion({
    required this.question,
    required this.a,
    required this.b,
    required this.c,
    required this.d,
    required this.aShort,
    required this.bShort,
    required this.cShort,
    required this.dShort,
    required this.section,
    required this.sectionTitle,
    required this.sectionEmoji,
  });
}

const List<_QuizQuestion> _kQuestions = [
  // ── Bölüm 1: Bireysel Vibe ──────────────────────────────────────────────────
  _QuizQuestion(
    section: 1, sectionTitle: 'Bireysel Vibe', sectionEmoji: '🔥',
    question: 'Hafta sonu enerjin hangisini daha çok yansıtıyor?',
    a: 'Planlı ve dolu dolu — dışarıda, etkinlikte veya sosyalleşerek.',
    b: 'Evde, kahve/çay eşliğinde rahatça film, dizi veya oyun.',
    c: 'Tamamen anlık — rüzgar nereye eserse, programsız takılarak.',
    d: 'Kendi projelerime odaklanarak, yeni şeyler öğrenip üreterek.',
    aShort: 'Planlı & Sosyal 🎉', bShort: 'Evde & Sakin 🏠',
    cShort: 'Spontane ⚡', dShort: 'Üretken 🎯',
  ),
  _QuizQuestion(
    section: 1, sectionTitle: 'Bireysel Vibe', sectionEmoji: '🔥',
    question: 'Hayatta seni en çok ne harlar (motive eder)?',
    a: 'Başarı hissi — kendimi sürekli bir üst seviyeye taşımak.',
    b: 'Sevdiklerimle kurduğum güçlü, derin bağlar.',
    c: 'Yeni deneyimler, maceralar ve bilinmeyeni keşfetmek.',
    d: 'Topluma veya insanlara faydalı bir şeyler bırakabilmek.',
    aShort: 'Başarı Hissi 🏆', bShort: 'Derin Bağlar 💕',
    cShort: 'Macera & Yeni Deneyimler 🌍', dShort: 'Topluma & İnsanlara Fayda 🤝',
  ),
  _QuizQuestion(
    section: 1, sectionTitle: 'Bireysel Vibe', sectionEmoji: '🔥',
    question: 'Bir ortamda \'buzları eriten\' ilk hamleyi genelde kim yapar?',
    a: 'Kesinlikle ben! Sessizliğe dayanamam, muhabbeti başlatırım.',
    b: 'Duruma göre — ortam güven verirse açılırım.',
    c: 'Genelde karşıdan beklerim, ilk adım atmak zor gelir.',
    d: 'Söze gerek duymam — beden dilimle enerjimi belli ederim.',
    aShort: 'İlk ben ✋', bShort: 'Duruma göre 🤔',
    cShort: 'Karşıdan beklerim 🌸', dShort: 'Beden dilimle enerjimi belli ederim 🕺',
  ),
  _QuizQuestion(
    section: 1, sectionTitle: 'Bireysel Vibe', sectionEmoji: '🔥',
    question: 'Stresli bir günün ardından \'zihin sıfırlama\' yöntemin?',
    a: 'Doğada yalnız bir yürüyüş veya sessiz bir ortam.',
    b: 'Derin strateji gerektiren oyun veya sürükleyici aktivite.',
    c: 'Kulaklığı takıp favori müziklerimle kaybolmak veya spor.',
    d: 'Güvendiğim bir dostla saatlerce her şeyi filtresiz konuşmak.',
    aShort: 'Doğa & Sessizlik 🌿', bShort: 'Oyun & Aktivite 🎮',
    cShort: 'Müzik & Spor 🎵', dShort: 'Arkadaşlarım ile Sohbet🗣️',
  ),
  // ── Bölüm 2: Kıvılcım ───────────────────────────────────────────────────────
  _QuizQuestion(
    section: 2, sectionTitle: 'Kıvılcım', sectionEmoji: '⚡',
    question: 'Yeni tanıştığın birinde sende \'kıvılcım\' yaratan ilk detay?',
    a: 'Göz teması, duruşu ve gülüşündeki o doğal sıcaklık.',
    b: 'Zekası, espri yeteneği ve sohbetin hiç takılmadan akması.',
    c: 'Kendine olan özgüveni ve yaydığı güçlü enerji.',
    d: 'Karşıdakini gerçekten dinleyen empati yeteneği.',
    aShort: 'Fizik & Gülüş 😍', bShort: 'Zeka & Mizah Anlayışı 😄',
    cShort: 'Özgüven & Aura 💪', dShort: 'Samimiyet ❤️',
  ),
  _QuizQuestion(
    section: 2, sectionTitle: 'Kıvılcım', sectionEmoji: '⚡',
    question: 'Kusursuz bir \'İlk Buluşma\' senaryosu hangisi?',
    a: 'Şık ama loş kafe/restoran — birbirimizi tanıyacağımız derin sohbet.',
    b: 'Beraber aktivite — konser, sergi, lunapark veya oyun merkezi.',
    c: 'Doğada, sakin bir yerde yürüyüş eşliğinde kahve.',
    d: 'Spontane gelişen, sokak lezzetleri veya rahat bir barda samimi akşam.',
    aShort: 'Kafe sohbet ☕', bShort: 'Konser & Aktivite 🎶',
    cShort: 'Doğa yürüyüşü 🌿', dShort: 'Spontane gelişen 🌆',
  ),
  _QuizQuestion(
    section: 2, sectionTitle: 'Kıvılcım', sectionEmoji: '⚡',
    question: 'İlişkilerde en büyük \'söndürücün\' (kırmızı çizgin)?',
    a: 'Net olmamak, sürekli taktik yapmak ve belirsizlik yaratmak.',
    b: 'Hayata karşı tutkusuz, vizyonsuz ve hep şikayetçi olmak.',
    c: 'Kişisel alanıma, hobilerime ve arkadaşlarıma saygı duymamak.',
    d: 'Empati eksikliği ve her tartışmada sadece kendini haklı görmek.',
    aShort: 'Belirsizlik 🚫', bShort: 'Tutkusuzluk 😑',
    cShort: 'Saygısızlık 🙅', dShort: 'Empati eksikliği 💔',
  ),
  _QuizQuestion(
    section: 2, sectionTitle: 'Kıvılcım', sectionEmoji: '⚡',
    question: 'Arandaki bağın \'harladığını\' nasıl anlarsın?',
    a: 'Hiç konuşmadan, o sessizliği bile rahatça paylaşabildiğimizde.',
    b: 'En filtresiz halimle bile yanında rahat davrandığımda.',
    c: 'Gelecek planlarıma onu doğal bir şekilde dahil ettiğimde.',
    d: 'Zor bir anımda aklıma gelen ilk kişi o olduğunda.',
    aShort: 'Sessizlik bile keyifliyse 🤫', bShort: 'Rahat hissettiriyorsa 😊',
    cShort: 'Gelecek planlarıma dahil olmaya başlamışsa 🔮', dShort: 'Zor bir anımda ilk aklıma gelen kişiyse 💭',
  ),
  _QuizQuestion(
    section: 2, sectionTitle: 'Kıvılcım', sectionEmoji: '⚡',
    question: 'Partnerinle en önemli \'uyum\' nerede olmalı?',
    a: 'Mizah anlayışı — aynı saçma şeylere gülüp eğlenebilmeliyiz.',
    b: 'Yaşam vizyonu — geleceğe dair hedeflerimiz aynı yöne bakmalı.',
    c: 'Sevgi dili — temas, kaliteli zaman ve onay sözleri.',
    d: 'Çatışma yönetimi — kavga ederken bile birbirimize saygılı kalmak.',
    aShort: 'Mizah 😂', bShort: 'Vizyon & Hedefler 🎯',
    cShort: 'Sevgi dili & Temas 💝', dShort: 'Saygı & Davranış 🕊️',
  ),
  _QuizQuestion(
    section: 2, sectionTitle: 'Kıvılcım', sectionEmoji: '⚡',
    question: '\'Aşk\' veya \'Derin Bağ\' bir ateşe benzeseydi seninki?',
    a: 'Aniden parlayan, tutkulu, baş döndürücü ve fırtınalı kamp ateşi.',
    b: 'Yavaş yavaş yanan, güven veren, uzun ömürlü şömine.',
    c: 'Duygu dolu, macera dolu festival ateşi.',
    d: 'Kontrollü — mantık ve duygunun mükemmel dengelendiği kalıcı ısı.',
    aShort: 'Tutkulu & Fırtınalı 🔥', bShort: 'Güvenli & Kalıcı 🕯️',
    cShort: 'Heyecanlı & Duygusal ❤️️', dShort: 'Dengeli & Kontrollü ⚖️',
  ),
  // ── Bölüm 3: Sosyal Dinamikler ──────────────────────────────────────────────
  _QuizQuestion(
    section: 3, sectionTitle: 'Sosyal Dinamikler', sectionEmoji: '🌐',
    question: 'Arkadaş grubundaki doğal rolün genelde nedir?',
    a: 'Organizatör — planları yapan, herkesi toplayan kişi.',
    b: 'Terapist — herkesin derdini anlattığı, tavsiye veren sırdaş.',
    c: 'Eğlendirici — ortamın enerjisini yüksek tutan, espri makinesi.',
    d: 'Gözlemci — kenarda, az ama öz konuşan kişi.',
    aShort: 'Organizatör & Lider 📅', bShort: 'Terapist & Dinleyici 👂',
    cShort: 'Eğlendirici & Konuşkan 🎭', dShort: 'Gözlemci & Sessiz 👁️',
  ),
  _QuizQuestion(
    section: 3, sectionTitle: 'Sosyal Dinamikler', sectionEmoji: '🌐',
    question: 'Bir anlaşmazlık anında nasıl tepki verirsin?',
    a: 'Hemen anında çözelim — yüzleşmekten asla kaçınmam.',
    b: 'Önce uzaklaşıp sakinleşmeyi tercih ederim.',
    c: 'Kırılırım veya içime atarım, tartışmayı büyütmem.',
    d: 'Duyguları bir kenara bırakıp mantıklı argümanlarla orta yolu ararım.',
    aShort: 'Hemen moduma göre tepki verir, yüzleşirim 💬', bShort: 'Uzaklaşırım, sakinleşip dönerim 😌',
    cShort: 'İçime atarım 😶', dShort: 'Objektif şekilde, mantıkla çözerim 🧠',
  ),
  _QuizQuestion(
    section: 3, sectionTitle: 'Sosyal Dinamikler', sectionEmoji: '🌐',
    question: 'Yapay zeka seni biriyle eşleştirse, o kişi sana ne sağlamalı?',
    a: 'Konfor alanımdan çıkarıp yeni maceralara sürüklemesi.',
    b: 'Hayatın karmaşasında beni sakinleştirmesi ve dengelemesi.',
    c: 'Hedeflerime ulaşmamda motive edip vizyonumu genişletmesi.',
    d: 'Olduğum gibi kabul edip, yargılamadan dinleyen bir liman olması.',
    aShort: 'Maceraya sürüklesin 🌍', bShort: 'Beni dengelesin & Rahatlatsın ⚖️',
    cShort: 'Motive etsin 🚀', dShort: 'Olduğum gibi kabul etsin & Şefkatle yaklaşsın 🏡',
  ),
];

// ─────────────────────────────────────────────
// Opening Dummy Card Data
// ─────────────────────────────────────────────

class _DummyCard {
  final Offset startOffset;
  final double startAngle;
  _DummyCard(this.startOffset, this.startAngle);
}

// ─────────────────────────────────────────────
// QuizScreen Widget
// ─────────────────────────────────────────────

class QuizScreen extends StatefulWidget {
  final VoidCallback onCompleted;
  const QuizScreen({super.key, required this.onCompleted});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with TickerProviderStateMixin {
  // Theme
  static const Color _accentColor = Color(0xFFFFFBF1);
  static const Color _bgDark = Color(0xFF12121A);
  static const Color _cardBgColor = Color(0xFF1E1E2A);

  // Core State
  final Map<int, String> _answers = {};
  int _currentIndex = 0;
  bool _isSubmitting = false;

  // Drag & Interaction State
  Offset _dragOffset = Offset.zero;
  int? _activeRegion; // 0: TL, 1: TR, 2: BL, 3: BR
  bool _isDragging = false;

  // Animation Flags
  bool _isOpeningStarted = false;
  bool _isOpeningFinished = false;
  bool _answersVisible = false;

  // Controllers
  late AnimationController _throwController;
  Animation<Offset>? _throwAnimation;

  // Data for Intro Animation
  List<_DummyCard> _dummyCards = [];
  bool _dummyCardsGenerated = false;

  @override
  void initState() {
    super.initState();

    _throwController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _throwController.addListener(() {
      if (_throwAnimation != null && mounted) {
        setState(() {
          _dragOffset = _throwAnimation!.value;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _isOpeningStarted = true);

      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) return;

        setState(() {
          _isOpeningFinished = true;
          _answersVisible = true;
        });
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dummyCardsGenerated) {
      _generateDummyCards();
      _dummyCardsGenerated = true;
    }
  }

  @override
  void dispose() {
    _throwController.dispose();
    super.dispose();
  }

  void _generateDummyCards() {
    final size = MediaQuery.of(context).size;
    final random = math.Random();

    // Create random start positions completely outside the screen
    final positions = [
      Offset(-size.width, -size.height), // Top Left
      Offset(size.width * 2, -size.height), // Top Right
      Offset(-size.width, size.height * 2), // Bottom Left
      Offset(size.width * 2, size.height * 2), // Bottom Right
      Offset(-size.width, size.height / 2), // Left Mid
      Offset(size.width * 2, size.height / 2), // Right Mid
      Offset(size.width / 2, -size.height), // Top Mid
      Offset(size.width / 2, size.height * 2), // Bottom Mid
    ];

    _dummyCards = positions.map((offset) {
      double angle = (random.nextDouble() - 0.5) * 4; // Random spin
      return _DummyCard(offset, angle);
    }).toList();
  }

  // ── Drag & Throw Mechanics ──────────────────────────

  void _onPanStart(DragStartDetails details) {
    if (_throwController.isAnimating) return;
    setState(() => _isDragging = true);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_throwController.isAnimating) return;
    setState(() {
      _dragOffset += details.delta;
      _updateActiveRegion();
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_throwController.isAnimating) return;
    setState(() => _isDragging = false);

    final velocity = details.velocity.pixelsPerSecond;
    final speed = velocity.distance;
    final hasEnoughMotion = speed > 300 || _dragOffset.distance > 80;

    if (hasEnoughMotion && _activeRegion != null) {
      _throwCard();
    } else {
      _snapBack();
    }
  }

  void _updateActiveRegion() {
    if (_dragOffset.distance < 40) {
      _activeRegion = null;
      return;
    }
    // Cross center lines (divided into 4 regions)
    if (_dragOffset.dx <= 0 && _dragOffset.dy <= 0) _activeRegion = 0; // Top-Left
    else if (_dragOffset.dx > 0 && _dragOffset.dy <= 0) _activeRegion = 1; // Top-Right
    else if (_dragOffset.dx <= 0 && _dragOffset.dy > 0) _activeRegion = 2; // Bottom-Left
    else if (_dragOffset.dx > 0 && _dragOffset.dy > 0) _activeRegion = 3; // Bottom-Right
  }

  void _throwCard() {
    final size = MediaQuery.of(context).size;
    late Offset targetOffset;

    switch (_activeRegion) {
      case 0:
        targetOffset = Offset(-size.width * 1.5, -size.height * 1.5);
        break;
      case 1:
        targetOffset = Offset(size.width * 1.5, -size.height * 1.5);
        break;
      case 2:
        targetOffset = Offset(-size.width * 1.5, size.height * 1.5);
        break;
      case 3:
        targetOffset = Offset(size.width * 1.5, size.height * 1.5);
        break;
      default:
        targetOffset = Offset(size.width, size.height);
    }

    _throwAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: targetOffset,
    ).animate(
      CurvedAnimation(
        parent: _throwController,
        curve: Curves.easeOutQuart,
      ),
    );

    _throwController.forward(from: 0).then((_) {
      _recordAnswerAndNext();
    });
  }

  void _snapBack() {
    final startOffset = _dragOffset;
    _throwAnimation = Tween<Offset>(begin: startOffset, end: Offset.zero)
        .animate(CurvedAnimation(parent: _throwController, curve: Curves.elasticOut));

    _throwController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _activeRegion = null;
        });
        _throwAnimation = null;
      }
    });
  }

  void _recordAnswerAndNext() {
    String mappedAnswer = 'A';
    if (_activeRegion == 1) mappedAnswer = 'B';
    if (_activeRegion == 2) mappedAnswer = 'C';
    if (_activeRegion == 3) mappedAnswer = 'D';

    _answers[_currentIndex] = mappedAnswer;

    if (_currentIndex == _kQuestions.length - 1) {
      setState(() {
        _isSubmitting = true;
      });
      _submitQuiz();
    } else {
      _throwAnimation = null;
      _throwController.reset();

      setState(() {
        _currentIndex++;
        _dragOffset = Offset.zero;
        _activeRegion = null;
      });
    }
  }

  Future<void> _submitQuiz() async {
    final answersMap = <String, dynamic>{};
    for (int i = 0; i < _kQuestions.length; i++) {
      answersMap['q${i + 1}'] = _answers[i] ?? '';
    }
    answersMap['completed_at'] = DateTime.now().toIso8601String();

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('user_profiles').upsert(
        {'user_id': userId, 'quiz_answers': answersMap},
        onConflict: 'user_id',
      );
      Supabase.instance.client.functions
          .invoke('analyze-user-profile', body: {'user_id': userId, 'quiz_answers': answersMap})
          .ignore();
    } catch (e) {
      debugPrint('Quiz submit error: $e');
    }

    if (mounted) {
      widget.onCompleted();
      Navigator.of(context).pop();
    }
  }

  // ─────────────────────────────────────────────
  // UI Builder
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isSubmitting) return _buildAnalyzingState();

    final size = MediaQuery.of(context).size;
    final cardW = math.min(size.width - 60, 340.0);
    final cardH = math.min(size.height * 0.5, 400.0);
    final centerX = (size.width - cardW) / 2;
    final centerY = (size.height - cardH) / 2;

    final q = _kQuestions[_currentIndex];

    return Scaffold(
      backgroundColor: _bgDark,
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.5,
                  colors: [
                    _accentColor.withOpacity(0.08),
                    _bgDark,
                  ],
                ),
              ),
            ),
          ),

          // Glowing Cross Lines
          _buildGlowingCrossLines(),

          // Corner Answers (Fades in after opening)
          // Hapları karta yaklaştırmak için değerleri 60 -> 110 ve 24 -> 36 olarak güncelledik
          _buildAnswerLabelWidget(0, q.aShort, top: 110, left: 36),
          _buildAnswerLabelWidget(1, q.bShort, top: 110, right: 36),
          _buildAnswerLabelWidget(2, q.cShort, bottom: 110, left: 36),
          _buildAnswerLabelWidget(3, q.dShort, bottom: 110, right: 36),

          // Center Card Deck & Top Card
          if (_isOpeningFinished)
            ..._buildCardDeck(cardW, cardH, centerX, centerY),

          // Intro Opening Animation
          if (!_isOpeningFinished)
            ..._dummyCards.map((cardData) {
              return AnimatedPositioned(
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeOutCubic,
                top: _isOpeningStarted ? centerY : cardData.startOffset.dy,
                left: _isOpeningStarted ? centerX : cardData.startOffset.dx,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                      begin: cardData.startAngle,
                      end: 0
                  ),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeOutCubic,
                  builder: (context, angle, child) {
                    return Transform.rotate(
                      angle: angle,
                      child: child,
                    );
                  },
                  child: IgnorePointer(child: _buildStaticCard(null, cardW, cardH, isDummy: true)),
                ),
              );
            }),

          // Header (Progress)
          if (_isOpeningFinished)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 20, right: 20,
              child: _buildHeader(q),
            ),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────

  Widget _buildGlowingCrossLines() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 800),
      opacity: _answersVisible ? 1.0 : 0.0,
      child: Stack(
        children: [
          // Vertical Line
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 1,
              height: double.infinity,
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.3),
                boxShadow: [
                  BoxShadow(color: _accentColor.withOpacity(0.4), blurRadius: 10, spreadRadius: 1)
                ],
              ),
            ),
          ),
          // Horizontal Line
          Align(
            alignment: Alignment.center,
            child: Container(
              height: 1,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.3),
                boxShadow: [
                  BoxShadow(color: _accentColor.withOpacity(0.4), blurRadius: 10, spreadRadius: 1)
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(_QuizQuestion q) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: Text(
                '${q.sectionEmoji} ${q.sectionTitle}',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '${_currentIndex + 1} / ${_kQuestions.length}',
              style: GoogleFonts.poppins(color: _accentColor, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnswerLabelWidget(int region, String text, {double? top, double? bottom, double? left, double? right}) {
    final isActive = _activeRegion == region;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      top: _answersVisible ? top : (top != null ? top - 50 : null),
      bottom: _answersVisible ? bottom : (bottom != null ? bottom - 50 : null),
      left: _answersVisible ? left : (left != null ? left - 50 : null),
      right: _answersVisible ? right : (right != null ? right - 50 : null),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 600),
        opacity: _answersVisible ? 1.0 : 0.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(maxWidth: 130),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? _accentColor.withOpacity(0.15) : _bgDark.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? _accentColor : Colors.white10,
              width: isActive ? 2 : 1,
            ),
            boxShadow: isActive ? [
              BoxShadow(color: _accentColor.withOpacity(0.6), blurRadius: 20, spreadRadius: 2)
            ] : [
              BoxShadow(color: Colors.black45, blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: isActive ? Colors.white : Colors.white54,
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCardDeck(double width, double height, double centerX, double centerY) {
    List<Widget> cards = [];

    // Draw up to 3 background cards + 1 top card
    int maxCards = math.min(4, _kQuestions.length - _currentIndex);

    for (int i = maxCards - 1; i >= 0; i--) {
      int absoluteIndex = _currentIndex + i;
      bool isTopCard = i == 0;

      // Tween Animation for smooth shifting when top card is thrown
      cards.add(
          Positioned(
            key: ValueKey(absoluteIndex),
            top: centerY,
            left: centerX,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: i.toDouble(), end: i.toDouble()),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              builder: (context, val, child) {
                // Scale down background cards slightly
                double scale = 1.0 - (val * 0.04);
                // Shift them down slightly to show a stacked deck effect
                double yOffset = val * 12.0;

                return Transform.translate(
                  offset: isTopCard ? _dragOffset : Offset(0, yOffset),
                  child: Transform.rotate(
                    // Slight rotation based on drag for the top card
                    angle: isTopCard ? _dragOffset.dx * 0.002 : 0,
                    child: Transform.scale(
                      scale: scale,
                      alignment: Alignment.bottomCenter,
                      child: child,
                    ),
                  ),
                );
              },
              child: isTopCard
                  ? GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: _buildStaticCard(_kQuestions[absoluteIndex], width, height, isTop: true),
              )
                  : _buildStaticCard(_kQuestions[absoluteIndex], width, height),
            ),
          )
      );
    }
    return cards;
  }

  Widget _buildStaticCard(_QuizQuestion? q, double width, double height, {bool isDummy = false, bool isTop = false}) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: _cardBgColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isTop ? _accentColor.withOpacity(0.5) : Colors.white10,
          width: isTop ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 30,
            offset: const Offset(0, 20),
          ),
          if (isTop)
            BoxShadow(
              color: _accentColor.withOpacity(0.1),
              blurRadius: 40,
              spreadRadius: 5,
            )
        ],
      ),
      child: isDummy || q == null
          ? const SizedBox()
          : Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Top Indicator lines
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _dot(), const SizedBox(width: 6), _dot(), const SizedBox(width: 6), _dot(),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: Center(
              child: Text(
                q.question,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Premium minimal hint
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.swipe, color: _accentColor.withOpacity(0.8), size: 16),
                const SizedBox(width: 8),
                Text(
                  'Köşeye Sürükle',
                  style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _dot() => Container(
    width: 6, height: 4,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(2),
    ),
  );

  Widget _buildAnalyzingState() {
    return Scaffold(
      backgroundColor: _bgDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                  color: _accentColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: _accentColor.withOpacity(0.2), blurRadius: 40, spreadRadius: 10)
                  ]
              ),
              child: const Icon(FontAwesomeIcons.wandMagicSparkles, color: _accentColor, size: 42),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: _accentColor, strokeWidth: 3),
            const SizedBox(height: 32),
            Text(
              'Yapay zeka seni analiz ediyor...',
              style: GoogleFonts.poppins(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Cevapların işleniyor, ruh ikizlerin aranıyor ✨',
              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}