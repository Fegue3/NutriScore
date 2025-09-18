// lib/core/widgets/app_bottom_nav.dart
import 'package:flutter/material.dart';
import '../theme.dart';

/// Navbar inferior minimalista (apenas a barra)
/// Ordem: Painel • Diário • Mais
/// Ícone + label animam juntos (scale) e fundo “pill” do selecionado anima.
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onChanged;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 80,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xEEFFFFFF)),
          child: Row(
            children: List.generate(_items.length, (i) {
              final spec = _items[i];
              final selected = currentIndex == i;
              return Expanded(
                child: _NavButton(
                  label: spec.label,
                  icon: spec.icon,
                  selectedIcon: spec.selectedIcon,
                  selected: selected,
                  onTap: () => onChanged(i),
                ),
              );
            }),
          ),
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

const _items = <_NavSpec>[
  _NavSpec('Painel', Icons.dashboard_outlined, Icons.dashboard_rounded),
  _NavSpec('Diário', Icons.book_outlined, Icons.book_rounded),
  _NavSpec('Mais', Icons.settings_outlined, Icons.settings_rounded),
];

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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Indicador de fundo a preencher sem usar larguras infinitas
                Positioned.fill(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.freshGreen.withAlpha(31) // ~0.12
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
                // Ícone + label com scale
                AnimatedScale(
                  scale: selected ? 1.12 : 1.0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        selected ? selectedIcon : icon,
                        size: 28,
                        color: color,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontFamily: AppText.bodyFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: color,
                        ),
                      ),
                    ],
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
