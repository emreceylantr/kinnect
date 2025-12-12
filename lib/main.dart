import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';

import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/change_password_screen.dart'; // Şifre değiştirme ekranın
import 'services/spotify_service.dart';

// 🔥 Global Navigator Key (Uygulamanın Direksiyonu)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://vxrvudcafkgqusjrawme.supabase.co',
    anonKey: 'sb_publishable_tSqnWtXnUhEog3MIx5ajRw_PZeTlwuG',
  );

  runApp(const MyApp());
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

  // 1. Link Dinleyicisi (Uygulama açıkken veya kapalıyken)
  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // A. Uygulama kapalıydı, linkle açıldı (Cold Start)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (_) {}

    // B. Uygulama arkadaydı, linkle öne geldi (Warm Start)
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });
  }

  // 2. Supabase Auth Dinleyicisi (Yedek Kontrol)
  void _initAuthListener() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      // Eğer Supabase "Bu bir şifre kurtarma" derse
      if (event == AuthChangeEvent.passwordRecovery) {
        debugPrint("🔐 Supabase Password Recovery Olayı Yakalandı!");
        _navigateToResetScreen();
      }
    });
  }

  // 🔥 LİNKİ ANALİZ ET VE YÖNLENDİR
  void _handleDeepLink(Uri uri) {
    debugPrint("🔗 Gelen Link: $uri");

    // Senaryo 1: Şifre Sıfırlama (reset-callback)
    // Link içinde 'reset-callback' veya 'type=recovery' varsa
    if (uri.host == 'reset-callback' || uri.fragment.contains('type=recovery')) {
      debugPrint("🚨 Şifre Sıfırlama Linki! Yönlendiriliyor...");
      _navigateToResetScreen();
    }

    // Senaryo 2: Spotify
    else if (uri.scheme == 'kinnect' && uri.host == 'callback') {
      final code = uri.queryParameters['code'];
      if (code != null) {
        SpotifyService().exchangeCodeForToken(code);
      }
    }
  }

  // ZORUNLU YÖNLENDİRME FONKSİYONU
  void _navigateToResetScreen() {
    // NavigatorKey kullanarak, o an hangi ekrandaysan (Login, Welcome vb.)
    // hepsini silip ChangePasswordScreen'i açar.
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
          (route) => false, // Geri dönülemesin
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
    return MaterialApp(
      navigatorKey: navigatorKey, // 🔥 DİREKSİYONU BURAYA TAKTIK
      debugShowCheckedModeBanner: false,
      title: 'Kinnect',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF050505),
        textTheme: GoogleFonts.poppinsTextTheme().apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white, size: 24),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      // AuthGate sadece normal açılışlar için karar verir
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    // Eğer oturum varsa Home, yoksa Welcome
    return session != null ? const HomeScreen() : const WelcomeScreen();
  }
}