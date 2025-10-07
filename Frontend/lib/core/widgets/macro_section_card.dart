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

    // Metas / limites recomendados (podem vir a null)
    this.sugarsTargetG,
    this.fiberTargetG,
    this.saltTargetG,
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

  // Recomendações
  final double? sugarsTargetG;
  final double? fiberTargetG;
  final double? saltTargetG;

  // evita 0/0 e mantém a barra visível
  num _nonZeroTarget(num? target, double used) {
    final t = (target ?? 0).toDouble();
    if (t > 0) return t;
    return used > 0 ? used : 1;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // neutros
    final neutralFill = cs.outlineVariant;
    final neutralTrack = cs.surfaceContainerHighest;

    final sugarsT = _nonZeroTarget(sugarsTargetG, sugarsG);
    final fiberT  = _nonZeroTarget(fiberTargetG,  fiberG);
    final saltT   = _nonZeroTarget(saltTargetG,   saltG);

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
              Text('Calorias', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
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

          // Macros principais — com metas
          MacroProgressBar(
            label: 'Proteína',
            unit: ' g',
            used: proteinG,
            target: _nonZeroTarget(proteinTargetG, proteinG),
            color: cs.primary, // Fresh Green
            backgroundColor: cs.surfaceContainerHighest,
            duration: const Duration(milliseconds: 1800),
            delay: const Duration(milliseconds: 80),
          ),
          MacroProgressBar(
            label: 'Hidratos',
            unit: ' g',
            used: carbG,
            target: _nonZeroTarget(carbTargetG, carbG),
            color: cs.secondary, // Warm Tangerine
            backgroundColor: cs.surfaceContainerHighest,
            duration: const Duration(milliseconds: 1800),
            delay: const Duration(milliseconds: 160),
          ),
          MacroProgressBar(
            label: 'Gordura',
            unit: ' g',
            used: fatG,
            target: _nonZeroTarget(fatTargetG, fatG),
            color: cs.error, // Ripe Red
            backgroundColor: cs.surfaceContainerHighest,
            duration: const Duration(milliseconds: 1800),
            delay: const Duration(milliseconds: 240),
          ),

          const SizedBox(height: 8),
          Divider(color: cs.surfaceContainerHighest, height: 1),

          // Nutrientes extra — com limites recomendados reais
          MacroProgressBar(
            label: 'Açúcar',
            unit: ' g',
            used: sugarsG,
            target: sugarsT,
            color: neutralFill,
            backgroundColor: neutralTrack,
            duration: const Duration(milliseconds: 1600),
            delay: const Duration(milliseconds: 320),
          ),
          MacroProgressBar(
            label: 'Fibra',
            unit: ' g',
            used: fiberG,
            target: fiberT,
            color: neutralFill,
            backgroundColor: neutralTrack,
            duration: const Duration(milliseconds: 1600),
            delay: const Duration(milliseconds: 400),
          ),
          MacroProgressBar(
            label: 'Sal',
            unit: ' g',
            used: saltG,
            target: saltT,
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
