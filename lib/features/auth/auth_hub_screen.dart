import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AuthHubScreen extends StatelessWidget {
  const AuthHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface, // fundo neutro (Soft Off-White)
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ícone do projeto
                  Image.asset(
                    'assets/utils/icon.png',
                    width: 256,
                    height: 256,
                  ),
                  const SizedBox(height: 12),

                  // Título + subtítulo (Nunito Sans / Inter via theme)
                  Text(
                    'NutriScore',
                    style: tt.headlineSmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Alimentação consciente e simples',
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: .70),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Card com os CTAs
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 10,
                          offset: Offset(0, 4),
                          color: Color(0x14000000),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // CTA primário — Criar conta (Fresh Green)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => context.go('/signup'),
                            icon: const Icon(Icons.person_add),
                            label: const Text('Sou um novo utilizador'),
                            style: FilledButton.styleFrom(
                              backgroundColor: cs.primary,
                              foregroundColor: cs.onPrimary,
                              padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // CTA secundário — Sign in (Ghost/Outline em Fresh Green)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => context.go('/login'),
                            icon: const Icon(Icons.login),
                            label: const Text('Já tenho conta'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: cs.primary,
                              side: BorderSide(color: cs.primary, width: 2),
                              padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Pequena nota opcional
                  Text(
                    'Ao continuar, aceita os Termos & Privacidade',
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: .50),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
