import 'package:flutter/material.dart';
import '../../data/models/analysis_result.dart';
import '../../../../core/constants/app_constants.dart';

class ImprovementTipsCard extends StatelessWidget {
  final List<ImprovementTip> tips;
  final List<String> strengths;

  const ImprovementTipsCard({super.key, required this.tips, required this.strengths});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (strengths.isNotEmpty) ...[
          Text('Strengths', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ...strengths.map((s) => _TipRow(
                icon: Icons.check_circle_rounded,
                color: AppColors.good,
                area: '',
                tip: s,
              )),
          const SizedBox(height: 20),
        ],
        if (tips.isNotEmpty) ...[
          Text('How to Improve', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ...tips.map((t) => _TipRow(
                icon: Icons.arrow_circle_up_rounded,
                color: AppColors.primary,
                area: t.area,
                tip: t.tip,
              )),
        ],
      ],
    );
  }
}

class _TipRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String area;
  final String tip;

  const _TipRow({required this.icon, required this.color, required this.area, required this.tip});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (area.isNotEmpty)
                  Text(area,
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                if (area.isNotEmpty) const SizedBox(height: 3),
                Text(tip, style: const TextStyle(fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
