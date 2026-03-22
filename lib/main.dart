import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'data/services/notification_service.dart';
import 'data/services/spotify_service.dart';
import 'data/services/chat_service.dart'; // 👁️ Son görülme için

import 'features/auth/screens/welcome_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/auth/screens/change_password_screen.dart';
import 'features/auth/screens/create_profile_screen.dart';
import 'core/theme/theme_manager.dart'; // 🌓 Tema Yöneticisi
import 'core/language/language_manager.dart'; // 🌐 Dil Yöneticisi
import 'core/language/app_l10n.dart';

// 🎨 Splash Screen Temaları
const Color kSplashBg = Color(0xFF06060A);
const Color kSplashPurple = Color(0xFF7C3AED);
const Color kSplashViolet = Color(0xFF8B5CF6);

// 🔥 Global Navigator Key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr', null);

  // 🚀 PERFORMANS OPTİMİZASYONU: Firebase'i arka planda başlat
  // Firebase başlatması UI'ı bloklamamalı
  _initializeFirebaseInBackground();

  // Supabase kritik - bunu beklemek zorundayız
  await Supabase.initialize(
    url: 'https://vxrvudcafkgqusjrawme.supabase.co',
    anonKey: 'sb_publishable_tSqnWtXnUhEog3MIx5ajRw_PZeTlwuG',
    authOptions: FlutterAuthClientOptions(
      // Spotify callback'lerini Supabase Auth'a gönderme
      // Çünkü Spotify bağlantısı auth değil, sadece müzik token'ı
      authFlowType: AuthFlowType.pkce,
    ),
  );

  // 🌓 Temayı yükle + dil yükle
  await ThemeManager().loadTheme();
  await LanguageManager().loadLocale();

  // 🚀 Uygulamayı HEMEN başlat - bildirim servisi arka planda çalışacak
  runApp(const MyApp());
}

/// 🔥 Firebase ve Push Notification'ı arka planda başlat
/// Bu sayede uygulama hızlı açılır, bildirimler sonra hazır olur
void _initializeFirebaseInBackground() {
  Future.microtask(() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      debugPrint('✅ Firebase arka planda başlatıldı');

      // Firebase hazır olduktan sonra notification service'i başlat
      // Ama sadece kullanıcı giriş yapmışsa
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        await NotificationService().initialize();
        debugPrint('✅ Notification service arka planda başlatıldı');
      }
    } catch (e) {
      debugPrint('⚠️ Arka plan Firebase/Notification hatası: $e');
    }
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _initAuthListener();
  }

  // 🔗 Deep Link Dinleyicisi
  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (_) {}

    _linkSubscription = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });
  }

  // 🔐 Supabase Auth Listener (SADECE RESET VE ÇIKIŞ İÇİN)
  void _initAuthListener() {
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;

      debugPrint("🔥 Auth Event Main: $event");

      // Şifre sıfırlama ekranına yönlendirme
      if (event == AuthChangeEvent.passwordRecovery) {
        _navigateToResetScreen();
      }

      // Çıkış yapılırsa Welcome'a at
      if (event == AuthChangeEvent.signedOut) {
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
      }
    });
  }

  // 🔍 Deep Link Analizi
  void _handleDeepLink(Uri uri) async {
    debugPrint("🔗 Gelen Link: $uri");

    // 🎵 SPOTIFY CALLBACK - Müzik bağlantısı için
    if (uri.host == 'spotify-callback') {
      debugPrint("🎵 Spotify callback yakalandı!");
      final success = await SpotifyService().handleCallback(uri);
      if (success) {
        // Başarılı mesajı göster
        Future.delayed(const Duration(milliseconds: 500), () {
          navigatorKey.currentState?.context != null
              ? ScaffoldMessenger.of(navigatorKey.currentState!.context)
                  .showSnackBar(
                  const SnackBar(
                    content: Text('🎵 Spotify başarıyla bağlandı!'),
                    backgroundColor: Color(0xFF1DB954),
                  ),
                )
              : null;
        });
      }
      return;
    }

    // Şifre sıfırlama callback
    if (uri.host == 'reset-callback' ||
        uri.fragment.contains('type=recovery')) {
      _navigateToResetScreen();
    }
  }

  void _navigateToResetScreen() {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🌓 Tema + Dil değişikliğini dinle
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeManager().themeNotifier,
      builder: (context, currentMode, _) {
        return ValueListenableBuilder<Locale>(
          valueListenable: LanguageManager().localeNotifier,
          builder: (context, currentLocale, _) {
            return MaterialApp(
              navigatorKey: navigatorKey,
              debugShowCheckedModeBanner: false,
              title: 'Kinnect',
              themeMode: currentMode,
              locale: currentLocale,
              supportedLocales: const [Locale('tr'), Locale('en')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              // 🌞 Light tema (gerektiğinde)
              theme: ThemeData(
                brightness: Brightness.light,
                scaffoldBackgroundColor: const Color(0xFFF9FAFB),
                fontFamily: GoogleFonts.poppins().fontFamily,
                useMaterial3: true,
                iconTheme: const IconThemeData(color: Colors.black),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  iconTheme: IconThemeData(color: Colors.black),
                ),
                textTheme: GoogleFonts.poppinsTextTheme().apply(
                  bodyColor: Colors.black,
                  displayColor: Colors.black,
                ),
              ),
              // 🌑 Karanlık Tema (Dark)
              darkTheme: ThemeData(
                brightness: Brightness.dark,
                scaffoldBackgroundColor: const Color(0xFF0A0A0F),
                fontFamily: GoogleFonts.poppins().fontFamily,
                useMaterial3: true,
                iconTheme: const IconThemeData(color: Colors.white),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  iconTheme: IconThemeData(color: Colors.white),
                ),
                textTheme: GoogleFonts.poppinsTextTheme().apply(
                  bodyColor: Colors.white,
                  displayColor: Colors.white,
                ),
              ),
              // 🔥 HER ŞEYİN KONTROL NOKTASI BURASI
              home: const AuthGate(),
            );
          },
        );
      },
    );
  }
}

