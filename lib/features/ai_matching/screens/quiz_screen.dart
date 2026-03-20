import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/theme/app_colors.dart';

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
    aShort: 'Başarı 🏆', bShort: 'Derin Bağlar 💕',
    cShort: 'Macera 🌍', dShort: 'Fayda 🤝',
  ),
  _QuizQuestion(
    section: 1, sectionTitle: 'Bireysel Vibe', sectionEmoji: '🔥',
    question: 'Bir ortamda \'buzları eriten\' ilk hamleyi genelde kim yapar?',
    a: 'Kesinlikle ben! Sessizliğe dayanamam, muhabbeti başlatırım.',
    b: 'Duruma göre — ortam güven verirse açılırım.',
    c: 'Genelde karşıdan beklerim, ilk adım atmak zor gelir.',
    d: 'Söze gerek duymam — beden dilimle enerjimi belli ederim.',
    aShort: 'İlk ben ✋', bShort: 'Duruma göre 🤔',
    cShort: 'Karşıdan beklerim 🌸', dShort: 'Beden dilim 🕺',
  ),
  _QuizQuestion(
    section: 1, sectionTitle: 'Bireysel Vibe', sectionEmoji: '🔥',
    question: 'Stresli bir günün ardından \'zihin sıfırlama\' yöntemin?',
    a: 'Doğada yalnız bir yürüyüş veya sessiz bir ortam.',
    b: 'Derin strateji gerektiren oyun veya sürükleyici aktivite.',
    c: 'Kulaklığı takıp favori müziklerimle kaybolmak veya spor.',
    d: 'Güvendiğim bir dostla saatlerce her şeyi filtresiz konuşmak.',
    aShort: 'Doğa & Sessizlik 🌿', bShort: 'Oyun & Aktivite 🎮',
    cShort: 'Müzik & Spor 🎵', dShort: 'Dost sohbet 🗣️',
  ),
  // ── Bölüm 2: Kıvılcım ───────────────────────────────────────────────────────
  _QuizQuestion(
    section: 2, sectionTitle: 'Kıvılcım', sectionEmoji: '⚡',
    question: 'Yeni tanıştığın birinde sende \'kıvılcım\' yaratan ilk detay?',
    a: 'Göz teması, duruşu ve gülüşündeki o doğal sıcaklık.',
    b: 'Zekası, espri yeteneği ve sohbetin hiç takılmadan akması.',
    c: 'Kendine olan özgüveni ve yaydığı güçlü enerji.',
    d: 'Karşıdakini gerçekten dinleyen empati yeteneği.',
    aShort: 'Fizik & Gülüş 😍', bShort: 'Zeka & Espri 😄',
    cShort: 'Özgüven 💪', dShort: 'Empati ❤️',
  ),
  _QuizQuestion(
    section: 2, sectionTitle: 'Kıvılcım', sectionEmoji: '⚡',
    question: 'Kusursuz bir \'İlk Buluşma\' senaryosu hangisi?',
    a: 'Şık ama loş kafe/restoran — birbirimizi tanıyacağımız derin sohbet.',
    b: 'Beraber aktivite — konser, sergi, lunapark veya oyun merkezi.',
    c: 'Doğada, sakin bir yerde yürüyüş eşliğinde kahve.',
    d: 'Spontane gelişen, sokak lezzetleri veya rahat bir barda samimi akşam.',
    aShort: 'Kafe sohbet ☕', bShort: 'Konser & Aktivite 🎶',
    cShort: 'Doğa yürüyüşü 🌿', dShort: 'Spontane sokak 🌆',
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
    aShort: 'Sessiz uyum 🤫', bShort: 'Filtresiz ben 😊',
    cShort: 'Gelecek planları 🔮', dShort: 'İlk aklıma gelen 💭',
  ),
  _QuizQuestion(
    section: 2, sectionTitle: 'Kıvılcım', sectionEmoji: '⚡',
    question: 'Partnerinle en önemli \'uyum\' nerede olmalı?',
    a: 'Mizah anlayışı — aynı saçma şeylere gülüp eğlenebilmeliyiz.',
    b: 'Yaşam vizyonu — geleceğe dair hedeflerimiz aynı yöne bakmalı.',
    c: 'Sevgi dili — temas, kaliteli zaman ve onay sözleri.',
    d: 'Çatışma yönetimi — kavga ederken bile birbirimize saygılı kalmak.',
    aShort: 'Mizah 😂', bShort: 'Vizyon 🎯',
    cShort: 'Sevgi dili 💝', dShort: 'Çatışma yönetimi 🕊️',
  ),
  _QuizQuestion(
    section: 2, sectionTitle: 'Kıvılcım', sectionEmoji: '⚡',
    question: '\'Aşk\' veya \'Derin Bağ\' bir ateşe benzeseydi seninki?',
    a: 'Aniden parlayan, tutkulu, baş döndürücü ve fırtınalı kamp ateşi.',
    b: 'Yavaş yavaş yanan, güven veren, uzun ömürlü şömine.',
    c: 'Sürekli yeni odunlar atılarak büyüyen, macera dolu festival ateşi.',
    d: 'Kontrollü — mantık ve duygunun mükemmel dengelendiği kalıcı ısı.',
    aShort: 'Tutkulu & Fırtınalı 🔥', bShort: 'Güvenli & Kalıcı 🕯️',
    cShort: 'Macera ateşi 🏕️', dShort: 'Dengeli mantık ⚖️',
  ),
  // ── Bölüm 3: Sosyal Dinamikler ──────────────────────────────────────────────
  _QuizQuestion(
    section: 3, sectionTitle: 'Sosyal Dinamikler', sectionEmoji: '🌐',
    question: 'Arkadaş grubundaki doğal rolün genelde nedir?',
    a: 'Organizatör — planları yapan, herkesi toplayan kişi.',
    b: 'Terapist — herkesin derdini anlattığı, tavsiye veren sırdaş.',
    c: 'Eğlendirici — ortamın enerjisini yüksek tutan, espri makinesi.',
    d: 'Gözlemci — kenarda, az ama öz konuşan kişi.',
    aShort: 'Organizatör 📅', bShort: 'Terapist 👂',
    cShort: 'Eğlendirici 🎭', dShort: 'Gözlemci 👁️',
  ),
  _QuizQuestion(
    section: 3, sectionTitle: 'Sosyal Dinamikler', sectionEmoji: '🌐',
    question: 'Bir anlaşmazlık anında nasıl tepki verirsin?',
    a: 'Hemen anında çözelim — yüzleşmekten asla kaçınmam.',
    b: 'Önce uzaklaşıp sakinleşmeyi tercih ederim.',
    c: 'Kırılırım veya içime atarım, tartışmayı büyütmem.',
    d: 'Duyguları bir kenara bırakıp mantıklı argümanlarla orta yolu ararım.',
    aShort: 'Hemen yüzleşirim 💬', bShort: 'Sakinleşip dönerim 😌',
    cShort: 'İçime atarım 😶', dShort: 'Mantıkla çözerim 🧠',
  ),
  _QuizQuestion(
    section: 3, sectionTitle: 'Sosyal Dinamikler', sectionEmoji: '🌐',
    question: 'Yapay zeka seni biriyle eşleştirse, o kişi sana ne sağlamalı?',
    a: 'Konfor alanımdan çıkarıp yeni maceralara sürüklemesi.',
    b: 'Hayatın karmaşasında beni sakinleştirmesi ve dengelemesi.',
    c: 'Hedeflerime ulaşmamda motive edip vizyonumu genişletmesi.',
    d: 'Olduğum gibi kabul edip, yargılamadan dinleyen bir liman olması.',
    aShort: 'Maceraya sürükle 🌍', bShort: 'Beni dengele ⚖️',
    cShort: 'Motive et 🚀', dShort: 'Kabul et & Dinle 🏡',
  ),
];

