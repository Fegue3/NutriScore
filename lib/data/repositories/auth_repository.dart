import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  AuthRepository(this._client);
  final SupabaseClient _client;

  // Stream para o router ouvir e refrescar
  Stream<void> get authStateChanges =>
    _client.auth.onAuthStateChange.map((_) {});

  // Getter usado no redirect do GoRouter
  bool get isLoggedIn => _client.auth.currentSession != null;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: fullName != null ? {'full_name': fullName} : null,
    );
  }

  Future<void> signOut() => _client.auth.signOut();
}
