import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../data/models/analysis_result.dart';

/// Maps a coaching area to its own glyph.
///
/// Every tip previously carried the same up-arrow, which made a list of them
/// read as one undifferentiated block. The icon is the fastest way to tell
/// "you drifted off topic" from "slow down".
IconData _areaIcon(String area) {
  final a = area.toLowerCase();
  if (a.contains('topic') || a.contains('relevance')) return LucideIcons.target;
  if (a.contains('coheren') || a.contains('structure')) {
    return LucideIcons.listTree;
  }
  if (a.contains('fluen') || a.contains('pace') || a.contains('speed')) {
    return LucideIcons.gauge;
  }
  if (a.contains('vocab') || a.contains('word')) return LucideIcons.bookOpen;
  if (a.contains('grammar')) return LucideIcons.spellCheck;
  if (a.contains('confid') || a.contains('deliver')) {
    return LucideIcons.megaphone;
  }
  if (a.contains('filler') || a.contains('pause')) return LucideIcons.eraser;
  return LucideIcons.lightbulb;
}

class ImprovementTipsCard extends StatelessWidget {
  final List<ImprovementTip> tips;
  final List<String> strengths;

  const ImprovementTipsCard({
    super.key,
    required this.tips,
    required this.strengths,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (strengths.isNotEmpty) ...[
          Text('Strengths', style: context.title),
          const SizedBox(height: Space.md),
          ...strengths.map(
            (s) => _TipRow(
              icon: LucideIcons.circleCheck,
              accent: AppColors.positive,
              area: '',
              tip: s,
            ),
          ),
          const SizedBox(height: Space.xl),
        ],
        if (tips.isNotEmpty) ...[
          Text('How to Improve', style: context.title),
          const SizedBox(height: Space.md),
          ...tips.map(
            (t) => _TipRow(
              icon: _areaIcon(t.area),
              accent: AppColors.accent,
              area: t.area,
              tip: t.tip,
            ),
          ),
        ],
      ],
    );
  }
}

class _TipRow extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String area;
  final String tip;

  const _TipRow({
    required this.icon,
    required this.accent,
    required this.area,
    required this.tip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Space.md),
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: AppColors.raised,
        borderRadius: Radii.mdAll,
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A tinted chip, so the glyph reads as a marker rather than
          // floating loose beside the text.
          Container(
            padding: const EdgeInsets.all(Space.sm),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: Radii.smAll,
            ),
            child: Icon(icon, color: accent, size: IconSize.sm),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (area.isNotEmpty) ...[
                  // Title takes the accent, body stays muted: the two were
                  // previously the same colour, so a tip read as one flat run
                  // of text.
                  Text(area, style: context.cardTitle.copyWith(color: accent)),
                  const SizedBox(height: Space.xs),
                ],
                Text(
                  tip,
                  style: context.body.copyWith(
                    color: AppColors.inkMuted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
