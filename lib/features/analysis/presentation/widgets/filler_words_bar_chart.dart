import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';

class FillerWordsBarChart extends StatelessWidget {
  final Map<String, int> fillerWords;

  const FillerWordsBarChart({super.key, required this.fillerWords});

  @override
  Widget build(BuildContext context) {
    if (fillerWords.isEmpty) {
      return Container(
        height: 80,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.good.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.good, size: 18),
            SizedBox(width: 8),
            Text('No filler words detected! Great job.',
                style: TextStyle(color: AppColors.good, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    final sorted = fillerWords.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = sorted.first.value.toDouble();

    return SizedBox(
      height: 28.0 * sorted.length + 20,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.start,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 72,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < sorted.length) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '"${sorted[idx].key}"',
                        style: const TextStyle(fontSize: 12),
                        textAlign: TextAlign.right,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) =>
                    Text('${value.toInt()}×', style: const TextStyle(fontSize: 10)),
              ),
            ),
          ),
          gridData: FlGridData(
            drawVerticalLine: true,
            drawHorizontalLine: false,
            getDrawingVerticalLine: (_) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          maxY: maxVal + 1,
          barGroups: List.generate(sorted.length, (i) {
            final count = sorted[i].value.toDouble();
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: count,
                  color: AppColors.fair,
                  width: 16,
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                  rodStackItems: [],
                ),
              ],
            );
          }),
        ),
        duration: const Duration(milliseconds: 400),
      ),
    );
  }
}
