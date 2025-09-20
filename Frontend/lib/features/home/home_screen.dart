import 'package:flutter/material.dart';
import '../../app/di.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => di.authRepository.signOut(),
          child: const Text('Logout (mock)'),
        ),
      ),
    );
  }
}
