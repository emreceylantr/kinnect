import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';

import 'services/notification_service.dart';

import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/change_password_screen.dart';
// 👇 Dosya yolun doğruysa burası kalabilir
import 'screens/create_profile_screen.dart';

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
  );

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
      // 🔥 HER ŞEYİN KONTROL NOKTASI BURASI
      home: const AuthGate(),
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

    // 1. Kontrol sürüyorsa Loading göster
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
