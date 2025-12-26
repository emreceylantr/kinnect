import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';

import 'services/notification_service.dart';
import 'services/spotify_service.dart';

import 'screens/auth/welcome_screen.dart';
import 'screens/main/home_screen.dart';
import 'screens/auth/change_password_screen.dart';
import 'screens/auth/create_profile_screen.dart';
import 'theme/theme_manager.dart'; // 🌓 Tema Yöneticisi

// 🎨 Splash Screen Temaları
const Color kSplashBg = Color(0xFF06060A);
const Color kSplashPurple = Color(0xFF7C3AED);
const Color kSplashViolet = Color(0xFF8B5CF6);

// 🔥 Global Navigator Key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // 🌓 Temayı yükle
  await ThemeManager().loadTheme();

  // 🚀 Uygulamayı HEMEN başlat - bildirim servisi arka planda çalışacak
  runApp(const MyApp());
}

/// 🔥 Firebase ve Push Notification'ı arka planda başlat
/// Bu sayede uygulama hızlı açılır, bildirimler sonra hazır olur
void _initializeFirebaseInBackground() {
  Future.microtask(() async {
    try {
      await Firebase.initializeApp();
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
    // 🌓 Tema değişikliğini dinle ve uygula
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeManager().themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'Kinnect',
          themeMode: currentMode,
          // 🌞 Aydınlık Tema (Light)
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
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSplashBg,
      body: Stack(
        children: [
          // Arka plan glow
          Positioned(
            top: -100,
            left: -100,
            right: -100,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Container(
                  height: 400,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 0.6 + _controller.value * 0.1,
                      colors: [
                        kSplashPurple.withOpacity(0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // İçerik
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pulsing halkalar + Logo
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Halka 1
                        Container(
                          width: 140 + _controller.value * 20,
                          height: 140 + _controller.value * 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: kSplashPurple
                                  .withOpacity(0.3 - _controller.value * 0.2),
                              width: 2,
                            ),
                          ),
                        ),
                        // Halka 2
                        Container(
                          width: 110 + _controller.value * 10,
                          height: 110 + _controller.value * 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: kSplashViolet
                                  .withOpacity(0.4 - _controller.value * 0.2),
                              width: 1.5,
                            ),
                          ),
                        ),
                        // Logo Container
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [kSplashPurple, kSplashViolet],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: kSplashPurple.withOpacity(0.4),
                                blurRadius: 30,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/icon/icon.png',
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 40),

                // Uygulama adı
                Text(
                  'Kinnect',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 12),

                // Yükleniyor animasyonu
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Opacity(
                      opacity: 0.5 + _controller.value * 0.5,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                kSplashPurple.withOpacity(0.8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Yükleniyor...',
                            style: GoogleFonts.inter(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
