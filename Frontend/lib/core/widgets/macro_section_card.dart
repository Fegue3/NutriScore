import 'package:flutter/material.dart';
import 'macro_progress_bar.dart';

class MacroSectionCard extends StatelessWidget {
  const MacroSectionCard({
    super.key,
    required this.kcalUsed,
    required this.kcalTarget,
    required this.proteinG,
    required this.proteinTargetG,
    required this.carbG,
    required this.carbTargetG,
    required this.fatG,
    required this.fatTargetG,
    required this.sugarsG,
    required this.fiberG,
    required this.saltG,
  });

  final int kcalUsed;
  final int kcalTarget;
  final double proteinG;
  final double proteinTargetG;
  final double carbG;
  final double carbTargetG;
  final double fatG;
  final double fatTargetG;
  final double sugarsG;
  final double fiberG;
  final double saltG;

  // fallback para quando a meta não existe/é 0
  num _fallbackTarget(double used, double target) {
    if (target > 0) return target;
    return used > 0 ? used : 1; // evita 0/0
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // neutros
    final neutralFill = cs.outlineVariant;            // cinza da barra
    final neutralTrack = cs.surfaceContainerHighest;  // track

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceBright,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, 4),
            color: Color.fromRGBO(0, 0, 0, 0.05),
          )
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Cabeçalho
          Row(
            children: [
              Text('Hoje',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.surfaceContainerHighest),
                ),
                child: Text(
                  '$kcalUsed / $kcalTarget kcal',
                  style: tt.labelLarge?.copyWith(color: cs.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: cs.surfaceContainerHighest, height: 1),

          // Macros principais — cores próprias + animação lenta
          MacroProgressBar(
            label: 'Proteína',
            unit: ' g',
            used: proteinG,
            target: _fallbackTarget(proteinG, proteinTargetG),
            color: cs.primary, // Fresh Green
            backgroundColor: cs.surfaceContainerHighest,
            duration: const Duration(milliseconds: 1800),
            delay: const Duration(milliseconds: 80),
          ),
          MacroProgressBar(
            label: 'Hidratos',
            unit: ' g',
            used: carbG,
            target: _fallbackTarget(carbG, carbTargetG),
            color: cs.secondary, // Warm Tangerine
            backgroundColor: cs.surfaceContainerHighest,
            duration: const Duration(milliseconds: 1800),
            delay: const Duration(milliseconds: 160),
          ),
          MacroProgressBar(
            label: 'Gordura',
            unit: ' g',
            used: fatG,
            target: _fallbackTarget(fatG, fatTargetG),
            color: cs.error, // Ripe Red
            backgroundColor: cs.surfaceContainerHighest,
            duration: const Duration(milliseconds: 1800),
            delay: const Duration(milliseconds: 240),
          ),

          const SizedBox(height: 8),
          Divider(color: cs.surfaceContainerHighest, height: 1),

          // Nutrientes extra — cinza + barra sempre visível (fallback)
          MacroProgressBar(
            label: 'Açúcar',
            unit: ' g',
            used: sugarsG,
            target: _fallbackTarget(sugarsG, 0),
            color: neutralFill,
            backgroundColor: neutralTrack,
            duration: const Duration(milliseconds: 1600),
            delay: const Duration(milliseconds: 320),
          ),
          MacroProgressBar(
            label: 'Fibra',
            unit: ' g',
            used: fiberG,
            target: _fallbackTarget(fiberG, 0),
            color: neutralFill,
            backgroundColor: neutralTrack,
            duration: const Duration(milliseconds: 1600),
            delay: const Duration(milliseconds: 400),
          ),
          MacroProgressBar(
            label: 'Sal',
            unit: ' g',
            used: saltG,
            target: _fallbackTarget(saltG, 0),
            color: neutralFill,
            backgroundColor: neutralTrack,
            duration: const Duration(milliseconds: 2200),
            delay: const Duration(milliseconds: 480),
          ),
        ],
      ),
    );
  }
}
