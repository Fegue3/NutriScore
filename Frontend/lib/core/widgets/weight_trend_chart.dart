// lib/core/widgets/weight_trend_chart.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../data/weight_api.dart';

class WeightPoint {
  final DateTime date;
  final double weightKg;
  WeightPoint({required this.date, required this.weightKg});
}

/// Card que carrega o histórico via API e desenha o gráfico (linha + gradiente + tooltip)
class WeightTrendCard extends StatefulWidget {
  const WeightTrendCard({
    super.key,
    this.daysBack = 120,
    this.title = 'Evolução do peso',
    this.showLegend = true,
  });

  final int daysBack;
  final String title;
  final bool showLegend;

  @override
  State<WeightTrendCard> createState() => _WeightTrendCardState();
}

class _WeightTrendCardState extends State<WeightTrendCard> {
  bool _loading = true;
  String? _error;
  List<WeightPoint> _points = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: widget.daysBack));
      final to = DateTime(now.year, now.month, now.day);

      final res = await WeightApi.I.getRange(from: from, to: to);
      final raw = (res['points'] as List?) ?? [];
      _points = raw.map((p) {
        // espera 'YYYY-MM-DD'
        final d = DateTime.parse(p['date'] as String);
        final w = (p['weightKg'] as num).toDouble();
        return WeightPoint(date: d, weightKg: w);
      }).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
    } catch (e) {
      _error = 'Não foi possível carregar o histórico de peso.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outline.withOpacity(.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // header
            Row(
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Atualizar',
                  onPressed: _loading ? null : _load,
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 240,
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _error != null
                      ? Center(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: cs.onSurface.withOpacity(.7),
                              fontSize: 13,
                            ),
                          ),
                        )
                      : (_points.isEmpty
                          ? Center(
                              child: Text(
                                'Sem registos ainda',
                                style: TextStyle(
                                  color: cs.onSurface.withOpacity(.7),
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : _buildChart(cs)),
            ),
            if (widget.showLegend) const SizedBox(height: 8),
            if (widget.showLegend && _points.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Toque e arraste para ver valores',
                  style: TextStyle(
                    color: cs.onSurface.withOpacity(.6),
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(ColorScheme cs) {
    // X será o índice sortido (0..n-1) -> é simples e evita problemas de escala com datas
    final minY = _points.map((e) => e.weightKg).reduce((a, b) => a < b ? a : b);
    final maxY = _points.map((e) => e.weightKg).reduce((a, b) => a > b ? a : b);
    final margin = ((maxY - minY).abs() * 0.06).clamp(0.6, 2.0);

    return LineChart(
      LineChartData(
        minY: minY - margin,
        maxY: maxY + margin,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: cs.outline.withOpacity(.22),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, _) => Text(
                v.toStringAsFixed(1),
                style: TextStyle(
                  color: cs.onSurface.withOpacity(.72),
                  fontSize: 10,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: (_points.length / 5).clamp(1, 999).toDouble(),
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= _points.length) {
                  return const SizedBox.shrink();
                }
                final d = _points[i].date;
                final label =
                    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: cs.onSurface.withOpacity(.72),
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipRoundedRadius: 12,
            tooltipPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            tooltipBgColor: cs.surface,
            getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
              final i = spot.x.toInt();
              final p = _points[i];
              final date =
                  '${p.date.day.toString().padLeft(2, '0')}/${p.date.month.toString().padLeft(2, '0')}/${p.date.year}';
              return LineTooltipItem(
                '$date\n${p.weightKg.toStringAsFixed(1)} kg',
                TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              );
            }).toList(),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            barWidth: 3,
            color: cs.primary,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 3.5,
                color: cs.primary,
                strokeWidth: 2,
                strokeColor: cs.surface,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  cs.primary.withOpacity(.25),
                  cs.primary.withOpacity(.05),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            spots: _points
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value.weightKg))
                .toList(),
          ),
        ],
      ),
    );
  }
}
