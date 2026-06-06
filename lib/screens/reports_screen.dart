import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/order_provider.dart';
import '../services/export_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _months = 6;

  List<String> _labelsForMonths(int months) {
    final now = DateTime.now();
    final List<String> labels = List.generate(months, (i) {
      final dt = DateTime(now.year, now.month - (months - 1 - i));
      return DateFormat.MMM().format(dt);
    });
    return labels;
  }

  double _maxYFor(List<double> values) {
    final maxValue = values.fold<double>(
      0,
      (max, value) => value > max ? value : max,
    );
    if (maxValue <= 0) return 1;
    return maxValue * 1.12;
  }

  String _formatAmount(double value) {
    if (value >= 1000) {
      final compact = value / 1000;
      return '${compact.toStringAsFixed(compact % 1 == 0 ? 0 : 1)}K';
    }
    return value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
  }

  Widget _monthTitle(List<String> labels, double value, TitleMeta meta) {
    final idx = value.round();
    if (value != idx || idx < 0 || idx >= labels.length) {
      return const SizedBox.shrink();
    }

    return SideTitleWidget(meta: meta, child: Text(labels[idx]));
  }

  Widget _amountTitle(double value, TitleMeta meta) {
    return SideTitleWidget(meta: meta, child: Text(_formatAmount(value)));
  }

  Widget _reportChart({
    required List<double> values,
    required List<String> labels,
    required Color color,
    double? height,
  }) {
    final chart = Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (_months - 1).toDouble(),
            minY: 0,
            maxY: _maxYFor(values),
            gridData: FlGridData(show: true),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  getTitlesWidget: (v, meta) => _monthTitle(labels, v, meta),
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 56,
                  getTitlesWidget: _amountTitle,
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: List.generate(
                  values.length,
                  (i) => FlSpot(i.toDouble(), values[i]),
                ),
                isCurved: true,
                dotData: FlDotData(show: true),
                barWidth: 3,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );

    if (height == null) return Expanded(child: chart);
    return SizedBox(height: height, child: chart);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrderProvider>();
    final sales = provider.salesSeries(months: _months);
    final commission = provider.commissionSeries(months: _months);
    final labels = _labelsForMonths(_months);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Range:'),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: _months,
                  items: [3, 6, 12]
                      .map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text('$m months'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _months = v ?? 6),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _exportCsv(provider),
                  icon: const Icon(Icons.table_chart_rounded),
                  label: const Text('Export CSV'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Sales', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _reportChart(
              values: sales,
              labels: labels,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 12),
            Text('Commission', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _reportChart(
              height: 180,
              values: commission,
              labels: labels,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  void _exportCsv(OrderProvider provider) async {
    final now = DateTime.now();
    final monthsBack = _months;
    final cutoff = DateTime(now.year, now.month - monthsBack + 1);
    final orders = provider.orders
        .where((o) => o.date.isAfter(cutoff) || o.date.isAtSameMomentAs(cutoff))
        .toList();
    try {
      await ExportService.exportToCsv(orders);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Export started')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }
}
