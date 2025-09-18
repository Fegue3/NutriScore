import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/di.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('SignIn placeholder'),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => context.go('/signup'),
            child: const Text('Criar conta'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () { di.authRepository.signIn(); },
            child: const Text('Entrar (mock)'),
          ),
        ]),
      ),
    );
  }
}
