import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';

import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/change_password_screen.dart';
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

  // 🔗 Deep Link Listener (Spotify + Password Reset)
  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Cold start
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (_) {}

    // Warm start
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });
  }

  // 🔐 Supabase Auth Listener (Password Recovery)
  void _initAuthListener() {
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _navigateToResetScreen();
      }
    });
  }

  // 🔥 Link Analizi
  void _handleDeepLink(Uri uri) {
    debugPrint("🔗 Gelen Link: $uri");

    // Şifre sıfırlama
    if (uri.host == 'reset-callback' ||
        uri.fragment.contains('type=recovery')) {
      _navigateToResetScreen();
    }

    // Spotify callback
    else if (uri.scheme == 'kinnect' && uri.host == 'callback') {
      final code = uri.queryParameters['code'];
      if (code != null) {
        SpotifyService().exchangeCodeForToken(code);
      }
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
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Kinnect',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF050505),
        textTheme: GoogleFonts.poppinsTextTheme().apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
      ),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    return session != null ? const HomeScreen() : const WelcomeScreen();
  }
}
