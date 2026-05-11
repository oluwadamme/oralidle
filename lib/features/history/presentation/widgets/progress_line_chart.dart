import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../analysis/data/models/session_record.dart';
import '../../../../core/constants/app_constants.dart';

class ProgressLineChart extends StatelessWidget {
  final List<SessionRecord> sessions;

  const ProgressLineChart({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) {
    if (sessions.length < 2) {
      return Container(
        height: 80,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Complete 2+ sessions to see your progress trend',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }

    final ordered = [...sessions]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final spots = ordered
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.result.overallScore.toDouble()))
        .toList();

    return SizedBox(
      height: 140,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 25,
                getTitlesWidget: (v, _) =>
                    Text('${v.toInt()}', style: const TextStyle(fontSize: 10, color: AppColors.textMedium)),
              ),
            ),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        '${s.y.toInt()}',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ))
                  .toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.primary,
              barWidth: 2.5,
              dotData: FlDotData(
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.primary,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
