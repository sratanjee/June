import 'package:flutter/material.dart';

import 'screens/entry_screen.dart';
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
      home: const EntryScreen(),
    );
  }
}
