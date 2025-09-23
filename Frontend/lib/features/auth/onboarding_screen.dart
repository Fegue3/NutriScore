import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/auth_api.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.authRepository});
  final AuthRepository authRepository;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Step { gender, birthdate, weight, targetWeight, targetDate, height, activity, done }

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _page = PageController();
  _Step _current = _Step.gender;

  String? _gender; // "MALE" | "FEMALE" | "OTHER"
  DateTime? _dob; // data de nascimento
  final _dobCtrl = TextEditingController();

  final _weight = TextEditingController();
  final _targetWeight = TextEditingController();
  final _height = TextEditingController();

  // Novo: data alvo (opcional)
  DateTime? _targetDate; // quando quer atingir o peso alvo (opcional)
  final _targetDateCtrl = TextEditingController();

  String?
      _activity; // "sedentary" | "light" | "moderate" | "active" | "very_active"

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
    _dobCtrl.dispose();
    _weight.dispose();
    _targetWeight.dispose();
    _height.dispose();
    _targetDateCtrl.dispose(); // novo
    super.dispose();
  }

  // --------- Fluxo de cancelamento no 1º passo ---------
  Future<void> _cancelAndDelete() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      await widget.authRepository.deleteAccount(); // DELETE /auth/me
    } catch (_) {}

    try {
      await widget.authRepository.logout(); // limpa tokens/estado local
    } catch (_) {}

    if (!mounted) return;
    context.go('/signup');
  }

  // -------- Navegação dos passos --------
  int get _index => _current.index;
  int get _total => _Step.done.index;

  void _goNext() async {
    if (!_validateStep()) return;

    if (_current == _Step.activity) {
      setState(() => _current = _Step.done);
      _page.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
      await _finishAndGo();
      return;
    }
    setState(() => _current = _Step.values[_index + 1]);
    _page.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  void _goBack() {
    if (_current == _Step.gender) {
      _cancelAndDelete(); // apaga + logout + volta ao signup
      return;
    }
    if (_current == _Step.done) {
      if (_submitting) return;
      setState(() => _current = _Step.activity);
      _page.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    setState(() => _current = _Step.values[_index - 1]);
    _page.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  bool _validateStep() {
    final snack = ScaffoldMessenger.of(context);
    switch (_current) {
      case _Step.gender:
        if (_gender == null) {
          snack.showSnackBar(
            const SnackBar(content: Text('Escolhe o teu género.')),
          );
          return false;
        }
        return true;

      case _Step.birthdate:
        if (_dob == null) {
          snack.showSnackBar(
            const SnackBar(content: Text('Escolhe a tua data de nascimento.')),
          );
          return false;
        }
        // idade entre 10 e 120 anos
        final now = DateTime.now();
        final minDate = DateTime(now.year - 120, now.month, now.day);
        final maxDate = DateTime(now.year - 10, now.month, now.day);
        if (_dob!.isBefore(minDate) || _dob!.isAfter(maxDate)) {
          snack.showSnackBar(
            const SnackBar(
              content: Text('Indica uma data de nascimento válida.'),
            ),
          );
          return false;
        }
        return true;

      case _Step.weight:
        final w = double.tryParse(_weight.text.replaceAll(',', '.'));
        if (w == null || w < 25 || w > 400) {
          snack.showSnackBar(
            const SnackBar(content: Text('Indica um peso válido (kg).')),
          );
          return false;
        }
        return true;

      case _Step.targetWeight:
        final tw = double.tryParse(_targetWeight.text.replaceAll(',', '.'));
        if (tw == null || tw < 25 || tw > 400) {
          snack.showSnackBar(
            const SnackBar(content: Text('Define um peso alvo válido (kg).')),
          );
          return false;
        }
        return true;

      case _Step.targetDate:
        // Opcional: se vazio, segue. Se preenchido, valida intervalo.
        if (_targetDate == null) return true;
        final now = DateTime.now();
        final earliest = DateTime(now.year, now.month, now.day).add(const Duration(days: 1)); // amanhã
        final latest = DateTime(now.year + 2, now.month, now.day); // até 2 anos
        if (_targetDate!.isBefore(earliest) || _targetDate!.isAfter(latest)) {
          snack.showSnackBar(
            const SnackBar(content: Text('Escolhe uma data futura (até 2 anos).')),
          );
          return false;
        }
        return true;

      case _Step.height:
        final h = int.tryParse(_height.text);
        if (h == null || h < 90 || h > 250) {
          snack.showSnackBar(
            const SnackBar(content: Text('Indica uma altura válida (cm).')),
          );
          return false;
        }
        return true;

      case _Step.activity:
        if (_activity == null) {
          snack.showSnackBar(
            const SnackBar(
              content: Text('Seleciona o teu nível de atividade.'),
            ),
          );
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

    // 1) Tenta guardar metas (se falhar, seguimos — não é bloqueante)
    try {
      final double? w = double.tryParse(_weight.text.replaceAll(',', '.'));
      final double? tw =
          double.tryParse(_targetWeight.text.replaceAll(',', '.'));
      final int? h = int.tryParse(_height.text);
      await AuthApi.I.upsertGoals(
        sex: _gender,
        dateOfBirth: _dob,
        currentWeightKg: w,
        targetWeightKg: tw,
        targetDate: _targetDate, // <--- NOVO (opcional)
        heightCm: h,
        activityLevel: _activity,
      );
    } catch (_) {
      // opcional: log / snackbar “não foi possível guardar metas, tentamos mais tarde”
    }

    // 2) Marca onboarding concluído (isto é BLOQUEANTE para sair daqui)
    bool ok = false;
    try {
      await AuthApi.I.setOnboardingCompleted(true);
      widget.authRepository.setOnboardingCompleted(true);
      ok = true;
    } catch (e) {
      ok = false;
    }

    if (!mounted) return;

    if (!ok) {
      // Não conseguimos marcar o flag → não navegamos porque o router vai forçar /onboarding
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível concluir o onboarding. Tenta novamente.',
          ),
        ),
      );
      // volta uma página para o utilizador poder “Concluir” outra vez
      setState(() => _current = _Step.activity);
      _page.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    // 3) Pequena animação e segue para o dashboard
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false, // intercepta sempre back do sistema
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _goBack();
      },
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          title: const Text('Completar perfil'),
          backgroundColor: cs.surface,
          surfaceTintColor: cs.surface,
          elevation: 0,
          // 👉 seta de voltar SEMPRE visível
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: (_current == _Step.done && _submitting) ? null : _goBack,
          ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
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
                          border: Border.all(
                            color: cs.outline.withValues(alpha: .25),
                          ),
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
                                    _buildBirthdateStep(context),
                                    _buildWeightStep(context),
                                    _buildTargetWeightStep(context),
                                    _buildTargetDateStep(context), // novo
                                    _buildHeightStep(context),
                                    _buildActivityStep(context),
                                    _buildDoneStep(context),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  if (_current != _Step.gender &&
                                      _current != _Step.done)
                                    OutlinedButton(
                                      onPressed: _goBack,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: cs.primary,
                                        side: BorderSide(color: cs.primary),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
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
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 22,
                                          vertical: 14,
                                        ),
                                      ),
                                      child: Text(
                                        _current == _Step.activity
                                            ? 'Concluir'
                                            : 'Continuar',
                                      ),
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

  // -------- Helpers --------
  String _formatDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    return '$day/$month/$year';
  }

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 120, now.month, now.day);
    final last = DateTime(now.year - 10, now.month, now.day);

    final initial = _dob != null
        ? _dob!
        : DateTime(now.year - 25, now.month, now.day); // default ~25 anos

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) || initial.isAfter(last)
          ? last
          : initial,
      firstDate: first,
      lastDate: last,
      helpText: 'Seleciona a tua data de nascimento',
      cancelText: 'Cancelar',
      confirmText: 'OK',
    );
    if (picked != null) {
      setState(() {
        _dob = DateTime(picked.year, picked.month, picked.day);
        _dobCtrl.text = _formatDate(_dob!);
      });
    }
  }

  Future<void> _pickTargetDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day).add(const Duration(days: 1)); // amanhã
    final last = DateTime(now.year + 2, now.month, now.day); // até 2 anos

    final initial = _targetDate != null
        ? _targetDate!
        : DateTime(now.year, now.month, now.day).add(const Duration(days: 90)); // sugestão: ~3 meses

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) || initial.isAfter(last)
          ? first
          : initial,
      firstDate: first,
      lastDate: last,
      helpText: 'Quando queres atingir o teu peso alvo? (opcional)',
      cancelText: 'Limpar',
      confirmText: 'OK',
    );

    // O showDatePicker não distingue "Cancelar" vs "Limpar", por isso:
    if (picked == null) {
      // Se quiseres “limpar”, deixa o user apagar manualmente ou adiciona um botão próprio.
      return;
    }

    setState(() {
      _targetDate = DateTime(picked.year, picked.month, picked.day);
      _targetDateCtrl.text = _formatDate(_targetDate!);
    });
  }

  // -------- UI dos passos --------
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
          style: tt.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
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
          style: tt.bodyMedium?.copyWith(
            color: cs.onSurface.withValues(alpha: .70),
          ),
        ),
      ],
    );
  }

  Widget _buildBirthdateStep(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Qual é a tua data de nascimento?',
          style: tt.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _dobCtrl,
          readOnly: true,
          onTap: _pickBirthdate,
          decoration: InputDecoration(
            labelText: 'Data de nascimento',
            hintText: 'DD/MM/AAAA',
            suffixIcon: const Icon(Icons.calendar_today_rounded),
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Isto ajuda a estimar o teu metabolismo basal.',
          style: tt.bodyMedium?.copyWith(
            color: cs.onSurface.withValues(alpha: .70),
          ),
        ),
      ],
    );
  }

  Widget _buildWeightStep(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Qual é o teu peso?',
          style: tt.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _weight,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9,\.]')),
          ],
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Apenas números. Ex.: 72.5',
          style: tt.bodyMedium?.copyWith(
            color: cs.onSurface.withValues(alpha: .70),
          ),
        ),
      ],
    );
  }

  Widget _buildTargetWeightStep(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Qual é o teu peso alvo?',
          style: tt.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _targetWeight,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9,\.]')),
          ],
          decoration: InputDecoration(
            labelText: 'Peso alvo (kg)',
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Define um objetivo realista. Ex.: 68.0',
          style: tt.bodyMedium?.copyWith(
            color: cs.onSurface.withValues(alpha: .70),
          ),
        ),
      ],
    );
  }

  Widget _buildTargetDateStep(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quando queres atingir esse peso? (opcional)',
          style: tt.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _targetDateCtrl,
          readOnly: true,
          onTap: _pickTargetDate,
          decoration: InputDecoration(
            labelText: 'Data alvo',
            hintText: 'DD/MM/AAAA',
            suffixIcon: const Icon(Icons.event_rounded),
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Se não escolheres, usamos só o peso alvo (podes definir a data mais tarde).',
          style: tt.bodyMedium?.copyWith(
            color: cs.onSurface.withValues(alpha: .70),
          ),
        ),
      ],
    );
  }

  Widget _buildHeightStep(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Qual é a tua altura?',
          style: tt.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ex.: 178',
          style: tt.bodyMedium?.copyWith(
            color: cs.onSurface.withValues(alpha: .70),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityStep(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Qual é o teu nível de atividade?',
          style: tt.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _activity,
          items: _activities
              .map(
                (a) => DropdownMenuItem<String>(value: a.$1, child: Text(a.$2)),
              )
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Isto ajuda a estimar as calorias diárias recomendadas.',
          style: tt.bodyMedium?.copyWith(
            color: cs.onSurface.withValues(alpha: .70),
          ),
        ),
      ],
    );
  }

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
                    style: tt.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A preparar o teu dashboard…',
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: .70),
                    ),
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
                    style: tt.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vamos configurar o teu plano diário…',
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: .70),
                    ),
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
                color: active
                    ? cs.primary
                    : cs.outlineVariant.withValues(alpha: .35),
                borderRadius: BorderRadius.circular(12),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: .35),
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
          border: Border.all(
            color: selected ? cs.primary : cs.outline.withValues(alpha: .45),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: .28),
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