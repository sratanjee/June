import 'package:flutter/material.dart';

import 'screens/entry_screen.dart';
import 'screens/onboarding_screen.dart';
import 'storage/local_store.dart';
import 'theme.dart';

void main() {
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

/// Tiny gate that decides between onboarding and the entry screen based on
/// whether a name has been persisted to LocalStore.
class _Boot extends StatefulWidget {
  const _Boot();

  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  Future<String?>? _future;

  @override
  void initState() {
    super.initState();
    _future = LocalStore.loadUserName();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                ),
              ),
            ),
          );
        }
        final name = snapshot.data;
        if (name == null || name.trim().isEmpty) {
          return const OnboardingScreen();
        }
        return const EntryScreen();
      },
    );
  }
}
