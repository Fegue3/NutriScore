// lib/features/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

// usa as variáveis do teu theme.dart
import '../../core/theme.dart' show AppColors;

import '../../app/di.dart'; // logout()
import '../../data/calorie_api.dart'; // CalorieApi.I
import '../../data/stats_api.dart'; // StatsApi.I + modelos
import '../../data/meals_api.dart'; // MealsApi.I (DayMeals, MealEntry)
import '../../core/widgets/weight_trend_chart.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ===== Dia selecionado (offset em relação a hoje) =====
  // (mantemos a lógica para futuro, mas não mostramos a navegação)
  final int _dayOffset = 0;
  DateTime get _date => DateTime.now().add(Duration(days: _dayOffset));

  String? _username;

  // ===== Estado =====
  bool _loading = true;
  String? _error;

  // ===== Calorias =====
  int _goalKcal = 2200;
  int _consumedKcal = 0;

  // kcal por refeição
  double _kBreakfast = 0, _kLunch = 0, _kSnack = 0, _kDinner = 0;

  // macros consumidas
  num _proteinG = 0, _carbG = 0, _fatG = 0;

  // metas/limites
  num _targetProteinG = 0, _targetCarbG = 0, _targetFatG = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<String?> _readUserName() async {
    try {
      final repo = di.authRepository as dynamic;
      final direct = (repo.currentUserName as String?);
      if (direct != null && direct.trim().isNotEmpty) return direct.trim();
      final userObj = (repo.user);
      if (userObj is Map && userObj['name'] is String) {
        final n = (userObj['name'] as String).trim();
        if (n.isNotEmpty) return n;
      }
      final profile = (repo.profile);
      if (profile is Map && profile['name'] is String) {
        final n = (profile['name'] as String).trim();
        if (n.isNotEmpty) return n;
      }
    } catch (_) {}
    try {
      final up = (di as dynamic).userProfile;
      if (up != null) {
        final n = (up as dynamic).name as String?;
        if (n != null && n.trim().isNotEmpty) return n.trim();
      }
    } catch (_) {}
    return null;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final day = DateTime(_date.year, _date.month, _date.day);

      final daily = await CalorieApi.I.getDaily(
        date: _dayOffset == 0 ? null : day,
      );
      final goalFromCalorieApi = daily.targetCalories;
      final consumedFromCalorieApi = daily.consumedCalories;

      final stats = await StatsApi.I.getDaily(
        date: _dayOffset == 0 ? null : day,
      );

      final consumedFromStats = stats.totals.kcal;
      final userGoalKcal = stats.goals.kcal;

      _proteinG = stats.totals.proteinG;
      _carbG = stats.totals.carbG;
      _fatG = stats.totals.fatG;

      _targetProteinG = stats.goals.proteinG ?? 0;
      _targetCarbG = stats.goals.carbG ?? 0;
      _targetFatG = stats.goals.fatG ?? 0;

      final rec = await StatsApi.I.getRecommendedTargets();
      _targetProteinG = _targetProteinG == 0 ? rec.proteinG : _targetProteinG;
      _targetCarbG = _targetCarbG == 0 ? rec.carbG : _targetCarbG;
      _targetFatG = _targetFatG == 0 ? rec.fatG : _targetFatG;

      if (stats.byMealRaw != null) {
        double parseKcal(dynamic v) =>
            v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);
        final m = Map<String, dynamic>.from(stats.byMealRaw!);
        _kBreakfast = parseKcal((m['BREAKFAST'] ?? m['breakfast'])?['kcal']);
        _kLunch = parseKcal((m['LUNCH'] ?? m['lunch'])?['kcal']);
        _kSnack = parseKcal((m['SNACK'] ?? m['snack'])?['kcal']);
        _kDinner = parseKcal((m['DINNER'] ?? m['dinner'])?['kcal']);
      } else {
        final dm = await MealsApi.I.getDay(day);
        final parsed = _kcalByMealFromDayMeals(dm);
        _kBreakfast = parsed['breakfast'] ?? 0;
        _kLunch = parsed['lunch'] ?? 0;
        _kSnack = parsed['snack'] ?? 0;
        _kDinner = parsed['dinner'] ?? 0;
        if (_consumedKcal == 0) {
          _consumedKcal = (_kBreakfast + _kLunch + _kSnack + _kDinner).round();
        }
      }

      _goalKcal = userGoalKcal ?? goalFromCalorieApi;
      _consumedKcal = consumedFromStats != 0
          ? consumedFromStats
          : consumedFromCalorieApi;

      _username ??= await _readUserName();

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Erro ao carregar dashboard: $e';
      });
    }
  }

  Map<String, double> _kcalByMealFromDayMeals(DayMeals dm) {
    double b = 0, l = 0, s = 0, d = 0;
    for (final e in dm.entries) {
      final kcal = (e.calories ?? 0).toDouble();
      switch (e.meal) {
        case MealType.breakfast:
          b += kcal;
          break;
        case MealType.lunch:
          l += kcal;
          break;
        case MealType.snack:
          s += kcal;
          break;
        case MealType.dinner:
          d += kcal;
          break;
      }
    }
    return {'breakfast': b, 'lunch': l, 'snack': s, 'dinner': d};
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final remaining = (_goalKcal - _consumedKcal).clamp(0, 1 << 31);
    final pct = _goalKcal <= 0
        ? 0.0
        : (_consumedKcal / _goalKcal).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.freshGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Dashboard',
          style: tt.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Terminar sessão',
            onPressed: () async {
              final navigator = GoRouter.of(context);
              await di.authRepository.logout();
              if (!mounted) return;
              navigator.go('/');
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),

      // (Sem FAB)
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _ErrorView(message: _error!, onRetry: _load)
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  // ===== Só o cumprimento — navegação de dias REMOVIDA =====
                  Text(
                    (_username == null || _username!.trim().isEmpty)
                        ? 'Olá 👋'
                        : 'Olá, ${_username!.trim()} 👋',
                    style: tt.titleLarge,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),

                  const SizedBox(height: 16),

                  // ===== Calorias =====
                  _Card(
                    child: Row(
                      children: [
                        _CaloriesRing(consumed: _consumedKcal, goal: _goalKcal),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Calorias de hoje', style: tt.titleMedium),
                              const SizedBox(height: 8),
                              _kv('Objetivo', '$_goalKcal kcal', tt),
                              _kv('Consumidas', '$_consumedKcal kcal', tt),
                              _kv(
                                'Restantes',
                                '$remaining kcal',
                                tt,
                                emphasize: true,
                                color: cs.primary,
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  // ===== Peso (gráfico) =====
                  const SizedBox(height: 12),
                  const WeightTrendCard(
                    daysBack: 120, // opcional
                    title: 'Evolução do peso',
                    showLegend: true,
                  ),
                  const SizedBox(height: 16),
                  // ===== Macros (3 círculos) =====
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Macros', style: tt.titleMedium),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _MacroCircle(
                                label: 'Proteína',
                                value: _proteinG.toDouble(),
                                target: _targetProteinG.toDouble(),
                                unit: 'g',
                                color: AppColors.leafyGreen,
                                onTap: () => context.go('/diary'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _MacroCircle(
                                label: 'Hidratos',
                                value: _carbG.toDouble(),
                                target: _targetCarbG.toDouble(),
                                unit: 'g',
                                color: AppColors.warmTangerine,
                                onTap: () => context.go('/diary'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _MacroCircle(
                                label: 'Gordura',
                                value: _fatG.toDouble(),
                                target: _targetFatG.toDouble(),
                                unit: 'g',
                                color: AppColors.goldenAmber,
                                onTap: () => context.go('/diary'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  // ===== Refeições =====
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Refeições', style: tt.titleMedium),
                        const SizedBox(height: 12),
                        _MealRow(
                          icon: Icons.free_breakfast,
                          label: 'Pequeno-almoço',
                          kcal: _kBreakfast,
                          onTap: () => context.go('/diary'),
                        ),
                        const SizedBox(height: 12),
                        _MealRow(
                          icon: Icons.lunch_dining,
                          label: 'Almoço',
                          kcal: _kLunch,
                          onTap: () => context.go('/diary'),
                        ),
                        const SizedBox(height: 12),
                        _MealRow(
                          icon: Icons.cookie_outlined,
                          label: 'Lanche',
                          kcal: _kSnack,
                          onTap: () => context.go('/diary'),
                        ),
                        const SizedBox(height: 12),
                        _MealRow(
                          icon: Icons.dinner_dining,
                          label: 'Jantar',
                          kcal: _kDinner,
                          onTap: () => context.go('/diary'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
      ),
    );
  }

  Widget _kv(
    String k,
    String v,
    TextTheme tt, {
    bool emphasize = false,
    Color? color,
  }) {
    final style = emphasize
        ? tt.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
            fontFamily: 'RobotoMono',
          )
        : tt.bodyMedium;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: tt.bodyMedium),
        Text(v, style: style),
      ],
    );
  }
}

// ================== UI building blocks ==================

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 4),
            color: Color(0x14000000),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

class _CaloriesRing extends StatelessWidget {
  final int consumed;
  final int goal;
  const _CaloriesRing({required this.consumed, required this.goal});

  @override
  Widget build(BuildContext context) {
    final pct = goal <= 0 ? 0.0 : (consumed / goal).clamp(0.0, 1.0);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: CircularProgressIndicator(
              value: pct,
              strokeWidth: 12,
              strokeCap: StrokeCap.round,
              color: cs.primary,
              backgroundColor: cs.surfaceContainerHighest,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(pct * 100).round()}%',
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFamily: 'RobotoMono',
                ),
              ),
              const SizedBox(height: 2),
              Text('kcal', style: tt.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

// ===== Macros em círculos =====
class _MacroCircle extends StatelessWidget {
  final String label;
  final double value; // consumido em g
  final double target; // alvo em g
  final String unit;
  final Color color;
  final VoidCallback? onTap;

  const _MacroCircle({
    required this.label,
    required this.value,
    required this.target,
    required this.unit,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final hasTarget = target > 0;
    final pct = hasTarget ? (value / target).clamp(0.0, 1.0) : 0.0;

    final circle = SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 12,
              strokeCap: StrokeCap.round,
              valueColor: AlwaysStoppedAnimation<Color>(
                cs.surfaceContainerHighest,
              ),
              backgroundColor: Colors.transparent,
            ),
          ),
          SizedBox(
            width: 96,
            height: 96,
            child: CircularProgressIndicator(
              value: pct,
              strokeWidth: 12,
              strokeCap: StrokeCap.round,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              backgroundColor: Colors.transparent,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${value.toStringAsFixed(0)} $unit',
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFamily: 'RobotoMono',
                ),
              ),
              Text(
                hasTarget ? 'Alvo ${target.toStringAsFixed(0)}' : 'sem alvo',
                style: tt.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onTap != null)
          InkWell(
            borderRadius: BorderRadius.circular(60),
            onTap: onTap,
            child: circle,
          )
        else
          circle,
        const SizedBox(height: 8),
        Text(label, style: tt.bodyMedium),
      ],
    );
  }
}

class _MealRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double kcal;
  final VoidCallback? onTap;
  const _MealRow({
    required this.icon,
    required this.label,
    required this.kcal,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final barPct = kcal <= 0
        ? 0.0
        : (kcal / 800).clamp(0.0, 1.0); // escala visual

    final row = Row(
      children: [
        Icon(icon, color: cs.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: tt.bodyLarge, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: barPct,
                  minHeight: 10,
                  color: AppColors.warmTangerine,
                  backgroundColor: cs.surfaceContainerHighest,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${kcal.round()} kcal',
          style: tt.titleSmall?.copyWith(fontFamily: 'RobotoMono'),
        ),
      ],
    );

    return onTap != null
        ? InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: row,
            ),
          )
        : row;
  }
}

// ===== Saúde & Limites — medidor exclusivo =====
class _LimitMeter extends StatelessWidget {
  final IconData icon;
  final String label;
  final double used;
  final double max;
  final String unit;

  const _LimitMeter({
    required this.icon,
    required this.label,
    required this.used,
    required this.max,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final hasMax = max > 0;
    final pct = hasMax ? (used / max).clamp(0.0, 1.0) : 0.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: cs.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: tt.bodyLarge),
              const SizedBox(height: 8),
              Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: pct,
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.leafyGreen,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.goldenAmber,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _chip(
                    '${used.toStringAsFixed(0)} $unit',
                    cs.surfaceContainerHigh,
                  ),
                  _chip(
                    hasMax
                        ? 'máx: ${max.toStringAsFixed(0)} $unit'
                        : 'sem limite definido',
                    const Color(0xFFE8F5E9), // Light Sage
                  ),
                  if (hasMax)
                    Text(
                      '${(pct * 100).round()}%',
                      style: tt.labelSmall?.copyWith(fontFamily: 'RobotoMono'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(String text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFE53935), size: 32),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
