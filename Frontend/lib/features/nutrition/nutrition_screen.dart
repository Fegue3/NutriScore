import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ⬇️ usa o CalorieApi que lê o token do AuthStorage automaticamente
import '../../data/calorie_api.dart'; // <-- ajusta o caminho conforme o teu projeto

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});
  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  // ===== Estado de navegação por dia =====
  int _dayOffset = 0; // 0=Hoje, -1=Ontem, 1=Amanhã…
  int _slideDir = 0; // -1 esquerda→direita, +1 direita→esquerda

  // ===== Calorias (local) =====
  final int _fallbackDailyGoal = 2200; // Meta fallback (até vir do backend)
  final Map<String, int> _mealCalories = {
    "Pequeno-almoço": 0,
    "Almoço": 0,
    "Lanche": 0,
    "Jantar": 0,
  };

  // ===== Calorias (vindas do backend) =====
  int? _dailyGoalFromApi;
  int? _consumedFromApi;
  bool _loading = false;
  String? _error;

  int get _localConsumed =>
      _mealCalories.values.fold<int>(0, (sum, v) => sum + v);

  int get _goal => _dailyGoalFromApi ?? _fallbackDailyGoal;
  int get _consumed => _consumedFromApi ?? _localConsumed;

  @override
  void initState() {
    super.initState();
    _fetchForOffset(0);
  }

  Future<void> _fetchForOffset(int offset) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final date = DateTime.now().add(Duration(days: offset));
      final result = await CalorieApi.I.getDaily(
        date: offset == 0 ? null : date,
      );
      if (!mounted) return;
      setState(() {
        _dailyGoalFromApi = result.targetCalories;
        _consumedFromApi = result.consumedCalories;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Falha ao carregar calorias: $e';
        _loading = false;
      });
    }
  }

  String _labelFor(BuildContext ctx, int off) {
    if (off == 0) return "Hoje";
    if (off == -1) return "Ontem";
    if (off == 1) return "Amanhã";
    final d = DateTime.now().add(Duration(days: off));
    return MaterialLocalizations.of(ctx).formatMediumDate(d);
  }

  void _go(int delta) {
    if (delta == 0) return;
    setState(() {
      _slideDir = delta > 0 ? 1 : -1;
      _dayOffset += delta;
    });
    _fetchForOffset(_dayOffset);
  }

  // Disponível quando integrares o fluxo “Adicionar alimento”
  // ignore: unused_element
  void _setMealCalories(String meal, int kcal) {
    if (!_mealCalories.containsKey(meal)) return;
    setState(() => _mealCalories[meal] = kcal.clamp(0, 100000));
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
        title: Text(
          "Diário das Calorias",
          style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_loading)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary,
                ),
              ),
            ),
          if (_error != null)
            IconButton(
              onPressed: () => _fetchForOffset(_dayOffset),
              tooltip: 'Tentar de novo',
              icon: Icon(Icons.refresh, color: cs.error),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/add-food');
        },
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // ===== HERO VERDE (setas + data + resumo de calorias) =====
          Container(
            color: cs.primary,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  GestureDetector(
                    onHorizontalDragEnd: (d) {
                      final v = d.primaryVelocity ?? 0;
                      if (v > 120) _go(-1);
                      if (v < -120) _go(1);
                    },
                    child: Row(
                      children: [
                        SizedBox(
                          width: 48,
                          height: 40,
                          child: _ArrowBtn(
                            icon: Icons.chevron_left_rounded,
                            onTap: () => _go(-1),
                          ),
                        ),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 240),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, anim) {
                              final begin = Offset((_slideDir) * 0.25, 0);
                              return ClipRect(
                                child: SlideTransition(
                                  position: Tween(
                                    begin: begin,
                                    end: Offset.zero,
                                  ).animate(anim),
                                  child: FadeTransition(
                                    opacity: anim,
                                    child: child,
                                  ),
                                ),
                              );
                            },
                            child: Center(
                              key: ValueKey(_dayOffset),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: const ShapeDecoration(
                                  color: Colors.white,
                                  shape: StadiumBorder(),
                                ),
                                child: Text(
                                  _labelFor(context, _dayOffset),
                                  style: tt.titleMedium?.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 48,
                          height: 40,
                          child: _ArrowBtn(
                            icon: Icons.chevron_right_rounded,
                            onTap: () => _go(1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // --- Resumo de calorias (compacto, sem ícones) ---
                  _CalorieSummaryConnectedCompact(
                    goal: _goal,
                    consumed: _consumed,
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onPrimary.withValues(alpha: .9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ===== Conteúdo do dia =====
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) {
                final begin = Offset((_slideDir) * 0.25, 0);
                return ClipRect(
                  child: SlideTransition(
                    position: Tween(
                      begin: begin,
                      end: Offset.zero,
                    ).animate(anim),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                );
              },
              child: _DayContent(
                key: ValueKey(_dayOffset),
                goal: _goal,
                consumed: _consumed,
                mealCalories: _mealCalories,
                onTapAddFood: (mealTitle) {
                  final meal = Uri.encodeComponent(mealTitle);
                  context.push('/add-food?meal=$meal');
                },
                // onCaloriesUpdated: _setMealCalories,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Auxiliares ----------

class _ArrowBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ArrowBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton.filled(
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: cs.onPrimary.withValues(alpha: .90),
        foregroundColor: cs.primary,
        padding: EdgeInsets.zero,
      ),
      icon: Icon(icon, size: 26),
    );
  }
}

class _DayContent extends StatelessWidget {
  final int goal;
  final int consumed;
  final Map<String, int> mealCalories;
  final void Function(String mealTitle)? onTapAddFood;

  const _DayContent({
    super.key,
    required this.goal,
    required this.consumed,
    required this.mealCalories,
    this.onTapAddFood,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return ScrollConfiguration(
      behavior: const _BounceScrollBehavior(),
      child: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 16),
        children: [
          _MealSection(
            title: "Pequeno-almoço",
            calories: mealCalories["Pequeno-almoço"] ?? 0,
            items: const [],
            onAddTap: () => onTapAddFood?.call("Pequeno-almoço"),
          ),
          const SizedBox(height: 16),
          _MealSection(
            title: "Almoço",
            calories: mealCalories["Almoço"] ?? 0,
            items: const [],
            onAddTap: () => onTapAddFood?.call("Almoço"),
          ),
          const SizedBox(height: 16),
          _MealSection(
            title: "Lanche",
            calories: mealCalories["Lanche"] ?? 0,
            items: const [],
            onAddTap: () => onTapAddFood?.call("Lanche"),
          ),
          const SizedBox(height: 16),
          _MealSection(
            title: "Jantar",
            calories: mealCalories["Jantar"] ?? 0,
            items: const [],
            onAddTap: () => onTapAddFood?.call("Jantar"),
          ),
          const SizedBox(height: 16),
          const _WaterCard(),
          const SizedBox(height: 24),
          const _BottomActions(),
        ],
      ),
    );
  }
}

class _BounceScrollBehavior extends ScrollBehavior {
  const _BounceScrollBehavior();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child; // sem glow
  }
}

/// --------- CALORIE SUMMARY (conectado, compacto e sem ícones) ---------
class _CalorieSummaryConnectedCompact extends StatelessWidget {
  final int goal;
  final int consumed;
  const _CalorieSummaryConnectedCompact({
    required this.goal,
    required this.consumed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final remaining = goal - consumed;
    final ok = remaining >= 0;

    final onP = cs.onPrimary;
    final dividerColor = onP.withValues(alpha: .22);

    // Segmento compacto (sem ícone)
    Widget seg({
      required String label,
      required String value,
      Color? valueColor,
    }) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // rótulo em "chip" pequeno
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: onP.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.labelSmall?.copyWith(
                    color: onP,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .2,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // valor: adapta escala para caber no terço disponível
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: tt.titleMedium?.copyWith(
                    color: valueColor ?? onP,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 70, // mais baixo para garantir espaço
        child: Stack(
          children: [
            // Fundo
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: onP.withValues(alpha: .14),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 10,
                      offset: Offset(0, 4),
                      color: Color(0x22000000),
                    ),
                  ],
                ),
              ),
            ),
            // Conteúdo (3 partes iguais)
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                seg(label: "Meta", value: "$goal kcal"),
                seg(label: "Consumidas", value: "$consumed kcal"),
                seg(
                  label: "Restantes",
                  value: "${remaining.abs()} kcal",
                  valueColor: ok ? onP : cs.error,
                ),
              ],
            ),
            // Divisórias desenhadas (não ocupam largura)
            Positioned.fill(
              child: CustomPaint(
                painter: _VerticalDividersPainter(
                  color: dividerColor,
                  count: 2,
                  topPad: 8,
                  bottomPad: 8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// pinta N divisórias verticais igualmente espaçadas, sem ocupar largura
class _VerticalDividersPainter extends CustomPainter {
  final Color color;
  final int count;
  final double topPad;
  final double bottomPad;
  const _VerticalDividersPainter({
    required this.color,
    this.count = 2,
    this.topPad = 10,
    this.bottomPad = 10,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (var i = 1; i <= count; i++) {
      final x = size.width * i / (count + 1);
      final alignedX = x.floorToDouble() + 0.5; // alinhado ao pixel
      canvas.drawLine(
        Offset(alignedX, topPad),
        Offset(alignedX, size.height - bottomPad),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VerticalDividersPainter old) =>
      old.color != color ||
      old.count != count ||
      old.topPad != topPad ||
      old.bottomPad != bottomPad;
}

/// --------- MEAL CARD ---------
class _MealSection extends StatefulWidget {
  final String title;
  final int calories;
  final List<String> items;
  final VoidCallback? onAddTap;

  const _MealSection({
    required this.title,
    required this.calories,
    required this.items,
    this.onAddTap,
  });

  @override
  State<_MealSection> createState() => _MealSectionState();
}

class _MealSectionState extends State<_MealSection> {
  bool _expanded = false;
  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            offset: Offset(0, 6),
            color: Color(0x14000000),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // HEADER verde
            Material(
              color: cs.primary,
              child: InkWell(
                onTap: _toggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: tt.titleLarge?.copyWith(
                            color: cs.onPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: ShapeDecoration(
                          color: cs.onPrimary.withValues(alpha: 0.15),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          "${widget.calories} kcal",
                          style: tt.titleMedium?.copyWith(
                            color: cs.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 160),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: cs.onPrimary,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // BODY branco (se expandido)
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              crossFadeState: _expanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: _ItemsList(
                  items: widget.items,
                  centerWhenEmpty: true,
                  onPrimaryContext: false,
                ),
              ),
              secondChild: const SizedBox.shrink(),
            ),

            // Divisor sutil → desaparece quando expandes
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 1,
              color: Colors.black.withValues(alpha: _expanded ? 0.0 : 0.06),
            ),

            // FOOTER ligado (CTA dentro do mesmo card)
            Material(
              color: Colors.white,
              child: InkWell(
                onTap: () {
                  if (widget.onAddTap != null) {
                    widget.onAddTap!();
                  } else {
                    final meal = Uri.encodeComponent(widget.title);
                    context.push('/add-food?meal=$meal');
                  }
                },
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Text(
                      "Adicionar alimento",
                      style: tt.titleMedium?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemsList extends StatelessWidget {
  final List<String> items;
  final bool centerWhenEmpty;
  final bool onPrimaryContext; // true => texto branco; false => onSurface
  const _ItemsList({
    required this.items,
    this.centerWhenEmpty = false,
    this.onPrimaryContext = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (items.isEmpty) {
      final clr = onPrimaryContext
          ? cs.onPrimary.withValues(alpha: .9)
          : cs.onSurface.withValues(alpha: .7);
      final text = Text(
        "Sem itens adicionados.",
        style: tt.bodyMedium?.copyWith(color: clr, fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
      );
      return centerWhenEmpty ? Center(child: text) : text;
    }

    final clr = onPrimaryContext ? cs.onPrimary : cs.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final t in items)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text("• $t", style: tt.bodyMedium?.copyWith(color: clr)),
          ),
      ],
    );
  }
}

/// --------- ÁGUA (header + progress + footer "Adicionar água" com bottom-sheet) ---------
class _WaterCard extends StatefulWidget {
  const _WaterCard();

  @override
  State<_WaterCard> createState() => _WaterCardState();
}

class _WaterCardState extends State<_WaterCard> {
  int ml = 0;
  final int goal = 2000;
  bool _expanded = true;

  void _toggle() => setState(() => _expanded = !_expanded);
  void _applyDelta(int delta) =>
      setState(() => ml = (ml + delta).clamp(0, 40000));

  Future<void> _openCustomAmountSheet() async {
    final res = await showModalBottomSheet<_CustomAmountResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _CustomAmountSheet(),
    );
    if (res != null && res.valueMl > 0) {
      _applyDelta(res.isSubtract ? -res.valueMl : res.valueMl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final progress = (ml / goal).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            offset: Offset(0, 6),
            color: Color(0x14000000),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // HEADER verde
            Material(
              color: cs.primary,
              child: InkWell(
                onTap: _toggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Água",
                          style: tt.titleLarge?.copyWith(
                            color: cs.onPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: ShapeDecoration(
                          color: cs.onPrimary.withValues(alpha: 0.15),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          "${ml ~/ 100}dl / ${goal ~/ 100}dl",
                          style: tt.titleMedium?.copyWith(
                            color: cs.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 160),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: cs.onPrimary,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // BODY branco (apenas progress)
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              crossFadeState: _expanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 12,
                        backgroundColor: cs.outlineVariant.withValues(
                          alpha: .4,
                        ),
                        valueColor: AlwaysStoppedAnimation(cs.primary),
                      ),
                    ),
                  ],
                ),
              ),
              secondChild: const SizedBox.shrink(),
            ),

            // FOOTER “Adicionar água” (abre bottom-sheet)
            Material(
              color: Colors.white,
              child: InkWell(
                onTap: _openCustomAmountSheet,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Text(
                      "Adicionar água",
                      style: tt.titleMedium?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// --------- Bottom sheet: quantidade + unidade + Somar/Subtrair ---------
class _CustomAmountSheet extends StatefulWidget {
  const _CustomAmountSheet();

  @override
  State<_CustomAmountSheet> createState() => _CustomAmountSheetState();
}

class _CustomAmountSheetState extends State<_CustomAmountSheet> {
  final _controller = TextEditingController(text: "250");
  String _unit = "ml";
  bool _subtract = false;

  int get _valueMl {
    final raw = int.tryParse(_controller.text.trim()) ?? 0;
    switch (_unit) {
      case "dl":
        return raw * 100;
      case "L":
      case "l":
        return raw * 1000;
      default:
        return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final inset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: inset + 16,
        top: 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Adicionar água",
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Quantidade",
                    hintText: "ex.: 350",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButtonHideUnderline(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButton<String>(
                    value: _unit,
                    items: const [
                      DropdownMenuItem(value: "ml", child: Text("ml")),
                      DropdownMenuItem(value: "dl", child: Text("dl")),
                      DropdownMenuItem(value: "L", child: Text("L")),
                    ],
                    onChanged: (v) => setState(() => _unit = v ?? "ml"),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text("Somar")),
              ButtonSegment(value: true, label: Text("Subtrair")),
            ],
            selected: {_subtract},
            onSelectionChanged: (s) => setState(() => _subtract = s.first),
            style: ButtonStyle(
              side: WidgetStatePropertyAll(BorderSide(color: cs.primary)),
            ),
          ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(
                _CustomAmountResult(valueMl: _valueMl, isSubtract: _subtract),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(vertical: 14),
                foregroundColor: Colors.white,
              ),
              child: const Text("Aplicar"),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomAmountResult {
  final int valueMl;
  final bool isSubtract;
  const _CustomAmountResult({required this.valueMl, required this.isSubtract});
}

/// --------- AÇÕES FINAIS (pills tonais + CTA em gradiente) ---------
class _BottomActions extends StatelessWidget {
  const _BottomActions();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Gradiente Fresh Green (#4CAF6D) → Leafy Green (#66BB6A)
    const freshGreen = Color(0xFF4CAF6D);
    const leafyGreen = Color(0xFF66BB6A);

    return Column(
      children: [
        Row(
          children: const [
            Expanded(
              child: _TonalPill(
                icon: Icons.pie_chart_outline_rounded,
                label: "Nutrição",
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _TonalPill(icon: Icons.note_alt_outlined, label: "Notas"),
            ),
          ],
        ),
        const SizedBox(height: 14),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                blurRadius: 18,
                offset: Offset(0, 10),
                color: Color(0x26000000),
              ),
            ],
            gradient: const LinearGradient(
              colors: [freshGreen, leafyGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.flag_circle_rounded, color: Colors.white),
              label: Text(
                "Acabar o dia",
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: const StadiumBorder(),
                foregroundColor: cs.onPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TonalPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TonalPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 4),
            color: Color(0x12000000),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () {},
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: cs.onSurface.withValues(alpha: .85)),
            const SizedBox(width: 8),
            Text(
              label,
              style: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
