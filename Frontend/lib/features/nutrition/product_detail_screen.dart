import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// NutriScore — ProductDetailScreen (v8)
/// - Kcal gigante no centro (não altera o donut)
/// - Chips de macros
/// - Dropdown de refeição
/// - Input de porções (decimais)
/// - Em “Informação adicional” fica APENAS “Informação nutricional”
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    // METADADOS
    required this.name,
    this.brand,
    this.origin, // ex.: "Portugal"
    required this.baseQuantityLabel, // ex.: "100 g" ou "1 un (18 g)"
    // NUTRIMENTOS por base (ex.: por 100 g ou por 1 un) — já escalados
    required this.kcalPerBase,
    required this.proteinGPerBase,
    required this.carbsGPerBase,
    required this.fatGPerBase,
    this.saltGPerBase,
    this.sugarsGPerBase,
    this.satFatGPerBase,
    this.fiberGPerBase,
    this.sodiumGPerBase,

    // EXTRA
    this.nutriScore, // "A".."E"
  });

  final String name;
  final String? brand;
  final String? origin;
  final String baseQuantityLabel;

  final int kcalPerBase;
  final double proteinGPerBase;
  final double carbsGPerBase;
  final double fatGPerBase;
  final double? saltGPerBase;
  final double? sugarsGPerBase;
  final double? satFatGPerBase;
  final double? fiberGPerBase;
  final double? sodiumGPerBase;

  final String? nutriScore;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  static const _meals = <String>[
    "Pequeno-almoço",
    "Almoço",
    "Lanche",
    "Jantar",
  ];
  String _selectedMeal = "Almoço";

  final TextEditingController _portionCtrl = TextEditingController(text: "1");
  double _portions = 1;

  @override
  void dispose() {
    _portionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final kcal = (widget.kcalPerBase * _portions).round();
    final protein = widget.proteinGPerBase * _portions;
    final carbs = widget.carbsGPerBase * _portions;
    final fat = widget.fatGPerBase * _portions;
    final salt = (widget.saltGPerBase ?? 0) * _portions;
    final sugar = (widget.sugarsGPerBase ?? 0) * _portions;
    final satFat = (widget.satFatGPerBase ?? 0) * _portions;
    final fiber = (widget.fiberGPerBase ?? 0) * _portions;
    final sodium = (widget.sodiumGPerBase ?? 0) * _portions;

    // kcal por macro (P=4, C=4, G=9) — apenas para o donut
    final pKcal = protein * 4;
    final cKcal = carbs * 4;
    final fKcal = fat * 9;
    final totalMacroKcal = pKcal + cKcal + fKcal;
    final scale = (totalMacroKcal > 0) ? (kcal / totalMacroKcal) : 1.0;

    final pKcalScaled = pKcal * scale;
    final cKcalScaled = cKcal * scale;
    final fKcalScaled = fKcal * scale;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            // HERO topo com voltar + título
            SliverToBoxAdapter(
              child: _HeroTopBar(
                title: "Detalhe do alimento",
                onBack: () => context.pop(),
              ),
            ),
            SliverToBoxAdapter(
              child: ClipPath(
                clipper: _TopCurveClipper(),
                child: Container(height: 16, color: cs.surface),
              ),
            ),

            // Card com nome + meta + NutriScore
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              sliver: SliverToBoxAdapter(
                child: _InfoCard(
                  title: widget.name,
                  subtitle: [
                    if (widget.brand?.isNotEmpty == true) widget.brand!,
                    if (widget.origin?.isNotEmpty == true) widget.origin!,
                    widget.baseQuantityLabel,
                  ].where((s) => s.isNotEmpty).join(" • "),
                  nutriScore: widget.nutriScore,
                ),
              ),
            ),

            // Donut + chips + controlos
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: .35),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // DONUT – kcal gigante no centro
                      SizedBox.square(
                        dimension: 260,
                        child: _MacroDonut(
                          totalKcal: kcal.toDouble(),
                          proteinKcal: pKcalScaled,
                          carbsKcal: cKcalScaled,
                          fatKcal: fKcalScaled,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Chips macro
                      Row(
                        children: [
                          Expanded(
                            child: _chipMetric(
                              context,
                              "Proteína",
                              "${protein.toStringAsFixed(1)} g",
                              dotColor: cs.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _chipMetric(
                              context,
                              "Hidratos",
                              "${carbs.toStringAsFixed(1)} g",
                              dotColor: cs.secondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _chipMetric(
                              context,
                              "Gordura",
                              "${fat.toStringAsFixed(1)} g",
                              dotColor: cs.error,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      _MealDropdown(
                        value: _selectedMeal,
                        onChanged: (v) => setState(() => _selectedMeal = v),
                      ),
                      const SizedBox(height: 12),

                      _PortionInput(
                        controller: _portionCtrl,
                        baseLabel: widget.baseQuantityLabel,
                        onChanged: (val) => setState(() => _portions = val),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Informação adicional — APENAS Informação nutricional
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Informação adicional",
                      style: tt.titleMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),

                    _ExpandableInfo(
                      title: "Informação nutricional",
                      body: "",
                      childBuilder: (_) => _NutritionInfo(
                        baseLabel: widget.baseQuantityLabel,
                        kcal: kcal,
                        protein: protein,
                        carbs: carbs,
                        sugars:
                            (widget.sugarsGPerBase != null) ? sugar : null,
                        fat: fat,
                        satFat:
                            (widget.satFatGPerBase != null) ? satFat : null,
                        fiber: (widget.fiberGPerBase != null) ? fiber : null,
                        salt: (widget.saltGPerBase != null) ? salt : null,
                        sodium:
                            (widget.sodiumGPerBase != null) ? sodium : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // CTA
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: () => context.pop(),
              child: Text("Adicionar ao $_selectedMeal"),
            ),
          ),
        ),
      ),
    );
  }

  // Helpers UI
  Widget _chipMetric(
    BuildContext context,
    String label,
    String value, {
    required Color dotColor,
  }) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: tt.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/* ========================= HERO ========================= */

class _HeroTopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  const _HeroTopBar({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                IconButton(
                  tooltip: "Voltar",
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: cs.onPrimary,
                  onPressed: onBack,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      title,
                      style: tt.titleLarge?.copyWith(
                        color: cs.onPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/* =================== WIDGETS SECUNDÁRIOS =================== */

class _InfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? nutriScore;
  const _InfoCard({
    required this.title,
    required this.subtitle,
    this.nutriScore,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Color nutriColor(String g) {
      switch (g.toUpperCase()) {
        case "A":
          return const Color(0xFF4CAF6D); // Fresh Green
        case "B":
          return const Color(0xFF66BB6A); // Leafy Green
        case "C":
          return const Color(0xFFFFC107); // Golden Amber
        case "D":
          return const Color(0xFFFF8A4C); // Warm Tangerine
        case "E":
          return const Color(0xFFE53935); // Ripe Red
        default:
          return cs.primary;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tt.titleMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if ((nutriScore ?? "").isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: nutriColor(nutriScore!).withValues(alpha: .12),
                border: Border.all(
                  color: nutriColor(nutriScore!).withValues(alpha: .35),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "NutriScore ${nutriScore!.toUpperCase()}",
                style: tt.labelMedium?.copyWith(
                  color: nutriColor(nutriScore!),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/* =================== DROPDOWN REFEIÇÃO =================== */

class _MealDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _MealDropdown({required this.value, required this.onChanged});

  static const _meals = <String>[
    "Pequeno-almoço",
    "Almoço",
    "Lanche",
    "Jantar",
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(999),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.expand_more_rounded),
          borderRadius: BorderRadius.circular(12),
          items: _meals
              .map(
                (m) => DropdownMenuItem<String>(
                  value: m,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      m,
                      style: tt.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

/* =================== INPUT PORÇÕES =================== */

class _PortionInput extends StatelessWidget {
  final TextEditingController controller;
  final String baseLabel;
  final ValueChanged<double> onChanged;
  const _PortionInput({
    required this.controller,
    required this.baseLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            "Porções • $baseLabel",
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          width: 96,
          child: TextField(
            controller: controller,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*([.,]\d*)?$')),
            ],
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (raw) {
              final txt = raw.replaceAll(',', '.');
              final v = double.tryParse(txt);
              onChanged(v == null || v <= 0 ? 1 : v);
            },
          ),
        ),
      ],
    );
  }
}

/* =================== EXPANDABLE INFO =================== */

class _ExpandableInfo extends StatefulWidget {
  final String title;
  final String body;
  final WidgetBuilder? childBuilder;
  const _ExpandableInfo({
    required this.title,
    required this.body,
    this.childBuilder,
  });

  @override
  State<_ExpandableInfo> createState() => _ExpandableInfoState();
}

class _ExpandableInfoState extends State<_ExpandableInfo> {
  bool _open = true; // já abre expandido — opcional
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final hasCustom = widget.childBuilder != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            title: Text(
              widget.title,
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            trailing: Icon(
              _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            ),
            onTap: () => setState(() => _open = !_open),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: hasCustom
                  ? Builder(builder: widget.childBuilder!)
                  : Text(
                      widget.body,
                      style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                    ),
            ),
            crossFadeState:
                _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 160),
          ),
        ],
      ),
    );
  }
}

/* =============== INFO NUTRICIONAL (tabela) =============== */

class _NutritionInfo extends StatelessWidget {
  final String baseLabel;
  final int kcal;
  final double protein;
  final double carbs;
  final double? sugars;
  final double fat;
  final double? satFat;
  final double? fiber;
  final double? salt;
  final double? sodium;

  const _NutritionInfo({
    required this.baseLabel,
    required this.kcal,
    required this.protein,
    required this.carbs,
    this.sugars,
    required this.fat,
    this.satFat,
    this.fiber,
    this.salt,
    this.sodium,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final rows = <_NutriRow>[
      _NutriRow("Energia", "$kcal kcal"),
      _NutriRow("Proteína", "${protein.toStringAsFixed(1)} g"),
      _NutriRow("Hidratos de carbono", "${carbs.toStringAsFixed(1)} g"),
      if (sugars != null)
        _NutriRow("Açúcares", "${sugars!.toStringAsFixed(1)} g"),
      _NutriRow("Gordura", "${fat.toStringAsFixed(1)} g"),
      if (satFat != null)
        _NutriRow("Gordura saturada", "${satFat!.toStringAsFixed(1)} g"),
      if (fiber != null) _NutriRow("Fibra", "${fiber!.toStringAsFixed(1)} g"),
      if (salt != null) _NutriRow("Sal", "${salt!.toStringAsFixed(2)} g"),
      if (sodium != null)
        _NutriRow("Sódio", "${sodium!.toStringAsFixed(2)} g"),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Valores por $baseLabel (x porções aplicadas)",
          style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: .25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            children: rows
                .map((r) => _NutriRowWidget(label: r.label, value: r.value))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _NutriRow {
  final String label;
  final String value;
  _NutriRow(this.label, this.value);
}

class _NutriRowWidget extends StatelessWidget {
  final String label;
  final String value;
  const _NutriRowWidget({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: .6)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: tt.bodyMedium?.copyWith(color: cs.onSurface),
            ),
          ),
          Text(
            value,
            style: tt.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/* =================== DONUT =================== */

class _MacroDonut extends StatelessWidget {
  const _MacroDonut({
    required this.totalKcal,
    required this.proteinKcal,
    required this.carbsKcal,
    required this.fatKcal,
  });

  final double totalKcal;
  final double proteinKcal;
  final double carbsKcal;
  final double fatKcal;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final proteinColor = cs.primary;
    final carbsColor = cs.secondary;
    final fatColor = cs.error;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (_, t, __) {
        return CustomPaint(
          painter: _DonutPainter(
            progress: t,
            proteinKcal: proteinKcal,
            carbsKcal: carbsKcal,
            fatKcal: fatKcal,
            proteinColor: proteinColor,
            carbsColor: carbsColor,
            fatColor: fatColor,
          ),
          child: LayoutBuilder(
            builder: (_, c) {
              final s = math.min(c.maxWidth, c.maxHeight);
              return Center(
                child: _KcalBig(totalKcal.round(), fontSize: s * 0.26),
              );
            },
          ),
        );
      },
    );
  }
}

class _KcalBig extends StatelessWidget {
  final int kcal;
  final double fontSize;
  const _KcalBig(this.kcal, {this.fontSize = 56});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 4),
            color: Color(0x0D000000),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$kcal",
            style: tt.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.0,
              fontSize: fontSize,
            ),
          ),
          Text(
            "kcal",
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.progress,
    required this.proteinKcal,
    required this.carbsKcal,
    required this.fatKcal,
    required this.proteinColor,
    required this.carbsColor,
    required this.fatColor,
  });

  final double progress;
  final double proteinKcal;
  final double carbsKcal;
  final double fatKcal;
  final Color proteinColor;
  final Color carbsColor;
  final Color fatColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 8;

    // fundo do donut
    final background = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..color = const Color(0x11000000);
    canvas.drawCircle(center, radius, background);

    final total = proteinKcal + carbsKcal + fatKcal;
    if (total <= 0) return;

    final stroke = 22.0;
    double start = -math.pi / 2;

    void drawSeg(double value, Color color) {
      final sweep = (value / total) * 2 * math.pi * progress;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke
        ..color = color.withValues(alpha: .95);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
      start += sweep;
    }

    drawSeg(proteinKcal, proteinColor);
    drawSeg(carbsKcal, carbsColor);
    drawSeg(fatKcal, fatColor);
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.progress != progress ||
      old.proteinKcal != proteinKcal ||
      old.carbsKcal != carbsKcal ||
      old.fatKcal != fatKcal ||
      old.proteinColor != proteinColor ||
      old.carbsColor != carbsColor ||
      old.fatColor != fatColor;
}

/* ========================= UTIL ========================= */

class _TopCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final p = Path();
    p.lineTo(0, 0);
    p.lineTo(0, size.height);
    p.quadraticBezierTo(
      size.width * 0.5,
      -size.height,
      size.width,
      size.height,
    );
    p.lineTo(size.width, 0);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