// 🚪 GÜÇLENDİRİLMİŞ AUTH GATE (Canlı Takip Yapar)
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoading = true;
  bool _hasProfile = false;
  String? _lastCheckedUserId; // Cache için
  StreamSubscription<AuthState>? _gateAuthSubscription;

  @override
  void initState() {
    super.initState();
    _checkUserStatus();

    // 🔥 GÜNCELLEME: Login/Logout olaylarını anlık dinle
    _gateAuthSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      // Sadece gerçek değişikliklerde kontrol et
      final newUserId = data.session?.user.id;
      if (newUserId != _lastCheckedUserId) {
        _checkUserStatus();
      }
    });
  }

  @override
  void dispose() {
    _gateAuthSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkUserStatus() async {
    if (mounted) setState(() => _isLoading = true);

    final session = Supabase.instance.client.auth.currentSession;

    // 1. Eğer oturum yoksa -> Yükleniyor'u kapat, Profile yok de.
    if (session == null) {
      _lastCheckedUserId = null;
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasProfile = false;
        });
      }
      return;
    }

    final userId = session.user.id;

    // Cache kontrolü - aynı kullanıcı için tekrar sorma
    if (_lastCheckedUserId == userId && _hasProfile) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // 🚀 OPTİMİZASYON: Sadece 'id' sütununu çek (tüm profil yerine)
      final data = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      _lastCheckedUserId = userId;

      if (mounted) {
        setState(() {
          _hasProfile = data != null;
          _isLoading = false;
        });
      }

      // 🔔 Profil varsa notification service'i arka planda başlat
      if (data != null) {
        Future.microtask(() async {
          try {
            if (!NotificationService().isInitialized) {
              await NotificationService().initialize();
              debugPrint(
                  '✅ NotificationService HomeScreen geçişinde başlatıldı');
            }
            // 👁️ Son görülme güncelle
            await ChatService().updateLastSeen();
            debugPrint('✅ Last seen güncelendi');
          } catch (e) {
            debugPrint('⚠️ NotificationService başlatma hatası: $e');
          }
        });
      }
    } catch (e) {
      debugPrint("Profil kontrol hatası: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasProfile = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    // 1. Kontrol sürüyorsa Splash Screen göster
    if (_isLoading) {
      return const KinnectSplashScreen();
    }

    // 2. Oturum yoksa -> Welcome Screen
    if (session == null) {
      return const WelcomeScreen();
    }

    // 3. Oturum var AMA Profil Yoksa -> Create Profile Screen
    if (!_hasProfile) {
      return const CreateProfileScreen();
    }

    // 4. Her şey tamamsa -> Home Screen
    return const HomeScreen();
  }
}

// 🎨 ANİMASYONLU SPLASH SCREEN
class KinnectSplashScreen extends StatefulWidget {
  const KinnectSplashScreen({super.key});

  @override
  State<KinnectSplashScreen> createState() => _KinnectSplashScreenState();
}

