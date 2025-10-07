import 'package:flutter/material.dart';
import '../../data/stats_api.dart';
import '../../core/widgets/macro_section_card.dart';

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
    });
    try {
      final s = await StatsApi.I.getDaily(date: _dayOffset == 0 ? null : _date);
      if (!mounted) return;
      setState(() {
        _stats = s;
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        title: Text('Nutrição',
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
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
          physics:
              const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // selector de dia
            Row(
              children: [
                IconButton.filled(
                  onPressed: () => _go(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: cs.surfaceContainerHighest,
                    foregroundColor: cs.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: ShapeDecoration(
                      color: cs.surfaceBright,
                      shape: const StadiumBorder(),
                      shadows: const [
                        BoxShadow(
                          blurRadius: 10,
                          spreadRadius: 0,
                          offset: Offset(0, 4),
                          color: Color.fromRGBO(0, 0, 0, 0.05),
                        )
                      ],
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
                  onPressed: () => _go(1),
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
                child:
                    Text(_error!, style: tt.bodyMedium?.copyWith(color: cs.error)),
              ),

            if (_stats != null) ...[
              MacroSectionCard(
                kcalUsed: _stats!.totals.kcal,
                kcalTarget: _stats!.goals.kcal ?? 0,
                proteinG: _stats!.totals.proteinG.toDouble(),
                proteinTargetG: (_stats!.goals.proteinG ?? 0).toDouble(),
                carbG: _stats!.totals.carbG.toDouble(),
                carbTargetG: (_stats!.goals.carbG ?? 0).toDouble(),
                fatG: _stats!.totals.fatG.toDouble(),
                fatTargetG: (_stats!.goals.fatG ?? 0).toDouble(),
                sugarsG: _stats!.totals.sugarsG.toDouble(),
                fiberG: _stats!.totals.fiberG.toDouble(),
                saltG: _stats!.totals.saltG.toDouble(),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}
