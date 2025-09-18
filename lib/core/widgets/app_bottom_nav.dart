// lib/core/widgets/app_bottom_nav.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';

/// Bottom nav com:
/// - Pill (sombra) a deslizar entre itens, com fade out quando chega.
/// - Ícones 32px e label 12px FIXOS (sem zoom).
/// - Fundo configurável (default #FFFFFFEE) e divisor superior opcional.
class AppBottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onChanged;

  // Destaque/estilo
  final Color backgroundColor; // destaca vs app bg (#FAFAF7)
  final bool showTopDivider;   // linha 1px no topo
  final bool showIndicatorWhenIdle; // se true, mantém a pill visível parado

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onChanged,
    this.backgroundColor = const Color(0xEEFFFFFF),
    this.showTopDivider = true,
    this.showIndicatorWhenIdle = false,
  });

  @override
  State<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends State<AppBottomNav> {
  // Layout / animações
  static const double _barHeight = 88.0;   // barra um pouco maior
  static const int _animMs = 280;          // velocidade do slide
  static const double _pillH = 60.0;       // altura do "pill" (sombra)
  static const double _pillHPad = 21.0;    // padding lateral dentro da célula
  static const double _pillMinW = 86.0;    // limites para estabilidade
  static const double _pillMaxW = 164.0;

  static const _items = <_NavSpec>[
    _NavSpec('Painel', Icons.dashboard_outlined, Icons.dashboard_rounded),
    _NavSpec('Diário', Icons.book_outlined, Icons.book_rounded),
    _NavSpec('Mais', Icons.settings_outlined, Icons.settings_rounded),
  ];

  double _indicatorOpacity = 0.0;
  Timer? _fadeTimer;

  @override
  void initState() {
    super.initState();
    _indicatorOpacity = widget.showIndicatorWhenIdle ? 1.0 : 0.0;
  }

  @override
  void didUpdateWidget(covariant AppBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      // mostra a sombra enquanto desliza, depois desvanece (se configurado)
      _fadeTimer?.cancel();
      setState(() => _indicatorOpacity = 1.0);
      if (!widget.showIndicatorWhenIdle) {
        _fadeTimer = Timer(Duration(milliseconds: _animMs + 120), () {
          if (mounted) setState(() => _indicatorOpacity = 0.0);
        });
      }
    }
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: _barHeight,
        child: LayoutBuilder(
          builder: (context, c) {
            final cellW = c.maxWidth / _items.length;

            // dimensões da "pill" dinâmica
            final pillW = (cellW - _pillHPad * 2)
                .clamp(_pillMinW, _pillMaxW)
                .toDouble();
            final pillTop = (_barHeight - _pillH) / 2;
            final pillLeft =
                cellW * widget.currentIndex + (cellW - pillW) / 2;

            return Stack(
              children: [
                // fundo destacado
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: widget.backgroundColor),
                  ),
                ),
                if (widget.showTopDivider)
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: Container(
                      height: 1,
                      color: Colors.black.withOpacity(0.07),
                    ),
                  ),

                // pill a deslizar + fade
                AnimatedPositioned(
                  duration: const Duration(milliseconds: _animMs),
                  curve: Curves.easeOutCubic,
                  top: pillTop,
                  left: pillLeft,
                  width: pillW,
                  height: _pillH,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    opacity: _indicatorOpacity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.freshGreen.withAlpha(31), // ~12%
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),

                // items
                Row(
                  children: List.generate(_items.length, (i) {
                    final spec = _items[i];
                    final selected = widget.currentIndex == i;
                    return Expanded(
                      child: _NavButton(
                        label: spec.label,
                        icon: spec.icon,
                        selectedIcon: spec.selectedIcon,
                        selected: selected,
                        onTap: () => widget.onChanged(i),
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NavSpec {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const _NavSpec(this.label, this.icon, this.selectedIcon);
}

class _NavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.freshGreen : AppColors.coolGray;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? selectedIcon : icon,
                size: 32, // FIXO
                color: color,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppText.bodyFamily,
                  fontSize: 12, // FIXO
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
