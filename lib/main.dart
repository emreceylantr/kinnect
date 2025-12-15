import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';

import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/change_password_screen.dart';
// 👇 BURAYI KENDİ DOSYA ADINA GÖRE DÜZENLE KANKA
import 'screens/create_profile_screen.dart';

// 🔥 Global Navigator Key
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

  // 🔐 Supabase Auth Listener (GÜNCELLENDİ)
  void _initAuthListener() {
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
          final event = data.event;
          final session = data.session;

          debugPrint("🔥 Auth Event: $event");

          // Şifre sıfırlama
          if (event == AuthChangeEvent.passwordRecovery) {
            _navigateToResetScreen();
          }

          // ✅ Login olunca direkt Home'a gitmek yerine KONTROL FONKSİYONUNA gidiyoruz
          if ((event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed) && session != null) {
            debugPrint("✅ Oturum açıldı, Profil kontrol ediliyor...");
            // Burada direkt yönlendirme yapmıyoruz, AuthGate zaten build edilecek
            // Ama eğer manuel tetiklemek istersen _checkProfileAndNavigate kullanılabilir.
            // Listener içinde genelde setState gerekmez, AuthGate session değişikliğini algılar.
          }

          // Çıkış yapıldıysa
          if (event == AuthChangeEvent.signedOut) {
            navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (route) => false,
            );
          }
        });
  }

  // 🔍 Deep Link Analizi
  void _handleDeepLink(Uri uri) {
    debugPrint("🔗 Gelen Link: $uri");

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
        iconTheme: const IconThemeData(color: Colors.white),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      // 🔥 ARTIK DİREKT HOMESCREEN YOK, KONTROL KAPISI VAR
      home: const AuthGate(),
    );
  }
}

// 🚪 YENİ GÜVENLİK KAPISI (PROFILE CHECKER)
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoading = true;
  bool _hasProfile = false;

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    final session = Supabase.instance.client.auth.currentSession;

    // 1. Eğer oturum yoksa direkt Welcome'a
    if (session == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      // 2. Oturum var, peki PROFİL var mı?
      final userId = session.user.id;
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle(); // maybeSingle: Kayıt varsa getirir, yoksa null döner (Hata vermez)

      if (mounted) {
        setState(() {
          _hasProfile = data != null; // Veri geldiyse profil vardır
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Profil kontrol hatası: $e");
      // Hata olursa güvenli taraf seçip loadingi kapatıyoruz, muhtemelen create'e düşer
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

    // 1. Henüz kontrol ediliyorsa Yükleniyor göster
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
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