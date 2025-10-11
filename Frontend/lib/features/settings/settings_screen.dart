// lib/features/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart' show AppColors;
import '../../app/di.dart' as di; // di.di.authRepository.logout()
import '../../data/auth_api.dart'; // baseUrl + upsertGoals + deleteAccount
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:file_saver/file_saver.dart';
import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../../data/weight_api.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = true;

  // Perfil
  String? _name;
  String? _email;

  // Preferências locais (TODO: persistir)
  bool _notifMeals = true;
  bool _notifSmart = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  /// Exemplo de dados a exportar (troca por dados reais da tua app)
  Future<List<List<String>>> _getExportRows() async {
    return [
      ['Data', 'Refeição', 'Nome', 'kcal'],
      ['2025-01-01', 'Almoço', 'Arroz', '250'],
      ['2025-01-01', 'Jantar', 'Frango', '420'],
    ];
  }

  /// Constrói o PDF e devolve os bytes
  Future<Uint8List> _buildPdfBytes() async {
    final doc = pw.Document();

    final rows = await _getExportRows();
    final header = rows.first;
    final data = rows.skip(1).toList();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Exportação NutriScore',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Gerado em: ${DateTime.now()}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 18),
              pw.TableHelper.fromTextArray(
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
                headers: header,
                data: data,
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.5,
                ),
                headerAlignment: pw.Alignment.centerLeft,
                cellStyle: const pw.TextStyle(fontSize: 11),
              ),
              pw.SizedBox(height: 12),
              pw.Divider(),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  '© ${DateTime.now().year} NutriScore',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  /// GUARDAR: abre o picker do SO para escolher a pasta (Downloads, etc.)
  Future<void> _savePdf() async {
    try {
      final bytes = await _buildPdfBytes();
      final name = 'nutriscore_${DateTime.now().millisecondsSinceEpoch}';
      await FileSaver.instance.saveFile(
        name: name,
        bytes: bytes,
        ext: 'pdf',
        mimeType: MimeType.pdf,
      );
      if (!mounted) return;
      _toastOk('PDF guardado');
    } catch (e) {
      if (!mounted) return;
      _toastErr('Falhou ao guardar: $e');
    }
  }

  /// PARTILHAR: grava temporário e abre a folha de partilha
  Future<void> _sharePdf() async {
    try {
      final bytes = await _buildPdfBytes();
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/nutriscore_export.pdf';
      final file = File(path);
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(path)], text: 'Export NutriScore (PDF)');
    } catch (e) {
      if (!mounted) return;
      _toastErr('Falhou ao partilhar: $e');
    }
  }

  /// Folha de ações com as duas opções
  Future<void> _showExportActions() async {
    final cs = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Exportar dados (PDF)',
                style: Theme.of(ctx).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(Icons.download_rounded, color: cs.primary),
                title: const Text('Guardar ficheiro…'),
                subtitle: const Text('Escolher pasta (ex.: Downloads)'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _savePdf();
                },
              ),
              ListTile(
                leading: Icon(Icons.ios_share_rounded, color: cs.primary),
                title: const Text('Partilhar…'),
                subtitle: const Text('Enviar por WhatsApp, Email, etc.'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _sharePdf();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _clearLocalCache() async {
    try {
      // Cache de imagens do Flutter
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      // Cache de ficheiros (network)
      await DefaultCacheManager().emptyCache();

      if (!mounted) return;
      _toastOk('Cache limpa.');
    } catch (e) {
      if (!mounted) return;
      _toastErr('Falha ao limpar cache: $e');
    }
  }

  Future<void> _openPrivacyPolicy() async {
    // se tiveres uma rota interna, usa context.go('/privacy');
    const url = 'https://example.com/privacy'; // troca pelo teu link real
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      _toastErr('Não consegui abrir a política de privacidade.');
    }
  }

  void _toastOk(String msg) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: cs.primary, // verde da app
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _toastErr(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ===========================================================================
  // Bootstrap
  // ===========================================================================
  Future<void> _bootstrap() async {
  try {
    // PERFIL
    try {
      final me = await AuthApi.I.getMe();
      _name = me.name;
      _email = me.email;
    } catch (_) {}

    // (Opcional) se quiseres guardar localmente o último peso para usar noutro lado
    // final latest = await WeightApi.I.getLatest();
    // final lastKg = (latest['weightKg'] as num?);
    // podes ignorar se não precisas aqui
  } catch (_) {
    /* no-op */
  }
  
  if (!mounted) return;
  setState(() => _loading = false);
}


  // ===========================================================================
  // Ações
  // ===========================================================================
  Future<void> _setCurrentWeight() async {
    // pré-preencher com o último peso vindo do backend (melhor que goals)
    String initial = '';
    try {
      final latest = await WeightApi.I.getLatest();
      final num? w = latest['weightKg'] as num?;
      if (w != null) initial = w.toString();
    } catch (_) {
      // fallback antigo (se quiseres): tenta nos goals
      try {
        final g = await AuthApi.I.getGoals();
        final num? w = g['currentWeightKg'] as num?;
        if (w != null) initial = w.toString();
      } catch (_) {}
    }

    // Check if widget is still mounted before using context
    if (!mounted) return;

    final controller = TextEditingController(text: initial);

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final insets = MediaQuery.of(ctx).viewInsets;
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + insets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Definir peso atual',
                style: Theme.of(ctx).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Peso (kg)',
                  hintText: 'Ex.: 72.5',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Guardar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (ok == true) {
      final txt = controller.text.replaceAll(',', '.').trim();
      final kg = double.tryParse(txt);
      if (kg == null || kg <= 0 || kg > 400) {
        _toastErr('Peso inválido.');
        return;
      }
      try {
        await WeightApi.I.upsertWeight(weightKg: kg);
        if (!mounted) return;
        _toastOk('Peso atualizado');
        await _bootstrap(); // refresca info do topo, se necessário
      } catch (e) {
        if (!mounted) return;
        _toastErr('Falha ao guardar: $e');
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar conta'),
        content: const Text(
          'Isto é definitivo. Queres mesmo apagar a tua conta e todos os dados?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.ripeRed),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await AuthApi.I.deleteAccount();
      } catch (_) {
        /* TODO: mostrar erro detalhado se precisares */
      }
      await di.di.authRepository.logout();
      if (!mounted) return;
      GoRouter.of(context).go('/');
    }
  }

  // ===========================================================================
  // UI
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.softOffWhite,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: cs.primary,
        foregroundColor: Colors.white,
        title: Text(
          'Definições',
          style: tt.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _bootstrap,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
            // ===== CONTA =====
            _SectionHeader('Conta'),
            _Card(
              child: Column(
                children: [
                  _ProfileRow(
                    title: _name ?? (_email ?? 'Utilizador'),
                    subtitle: _name != null && _name!.isNotEmpty
                        ? (_email ?? '')
                        : '',
                  ),
                  const SizedBox(height: 8),
                  _DividerSoft(),
                  _Tile(
                    icon: Icons.manage_accounts_outlined,
                    iconBg: AppColors.freshGreen.withAlpha(24),
                    iconColor: AppColors.freshGreen,
                    title: 'Editar informações do utilizador',
                    subtitle: 'Nome, preferências e dados básicos.',
                    onTap: () => context.go('/settings/user'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            // ===== NOTIFICAÇÕES =====
            _SectionHeader('Notificações (TODO)'),
            _Card(
              child: Column(
                children: [
                  _SwitchTile(
                    icon: Icons.restaurant_outlined,
                    iconBg: AppColors.freshGreen.withAlpha(24),
                    title: 'Lembretes de refeições',
                    value: _notifMeals,
                    onChanged: (v) => setState(() => _notifMeals = v),
                  ),
                  _DividerSoft(),
                  _SwitchTile(
                    icon: Icons.alarm_outlined,
                    iconBg: AppColors.freshGreen.withAlpha(24),
                    title: 'Lembretes inteligentes',
                    subtitle: 'Sugestões com base no teu padrão diário.',
                    value: _notifSmart,
                    onChanged: (v) => setState(() => _notifSmart = v),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            // ===== DIETA & OBJETIVOS =====
            _SectionHeader('Dieta & Objetivos'),
            _Card(
              child: Column(
                children: [
                  _Tile(
                    icon: Icons.monitor_weight_outlined,
                    iconBg: AppColors.freshGreen.withAlpha(24),
                    iconColor: AppColors.freshGreen,
                    title: 'Definir peso atual',
                    onTap: _setCurrentWeight,
                  ),
                  _DividerSoft(),
                  _Tile(
                    icon: Icons.bar_chart_outlined,
                    iconBg: AppColors.freshGreen.withAlpha(24),
                    iconColor: AppColors.freshGreen,
                    title: 'Ver progresso de nutrição',
                    onTap: () => context.go('/nutrition'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            // ===== DADOS & PRIVACIDADE =====
            _SectionHeader('Dados & Privacidade'),
            _Card(
              child: Column(
                children: [
                  _Tile(
                    icon: Icons.download_outlined,
                    iconBg: AppColors.freshGreen.withAlpha(24),
                    iconColor: AppColors.freshGreen,
                    title: 'Exportar dados (PDF)',
                    onTap: _showExportActions,
                  ),
                  _DividerSoft(),
                  _Tile(
                    icon: Icons.cleaning_services_outlined,
                    iconBg: AppColors.freshGreen.withAlpha(24),
                    iconColor: AppColors.freshGreen,
                    title: 'Limpar cache local',
                    onTap: _clearLocalCache,
                  ),
                  _DividerSoft(),
                  _Tile(
                    icon: Icons.privacy_tip_outlined,
                    iconBg: AppColors.freshGreen.withAlpha(24),
                    iconColor: AppColors.freshGreen,
                    title: 'Política de privacidade',
                    onTap: _openPrivacyPolicy,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            // ===== DANGER ZONE =====
            _SectionHeaderDanger('Danger Zone'),
            _DangerCard(
              child: Column(
                children: [
                  _DangerTile(
                    icon: Icons.delete_forever_outlined,
                    title: 'Apagar conta',
                    subtitle: 'Remove todos os teus dados do servidor.',
                    onTap: _confirmDeleteAccount,
                  ),
                  _DangerDivider(),
                  _DangerTile(
                    icon: Icons.logout,
                    title: 'Terminar sessão',
                    onTap: () async {
                      final router = GoRouter.of(context);
                      await di.di.authRepository.logout();
                      if (!mounted) return;
                      router.go('/');
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            // ===== SOBRE =====
            _SectionHeader('Sobre'),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _AboutRow(name: 'NutriScore', version: 'v1.0.0'),
                  SizedBox(height: 8),
                  Text(
                    'Aplicação para escolhas alimentares conscientes.\n'
                    'Área 2 – Segurança Alimentar e Agricultura Sustentável.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Widgets / Helpers
// ============================================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: tt.headlineMedium?.copyWith(
          color: AppColors.charcoal,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// Título vermelho para a Danger Zone
class _SectionHeaderDanger extends StatelessWidget {
  final String title;
  const _SectionHeaderDanger(this.title);

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: tt.headlineMedium?.copyWith(
          color: AppColors.ripeRed,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightSage,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

// Card específico vermelho (tinte leve) para a Danger Zone
class _DangerCard extends StatelessWidget {
  final Widget child;
  const _DangerCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.ripeRed.withAlpha(16), // fundo com leve vermelho
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.ripeRed.withAlpha(120), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final String title;
  final String subtitle;
  const _ProfileRow({required this.title, this.subtitle = ''});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.freshGreen.withAlpha(40),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            (title.isNotEmpty ? title[0] : 'U').toUpperCase(),
            style: tt.titleLarge?.copyWith(
              color: AppColors.freshGreen,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: tt.bodyMedium?.copyWith(color: AppColors.coolGray),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _Tile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: tt.bodyLarge?.copyWith(
                      color: AppColors.charcoal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: tt.bodyMedium?.copyWith(
                          color: AppColors.coolGray,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}

// Tiles específicos para Danger Zone (vermelhos por defeito)
class _DangerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _DangerTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.ripeRed.withAlpha(22),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 20, color: AppColors.ripeRed),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: tt.bodyLarge?.copyWith(
                      color: AppColors.ripeRed,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: tt.bodyMedium?.copyWith(
                          color: AppColors.ripeRed.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}

class _DangerDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 12,
      thickness: 1,
      color: AppColors.ripeRed.withValues(alpha: 0.25),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.iconBg,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: AppColors.freshGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: tt.bodyMedium?.copyWith(color: AppColors.coolGray),
                    ),
                  ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}


class _DividerSoft extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 12,
      thickness: 1,
      color: Colors.black12.withValues(alpha: 0.06),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String name;
  final String version;
  const _AboutRow({required this.name, required this.version});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Text(version, style: tt.bodyMedium),
      ],
    );
  }
}
