import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/services.dart'; // para HapticFeedback
import '../../data/products_api.dart';
import 'package:dio/dio.dart';

class ScannerScreen extends StatefulWidget {
  final String? initialMealLabelPt; // ex: "Almoço"
  final String? isoDate; // ex: "2025-10-11T00:00:00.000"
  const ScannerScreen({super.key, this.initialMealLabelPt, this.isoDate});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _c = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  bool _busy = false;
  String? _last;
  Timer? _cooldown;

  DateTime get _date =>
      (widget.isoDate != null ? DateTime.tryParse(widget.isoDate!) : null) ??
      DateTime.now();

  String? get _mealLabelPt => widget.initialMealLabelPt;

  @override
  void dispose() {
    _c.dispose();
    _cooldown?.cancel();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture cap) async {
    if (_busy) return;
    final code = cap.barcodes.first.rawValue;
    if (code == null || code.isEmpty || code == _last) return;

    _busy = true;
    _last = code;

    try {
      HapticFeedback.mediumImpact(); // vibração nativa (sem plugin)

      final detail = await ProductsApi.I.getByBarcode(code);

      if (!mounted) return;

      // >>> usa PUSH para permitir voltar <<<
      await context.pushNamed(
        'productDetail',
        extra: {
          'barcode': detail.barcode,
          'initialMeal': _mealLabelPt,
          'date': _date,
          'name': detail.name,
          'brand': detail.brand,
          'nutriScore': detail.nutriScore,
          'baseQuantityLabel': detail.quantity ?? '100 g',
          'kcalPerBase': detail.kcal100g ?? 0,
          'proteinGPerBase': detail.protein100g,
          'carbsGPerBase': detail.carbs100g,
          'fatGPerBase': detail.fat100g,
          'sugarsGPerBase': detail.sugars100g,
          'satFatGPerBase': detail.satFat100g,
          'fiberGPerBase': detail.fiber100g,
          'saltGPerBase': detail.salt100g,
          'sodiumGPerBase': detail.sodium100g,
        },
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (!mounted) return;

      if (status == 404) {
        // não encontrado no backend
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Produto não encontrado. Tenta outro código.'),
          ),
        );
      } else if (status == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sessão expirada. Faz login novamente.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao obter produto (HTTP $status).')),
        );
      }

      // rearmar o scanner para novo scan
      _last = null;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro inesperado: $e')));
      _last = null;
    } finally {
      // sem cooldown longo; volta a aceitar scans assim que regressa
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(title: const Text('Scanner'), backgroundColor: cs.surface),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _c, onDetect: _onDetect),
          // moldura simples
          Align(
            alignment: const Alignment(0, -0.1),
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.primary, width: 3),
              ),
            ),
          ),
          // ações
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _pill('Flash', Icons.flash_on, _c.toggleTorch, cs),
                _pill('Inverter', Icons.cameraswitch, _c.switchCamera, cs),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(
    String label,
    IconData icon,
    VoidCallback onTap,
    ColorScheme cs,
  ) {
    return Material(
      color: cs.primary,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: cs.onPrimary),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: cs.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
