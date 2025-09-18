import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'core/widgets/app_bottom_nav.dart';

void main() => runApp(const NutriTrackApp());

class NutriTrackApp extends StatelessWidget {
  const NutriTrackApp({super.key});

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
  const _NavShell({Key? key}) : super(key: key); // <- fixa o aviso

  @override
  State<_NavShell> createState() => _NavShellState();
}

class _NavShellState extends State<_NavShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const SizedBox.shrink(), // sem conteúdo — só a navbar
      bottomNavigationBar: AppBottomNav(
        currentIndex: _index,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}
