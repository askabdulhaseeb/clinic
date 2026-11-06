import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/karachi_date.dart';
import '../../../../core/utils/money.dart';
import '../viewmodels/dashboard_vm.dart';

const double _chartHeight = 180;

/// Net amount per label as vertical bars with the amounts listed under
/// the chart (UI_DESIGN §4.8).
class BreakdownChart extends StatelessWidget {
  const BreakdownChart({super.key, required this.entries});

  final List<BreakdownEntry> entries;

  @override
  Widget build(BuildContext context) {
    return AmountBars(
      entries: [
        for (final e in entries)
          AmountEntry(id: e.id, label: e.label, amount: e.bucket.net),
      ],
      detail: (i) => '${entries[i].bucket.visits} visits',
    );
  }
}

class AmountBars extends StatelessWidget {
  const AmountBars({super.key, required this.entries, this.detail});

  final List<AmountEntry> entries;
  final String Function(int index)? detail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'Nothing in this range',
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: scheme.outline),
        ),
      );
    }
    final maxY = entries
        .map((e) => e.amount)
        .fold(0, (m, v) => v > m ? v : m)
        .toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _chartHeight,
          child: BarChart(
            BarChartData(
              maxY: maxY <= 0 ? 1 : maxY * 1.15,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (i < 0 || i >= entries.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _short(entries[i].label),
                          style: text.labelSmall,
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                    '${entries[group.x].label}\n${Money.format(rod.toY.round())}',
                    text.labelMedium ?? const TextStyle(),
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < entries.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: entries[i].amount.toDouble(),
                        width: 22,
                        color: scheme.primary,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < entries.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(child: Text(entries[i].label)),
                if (detail != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      detail!(i),
                      style: text.bodySmall?.copyWith(color: scheme.outline),
                    ),
                  ),
                Text(
                  Money.format(entries[i].amount),
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _short(String s) =>
      s.length <= 10 ? s : '${s.substring(0, 9)}…';
}

/// Visits per day of the range as a line.
class VisitsLineChart extends StatelessWidget {
  const VisitsLineChart({super.key, required this.days});

  final List<DayCount> days;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final maxY = days.map((d) => d.visits).fold(0, (m, v) => v > m ? v : m);
    final step = days.length <= 7 ? 1 : (days.length / 6).ceil();
    return SizedBox(
      height: _chartHeight,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: (maxY <= 0 ? 1 : maxY * 1.2).toDouble(),
          gridData: const FlGridData(drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(),
            topTitles: const AxisTitles(),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 28),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: step.toDouble(),
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= days.length || v != i) {
                    return const SizedBox.shrink();
                  }
                  final d = KarachiDate.parse(days[i].date);
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${d.day}/${d.month}', style: text.labelSmall),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${KarachiDate.display(days[s.x.toInt()].date)}\n'
                    '${s.y.round()} visits',
                    text.labelMedium ?? const TextStyle(),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < days.length; i++)
                  FlSpot(i.toDouble(), days[i].visits.toDouble()),
              ],
              isCurved: false,
              color: scheme.primary,
              barWidth: 3,
              dotData: FlDotData(show: days.length <= 31),
              belowBarData: BarAreaData(
                show: true,
                color: scheme.primary.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
