import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/di.dart';

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign up')),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('SignUp placeholder'),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => context.go('/login'),
            child: const Text('Já tenho conta'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () { di.authRepository.signIn(); },
            child: const Text('Registar & entrar (mock)'),
          ),
        ]),
      ),
    );
  }
}