class _KinnectSplashScreenState extends State<KinnectSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _shimmerCtrl;
  late AnimationController _dotsCtrl;

  late Animation<double> _fadeIn;
  late Animation<double> _slideUp;
  late Animation<double> _taglineFade;

  int _dotIndex = 0;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeIn = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideUp = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic),
    );
    _taglineFade = CurvedAnimation(
      parent: _fadeCtrl,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _fadeCtrl.forward();
    });

    _dotsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          if (mounted) setState(() => _dotIndex = (_dotIndex + 1) % 3);
          _dotsCtrl.forward(from: 0);
        }
      });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _dotsCtrl.forward();
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    _shimmerCtrl.dispose();
    _dotsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: kSplashBg,
      body: Stack(
        children: [
          // ── BG GLOW TOP ──
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Positioned(
              top: -160,
              left: -80,
              right: -80,
              child: Container(
                height: 500,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 0.65 + _pulseCtrl.value * 0.08,
                    colors: [
                      kSplashPurple.withOpacity(0.28 + _pulseCtrl.value * 0.06),
                      kSplashViolet.withOpacity(0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── BG GLOW BOTTOM ──
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Positioned(
              bottom: -200,
              left: size.width * 0.1,
              right: size.width * 0.1,
              child: Container(
                height: 400,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 0.5 + _pulseCtrl.value * 0.06,
                    colors: [
                      const Color(0xFFEC4899).withOpacity(0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── MAIN CONTENT ──
          Center(
            child: FadeTransition(
              opacity: _fadeIn,
              child: AnimatedBuilder(
                animation: _slideUp,
                builder: (_, child) => Transform.translate(
                  offset: Offset(0, _slideUp.value),
                  child: child,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── LOGO ──
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (_, __) => Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer ring
                          Container(
                            width: 165 + _pulseCtrl.value * 18,
                            height: 165 + _pulseCtrl.value * 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: kSplashPurple.withOpacity(
                                    0.18 - _pulseCtrl.value * 0.12),
                                width: 1.5,
                              ),
                            ),
                          ),
                          // Middle ring
                          Container(
                            width: 130 + _pulseCtrl.value * 10,
                            height: 130 + _pulseCtrl.value * 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: kSplashViolet.withOpacity(
                                    0.28 - _pulseCtrl.value * 0.16),
                                width: 1,
                              ),
                            ),
                          ),
                          // Glow bg
                          Container(
                            width: 112,
                            height: 112,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: kSplashPurple.withOpacity(
                                      0.45 + _pulseCtrl.value * 0.15),
                                  blurRadius: 40 + _pulseCtrl.value * 20,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          // Icon circle
                          Container(
                            width: 108,
                            height: 108,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF7C3AED), Color(0xFF9D5CF6)],
                              ),
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/icon/icon.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 36),

                    // ── APP NAME ──
                    AnimatedBuilder(
                      animation: _shimmerCtrl,
                      builder: (_, __) {
                        return ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: const [
                              Colors.white,
                              Color(0xFFB89FFF),
                              Colors.white,
                              Color(0xFFB89FFF),
                              Colors.white,
                            ],
                            stops: [
                              0.0,
                              (_shimmerCtrl.value - 0.3).clamp(0.0, 1.0),
                              _shimmerCtrl.value.clamp(0.0, 1.0),
                              (_shimmerCtrl.value + 0.3).clamp(0.0, 1.0),
                              1.0,
                            ],
                          ).createShader(bounds),
                          child: Text(
                            'Kinnect',
                            style: GoogleFonts.spaceGrotesk(
                              color: Colors.white,
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 10),

                    // ── TAGLINE ──
                    FadeTransition(
                      opacity: _taglineFade,
                      child: Text(
                        AppL10n.currentLanguageCode == 'en'
                            ? 'Find your people'
                            : 'Gerçek bağlantılar kur',
                        style: GoogleFonts.inter(
                          color: Colors.white38,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),

                    const SizedBox(height: 64),

                    // ── LOADING DOTS ──
                    FadeTransition(
                      opacity: _taglineFade,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (i) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: _dotIndex == i ? 22 : 7,
                            height: 7,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: _dotIndex == i
                                  ? kSplashViolet
                                  : Colors.white.withOpacity(0.15),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── BOTTOM BADGE ──
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _taglineFade,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome,
                        size: 13,
                        color: kSplashViolet.withOpacity(0.6)),
                    const SizedBox(width: 6),
                    Text(
                      AppL10n.currentLanguageCode == 'en'
                          ? 'AI-powered connections'
                          : 'Yapay zeka destekli',
                      style: GoogleFonts.inter(
                        color: Colors.white24,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
