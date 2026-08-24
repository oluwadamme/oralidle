import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../data/models/analysis_result.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/text_styles.dart';

class SpeechRadarChart extends StatelessWidget {
  final SpeechScores scores;

  const SpeechRadarChart({super.key, required this.scores});

  static const _labels = [
    'Fluency',
    'Vocab',
    'Grammar',
    'Coherence',
    'Topic',
    'Confidence',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: RadarChart(
        RadarChartData(
          radarShape: RadarShape.polygon,
          tickCount: 4,
          ticksTextStyle: context.overline.copyWith(color: Colors.transparent),
          radarBorderData: const BorderSide(color: AppColors.line, width: 1),
          gridBorderData: const BorderSide(color: AppColors.line, width: 1),
          tickBorderData: const BorderSide(color: AppColors.line, width: 1),
          titleTextStyle: context.overline.copyWith(
            color: AppColors.inkMuted,
            fontWeight: AppFontWeight.w600,
          ),
          getTitle: (index, angle) =>
              RadarChartTitle(text: _labels[index], angle: 0),
          dataSets: [
            RadarDataSet(
              dataEntries: scores.asList
                  .map((v) => RadarEntry(value: v))
                  .toList(),
              fillColor: AppColors.raised2,
              borderColor: AppColors.ink,
              borderWidth: 2.5,
              entryRadius: 4,
            ),
          ],
        ),
      ),
    );
  }
}
