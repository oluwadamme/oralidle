import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../providers/history_provider.dart';
import '../widgets/session_tile.dart';
import '../widgets/progress_line_chart.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/theme/text_styles.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(historyProvider);

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: sessions.isEmpty
                ? _EmptyState()
                : CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: centeredPagePadding(
                            MediaQuery.sizeOf(context).width,
                            top: 16,
                            bottom: 8,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'My Progress',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 16),
                              SurfaceCard(
                                padding: const EdgeInsets.all(16),
                                radius: 16,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Score Trend',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(color: AppColors.inkMuted),
                                    ),
                                    const SizedBox(height: 12),
                                    ProgressLineChart(sessions: sessions),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              _StatsRow(sessions: sessions),
                              const SizedBox(height: 24),
                              Text(
                                'All Sessions (${sessions.length})',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => Padding(
                            padding: centeredPagePadding(
                              MediaQuery.sizeOf(context).width,
                            ),
                            child: SessionTile(
                              record: sessions[index],
                              onTap: () => context.push(
                                AppRoutes.results,
                                extra: sessions[index],
                              ),
                            ),
                          ),
                          childCount: sessions.length,
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.raised2,
                border: Border.all(color: AppColors.borderControl),
              ),
              child: const Icon(
                LucideIcons.history,
                size: 32,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No sessions yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Complete your first recording to see results here',
              style: context.body.copyWith(color: AppColors.inkMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final List sessions;
  const _StatsRow({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final scores = sessions.map((s) => s.result.overallScore as int).toList();
    final avg = scores.isEmpty
        ? 0
        : scores.reduce((a, b) => a + b) ~/ scores.length;
    final best = scores.isEmpty ? 0 : scores.reduce((a, b) => a > b ? a : b);

    return Row(
      children: [
        Expanded(
          child: _StatChip(label: 'Sessions', value: '${sessions.length}'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatChip(
            label: 'Avg Score',
            value: '$avg',
            color: AppColors.scoreColor(avg),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatChip(
            label: 'Best Score',
            value: '$best',
            color: AppColors.scoreColor(best),
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    this.color = AppColors.ink,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.raised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: context.title.copyWith(
              color: color,
              fontWeight: AppFontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: context.overline.copyWith(color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}
