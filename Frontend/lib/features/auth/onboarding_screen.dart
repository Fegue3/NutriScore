// lib/features/auth/onboarding_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Onboarding com 4 passos:
/// 1) Género  2) Peso (kg)  3) Altura (cm)  4) Nível de atividade (combo)
/// Depois mostra "Obrigado" e navega para /dashboard após ~3.8s.
/// Usa apenas Theme (sem cores hardcoded) e uma progress bar segmentada.

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Step { gender, weight, height, activity, done }

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _page = PageController();
  _Step _current = _Step.gender;

  // respostas
  String? _gender; // "MALE" | "FEMALE" | "OTHER"
  final _weight = TextEditingController();
  final _height = TextEditingController();
  String? _activity; // "sedentary" | "light" | "moderate" | "active" | "very_active"

  bool _submitting = false;

  static const _activities = <(String, String)>[
    ('sedentary', 'Sedentário (pouco/no exercício)'),
    ('light', 'Leve (1–3x/semana)'),
    ('moderate', 'Moderado (3–5x/semana)'),
    ('active', 'Ativo (6–7x/semana)'),
    ('very_active', 'Muito ativo (treino intenso)'),
  ];

  @override
  void dispose() {
    _page.dispose();
    _weight.dispose();
    _height.dispose();
    super.dispose();
  }

  // -------- Navegação dos passos --------
  int get _index => _current.index;
  int get _total => _Step.done.index; // 4 passos úteis

  void _goNext() async {
    if (!_validateStep()) return;

    if (_current == _Step.activity) {
      setState(() => _current = _Step.done);
      _page.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
      await _finishAndGo();
      return;
    }

    setState(() => _current = _Step.values[_index + 1]);
    _page.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
  }

  void _goBack() {
    if (_current == _Step.gender) return;
    setState(() => _current = _Step.values[_index - 1]);
    _page.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
  }

  bool _validateStep() {
    final snack = ScaffoldMessenger.of(context);
    switch (_current) {
      case _Step.gender:
        if (_gender == null) {
          snack.showSnackBar(const SnackBar(content: Text('Escolhe o teu género.')));
          return false;
        }
        return true;
      case _Step.weight:
        final w = double.tryParse(_weight.text.replaceAll(',', '.'));
        if (w == null || w < 25 || w > 400) {
          snack.showSnackBar(const SnackBar(content: Text('Indica um peso válido (kg).')));
          return false;
        }
        return true;
      case _Step.height:
        final h = int.tryParse(_height.text);
        if (h == null || h < 90 || h > 250) {
          snack.showSnackBar(const SnackBar(content: Text('Indica uma altura válida (cm).')));
          return false;
        }
        return true;
      case _Step.activity:
        if (_activity == null) {
          snack.showSnackBar(const SnackBar(content: Text('Seleciona o teu nível de atividade.')));
          return false;
        }
        return true;
      case _Step.done:
        return true;
    }
  }

  Future<void> _finishAndGo() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    // TODO: enviar para a API (update profile) se precisares.

    await Future.delayed(const Duration(milliseconds: 3800));
    if (!mounted) return;
    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return WillPopScope(
      onWillPop: () async {
        if (_current != _Step.gender && _current != _Step.done) {
          _goBack();
          return false; // recua passo em vez de sair
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          title: const Text('Completar perfil'),
          backgroundColor: cs.surface,
          surfaceTintColor: cs.surface,
          elevation: 0,
          leading: (_current != _Step.gender && _current != _Step.done)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: _goBack,
                )
              : null,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: _SegmentedProgress(currentIndex: _index, total: _total),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              blurRadius: 10,
                              offset: Offset(0, 4),
                              color: Color(0x14000000),
                            ),
                          ],
                          border: Border.all(color: cs.outline.withValues(alpha: .25)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Expanded(
                                child: PageView(
                                  controller: _page,
                                  physics: const NeverScrollableScrollPhysics(),
                                  children: [
                                    _buildGenderStep(context),
                                    _buildWeightStep(context),
                                    _buildHeightStep(context),
                                    _buildActivityStep(context),
                                    _buildDoneStep(context),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  if (_current != _Step.gender && _current != _Step.done)
                                    OutlinedButton(
                                      onPressed: _goBack,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: cs.primary,
                                        side: BorderSide(color: cs.primary),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(24),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                      ),
                                      child: const Text('Voltar'),
                                    )
                                  else
                                    const SizedBox.shrink(),
                                  const Spacer(),
                                  if (_current != _Step.done)
                                    FilledButton(
                                      onPressed: _goNext,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: cs.primary,
                                        foregroundColor: cs.onPrimary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(24),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 22,
                                          vertical: 14,
                                        ),
                                      ),
                                      child: Text(_current == _Step.activity ? 'Concluir' : 'Continuar'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // -------- Passo 1: Género --------
  Widget _buildGenderStep(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final chips = [
      ('MALE', 'Masculino', Icons.male_rounded),
      ('FEMALE', 'Feminino', Icons.female_rounded),
      ('OTHER', 'Outro', Icons.transgender_rounded),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Qual é o teu género?',
          style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final c in chips)
              _SelectableChip(
                selected: _gender == c.$1,
                label: c.$2,
                icon: c.$3,
                onTap: () => setState(() => _gender = c.$1),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Usamos isto apenas para calcular necessidades energéticas.',
          style: tt.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: .70)),
        ),
      ],
    );
  }

  // -------- Passo 2: Peso --------
  Widget _buildWeightStep(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Qual é o teu peso?',
          style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _weight,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,\.]'))],
          decoration: InputDecoration(
            labelText: 'Peso (kg)',
            suffixText: 'kg',
            filled: true,
            fillColor: cs.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: cs.outline.withValues(alpha: .50)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: cs.outline.withValues(alpha: .50)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: cs.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Apenas números. Ex.: 72.5',
          style: tt.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: .70)),
        ),
      ],
    );
  }

  // -------- Passo 3: Altura --------
  Widget _buildHeightStep(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Qual é a tua altura?',
          style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _height,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Altura (cm)',
            suffixText: 'cm',
            filled: true,
            fillColor: cs.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: cs.outline.withValues(alpha: .50)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: cs.outline.withValues(alpha: .50)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: cs.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ex.: 178',
          style: tt.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: .70)),
        ),
      ],
    );
  }

  // -------- Passo 4: Atividade --------
  Widget _buildActivityStep(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Qual é o teu nível de atividade?',
          style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _activity,
          items: _activities
              .map((a) => DropdownMenuItem<String>(value: a.$1, child: Text(a.$2)))
              .toList(),
          onChanged: (v) => setState(() => _activity = v),
          decoration: InputDecoration(
            labelText: 'Seleciona uma opção',
            filled: true,
            fillColor: cs.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: cs.outline.withValues(alpha: .50)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: cs.outline.withValues(alpha: .50)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: cs.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Isto ajuda a estimar as calorias diárias recomendadas.',
          style: tt.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: .70)),
        ),
      ],
    );
  }

  // -------- Passo final: Obrigado --------
  Widget _buildDoneStep(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: _submitting
            ? Column(
                key: const ValueKey('submitting'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, size: 64, color: cs.primary),
                  const SizedBox(height: 12),
                  Text(
                    'Obrigado por te registares! 🎉',
                    style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A preparar o teu dashboard…',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: .70)),
                  ),
                ],
              )
            : Column(
                key: const ValueKey('ready'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.celebration_rounded, size: 64, color: cs.primary),
                  const SizedBox(height: 12),
                  Text(
                    'Tudo pronto! 🎯',
                    style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vamos configurar o teu plano diário…',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: .70)),
                  ),
                ],
              ),
      ),
    );
  }
}

// ================== Widgets de UI ==================

class _SegmentedProgress extends StatelessWidget {
  const _SegmentedProgress({required this.currentIndex, required this.total});

  final int currentIndex;
  final int total;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 8.0;
        final segWidth = (c.maxWidth - gap * (total - 1)) / total;
        return Row(
          children: List.generate(total, (i) {
            final active = i <= currentIndex && currentIndex < total;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: segWidth,
              height: 10,
              margin: EdgeInsets.only(right: i == total - 1 ? 0 : gap),
              decoration: BoxDecoration(
                color: active ? cs.primary : cs.outlineVariant.withValues(alpha: .35),
                borderRadius: BorderRadius.circular(12),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: cs.primary.withOpacity(.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
            );
          }),
        );
      },
    );
  }
}

class _SelectableChip extends StatelessWidget {
  const _SelectableChip({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? cs.primary : cs.outline.withValues(alpha: .45)),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: cs.primary.withOpacity(.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: selected ? cs.onPrimary : cs.onSurface),
            const SizedBox(width: 8),
            Text(
              label,
              style: tt.bodyMedium?.copyWith(
                color: selected ? cs.onPrimary : cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
