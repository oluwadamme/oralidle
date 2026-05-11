import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/history_provider.dart';
import '../widgets/session_tile.dart';
import '../widgets/progress_line_chart.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/glass_card.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(historyProvider);

    return Scaffold(
      body: Stack(
        children: [
          const Positioned(
            top: -40,
            right: -50,
            child: AmbientOrb(color: AppColors.primary, size: 200),
          ),
          const Positioned(
            bottom: 80,
            left: -50,
            child: AmbientOrb(color: AppColors.amber, size: 160),
          ),
          SafeArea(
            child: sessions.isEmpty
                ? _EmptyState()
                : CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('My Progress',
                                  style: Theme.of(context).textTheme.headlineSmall),
                              const SizedBox(height: 16),
                              GlassCard(
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
                                          ?.copyWith(color: AppColors.textMedium),
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
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: SessionTile(
                              record: sessions[index],
                              onTap: () =>
                                  context.push(AppRoutes.results, extra: sessions[index]),
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
                color: AppColors.primary.withValues(alpha: 0.1),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: const Icon(Icons.history_rounded, size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              'No sessions yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Complete your first recording to see results here',
              style: TextStyle(color: AppColors.textMedium, fontSize: 14),
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
    final avg = scores.isEmpty ? 0 : scores.reduce((a, b) => a + b) ~/ scores.length;
    final best = scores.isEmpty ? 0 : scores.reduce((a, b) => a > b ? a : b);

    return Row(
      children: [
        Expanded(child: _StatChip(label: 'Sessions', value: '${sessions.length}')),
        const SizedBox(width: 10),
        Expanded(child: _StatChip(label: 'Avg Score', value: '$avg')),
        const SizedBox(width: 10),
        Expanded(
            child: _StatChip(label: 'Best Score', value: '$best', color: AppColors.good)),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({required this.label, required this.value, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textMedium),
          ),
        ],
      ),
    );
  }
}
