import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/home_provider.dart';
import '../widgets/stat_summary_card.dart';
import '../../../history/presentation/widgets/session_tile.dart';
import '../../../history/presentation/widgets/progress_line_chart.dart';
import '../../../history/providers/history_provider.dart';
import '../../../../core/constants/app_constants.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider);
    final recent = ref.watch(recentSessionsProvider);
    final allSessions = ref.watch(historyProvider);

    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$greeting, Speaker!',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.local_fire_department_rounded,
                                color: Colors.orangeAccent, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              streak > 0
                                  ? '$streak day streak — keep it up!'
                                  : 'Start your streak today!',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9), fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.history_rounded, color: Colors.white),
                onPressed: () => context.push(AppRoutes.history),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => context.push(AppRoutes.topics),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(58),
                      backgroundColor: AppColors.primary,
                    ),
                    icon: const Icon(Icons.mic_rounded, size: 22),
                    label: const Text('Start Speaking', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(height: 20),
                  if (allSessions.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: StatSummaryCard(
                            icon: Icons.bar_chart_rounded,
                            value: '${allSessions.length}',
                            label: 'Sessions',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatSummaryCard(
                            icon: Icons.emoji_events_rounded,
                            value: '${allSessions.map((s) => s.result.overallScore).reduce((a, b) => a > b ? a : b)}',
                            label: 'Best Score',
                            color: AppColors.good,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatSummaryCard(
                            icon: Icons.trending_up_rounded,
                            value: '${allSessions.map((s) => s.result.overallScore).reduce((a, b) => a + b) ~/ allSessions.length}',
                            label: 'Avg Score',
                            color: AppColors.fair,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('Progress', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    ProgressLineChart(sessions: allSessions),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Recent Sessions', style: Theme.of(context).textTheme.titleMedium),
                        if (allSessions.length > 3)
                          TextButton(
                            onPressed: () => context.push(AppRoutes.history),
                            child: const Text('See all'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...recent.map((s) => SessionTile(
                          record: s,
                          onTap: () => context.push(AppRoutes.results, extra: s),
                        )),
                  ] else ...[
                    _EmptyState(),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
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
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          const Icon(Icons.mic_none_rounded, size: 52, color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            'Ready to improve your English?',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Pick a topic, speak for 1–2 minutes, and get detailed AI coaching on your fluency, grammar, and more.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
