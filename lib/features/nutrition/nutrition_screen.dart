import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});
  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  int _dayOffset = 0;   // 0=Hoje, -1=Ontem, 1=Amanhã…
  int _slideDir = 0;    // -1 esquerda→direita, +1 direita→esquerda

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
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Ação rápida "+" → abre a AddFoodScreen sem bottom nav
          context.push('/add-food');
        },
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // ===== Barra verde com setas + swipe + título centrado =====
          Container(
            color: cs.primary,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: SafeArea(
              bottom: false,
              child: GestureDetector(
                onHorizontalDragEnd: (d) {
                  final v = d.primaryVelocity ?? 0;
                  if (v > 120) _go(-1);
                  if (v < -120) _go(1);
                },
                child: Row(
                  children: [
                    SizedBox(
                      width: 48, height: 40,
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
                              position: Tween(begin: begin, end: Offset.zero).animate(anim),
                              child: FadeTransition(opacity: anim, child: child),
                            ),
                          );
                        },
                        child: Center(
                          key: ValueKey(_dayOffset),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: const ShapeDecoration(
                              color: Colors.white, shape: StadiumBorder(),
                            ),
                            child: Text(
                              _labelFor(context, _dayOffset),
                              style: tt.titleMedium?.copyWith(
                                color: cs.primary, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 48, height: 40,
                      child: _ArrowBtn(
                        icon: Icons.chevron_right_rounded,
                        onTap: () => _go(1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ===== Conteúdo do dia com SLIDE do ecrã inteiro =====
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) {
                final begin = Offset((_slideDir) * 0.25, 0);
                return ClipRect(
                  child: SlideTransition(
                    position: Tween(begin: begin, end: Offset.zero).animate(anim),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                );
              },
              child: _DayContent(key: ValueKey(_dayOffset)),
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
  const _DayContent({super.key});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return ScrollConfiguration(
      behavior: const _BounceScrollBehavior(),
      child: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        // só o essencial no fim (nada de espaço morto)
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 16),
        children: const [
          _MealSection(title: "Pequeno-almoço", calories: 0, items: []),
          SizedBox(height: 16),
          _MealSection(title: "Almoço", calories: 0, items: []),
          SizedBox(height: 16),
          _MealSection(title: "Lanche", calories: 0, items: []),
          SizedBox(height: 16),
          _MealSection(title: "Jantar", calories: 0, items: []),
          SizedBox(height: 16),
          _WaterCard(),
          SizedBox(height: 24),
          _BottomActions(),
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
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child; // sem glow
  }
}

/// --------- MEAL CARD ---------
class _MealSection extends StatefulWidget {
  final String title;
  final int calories;
  final List<String> items;

  const _MealSection({
    required this.title,
    required this.calories,
    required this.items,
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
          BoxShadow(blurRadius: 14, offset: Offset(0, 6), color: Color(0x14000000)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                        child: Icon(Icons.keyboard_arrow_down_rounded,
                            color: cs.onPrimary, size: 26),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // BODY branco (se expandido)
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              crossFadeState:
                  _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
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
                  // Abre a nova screen de adicionar alimento (passa a refeição como query param)
                  final meal = Uri.encodeComponent(widget.title);
                  context.push('/add-food?meal=$meal');
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
      final clr =
          onPrimaryContext ? cs.onPrimary.withValues(alpha: .9) : cs.onSurface.withValues(alpha: .7);
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
  void _applyDelta(int delta) => setState(() => ml = (ml + delta).clamp(0, 40000));

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
          BoxShadow(blurRadius: 14, offset: Offset(0, 6), color: Color(0x14000000)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                        child: Icon(Icons.keyboard_arrow_down_rounded,
                            color: cs.onPrimary, size: 26),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // BODY branco (apenas progress)
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              crossFadeState:
                  _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
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
                        backgroundColor: cs.outlineVariant.withValues(alpha: .4),
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
      padding: EdgeInsets.only(left: 16, right: 16, bottom: inset + 16, top: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Adicionar água",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
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
                      DropdownMenuItem(value: "L",  child: Text("L")),
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
              ButtonSegment(value: true,  label: Text("Subtrair")),
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
    const leafyGreen  = Color(0xFF66BB6A);

    return Column(
      children: [
        Row(
          children: const [
            Expanded(child: _TonalPill(icon: Icons.pie_chart_outline_rounded, label: "Nutrição")),
            SizedBox(width: 12),
            Expanded(child: _TonalPill(icon: Icons.note_alt_outlined, label: "Notas")),
          ],
        ),
        const SizedBox(height: 14),
        // CTA principal em gradiente + ícone branco
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(blurRadius: 18, offset: Offset(0, 10), color: Color(0x26000000)),
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
              onPressed: () {
                // TODO: finalizar dia
              },
              icon: const Icon(Icons.flag_circle_rounded, color: Colors.white),
              label: Text(
                "Acabar o dia",
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.white, // <- branco (substitui o preto)
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
        color: cs.surfaceContainerHighest, // tonal suave, sem borda dura
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 4),
            color: Color(0x12000000),
          )
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () {
          // TODO: abrir secção
        },
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
