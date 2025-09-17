import 'package:flutter/material.dart';
import 'core/theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NutriTrack',
      theme: NutriTheme.light, // 🔗 liga o theme.dart aqui
      home: const Scaffold(
        body: Center(child: Text('NutriTrack 🚀')),
      ),
    );
  }
}
