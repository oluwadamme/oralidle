import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../data/models/analysis_result.dart';
import '../../../../core/constants/app_constants.dart';

class SpeechRadarChart extends StatelessWidget {
  final SpeechScores scores;

  const SpeechRadarChart({super.key, required this.scores});

  static const _labels = ['Fluency', 'Vocab', 'Grammar', 'Coherence', 'Topic', 'Confidence'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: RadarChart(
        RadarChartData(
          radarShape: RadarShape.polygon,
          tickCount: 4,
          ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 0),
          radarBorderData: BorderSide(color: Colors.grey.shade300, width: 1),
          gridBorderData: BorderSide(color: Colors.grey.shade200, width: 1),
          titleTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
          getTitle: (index, angle) => RadarChartTitle(text: _labels[index], angle: 0),
          dataSets: [
            RadarDataSet(
              dataEntries: scores.asList.map((v) => RadarEntry(value: v)).toList(),
              fillColor: AppColors.primary.withValues(alpha: 0.18),
              borderColor: AppColors.primary,
              borderWidth: 2.5,
              entryRadius: 4,
            ),
          ],
          tickBorderData: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
    );
  }
}
