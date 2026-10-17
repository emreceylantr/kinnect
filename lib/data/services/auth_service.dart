// Kinnect - Authentication Service
// Handles Google OAuth and Email/Password authentication

import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/auth_repository.dart';
import '../repositories/profile_repository.dart';

/// Giriş sonucu - kullanıcı ID ve profil durumu.
class AuthResult {
  final String userId;
  final bool hasProfile;
  final Map<String, dynamic>? profile;

  AuthResult({
    required this.userId,
    required this.hasProfile,
    this.profile,
  });
}

/// Kullanıcı kimlik doğrulama servisi.
/// Google OAuth ve E-posta/Şifre destekler.
class AuthService {
  final AuthRepository _authRepository;
  final ProfileRepository _profileRepository;
  final GoogleSignIn _googleSignIn;

  AuthService({SupabaseClient? client, GoogleSignIn? googleSignIn})
      : _authRepository = AuthRepository(client ?? Supabase.instance.client),
        _profileRepository =
            ProfileRepository(client ?? Supabase.instance.client),
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              clientId:
                  '71608708372-9dvs03siqhcg5o9g8f7q6haatc1ismcn.apps.googleusercontent.com', // iOS
              serverClientId:
                  '71608708372-c01lic0b0jlojeqvaou65j8me28h4n99.apps.googleusercontent.com', // Web
            );

  /// Şifre sıfırlama e-postası gönder
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'kinnect://reset-callback',
      );
    } catch (e) {
      throw Exception("Sıfırlama maili gönderilemedi: $e");
    }
  }

  /// E-posta ile giriş
  Future<AuthResult> signInWithEmail(String email, String password) async {
    final res = await _authRepository.signInWithEmail(email, password);
    final userId = res.user!.id;

    final profile = await _profileRepository.getProfileById(userId);

    return AuthResult(
      userId: userId,
      hasProfile: profile != null,
      profile: profile,
    );
  }

  /// E-posta ile kayıt
  Future<void> signUpWithEmail(String email, String password) {
    return _authRepository.signUpWithEmail(email, password);
  }

  /// Google ile giriş (Native - Skip nonce checks enabled on Supabase)
  Future<AuthResult> signInWithGoogle() async {
    // Native Google Sign-In
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('Google oturumu iptal edildi.');
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) {
      throw Exception('Google ID Token alınamadı.');
    }

    // Supabase'e gönder - Skip nonce checks açık olduğu için nonce gerekmiyor
    final res = await Supabase.instance.client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );

    final userId = res.user!.id;
    final profile = await _profileRepository.getProfileById(userId);

    return AuthResult(
      userId: userId,
      hasProfile: profile != null,
      profile: profile,
    );
  }

  Future<void> signOut() => _authRepository.signOut();

  Session? currentSession() => _authRepository.currentSession();
}
