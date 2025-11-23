// lib/services/auth_service.dart
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/auth_repository.dart';
import '../repositories/profile_repository.dart';

class AuthResult {
  final String userId;
  final bool hasProfile;

  AuthResult({
    required this.userId,
    required this.hasProfile,
  });
}

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
              serverClientId:
              '71608708372-c01lic0b0jlojeqvaou65j8me28h4n99.apps.googleusercontent.com',
            );

  /// E-posta ile giriş
  Future<AuthResult> signInWithEmail(String email, String password) async {
    final res = await _authRepository.signInWithEmail(email, password);
    final userId = res.user!.id;

    final profile = await _profileRepository.getProfileById(userId);

    return AuthResult(
      userId: userId,
      hasProfile: profile != null,
    );
  }

  /// E-posta ile kayıt
  Future<void> signUpWithEmail(String email, String password) {
    return _authRepository.signUpWithEmail(email, password);
  }

  /// Google ile giriş
  Future<AuthResult> signInWithGoogle() async {
    // Kullanıcı hesabı seçer
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('Google oturumu iptal edildi.');
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;

    if (idToken == null) {
      throw Exception('Google ID Token alınamadı.');
    }

    final res = await _authRepository.signInWithIdToken(
      idToken: idToken,
      accessToken: googleAuth.accessToken,
    );

    final userId = res.user!.id;
    final profile = await _profileRepository.getProfileById(userId);

    return AuthResult(
      userId: userId,
      hasProfile: profile != null,
    );
  }

  Future<void> signOut() => _authRepository.signOut();

  Session? currentSession() => _authRepository.currentSession();
}