// ─────────────────────────────────────────────
// Flame Trail Painter
// ─────────────────────────────────────────────

class _FlamePainter extends CustomPainter {
  final List<Offset> points;
  _FlamePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    for (int i = 0; i < points.length; i++) {
      final t = i / points.length;
      final radius = 3.0 + t * 10.0;
      final opacity = t * 0.5;
      // Outer glow — purple
      final paint = Paint()
        ..color = const Color(0xFF7C3AED).withValues(alpha: opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(points[i], radius, paint);

      // Inner core — lighter violet
      final corePaint = Paint()
        ..color = const Color(0xFFBB86FC).withValues(alpha: opacity * 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(points[i], radius * 0.45, corePaint);
    }
  }

  @override
  bool shouldRepaint(_FlamePainter old) => old.points != points;
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
  final Map<int, String> _answers = {};
  int _currentIndex = 0;
  bool _isSubmitting = false;

  // Drag state
  Offset _cardOffset = Offset.zero;
  double _cardRotation = 0;
  final List<Offset> _trailPoints = [];
  String? _activeCorner; // 'A', 'B', 'C', 'D'
  bool _isAnimating = false;

  // Animation controllers
  late AnimationController _throwController;
  late AnimationController _entryController;
  Animation<double>? _entrySlide; // 0 = off-screen-bottom, 1 = in place
  Animation<double>? _entryScale;

  @override
  void initState() {
    super.initState();
    _throwController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _entryController.value = 1.0; // First card already in place
    _entryController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _throwController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  // ── Drag handlers ─────────────────────────────

  void _onPanStart(DragStartDetails d) {
    if (_isAnimating) return;
    _trailPoints.clear();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_isAnimating) return;
    setState(() {
      _cardOffset += d.delta;
      _cardRotation = (_cardOffset.dx / 260) * 0.28;
      _trailPoints.add(d.globalPosition);
      if (_trailPoints.length > 35) _trailPoints.removeAt(0);
      _updateActiveCorner();
    });
  }

  void _onPanEnd(DragEndDetails d) {
    if (_isAnimating) return;
    final velocity = d.velocity.pixelsPerSecond;
    final speed = velocity.distance;
    final hasEnoughMotion = speed > 280 || _cardOffset.distance > 60;

    if (hasEnoughMotion) {
      final dx = speed > 280 ? velocity.dx : _cardOffset.dx;
      final dy = speed > 450 ? velocity.dy : _cardOffset.dy;
      final corner = _cornerFromDirection(dx, dy);
      _throwCard(corner);
    } else {
      _snapBack();
    }
  }

  void _updateActiveCorner() {
    if (_cardOffset.distance < 28) {
      _activeCorner = null;
    } else {
      _activeCorner = _cornerFromDirection(_cardOffset.dx, _cardOffset.dy);
    }
  }

  String _cornerFromDirection(double dx, double dy) {
    if (dx <= 0 && dy <= 0) return 'A';
    if (dx > 0 && dy <= 0) return 'B';
    if (dx <= 0 && dy > 0) return 'C';
    return 'D';
  }

  // ── Throw animation ───────────────────────────

  void _throwCard(String corner) {
    _isAnimating = true;
    final size = MediaQuery.of(context).size;
    late Offset target;
    switch (corner) {
      case 'A': target = Offset(-size.width * 1.2, -size.height * 0.9);
      case 'B': target = Offset(size.width * 1.2, -size.height * 0.9);
      case 'C': target = Offset(-size.width * 1.2, size.height * 0.9);
      default:  target = Offset(size.width * 1.2, size.height * 0.9);
    }

    final startOffset = _cardOffset;
    final offsetAnim = Tween<Offset>(begin: startOffset, end: target)
        .animate(CurvedAnimation(parent: _throwController, curve: Curves.easeIn));
    final rotAnim = Tween<double>(begin: _cardRotation, end: _cardRotation * 2.5)
        .animate(_throwController);

    void listener() {
      if (mounted) {
        setState(() {
          _cardOffset = offsetAnim.value;
          _cardRotation = rotAnim.value;
        });
      }
    }

    _throwController.addListener(listener);
    _throwController.forward(from: 0).then((_) {
      _throwController.removeListener(listener);
      _recordAnswer(corner);
    });
  }

  void _recordAnswer(String corner) {
    _answers[_currentIndex] = corner;
    if (_currentIndex == _kQuestions.length - 1) {
      setState(() {
        _cardOffset = Offset.zero;
        _cardRotation = 0;
        _trailPoints.clear();
        _activeCorner = null;
        _isAnimating = false;
        _isSubmitting = true;
      });
      _submitQuiz();
    } else {
      _throwController.reset();
      // Prepare entry for next card (starts below screen)
      _entryController.value = 0;
      _entrySlide = Tween<double>(begin: 1.0, end: 0.0)
          .animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));
      _entryScale = Tween<double>(begin: 0.82, end: 1.0)
          .animate(CurvedAnimation(parent: _entryController, curve: Curves.elasticOut));

      setState(() {
        _currentIndex++;
        _cardOffset = Offset.zero;
        _cardRotation = 0;
        _trailPoints.clear();
        _activeCorner = null;
      });

      _entryController.forward().then((_) {
        if (mounted) setState(() => _isAnimating = false);
      });
    }
  }

  // ── Snap back animation ───────────────────────

  void _snapBack() {
    _isAnimating = true;
    final startOffset = _cardOffset;
    final startRot = _cardRotation;
    final controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300));
    final offsetAnim = Tween<Offset>(begin: startOffset, end: Offset.zero)
        .animate(CurvedAnimation(parent: controller, curve: Curves.elasticOut));
    final rotAnim = Tween<double>(begin: startRot, end: 0)
        .animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));

    void listener() {
      if (mounted) {
        setState(() {
          _cardOffset = offsetAnim.value;
          _cardRotation = rotAnim.value;
        });
      }
    }

    controller.addListener(listener);
    controller.forward().then((_) {
      controller.removeListener(listener);
      controller.dispose();
      if (mounted) {
        setState(() {
          _trailPoints.clear();
          _activeCorner = null;
          _isAnimating = false;
        });
      }
    });
  }

  // ── Submit ────────────────────────────────────

  Future<void> _submitQuiz() async {
    final answersMap = <String, dynamic>{};
    for (int i = 0; i < _kQuestions.length; i++) {
      answersMap['q${i + 1}'] = _answers[i] ?? '';
    }
    answersMap['completed_at'] = DateTime.now().toIso8601String();

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      // Cevapları DB'ye kaydet (hızlı)
      await Supabase.instance.client.from('user_profiles').upsert(
        {'user_id': userId, 'quiz_answers': answersMap},
        onConflict: 'user_id',
      );
      // Analizi arka planda başlat — await etme, uzun sürer
      Supabase.instance.client.functions
          .invoke('analyze-user-profile',
              body: {'user_id': userId, 'quiz_answers': answersMap})
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
  // Build
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isSubmitting) return _buildAnalyzingState();

    final q = _kQuestions[_currentIndex];
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        children: [
          // Radial gradient background
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.4,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.12),
                    AppColors.bgDark,
                  ],
                ),
              ),
            ),
          ),

          // Flame trail (global coords — full screen painter)
          if (_trailPoints.length > 2)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _FlamePainter(_trailPoints)),
              ),
            ),

          // Main layout
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(q),
                Expanded(
                  child: Stack(
                    children: [
                      // Corner labels anchored inside card area
                      Positioned(top: 14, left: 12,
                          child: _buildCornerLabel('A', q.aShort, 'A')),
                      Positioned(top: 14, right: 12,
                          child: _buildCornerLabel('B', q.bShort, 'B')),
                      Positioned(bottom: 44, left: 12,
                          child: _buildCornerLabel('C', q.cShort, 'C')),
                      Positioned(bottom: 44, right: 12,
                          child: _buildCornerLabel('D', q.dShort, 'D')),

                      // Card centered in expanded area
                      Center(child: _buildDraggableCard(q, size)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 14),
                  child: Text(
                    'Kartı köşeye fırlat ✨',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(color: Colors.white24, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Top bar ───────────────────────────────────

  Widget _buildTopBar(_QuizQuestion q) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${q.sectionEmoji} ${q.sectionTitle}',
                  style: GoogleFonts.poppins(
                    color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                'Q${_currentIndex + 1} / ${_kQuestions.length}',
                style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: (_currentIndex + 1) / _kQuestions.length,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            color: AppColors.primary,
            minHeight: 3,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  // ── Corner label ──────────────────────────────

  Widget _buildCornerLabel(String letter, String shortLabel, String corner) {
    final isActive = _activeCorner == corner;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primary.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.85)
              : Colors.white.withValues(alpha: 0.1),
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: isActive
            ? [BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.45),
                blurRadius: 18, spreadRadius: 1)]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            letter,
            style: GoogleFonts.poppins(
              color: isActive ? AppColors.primary : Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 82),
            child: Text(
              shortLabel,
              style: GoogleFonts.poppins(
                color: isActive ? Colors.white : Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Draggable card ────────────────────────────

  Widget _buildDraggableCard(_QuizQuestion q, Size size) {
    // Entry animation values
    final slideProgress = _entrySlide?.value ?? 0.0;
    final scaleValue = _entryScale?.value ?? 1.0;

    return Transform.translate(
      offset: _cardOffset + Offset(0, slideProgress * size.height * 0.55),
      child: Transform.rotate(
        angle: _cardRotation,
        child: Transform.scale(
          scale: scaleValue,
          child: GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: _buildCard(q, size),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(_QuizQuestion q, Size size) {
    final cardW = math.min(size.width - 80, 360.0);
    final cardH = math.min(size.height * 0.42, 300.0);

    return Container(
      width: cardW,
      constraints: BoxConstraints(minHeight: cardH),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E1A2E),
            const Color(0xFF16122A),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 40, offset: const Offset(0, 16)),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 24, spreadRadius: 2),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag indicator dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _dot(), const SizedBox(width: 4), _dot(), const SizedBox(width: 4), _dot(),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            q.question,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          // Hint arrows
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.north_west_rounded, color: Colors.white.withValues(alpha: 0.15), size: 14),
              const SizedBox(width: 4),
              Icon(Icons.north_east_rounded, color: Colors.white.withValues(alpha: 0.15), size: 14),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.south_west_rounded, color: Colors.white.withValues(alpha: 0.15), size: 14),
              const SizedBox(width: 4),
              Icon(Icons.south_east_rounded, color: Colors.white.withValues(alpha: 0.15), size: 14),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dot() => Container(
    width: 5, height: 5,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.2),
      shape: BoxShape.circle,
    ),
  );

  // ── Analyzing state ───────────────────────────

  Widget _buildAnalyzingState() {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(FontAwesomeIcons.wandMagicSparkles,
                  color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
            const SizedBox(height: 24),
            Text(
              'Yapay zeka seni analiz ediyor...',
              style: GoogleFonts.poppins(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Cevapların işleniyor, ruh ikizlerin aranıyor ✨',
              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
