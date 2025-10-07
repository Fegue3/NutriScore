// lib/features/nutrition/nutrition_stats_screen.dart
import 'package:flutter/material.dart';
import '../../data/stats_api.dart';
import '../../data/meals_api.dart';
import '../../core/widgets/macro_section_card.dart';
import '../../core/widgets/calories_meals_pie.dart';

class NutritionStatsScreen extends StatefulWidget {
  const NutritionStatsScreen({super.key});
  @override
  State<NutritionStatsScreen> createState() => _NutritionStatsScreenState();
}

class _NutritionStatsScreenState extends State<NutritionStatsScreen> {
  int _dayOffset = 0; // 0=hoje, -1=ontem, 1=amanhã...
  bool _loading = false;
  String? _error;
  DailyStats? _stats;
  RecommendedResponse? _recommended;

  // kcal por refeição calculado no cliente (fallback)
  Map<MealSlot, double>? _kcalByMealClient;

  DateTime get _date => DateTime.now().add(Duration(days: _dayOffset));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _kcalByMealClient = null;
    });
    try {
      // zera hora/min/seg para o endpoint do Diário
      final dayOnly = DateTime(_date.year, _date.month, _date.day);

      final resp = await Future.wait([
        StatsApi.I.getDaily(date: _dayOffset == 0 ? null : _date),
        StatsApi.I.getRecommended(),
        MealsApi.I.getDay(dayOnly), // posicional
      ]);

      if (!mounted) return;
      final mealsPayload = resp[2];
      setState(() {
        _stats = resp[0] as DailyStats;
        _recommended = resp[1] as RecommendedResponse;
        _kcalByMealClient = _calcKcalFromMealsPayload(mealsPayload);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Falha ao carregar: $e';
        _loading = false;
      });
    }
  }

  void _go(int delta) {
    setState(() => _dayOffset += delta);
    _load();
  }

  String _labelFor(BuildContext ctx) {
    if (_dayOffset == 0) return "Hoje";
    if (_dayOffset == -1) return "Ontem";
    if (_dayOffset == 1) return "Amanhã";
    return MaterialLocalizations.of(ctx).formatMediumDate(_date);
  }

  // ===== Helpers para o pie chart =====
  Map<MealSlot, double>? _kcalByMealFromStats(DailyStats s) {
    // 0) Novo modelo do StatsApi (campo byMealRaw)
    if (s.byMealRaw != null) {
      final bm = s.byMealRaw!;
      double read(Map m, String key) {
        final v = m[key];
        if (v is Map && v['kcal'] != null) {
          final x = v['kcal'];
          return x is num ? x.toDouble() : double.tryParse('$x') ?? 0.0;
        }
        return 0.0;
      }

      return {
        MealSlot.breakfast: read(bm, 'BREAKFAST'),
        MealSlot.lunch: read(bm, 'LUNCH'),
        MealSlot.snack: read(bm, 'SNACK'),
        MealSlot.dinner: read(bm, 'DINNER'),
      };
    }

    // 1) Possível payload com chaves MAIÚSCULAS em s.byMeal
    final dyn = s as dynamic;
    try {
      final byMeal = dyn.byMeal;
      if (byMeal is Map) {
        double readU(Map m, String key) {
          final v = m[key];
          if (v is Map && v['kcal'] != null) {
            final x = v['kcal'];
            return x is num ? x.toDouble() : double.tryParse('$x') ?? 0.0;
          }
          return 0.0;
        }

        // suporta tanto MAIÚSCULAS como minúsculas
        double pick(Map m, String up, String low) =>
            readU(m, up) > 0 ? readU(m, up) : readU(m, low);

        return {
          MealSlot.breakfast: pick(byMeal, 'BREAKFAST', 'breakfast'),
          MealSlot.lunch: pick(byMeal, 'LUNCH', 'lunch'),
          MealSlot.snack: pick(byMeal, 'SNACK', 'snack'),
          MealSlot.dinner: pick(byMeal, 'DINNER', 'dinner'),
        };
      }
    } catch (_) {}

    // 2) Fallback antigo: mapa simples kcalByMeal {breakfast/lunch/...: number}
    try {
      final map = dyn.kcalByMeal;
      if (map != null) {
        double nn(String k) {
          final v = map[k];
          return v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
        }

        return {
          MealSlot.breakfast: nn('breakfast'),
          MealSlot.lunch: nn('lunch'),
          MealSlot.snack: nn('snack'),
          MealSlot.dinner: nn('dinner'),
        };
      }
    } catch (_) {}

    return null;
  }

  Map<MealSlot, double> _calcKcalFromMealsPayload(dynamic data) {
    double b = 0, l = 0, sn = 0, d = 0;

    // normaliza lista de grupos
    List<dynamic> groups;
    if (data is Map && data['meals'] is List) {
      groups = List.from(data['meals']);
    } else if (data is Map && data['groups'] is List) {
      groups = List.from(data['groups']);
    } else if (data is Map && data['sections'] is List) {
      groups = List.from(data['sections']);
    } else if (data is List) {
      groups = List.from(data);
    } else {
      groups = const [];
    }

    String slotOf(Map g) {
      final raw =
          (g['type'] ??
                  g['slot'] ??
                  g['name'] ??
                  g['title'] ??
                  g['header'] ??
                  '')
              .toString()
              .toLowerCase();
      if (raw.contains('break') || raw.contains('peq') || raw.contains('manh'))
        return 'breakfast';
      if (raw.contains('lunch') || raw.contains('almo')) return 'lunch';
      if (raw.contains('snack') || raw.contains('lanche')) return 'snack';
      if (raw.contains('dinner') ||
          raw.contains('jantar') ||
          raw.contains('noite'))
        return 'dinner';
      final idx = g['index'] ?? g['slotIndex'] ?? g['id'];
      if (idx is num) {
        switch (idx.toInt()) {
          case 0:
            return 'breakfast';
          case 1:
            return 'lunch';
          case 2:
            return 'snack';
          case 3:
            return 'dinner';
        }
      }
      return 'snack';
    }

    double numv(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(
            v
                .toString()
                .replaceAll(',', '.')
                .replaceAll(RegExp(r'[^0-9\.\-]'), ''),
          ) ??
          0;
    }

    double groupKcal(Map g) {
      final direct =
          g['totalKcal'] ??
          g['kcal'] ??
          g['kcals'] ??
          g['calories'] ??
          g['energyKcal'] ??
          g['sumKcal'] ??
          (g['totals'] is Map
              ? (g['totals']['kcal'] ?? g['totals']['calories'])
              : null);
      if (direct != null) return numv(direct);

      final items =
          (g['items'] ?? g['entries'] ?? g['foods'] ?? g['list'] ?? const [])
              as List? ??
          const [];
      double sum = 0;
      for (final it in items) {
        if (it is! Map) continue;
        final v =
            it['kcal'] ??
            it['calories'] ??
            it['energyKcal'] ??
            it['energy_kcal'] ??
            (it['nutriments'] is Map
                ? (it['nutriments']['energy-kcal'] ??
                      it['nutriments']['energy-kcal_100g'] ??
                      it['nutriments']['energyKcal'])
                : null) ??
            (it['nutrition'] is Map ? it['nutrition']['kcal'] : null);
        sum += numv(v);
      }
      return sum;
    }

    for (final g in groups) {
      if (g is! Map) continue;
      final slot = slotOf(g);
      final kcal = groupKcal(g);
      switch (slot) {
        case 'breakfast':
          b += kcal;
          break;
        case 'lunch':
          l += kcal;
          break;
        case 'snack':
          sn += kcal;
          break;
        case 'dinner':
          d += kcal;
          break;
      }
    }

    return {
      MealSlot.breakfast: b,
      MealSlot.lunch: l,
      MealSlot.snack: sn,
      MealSlot.dinner: d,
    };
  }

  double _totalKcal(DailyStats s) {
    // 1) valor oficial
    final tk = s.totals.kcal.toDouble();
    if (tk > 0) return tk;

    // 2) soma do byMeal vindo do stats
    final fromStats = _kcalByMealFromStats(s);
    if (fromStats != null) {
      final sum = fromStats.values.fold(0.0, (a, b) => a + b);
      if (sum > 0) return sum;
    }

    // 3) fallback cliente (MealsApi)
    final client = _kcalByMealClient;
    if (client != null) return client.values.fold(0.0, (a, b) => a + b);

    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final stats = _stats;
    final rec = _recommended;

    final kcalTarget = stats?.goals.kcal ?? rec?.targets.kcal ?? 0;
    final proteinTarget = stats?.goals.proteinG ?? rec?.targets.proteinG ?? 0;
    final carbTarget = stats?.goals.carbG ?? rec?.targets.carbG ?? 0;
    final fatTarget = stats?.goals.fatG ?? rec?.targets.fatG ?? 0;

    final sugarsTarget = rec?.targets.sugarsGMax ?? 0;
    final fiberTarget = rec?.targets.fiberG ?? 0;
    final saltTarget = rec?.targets.saltGMax ?? 0;

    final kcalByMeal = () {
      if (stats != null) {
        final m = _kcalByMealFromStats(stats);
        if (m != null) return m;
      }
      return _kcalByMealClient ??
          {
            MealSlot.breakfast: 0,
            MealSlot.lunch: 0,
            MealSlot.snack: 0,
            MealSlot.dinner: 0,
          };
    }();

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        title: Text(
          'Nutrição',
          style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // selector de dia
            Row(
              children: [
                IconButton.filled(
                  onPressed: _loading ? null : () => _go(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: cs.surfaceContainerHighest,
                    foregroundColor: cs.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: const ShapeDecoration(
                      color: Colors.transparent,
                      shape: StadiumBorder(),
                    ),
                    child: Center(
                      child: Text(
                        _labelFor(context),
                        style: tt.titleMedium?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _loading ? null : () => _go(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: cs.surfaceContainerHighest,
                    foregroundColor: cs.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _error!,
                  style: tt.bodyMedium?.copyWith(color: cs.error),
                ),
              ),

            if (stats != null) ...[
              // Pie chart
              CaloriesMealsPie(
                kcalByMeal: kcalByMeal,
                totalKcal: _totalKcal(stats),
                goalKcal: kcalTarget.toDouble(),
              ),
              const SizedBox(height: 16),

              // Card “Calorias” + Macros
              MacroSectionCard(
                kcalUsed: stats.totals.kcal,
                kcalTarget: kcalTarget,
                proteinG: stats.totals.proteinG.toDouble(),
                proteinTargetG: proteinTarget.toDouble(),
                carbG: stats.totals.carbG.toDouble(),
                carbTargetG: carbTarget.toDouble(),
                fatG: stats.totals.fatG.toDouble(),
                fatTargetG: fatTarget.toDouble(),
                sugarsG: stats.totals.sugarsG.toDouble(),
                fiberG: stats.totals.fiberG.toDouble(),
                saltG: stats.totals.saltG.toDouble(),
                sugarsTargetG: sugarsTarget.toDouble(),
                fiberTargetG: fiberTarget.toDouble(),
                saltTargetG: saltTarget.toDouble(),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}
