// lib/repositories/auth_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final SupabaseClient client;

  AuthRepository(this.client);

  Future<AuthResponse> signInWithEmail(String email, String password) {
    return client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUpWithEmail(String email, String password) {
    return client.auth.signUp(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signInWithIdToken({
    required String idToken,
    String? accessToken,
  }) {
    return client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  Future<void> signOut() {
    return client.auth.signOut();
  }

  Session? currentSession() {
    return client.auth.currentSession;
  }
}
