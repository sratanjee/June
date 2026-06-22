import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_service.dart';
import 'screens/auth_screen.dart';
import 'screens/entry_screen.dart';
import 'screens/onboarding_screen.dart';
import 'storage/local_store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.init();
  runApp(const JuneApp());
}

class JuneApp extends StatelessWidget {
  const JuneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'June',
      debugShowCheckedModeBanner: false,
      theme: juneTheme(),
      home: const _Boot(),
    );
  }
}

/// Tiny gate that decides between onboarding, the auth screen, and the entry
/// screen.
///
/// Routing matrix:
///   - AuthService not configured  → name? entry : onboarding   (legacy path)
///   - configured + no session     → AuthScreen
///   - configured + session, no name → OnboardingScreen
///   - configured + session + name → EntryScreen
class _Boot extends StatefulWidget {
  const _Boot();

  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  String? _name;
  bool _nameLoaded = false;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _loadName();
    if (AuthService.configured) {
      _authSub = AuthService.authStateChanges.listen((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _loadName() async {
    final name = await LocalStore.loadUserName();
    if (!mounted) return;
    setState(() {
      _name = name;
      _nameLoaded = true;
    });
  }

  Widget _routeFor(bool hasName) {
    if (!AuthService.configured) {
      return hasName ? const EntryScreen() : const OnboardingScreen();
    }
    final session = AuthService.currentSession;
    if (session == null) return const AuthScreen();
    if (!hasName) return const OnboardingScreen();
    return const EntryScreen();
  }

  @override
  Widget build(BuildContext context) {
    if (!_nameLoaded) {
      return const Scaffold(
        body: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      );
    }
    final hasName = _name != null && _name!.trim().isNotEmpty;
    final body = _routeFor(hasName);

    // Debug-only banner when auth isn't configured yet, so it's obvious in
    // development without surfacing anything in release builds.
    if (kDebugMode && !AuthService.configured) {
      return Banner(
        location: BannerLocation.topEnd,
        message: 'auth off',
        color: JuneColors.amber,
        textStyle: const TextStyle(
          color: JuneColors.paper,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
        child: body,
      );
    }
    return body;
  }
}
