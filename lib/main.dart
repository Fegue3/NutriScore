// lib/main.dart
import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'core/widgets/app_bottom_nav.dart';

void main() => runApp(const NutriTrackApp());

class NutriTrackApp extends StatelessWidget {
  const NutriTrackApp(); // sem key

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NutriTrack',
      debugShowCheckedModeBanner: false,
      theme: NutriTheme.light,
      home: const _NavShell(),
    );
  }
}

class _NavShell extends StatefulWidget {
  const _NavShell(); // sem key

  @override
  State<_NavShell> createState() => _NavShellState();
}

class _NavShellState extends State<_NavShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const SizedBox.shrink(),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _index,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}
