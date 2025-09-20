import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// NutriScore — AddFoodScreen (v7.1 – spacing tweaks)
class AddFoodScreen extends StatefulWidget {
  final String? initialMeal; // "Pequeno-almoço", "Almoço", "Lanche", "Jantar"
  const AddFoodScreen({super.key, this.initialMeal});

  @override
  State<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends State<AddFoodScreen> {
  final _searchCtrl = TextEditingController();
  static const _meals = <String>["Pequeno-almoço", "Almoço", "Lanche", "Jantar"];
  late String _selectedMeal;

  final List<_HistoryItem> _history = const [
    _HistoryItem(name: "Iogurte natural", kcal: 63, brand: "Milbona", homemade: false, organic: true, quantityLabel: "125 g", sugarsG: 4.7, fatG: 3.5, saltG: 0.08),
    _HistoryItem(name: "Pão integral", kcal: 240, brand: "Padaria do Bairro", homemade: true, organic: false, quantityLabel: "1 fatia (40 g)", sugarsG: 1.6, fatG: 1.3, saltG: 0.45),
    _HistoryItem(name: "Bolacha de aveia", kcal: 90, brand: "OatBite", homemade: false, organic: false, quantityLabel: "1 un (18 g)", sugarsG: 3.2, fatG: 3.8, saltG: 0.06),
    _HistoryItem(name: "Sumo de laranja", kcal: 45, brand: "Caseiro", homemade: true, organic: false, quantityLabel: "200 ml", sugarsG: 8.9, fatG: 0.1, saltG: 0.00),
  ];

  @override
  void initState() {
    super.initState();
    _selectedMeal = _meals.contains(widget.initialMeal) ? widget.initialMeal! : "Lanche";
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

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
                              onChanged: (v) => setState(() => _selectedMeal = v),
                              chipColor: cs.primary,
                              textColor: cs.onPrimary, // branco
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
                      onSubmitted: (_) {},
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
              child: _ScanCardSurfaceGreen(onTap: () {
                // TODO: abrir scanner
              }),
            ),

            // ===================== HISTÓRICO =====================
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount: _history.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Text(
                        "Histórico",
                        style: tt.titleMedium?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    );
                  }
                  final it = _history[i - 1];
                  return _HistoryTile(item: it, onTap: () {});
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

/// Chip verde com **texto branco + seta** juntos e **centrados**.
/// Blendado com o fundo (sem sombra/elevation).
class _MealComboChipCentered extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final Color chipColor;
  final Color textColor;
  const _MealComboChipCentered({
    required this.value,
    required this.onChanged,
    required this.chipColor,
    required this.textColor,
  });

  static const _meals = <String>["Pequeno-almoço", "Almoço", "Lanche", "Jantar"];

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: ShapeDecoration(
        color: Colors.transparent, // verde mais “blendado”
        shape: StadiumBorder(),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            icon: const SizedBox.shrink(), // desenhamos a nossa seta
            alignment: Alignment.center,
            dropdownColor: chipColor, // menu verde sólido
            borderRadius: BorderRadius.circular(12),
            // Texto no botão (centrado + seta) — branco
            selectedItemBuilder: (_) => _meals
                .map(
                  (m) => Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          m,
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
                  ),
                )
                .toList(),
            // Itens do menu — texto branco, sem destaque
            items: _meals
                .map(
                  (m) => DropdownMenuItem<String>(
                    value: m,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          m,
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: textColor, // branco
                          ),
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
      ),
    );
  }
}

/// Search bar “frosted”
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
            boxShadow: const [BoxShadow(blurRadius: 10, offset: Offset(0, 4), color: Color(0x22000000))],
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
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                  cursorColor: textColor,
                  onSubmitted: onSubmitted,
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(color: textColor.withValues(alpha: .9)),
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
                    onSubmitted?.call('');
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ============================ SCAN (FUNDO CLARO, ÁREA INTERNA VERDE) ============================ */

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
          boxShadow: const [BoxShadow(blurRadius: 10, offset: Offset(0, 6), color: Color(0x1A000000))],
          border: Border.all(color: Colors.white.withValues(alpha: .30), width: 1.2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.qr_code_scanner_rounded, color: cs.onPrimary, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Scan código de barras",
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: cs.onPrimary,
                          )),
                      const SizedBox(height: 4),
                      Text(
                        "Usa a câmara para adicionar rapidamente um produto.",
                        style: tt.bodyMedium?.copyWith(color: cs.onPrimary.withValues(alpha: .96)),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: cs.onPrimary.withValues(alpha: .96)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ============================ OUTROS WIDGETS ============================ */

class _TopCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final p = Path();
    p.lineTo(0, 0);
    p.lineTo(0, size.height);
    p.quadraticBezierTo(size.width * 0.5, -size.height, size.width, size.height);
    p.lineTo(size.width, 0);
    p.close();
    return p;
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/* ============================ HISTÓRICO ============================ */

class _HistoryItem {
  final String name;
  final int kcal;
  final String brand;
  final bool homemade;
  final bool organic;
  final String quantityLabel;
  final double sugarsG;
  final double fatG;
  final double saltG;
  const _HistoryItem({
    required this.name,
    required this.kcal,
    required this.brand,
    required this.homemade,
    required this.organic,
    required this.quantityLabel,
    required this.sugarsG,
    required this.fatG,
    required this.saltG,
  });
}

class _HistoryTile extends StatelessWidget {
  final _HistoryItem item;
  final VoidCallback? onTap;
  const _HistoryTile({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Widget tag(String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: cs.primary.withValues(alpha: .25)),
          ),
          child: Text(text, style: tt.labelSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
        );

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(item.name, style: tt.titleMedium?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w800))),
                        Material(
                          color: cs.primary,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: onTap,
                            child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.add, size: 20, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text("${item.brand} • ${item.quantityLabel}", style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Row(children: [
                      if (item.homemade) tag("Caseiro"),
                      if (item.homemade && item.organic) const SizedBox(width: 6),
                      if (item.organic) tag("Bio"),
                    ]),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _MiniMetric(label: "Calorias", value: "${item.kcal} kcal"),
                        const SizedBox(width: 12),
                        _MiniMetric(label: "Açúcares", value: "${item.sugarsG.toStringAsFixed(1)} g"),
                        const SizedBox(width: 12),
                        _MiniMetric(label: "Gord.", value: "${item.fatG.toStringAsFixed(1)} g"),
                        const SizedBox(width: 12),
                        _MiniMetric(label: "Sal", value: "${item.saltG.toStringAsFixed(2)} g"),
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
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  const _MiniMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: .35),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text(value, style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface)),
          ],
        ),
      ),
    );
  }
}
