import 'package:flutter/material.dart';

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
    // sem intl — usa formatador nativo do Material
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

          // ===== Conteúdo do dia com SLIDE do ecrã inteiro (chave muda por dia) =====
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

// ---------- Widgets auxiliares ----------

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
    return ScrollConfiguration(
      behavior: const _BounceScrollBehavior(),
      child: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: const [
          _MealSection(title: "Pequeno-almoço", calories: 0, items: []),
          SizedBox(height: 16),
          _MealSection(title: "Almoço", calories: 0, items: []),
          SizedBox(height: 16),
          _MealSection(title: "Lanche", calories: 0, items: []),
          SizedBox(height: 16),
          _MealSection(title: "Jantar", calories: 0, items: []),
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

/// Card com header verde (título/kcal), corpo branco ao expandir
/// e **rodapé conectado** “Adicionar alimento” (tudo no MESMO card).
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

            // DIVISOR sutil a ligar body -> footer
            Container(
              height: 1,
              color: cs.outlineVariant.withValues(alpha: .5),
            ),

            // FOOTER conectado (CTA dentro do MESMO card)
            Material(
              color: Colors.white,
              child: InkWell(
                onTap: () {
                  // TODO: abrir fluxo "Adicionar alimento"
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
