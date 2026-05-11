import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/history_provider.dart';
import '../widgets/session_tile.dart';
import '../widgets/progress_line_chart.dart';
import '../../../../core/constants/app_constants.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Progress')),
      body: sessions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded, size: 60, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No sessions yet',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text('Complete your first recording to see results here'),
                ],
              ),
            )
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Overall Progress', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        ProgressLineChart(sessions: sessions),
                        const SizedBox(height: 8),
                        _StatsRow(sessions: sessions),
                        const SizedBox(height: 20),
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
                        onTap: () => context.push(AppRoutes.results, extra: sessions[index]),
                      ),
                    ),
                    childCount: sessions.length,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
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
        const SizedBox(width: 8),
        Expanded(child: _StatChip(label: 'Avg Score', value: '$avg')),
        const SizedBox(width: 8),
        Expanded(child: _StatChip(label: 'Best Score', value: '$best', color: AppColors.good)),
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
