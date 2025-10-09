// lib/core/widgets/calories_meals_pie.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Slots de refeição suportados.
enum MealSlot { breakfast, lunch, snack, dinner }

extension MealSlotX on MealSlot {
  String get label {
    switch (this) {
      case MealSlot.breakfast:
        return 'Peq-almoço';
      case MealSlot.lunch:
        return 'Almoço';
      case MealSlot.snack:
        return 'Lanche';
      case MealSlot.dinner:
        return 'Jantar';
    }
  }
}

/// Pie chart da distribuição de calorias por refeição.
class CaloriesMealsPie extends StatelessWidget {
  final Map<MealSlot, double> kcalByMeal;
  final double totalKcal;
  final double? goalKcal;
  final EdgeInsetsGeometry padding;
  final double chartSize;

  const CaloriesMealsPie({
    super.key,
    required this.kcalByMeal,
    this.totalKcal = 0,
    this.goalKcal,
    this.padding = const EdgeInsets.all(16),
    this.chartSize = 160,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final colors = <MealSlot, Color>{
      MealSlot.breakfast: cs.primary,
      MealSlot.lunch: cs.tertiary,
      MealSlot.snack: cs.secondary,
      MealSlot.dinner: cs.error,
    };

    final values =
        MealSlot.values.map((m) => (kcalByMeal[m] ?? 0).toDouble()).toList();

    final sum =
        (totalKcal > 0 ? totalKcal : values.fold<double>(0, (a, b) => a + b))
            .toDouble();
    final isEmpty = sum <= 0.0001;
    final safeSum = isEmpty ? 1.0 : sum;

    final sections = isEmpty
        ? <PieChartSectionData>[
            PieChartSectionData(
              color: cs.surfaceContainerHighest,
              value: 1,
              radius: 18,
              showTitle: false,
            ),
          ]
        : MealSlot.values.map((slot) {
            final v = (kcalByMeal[slot] ?? 0).toDouble();
            return PieChartSectionData(
              color: colors[slot],
              value: v <= 0 ? 0.0001 : v,
              radius: 18,
              showTitle: false,
            );
          }).toList();

    final mono = theme.textTheme.bodyMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
      fontWeight: FontWeight.w600,
    );

    return Card(
      color: theme.cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Distribuição das Calorias', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                // DONUT
                SizedBox(
                  width: chartSize,
                  height: chartSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sections: sections,
                          startDegreeOffset: -90,
                          centerSpaceRadius: chartSize * 0.38,
                          sectionsSpace: isEmpty ? 0 : 2,
                          pieTouchData: PieTouchData(enabled: !isEmpty),
                        ),
                        swapAnimationDuration: const Duration(milliseconds: 1200),
                        swapAnimationCurve: Curves.easeOutCubic,
                      ),
                      // Centro
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isEmpty)
                            Text('Sem calorias',
                                style: theme.textTheme.labelMedium)
                          else
                            Text('${sum.toStringAsFixed(0)} kcal',
                                style: mono),
                          if (!isEmpty && goalKcal != null && goalKcal! > 0)
                            Text(
                              '${((sum / goalKcal!).clamp(0, 1) * 100).round()}% do objetivo',
                              style: theme.textTheme.labelSmall,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // LEGENDA (compacta)
                Expanded(
                  child: Column(
                    children: MealSlot.values.map((slot) {
                      final v = (kcalByMeal[slot] ?? 0).toDouble();
                      final pct = (v / safeSum) * 100.0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4), // era 6
                        child: Row(
                          children: [
                            _LegendDot(
                              color: (isEmpty ? cs.surfaceContainerHighest : colors[slot])!,
                              size: 8, // era 12
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                slot.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${v.toStringAsFixed(0)} kcal · ${pct.toStringAsFixed(0)}%',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final double size;
  const _LegendDot({required this.color, this.size = 12});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
