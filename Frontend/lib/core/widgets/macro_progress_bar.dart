import 'package:flutter/material.dart';
/// Barra de progresso para nutrientes, com animação on-mount.
/// - Mostra "label" à esquerda e "used[/target] + unidade" à direita.
/// - Se [target] for null/<=0, mostra só o valor (sem barra).
class MacroProgressBar extends StatefulWidget {
  final String label;     // "Proteína"
  final String unit;      // "g" | "kcal"
  final num used;         // valor consumido
  final num? target;      // null -> sem alvo/barra
  final String? helper;   // texto extra abaixo (opcional)
  final EdgeInsets padding;
  final bool dense;

  /// Cores (opcional). Se não passares, usa o tema.
  final Color? color;           // cor da barra (ex.: primary/secondary/error)
  final Color? backgroundColor; // fundo da barra
  final Duration duration;      // duração da animação
  final Curve curve;            // curva da animação
  final Duration? delay;        // atraso inicial (para stagger)

  const MacroProgressBar({
    super.key,
    required this.label,
    required this.unit,
    required this.used,
    this.target,
    this.helper,
    this.padding = const EdgeInsets.symmetric(vertical: 10),
    this.dense = false,
    this.color,
    this.backgroundColor,
    this.duration = const Duration(milliseconds: 750),
    this.curve = Curves.easeOutCubic,
    this.delay,
  });

  @override
  State<MacroProgressBar> createState() => _MacroProgressBarState();
}

class _MacroProgressBarState extends State<MacroProgressBar>
    with SingleTickerProviderStateMixin {
  double _t = 0; // 0..1 para animar widthFactor

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant MacroProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reanima se o alvo/valor mudarem significativamente
    if (oldWidget.used != widget.used || oldWidget.target != widget.target) {
      _t = 0;
      _start();
    }
  }

  Future<void> _start() async {
    if (widget.delay != null) {
      await Future.delayed(widget.delay!);
    }
    if (!mounted) return;
    setState(() => _t = 1);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final hasTarget = widget.target != null && widget.target! > 0;
    final pct = hasTarget ? (widget.used / widget.target!).clamp(0, 2).toDouble() : null;
    final over = hasTarget && widget.used > widget.target!;
    final barColor = widget.color ?? (over ? cs.error : cs.primary);
    final bg = widget.backgroundColor ?? cs.surfaceContainerHighest;
    final onBg = cs.onSurface;

    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título + valores
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: onBg,
                  ),
                ),
              ),
              Text(
                hasTarget
                    ? '${_fmt(widget.used)}${widget.unit} / ${_fmt(widget.target!)}${widget.unit}'
                    : '${_fmt(widget.used)}${widget.unit}',
                style: tt.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: over ? cs.error : onBg,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Barra com animação do widthFactor
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: widget.dense ? 8 : 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // fundo
                  ColoredBox(color: bg),
                  if (pct != null)
                    TweenAnimationBuilder<double>(
                      key: ValueKey('${widget.label}-${widget.used}-${widget.target}'),
                      tween: Tween<double>(begin: 0, end: pct.clamp(0, 1)),
                      duration: widget.duration,
                      curve: widget.curve,
                      builder: (ctx, value, child) {
                        // aplica também o "gatilho" manual _t para suportar delay
                        final width = value * _t;
                        return FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: width,
                          child: child,
                        );
                      },
                      child: ColoredBox(color: barColor),
                    ),
                ],
              ),
            ),
          ),
          if (widget.helper != null && widget.helper!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              widget.helper!,
              style: tt.bodySmall?.copyWith(
                color: onBg.withValues(alpha: .7),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _fmt(num n) {
    final s = n.toStringAsFixed(n % 1 == 0 ? 0 : 1);
    return s.replaceAll('.', ',');
  }
}
