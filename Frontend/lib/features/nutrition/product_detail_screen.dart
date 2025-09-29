// lib/features/nutrition/product_detail_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../data/meals_api.dart';
import '../../data/products_api.dart'; // cliente dos endpoints /api/products/*

/// NutriScore — ProductDetailScreen (v9.3)
/// - Usa ProductsApi.I.getByBarcode(barcode)
/// - Usa ProductsApi.I.toggleFavorite(barcode)
/// - Grava refeição via MealsApi.I.add(...)
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,

    // Preferencialmente usar barcode para fetch
    this.barcode,

    // Fallbacks (usados se não houver barcode)
    this.name,
    this.brand,
    this.origin,
    this.baseQuantityLabel,

    // Nutrimentos por base
    this.kcalPerBase,
    this.proteinGPerBase,
    this.carbsGPerBase,
    this.fatGPerBase,
    this.saltGPerBase,
    this.sugarsGPerBase,
    this.satFatGPerBase,
    this.fiberGPerBase,
    this.sodiumGPerBase,

    // Extra
    this.nutriScore,
    this.initialMeal,
    this.date,
  });

  final String? barcode;

  final String? name;
  final String? brand;
  final String? origin;
  final String? baseQuantityLabel;

  final int? kcalPerBase;
  final double? proteinGPerBase;
  final double? carbsGPerBase;
  final double? fatGPerBase;
  final double? saltGPerBase;
  final double? sugarsGPerBase;
  final double? satFatGPerBase;
  final double? fiberGPerBase;
  final double? sodiumGPerBase;

  final String? nutriScore;
  final MealType? initialMeal;
  final DateTime? date;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late MealType _selectedMeal;

  final TextEditingController _portionCtrl = TextEditingController(text: "1");
  double _portions = 1;

  bool _loading = false;
  bool _favorited = false;

  // estado do produto
  String? _name;
  String? _brand;
  String? _origin;
  String _baseLabel = "100 g";
  String? _nutri;

  int _kcalBase = 0;
  double _p = 0,
      _c = 0,
      _f = 0,
      _salt = 0,
      _sugar = 0,
      _sat = 0,
      _fiber = 0,
      _sodium = 0;

  @override
  void initState() {
    super.initState();
    _selectedMeal = widget.initialMeal ?? MealType.breakfast;
    _hydrateWithFallback();
    _maybeFetch();
  }

  void _hydrateWithFallback() {
    _name = widget.name;
    _brand = widget.brand;
    _origin = widget.origin;
    _baseLabel = widget.baseQuantityLabel ?? _baseLabel;
    _nutri = widget.nutriScore;

    _kcalBase = widget.kcalPerBase ?? _kcalBase;
    _p = widget.proteinGPerBase ?? _p;
    _c = widget.carbsGPerBase ?? _c;
    _f = widget.fatGPerBase ?? _f;
    _salt = widget.saltGPerBase ?? _salt;
    _sugar = widget.sugarsGPerBase ?? _sugar;
    _sat = widget.satFatGPerBase ?? _sat;
    _fiber = widget.fiberGPerBase ?? _fiber;
    _sodium = widget.sodiumGPerBase ?? _sodium;
  }

  Future<void> _maybeFetch() async {
    final bc = widget.barcode;
    if (bc == null || bc.isEmpty) return;

    setState(() => _loading = true);
    try {
      final d = await ProductsApi.I.getByBarcode(bc);
      if (!mounted) return;

      final hasServ = d.kcalServ != null && d.kcalServ! > 0;

      setState(() {
        _name = d.name;
        _brand = d.brand;
        _origin = (d.origin ?? '').split(',').first.trim().isEmpty
            ? null
            : d.origin;
        _nutri = d.nutriScore;

        // ===== derivar label base + kcal base com precisão =====
        final rawServ = (d.servingSize ?? '').trim(); // ex.: "41,5 g", "330 ml"
        final rawQty = (d.quantity ?? '')
            .trim(); // ex.: "100 g", "100 ml", "500 g"
        final hasServLabel = rawServ.isNotEmpty;

        // tenta extrair número+unidade da string (g|ml)
        num? extractQty(String s, String unit) {
          final m = RegExp(
            r'(\d+(?:[.,]\d+)?)\s*' + unit + r'\b',
            caseSensitive: false,
          ).firstMatch(s.toLowerCase());
          if (m == null) return null;
          return num.tryParse(m.group(1)!.replaceAll(',', '.'));
        }

        final servG = extractQty(rawServ, 'g');
        final servMl = extractQty(rawServ, 'ml');
        final qtyG = extractQty(rawQty, 'g');
        final qtyMl = extractQty(rawQty, 'ml');

        // 1) Se houver info de porção → usar porção
        if (hasServLabel && (servG != null || servMl != null)) {
          _baseLabel = rawServ; // ex.: "41,5 g" ou "330 ml"
          if (d.kcalServ != null && d.kcalServ! > 0) {
            _kcalBase = d.kcalServ!;
          } else if (servG != null && d.kcal100g != null) {
            _kcalBase = ((d.kcal100g! * servG) / 100).round();
          } else if (servMl != null && d.kcal100g != null) {
            _kcalBase = ((d.kcal100g! * servMl) / 100).round();
          } else {
            _kcalBase = d.kcal100g ?? _kcalBase; // fallback
          }
        }
        // 2) Caso contrário, usar quantity (100 g / 100 ml, ou outro)
        else if (qtyG != null || qtyMl != null) {
          _baseLabel = rawQty; // ex.: "100 g", "100 ml", "500 g"
          if (qtyG != null && d.kcal100g != null) {
            _kcalBase = ((d.kcal100g! * qtyG) / 100).round();
          } else if (qtyMl != null && d.kcal100g != null) {
            _kcalBase = ((d.kcal100g! * qtyMl) / 100).round();
          } else {
            _kcalBase = d.kcal100g ?? _kcalBase; // fallback
          }
        }
        // 3) Último recurso: manter anteriores
        else {
          _baseLabel = _baseLabel; // mantém o que já vinha de fallback
          _kcalBase = d.kcal100g ?? _kcalBase;
        }

        _p = (hasServ ? d.proteinServ : d.protein100g) ?? _p;
        _c = (hasServ ? d.carbsServ : d.carbs100g) ?? _c;
        _f = (hasServ ? d.fatServ : d.fat100g) ?? _f;
        _salt = (hasServ ? d.saltServ : d.salt100g) ?? _salt;
        _sugar = (hasServ ? d.sugarsServ : d.sugars100g) ?? _sugar;
        _sat = (hasServ ? d.satFatServ : d.satFat100g) ?? _sat;
        _fiber = (hasServ ? d.fiberServ : d.fiber100g) ?? _fiber;
        _sodium = (hasServ ? d.sodiumServ : d.sodium100g) ?? _sodium;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _portionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final kcal = (_kcalBase * _portions).round();
    final protein = _p * _portions;
    final carbs = _c * _portions;
    final fat = _f * _portions;
    final salt = _salt * _portions;
    final sugar = _sugar * _portions;
    final satFat = _sat * _portions;
    final fiber = _fiber * _portions;
    final sodium = _sodium * _portions;

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
            // HERO topo com voltar + favorito
            SliverToBoxAdapter(
              child: Container(
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
                            onPressed: () => context.pop(),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                "Detalhe do alimento",
                                style: tt.titleLarge?.copyWith(
                                  color: cs.onPrimary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: "Favorito",
                            icon: Icon(
                              _favorited
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: cs.onPrimary,
                            ),
                            onPressed: (widget.barcode == null)
                                ? null
                                : () async {
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    try {
                                      final fav = await ProductsApi.I
                                          .toggleFavorite(widget.barcode!);
                                      if (!mounted) return;
                                      setState(() => _favorited = fav);
                                    } catch (e) {
                                      if (!mounted) return;
                                      messenger.showSnackBar(
                                        SnackBar(content: Text(e.toString())),
                                      );
                                    }
                                  },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
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
                  title: _name ?? 'Produto',
                  subtitle: [
                    if ((_brand ?? '').isNotEmpty) _brand!,
                    if ((_origin ?? '').isNotEmpty) _origin!,
                    _baseLabel,
                  ].where((s) => s.isNotEmpty).join(" • "),
                  nutriScore: _nutri,
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
                      if (_loading)
                        const SizedBox(
                          height: 220,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else
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
                        baseLabel: _baseLabel,
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
                        baseLabel: _baseLabel,
                        kcal: kcal,
                        protein: protein,
                        carbs: carbs,
                        sugars: _sugar > 0 ? sugar : null,
                        fat: fat,
                        satFat: _sat > 0 ? satFat : null,
                        fiber: _fiber > 0 ? fiber : null,
                        salt: _salt > 0 ? salt : null,
                        sodium: _sodium > 0 ? sodium : null,
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
              onPressed: (widget.barcode == null)
                  ? null
                  : () async {
                      try {
                        // Aceita "100 g", "125 g", "330 ml", "1 porção", etc.
                        final base = _baseLabel.toLowerCase().trim();

                        // Tenta apanhar um número + unidade (g|ml)
                        final match = RegExp(
                          r'(\d+(?:[.,]\d+)?)\s*(g|ml)\b',
                        ).firstMatch(base);

                        num? qGrams;
                        num? qMl;
                        num? qServ;

                        if (match != null) {
                          final n =
                              num.tryParse(
                                match.group(1)!.replaceAll(',', '.'),
                              ) ??
                              100;
                          final unitStr = match.group(2); // "g" | "ml"
                          if (unitStr == 'g') {
                            qGrams = _portions * n;
                          } else {
                            qMl = _portions * n;
                          }
                        } else {
                          // Não há número + (g|ml) → tratamos como "porção/unidade"
                          qServ = _portions;
                        }

                        await MealsApi.I.add(
                          at: widget.date ?? DateTime.now(),
                          meal: _selectedMeal,
                          barcode: widget.barcode!,
                          name: _name,
                          brand: _brand,
                          quantityGrams: qGrams,
                          quantityMl: qMl,
                          servings: qServ,
                          calories: (_kcalBase * _portions).round(),
                          protein: _p * _portions,
                          carbs: _c * _portions,
                          fat: _f * _portions,
                          sugars: _sugar * _portions,
                          salt: _salt * _portions,
                        );

                        if (context.mounted) context.pop(true);
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    },
              child: Text("Adicionar ao ${_selectedMeal.labelPt}"),
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
          return const Color(0xFF4CAF6D);
        case "B":
          return const Color(0xFF66BB6A);
        case "C":
          return const Color(0xFFFFC107);
        case "D":
          return const Color(0xFFFF8A4C);
        case "E":
          return const Color(0xFFE53935);
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

class _MealDropdown extends StatelessWidget {
  final MealType value;
  final ValueChanged<MealType> onChanged;
  const _MealDropdown({required this.value, required this.onChanged});

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
        child: DropdownButton<MealType>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.expand_more_rounded),
          borderRadius: BorderRadius.circular(12),
          items: MealType.values.map((m) {
            return DropdownMenuItem<MealType>(
              value: m,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  m.labelPt,
                  style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

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
  bool _open = true;
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
            crossFadeState: _open
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
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
      if (sodium != null) _NutriRow("Sódio", "${sodium!.toStringAsFixed(2)} g"),
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
