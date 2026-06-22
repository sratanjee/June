import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper over the Supabase client so the rest of the app doesn't
/// import `supabase_flutter` directly.
///
/// The anon key is read from a `--dart-define=SUPABASE_ANON_KEY=...` at build
/// time. If it's empty the wrapper is considered "not configured" — `init()`
/// becomes a no-op and the boot path falls back to the local-only flow.
class AuthService {
  AuthService._();

  static const _supabaseUrl = 'https://aejmtjgikqqqflhtynip.supabase.co';
  static const _supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool _initialized = false;

  /// True once we have a non-empty anon key compiled in.
  static bool get configured => _supabaseAnonKey.isNotEmpty;

  /// Initializes Supabase if [configured] is true. Safe to call multiple times.
  static Future<void> init() async {
    if (!configured || _initialized) return;
    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _supabaseAnonKey,
    );
    _initialized = true;
  }

  /// Returns the current session, or null if unauthenticated / unconfigured.
  static Session? get currentSession {
    if (!configured || !_initialized) return null;
    return Supabase.instance.client.auth.currentSession;
  }

  /// Broadcast of auth state changes. Empty stream when not configured.
  static Stream<AuthState> get authStateChanges {
    if (!configured || !_initialized) {
      return const Stream<AuthState>.empty();
    }
    return Supabase.instance.client.auth.onAuthStateChange;
  }

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    _assertReady();
    return Supabase.instance.client.auth.signUp(
      email: email,
      password: password,
    );
  }

  static Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) {
    _assertReady();
    return Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() {
    _assertReady();
    return Supabase.instance.client.auth.signOut();
  }

  static void _assertReady() {
    if (!configured || !_initialized) {
      throw StateError(
        'AuthService is not configured. Build with --dart-define=SUPABASE_ANON_KEY=...',
      );
    }
  }
}
