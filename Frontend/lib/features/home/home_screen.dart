import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/di.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Terminar sessão',
            onPressed: () {
              di.authRepository.logout(); // <— este é o nome certo
              context.go('/');            // opcional
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: const Center(
        child: Text('Bem-vindo ao NutriScore 👋'),
      ),
    );
  }
}
