// lib/features/nutrition/add_food_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/meals_api.dart';
import '../../data/products_api.dart'; // ProductsApi, ProductSummary, ProductHistoryItem

/// NutriScore — AddFoodScreen (v9.2 - histórico real via API, sem imagens nas listas)
class AddFoodScreen extends StatefulWidget {
  final MealType? initialMeal; // "Pequeno-almoço", "Almoço", "Lanche", "Jantar"
  final DateTime? selectedDate;
  const AddFoodScreen({super.key, this.initialMeal, this.selectedDate});

  @override
  State<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends State<AddFoodScreen> {
  final _searchCtrl = TextEditingController();
  late MealType _selectedMeal;

  // Alterna título Histórico/Pesquisa
  bool _showPesquisa = false;

  // Estado API
  bool _loading = false;
  List<ProductSummary> _results = const [];

  // Histórico REAL
  bool _loadingHistory = false;
  List<ProductHistoryItem> _history = const [];

  @override
  void initState() {
    super.initState();
    _selectedMeal = widget.initialMeal ?? MealType.breakfast;
    _fetchHistory(); // carrega logo o histórico

    // Sugestões rápidas enquanto escreve
    _searchCtrl.addListener(() async {
      final q = _searchCtrl.text.trim();
      setState(() => _showPesquisa = q.isNotEmpty);
      if (q.isEmpty) {
        setState(() => _results = const []);
        return;
      }
      try {
        final items = await ProductsApi.I.suggest(q, limit: 8);
        if (!mounted) return;
        setState(() => _results = items);
      } catch (_) {
        // silencioso
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final resp = await ProductsApi.I.getHistory(page: 1, pageSize: 20);
      if (!mounted) return;
      setState(() => _history = resp.items);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _onSearchSubmitted(String q) async {
    final query = q.trim();
    setState(() {
      _showPesquisa = query.isNotEmpty;
      _loading = query.isNotEmpty;
    });
    if (query.isEmpty) {
      setState(() => _results = const []);
      return;
    }
    try {
      final resp = await ProductsApi.I.searchConfirm(
        query,
        page: 1,
        pageSize: 20,
      );
      if (!mounted) return;
      setState(() => _results = resp.items);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDetailFromSummary(ProductSummary it) async {
    await context.pushNamed(
      'productDetail',
      extra: {
        "barcode": it.barcode,
        "name": it.name,
        "brand": it.brand,
        "baseQuantityLabel": "100 g",
        "kcalPerBase": it.energyKcal100g ?? 0,
        "nutriScore": it.nutriScore,
        "initialMeal": _selectedMeal.labelPt,
        "date":  widget.selectedDate,
      },
    );
    if (!mounted) return;
    _fetchHistory(); // <-- atualiza a lista ao voltar
  }

  Future<void> _openDetailFromHistory(ProductHistoryItem h) async {
    final day = widget.selectedDate ?? DateTime.now();
    final barcode = h.barcode ?? h.product?.barcode;
    if (barcode != null && barcode.isNotEmpty) {
      await context.pushNamed(
        'productDetail',
        extra: {"barcode": barcode, "initialMeal": _selectedMeal.labelPt, "date": day,},
      );
    } else {
      final p = h.product;
      await context.pushNamed(
        'productDetail',
        extra: {
          if (p != null) "name": p.name,
          if (p != null) "brand": p.brand,
          "baseQuantityLabel": "100 g",
          "kcalPerBase": p?.energyKcal100g ?? h.calories ?? 0,
          "nutriScore": p?.nutriScore ?? h.nutriScore ?? '',
          "proteinGPerBase": h.proteins,
          "carbsGPerBase": h.carbs,
          "fatGPerBase": h.fat,
          "initialMeal": _selectedMeal.labelPt,
          "date": day,
        },
      );
    }
    if (!mounted) return;
    _fetchHistory();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final showingResults = _showPesquisa;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ===================== HERO VERDE =====================
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary, cs.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  // Back + combo (chip verde blendado)
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
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: _MealComboChipCentered(
                              value: _selectedMeal,
                              onChanged: (v) =>
                                  setState(() => _selectedMeal = v),
                              chipColor: cs.primary,
                              textColor: cs.onPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),

                  // Search pill (frosted)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: _SearchBarHero(
                      controller: _searchCtrl,
                      hintText: "Pesquisar alimento…",
                      textColor: cs.onPrimary,
                      onSubmitted: _onSearchSubmitted,
                    ),
                  ),
                ],
              ),
            ),

            // Curva separadora
            ClipPath(
              clipper: _TopCurveClipper(),
              child: Container(height: 16, color: cs.surface),
            ),

            // ===================== SCAN =====================
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _ScanCardSurfaceGreen(
                onTap: () {
                  // TODO: abrir scanner
                },
              ),
            ),

            // ===================== HISTÓRICO / PESQUISA =====================
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount:
                    (showingResults ? _results.length : _history.length) + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              showingResults ? "Pesquisa" : "Histórico",
                              style: tt.titleMedium?.copyWith(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (!showingResults)
                            IconButton(
                              tooltip: "Atualizar histórico",
                              icon: const Icon(Icons.refresh_rounded),
                              onPressed: _loadingHistory ? null : _fetchHistory,
                            ),
                        ],
                      ),
                    );
                  }

                  if (showingResults) {
                    if (_loading) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (_results.isEmpty) return const SizedBox.shrink();
                    final it = _results[i - 1];
                    return _ResultTile(
                      item: it,
                      onTap: () => _openDetailFromSummary(it),
                    );
                  }

                  // Histórico real
                  if (_loadingHistory && _history.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (_history.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        "Ainda não tens histórico.",
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final h = _history[i - 1];
                  return _HistoryTileReal(
                    item: h,
                    onTap: () => _openDetailFromHistory(h),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ============================ WIDGETS HERO ============================ */

class _MealComboChipCentered extends StatelessWidget {
  final MealType value;
  final ValueChanged<MealType> onChanged;
  final Color chipColor;
  final Color textColor;
  const _MealComboChipCentered({
    required this.value,
    required this.onChanged,
    required this.chipColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const ShapeDecoration(
        color: Colors.transparent,
        shape: StadiumBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<MealType>(
          value: value,
          isExpanded: true,
          icon: const SizedBox.shrink(),
          alignment: Alignment.center,
          dropdownColor: chipColor,
          borderRadius: BorderRadius.circular(12),

          selectedItemBuilder: (_) => MealType.values.map((m) {
            return Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    m.labelPt,
                    style: tt.titleMedium?.copyWith(
                      fontSize: 20,
                      color: textColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.expand_more_rounded, color: textColor),
                ],
              ),
            );
          }).toList(),

          items: MealType.values.map((m) {
            return DropdownMenuItem<MealType>(
              value: m,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    m.labelPt,
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
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

class _SearchBarHero extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final Color textColor;
  final ValueChanged<String>? onSubmitted;
  const _SearchBarHero({
    required this.controller,
    required this.hintText,
    required this.textColor,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: .22)),
            boxShadow: const [
              BoxShadow(
                blurRadius: 10,
                offset: Offset(0, 4),
                color: Color(0x22000000),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: textColor),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.search,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                  cursorColor: textColor,
                  onSubmitted: onSubmitted,
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(
                      color: textColor.withValues(alpha: .9),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              if (controller.text.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.close_rounded, color: textColor),
                  onPressed: () {
                    controller.clear();
                    onSubmitted?.call(''); // limpa para voltar a "Histórico"
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ============================ SCAN CARD ============================ */

class _ScanCardSurfaceGreen extends StatelessWidget {
  final VoidCallback? onTap;
  const _ScanCardSurfaceGreen({this.onTap});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              blurRadius: 10,
              offset: Offset(0, 6),
              color: Color(0x1A000000),
            ),
          ],
          border: Border.all(
            color: Colors.white.withValues(alpha: .30),
            width: 1.2,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.qr_code_scanner_rounded,
                  color: cs.onPrimary,
                  size: 36,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Scan código de barras",
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: cs.onPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Usa a câmara para adicionar rapidamente um produto.",
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onPrimary.withValues(alpha: .96),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: cs.onPrimary.withValues(alpha: .96),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ============================ HISTÓRICO (REAL) ============================ */
/*  SEM IMAGEM  */
class _HistoryTileReal extends StatelessWidget {
  final ProductHistoryItem item;
  final VoidCallback? onTap;
  const _HistoryTileReal({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final p = item.product;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // (sem thumbnail)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            (p?.name ?? 'Produto'),
                            style: tt.titleMedium?.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Material(
                          color: cs.primary,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: onTap,
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.add,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if ((p?.brand ?? '').isNotEmpty) p!.brand!,
                        _fmtDate(item.scannedAt),
                      ].join(' • '),
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if ((item.nutriScore ?? p?.nutriScore ?? '').isNotEmpty)
                          _NutriTag(grade: (item.nutriScore ?? p?.nutriScore)!),
                        const SizedBox(width: 8),
                        if ((p?.energyKcal100g ?? item.calories) != null)
                          _ChipMetric(
                            label: "por 100g",
                            value:
                                "${(p?.energyKcal100g ?? item.calories)!} kcal",
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return "${two(d.day)}/${two(d.month)}/${d.year}";
  }
}

/* ============================ UTIL PARTILHADO ============================ */

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

/* ============================ RESULT TILE (API) ============================ */
/*  SEM IMAGEM  */
class _ResultTile extends StatelessWidget {
  final ProductSummary item;
  final VoidCallback? onTap;
  const _ResultTile({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // (sem thumbnail)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: tt.titleMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if ((item.brand ?? '').isNotEmpty) item.brand!,
                        if ((item.categories ?? '').isNotEmpty)
                          item.categories!,
                      ].join(' • '),
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if ((item.nutriScore ?? '').isNotEmpty)
                          _NutriTag(grade: item.nutriScore!),
                        const SizedBox(width: 8),
                        if (item.energyKcal100g != null)
                          _ChipMetric(
                            label: "por 100g",
                            value: "${item.energyKcal100g} kcal",
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: cs.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onTap,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipMetric extends StatelessWidget {
  final String label;
  final String value;
  const _ChipMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: tt.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _NutriTag extends StatelessWidget {
  final String grade;
  const _NutriTag({required this.grade});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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

    final c = nutriColor(grade);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: .35)),
      ),
      child: Text(
        "NutriScore ${grade.toUpperCase()}",
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800, color: c),
      ),
    );
  }
}
