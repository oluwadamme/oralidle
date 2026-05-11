import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/home_provider.dart';
import '../widgets/stat_summary_card.dart';
import '../../../history/presentation/widgets/session_tile.dart';
import '../../../history/presentation/widgets/progress_line_chart.dart';
import '../../../history/providers/history_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/glass_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider);
    final recent = ref.watch(recentSessionsProvider);
    final allSessions = ref.watch(historyProvider);

    final hour = DateTime.now().hour;
    final greeting =
        hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';

    final level = _levelTitle(allSessions.length);

    return Scaffold(
      body: Stack(
        children: [
          // Ambient orbs
          const Positioned(
            top: -40,
            right: -40,
            child: AmbientOrb(color: AppColors.primary, size: 220),
          ),
          const Positioned(
            top: 120,
            left: -60,
            child: AmbientOrb(color: AppColors.amber, size: 140),
          ),
          // Content
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Header ────────────────────────────────────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$greeting,',
                                    style:
                                        Theme.of(context).textTheme.bodyLarge?.copyWith(
                                              color: AppColors.textMedium,
                                            ),
                                  ),
                                  Text(
                                    'Speaker!',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineLarge
                                        ?.copyWith(height: 1.1),
                                  ),
                                ],
                              ),
                            ),
                            // Level badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary.withValues(alpha: 0.25),
                                    AppColors.primaryLight.withValues(alpha: 0.15),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                level,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Streak chip
                        if (streak > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.amber.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: AppColors.amber.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.local_fire_department_rounded,
                                    color: AppColors.amber, size: 15),
                                const SizedBox(width: 4),
                                Text(
                                  '$streak-day streak — keep it up!',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.amber,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 28),

                        // ── Start Practice CTA ────────────────────────────
                        GestureDetector(
                          onTap: () => context.go(AppRoutes.topics),
                          child: Container(
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primaryLight, AppColors.primary],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.35),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.mic_rounded,
                                    color: Color(0xFF490080), size: 22),
                                SizedBox(width: 10),
                                Text(
                                  'Start Practice',
                                  style: TextStyle(
                                    color: Color(0xFF490080),
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Stats row ─────────────────────────────────────
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
                                  value:
                                      '${allSessions.map((s) => s.result.overallScore).reduce((a, b) => a > b ? a : b)}',
                                  label: 'Best Score',
                                  color: AppColors.good,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: StatSummaryCard(
                                  icon: Icons.trending_up_rounded,
                                  value:
                                      '${allSessions.map((s) => s.result.overallScore).reduce((a, b) => a + b) ~/ allSessions.length}',
                                  label: 'Avg Score',
                                  color: AppColors.fair,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // ── Progress chart ────────────────────────────
                          Text('Progress',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 10),
                          GlassCard(
                            padding: const EdgeInsets.all(16),
                            child: ProgressLineChart(sessions: allSessions),
                          ),
                          const SizedBox(height: 24),

                          // ── Recent sessions ───────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Recent Sessions',
                                  style: Theme.of(context).textTheme.titleMedium),
                              if (allSessions.length > 3)
                                TextButton(
                                  onPressed: () => context.go(AppRoutes.history),
                                  child: const Text('See all',
                                      style: TextStyle(color: AppColors.primary)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...recent.map((s) => SessionTile(
                                record: s,
                                onTap: () =>
                                    context.push(AppRoutes.results, extra: s),
                              )),
                        ] else
                          _EmptyState(onStart: () => context.go(AppRoutes.topics)),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _levelTitle(int sessions) {
    if (sessions >= 20) return '✦ Eloquent Speaker';
    if (sessions >= 10) return '◆ Articulate';
    if (sessions >= 4) return '● Developing';
    return '○ Rising Voice';
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onStart;
  const _EmptyState({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(32),
      bgColor: AppColors.primary.withValues(alpha: 0.05),
      borderColor: AppColors.primary.withValues(alpha: 0.2),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.mic_none_rounded, size: 30, color: AppColors.primary),
          ),
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
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onStart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryLight, AppColors.primary],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Text(
                'Pick Your First Topic',
                style: TextStyle(
                    color: Color(0xFF490080),
                    fontWeight: FontWeight.w700,
                    fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
