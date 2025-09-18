// lib/core/widgets/app_bottom_nav.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';

class AppBottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onChanged;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onChanged,
  });

  @override
  State<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends State<AppBottomNav> {
  static const _barHeight = 88.0;      // barra um pouco maior
  static const _animMs = 280;          // animação mais lenta
  static const _items = <_NavSpec>[
    _NavSpec('Painel', Icons.dashboard_outlined, Icons.dashboard_rounded),
    _NavSpec('Diário', Icons.book_outlined, Icons.book_rounded),
    _NavSpec('Mais', Icons.settings_outlined, Icons.settings_rounded),
  ];

  double _indicatorOpacity = 0.0;
  Timer? _fadeTimer;

  @override
  void didUpdateWidget(covariant AppBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      // mostra a sombra enquanto desliza, depois desvanece
      _fadeTimer?.cancel();
      setState(() => _indicatorOpacity = 1.0);
      _fadeTimer = Timer(const Duration(milliseconds: _animMs + 120), () {
        if (mounted) setState(() => _indicatorOpacity = 0.0);
      });
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

            // dimensões do "pill" (sombra)
            const pillH = 60.0;
            final pillW = (cellW - 42).clamp(86.0, 164.0);
            final pillTop = (_barHeight - pillH) / 2;
            final pillLeft =
                cellW * widget.currentIndex + (cellW - pillW) / 2;

            return Stack(
              children: [
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Color(0xEEFFFFFF)),
                  ),
                ),
                // pill dinâmico a deslizar + fade-out quando chega
                AnimatedPositioned(
                  duration: const Duration(milliseconds: _animMs),
                  curve: Curves.easeOutCubic,
                  top: pillTop,
                  left: pillLeft,
                  width: pillW,
                  height: pillH,
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
        child: AnimatedScale(
          scale: selected ? 1.12 : 1.0,       // anima ícone + label
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  size: 32,                    // ← ícones MAIORES
                  color: color,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppText.bodyFamily,
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
