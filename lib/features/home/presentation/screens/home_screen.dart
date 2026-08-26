import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../providers/home_provider.dart';
import '../../../auth/presentation/sync_status_tile.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../history/presentation/widgets/session_tile.dart';
import '../../../history/presentation/widgets/progress_line_chart.dart';
import '../../../history/providers/history_provider.dart';
import '../../../analysis/data/models/session_record.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../core/widgets/tabular_text.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/ad_banner_widget.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/theme/app_spacing.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider);
    final recent = ref.watch(recentSessionsProvider);
    final allSessions = ref.watch(historyProvider);

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final level = _levelTitle(allSessions.length);
    final name = ref.watch(authProvider).greetingName;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= Breakpoints.twoColumn) {
            return _WebHome(
              availableWidth: constraints.maxWidth,
              greeting: greeting,
              name: name,
              level: level,
              streak: streak,
              allSessions: allSessions,
              recent: recent,
            );
          }
          return _MobileHome(
            greeting: greeting,
            name: name,
            level: level,
            streak: streak,
            allSessions: allSessions,
            recent: recent,
          );
        },
      ),
    );
  }

  static String _levelTitle(int sessions) {
    if (sessions >= 20) return '✦ Eloquent Speaker';
    if (sessions >= 10) return '◆ Articulate';
    if (sessions >= 4) return '● Developing';
    return '○ Rising Voice';
  }
}

// ── Web two-column layout ─────────────────────────────────────────────────────

class _WebHome extends ConsumerWidget {
  /// Width of the content area, excluding the shell's sidebar.
  final double availableWidth;
  final String greeting;
  final String name;
  final String level;
  final int streak;
  final List<SessionRecord> allSessions;
  final List<SessionRecord> recent;

  const _WebHome({
    required this.availableWidth,
    required this.greeting,
    required this.name,
    required this.level,
    required this.streak,
    required this.allSessions,
    required this.recent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        SafeArea(
          child: SingleChildScrollView(
            padding: centeredPagePadding(
              availableWidth,
              minHorizontal: 32,
              top: 32,
              bottom: 32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top bar ───────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: Radii.pillAll,
                            color: AppColors.raised2,
                            border: Border.all(color: AppColors.borderControl),
                          ),
                          child: Text(
                            level,
                            style: const TextStyle(
                              fontWeight: AppFontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$greeting,',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: AppColors.inkMuted),
                        ),
                        Text(
                          '$name!',
                          style: Theme.of(
                            context,
                          ).textTheme.headlineLarge?.copyWith(height: 1.1),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const SyncStatusTile(),
                    const SizedBox(width: Space.sm),
                    if (streak > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: Radii.pillAll,
                          color: AppColors.caution.withValues(alpha: 0.1),
                          border: Border.all(
                            color: AppColors.caution.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              LucideIcons.flame,
                              color: AppColors.caution,
                              size: 15,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '$streak-day streak',
                              style: const TextStyle(
                                fontWeight: AppFontWeight.w600,
                                color: AppColors.caution,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 32),

                // ── Two columns ───────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Left panel ─────────────────────────────────────
                    SizedBox(
                      width: 300,
                      child: Column(
                        children: [
                          // Stats card
                          if (allSessions.isNotEmpty) ...[
                            SurfaceCard(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Your Stats',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(color: AppColors.inkMuted),
                                  ),
                                  const SizedBox(height: 16),
                                  _StatRow(
                                    icon: LucideIcons.barChart2,
                                    label: 'Sessions',
                                    value: '${allSessions.length}',
                                  ),
                                  const SizedBox(height: 12),
                                  _StatRow(
                                    icon: LucideIcons.trophy,
                                    label: 'Best Score',
                                    score: allSessions
                                        .map((s) => s.result.overallScore)
                                        .reduce((a, b) => a > b ? a : b),
                                  ),
                                  const SizedBox(height: 12),
                                  _StatRow(
                                    icon: LucideIcons.trendingUp,
                                    label: 'Avg Score',
                                    score:
                                        allSessions.map((s) => s.result.overallScore).reduce((a, b) => a + b) ~/
                                        allSessions.length,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            SurfaceCard(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Progress',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(color: AppColors.inkMuted),
                                  ),
                                  const SizedBox(height: 12),
                                  ProgressLineChart(sessions: allSessions),
                                ],
                              ),
                            ),
                          ] else
                            SurfaceCard(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.ink.withValues(
                                        alpha: 0.12,
                                      ),
                                    ),
                                    child: const Icon(
                                      LucideIcons.mic,
                                      size: 24,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No sessions yet',
                                    style: TextStyle(
                                      fontWeight: AppFontWeight.w600,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Complete your first session to see stats here.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppColors.inkMuted),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),

                    // ── Right panel ────────────────────────────────────
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // CTA card
                          SurfaceCard(
                            padding: const EdgeInsets.all(24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Ready for your next session?',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'AI analysis will coach your fluency, pace, and filler word frequency in real-time.',
                                        style: context.body,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: Space.xl),
                                Flexible(
                                  child: AppButton.primary(
                                    label: 'Practice',
                                    icon: LucideIcons.mic,
                                    onPressed: () => context.go(AppRoutes.topics),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Recent sessions table
                          if (allSessions.isNotEmpty) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Recent Sessions',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                TextButton(
                                  onPressed: () =>
                                      context.go(AppRoutes.history),
                                  child: const Text(
                                    'View All →',
                                    style: TextStyle(color: AppColors.ink),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SurfaceCard(
                              padding: EdgeInsets.zero,
                              child: _SessionsTable(sessions: recent, ref: ref),
                            ),
                            const SizedBox(height: 20),
                            const AppAdBannerWidget(),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Sessions table (web) ──────────────────────────────────────────────────────

class _SessionsTable extends StatelessWidget {
  final List<SessionRecord> sessions;
  final WidgetRef ref;

  const _SessionsTable({required this.sessions, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(
            borderRadius: Radii.mdAll,
            border: Border(bottom: BorderSide(color: AppColors.line)),
          ),
          child: const Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  'SESSION',
                  style: TextStyle(
                    fontWeight: AppFontWeight.w700,
                    color: AppColors.inkMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'DATE',
                  style: TextStyle(
                    fontWeight: AppFontWeight.w700,
                    color: AppColors.inkMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'DURATION',
                  style: TextStyle(
                    fontWeight: AppFontWeight.w700,
                    color: AppColors.inkMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'SCORE',
                  style: TextStyle(
                    fontWeight: AppFontWeight.w700,
                    color: AppColors.inkMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Data rows
        ...sessions.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          final score = s.result.overallScore;
          final color = AppColors.scoreColor(score);
          final isLast = i == sessions.length - 1;

          return InkWell(
            onTap: () => context.push(AppRoutes.results, extra: s),
            hoverColor: AppColors.raised2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: Radii.mdAll,
                border: isLast
                    ? null
                    : const Border(bottom: BorderSide(color: AppColors.line)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      s.topicTitle,
                      style: const TextStyle(
                        fontWeight: AppFontWeight.w500,
                        color: AppColors.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      DateFormat('MMM d, y').format(s.timestamp),
                      style: const TextStyle(color: AppColors.inkMuted),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      s.formattedDuration,
                      style: const TextStyle(color: AppColors.inkMuted),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: Radii.pillAll,
                            color: color.withValues(alpha: 0.12),
                            border: Border.all(
                              color: color.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            '$score',
                            style: TextStyle(
                              fontWeight: AppFontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ── Stat row (web left panel) ─────────────────────────────────────────────────

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;

  /// When present the row is a score, so it takes its band colour.
  final int? score;

  const _StatRow({
    required this.icon,
    required this.label,
    this.value, this.score,
  });

  Color get color => score == null ? AppColors.inkMuted : AppColors.scoreColor(score!);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.12),
          ),
          child: Icon(icon, size: IconSize.sm, color: color),
        ),
        const SizedBox(width: Space.md),
        Expanded(
          child: Text(
            label,
            style: context.body.copyWith(color: AppColors.inkMuted),
          ),
        ),
        TabularText(
          value ?? '${score ?? 0}',
          style: context.readoutAt(16,
            color: color,
            weight: AppFontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ── Mobile layout ─────────────────────────────────────────────────────────────

class _MobileHome extends ConsumerWidget {
  final String greeting;
  final String name;
  final String level;
  final int streak;
  final List<SessionRecord> allSessions;
  final List<SessionRecord> recent;

  const _MobileHome({
    required this.greeting,
    required this.name,
    required this.level,
    required this.streak,
    required this.allSessions,
    required this.recent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$greeting,',
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(color: AppColors.inkMuted),
                                ),
                                Text(
                                  '$name!',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineLarge
                                      ?.copyWith(height: 1.1),
                                ),
                              ],
                            ),
                          ),
                          // Top-right is where people look for their account.
                          // The level moves down to the chip row below, so this
                          // row holds two items instead of three and stops
                          // running out of width at 1.5x text.
                          const SyncStatusTile(),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Wraps rather than sharing a Row: the streak copy and
                      // the sync pill together overflow 390px at 1.5x text.
                      Wrap(
                        spacing: Space.sm,
                        runSpacing: Space.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: Radii.pillAll,
                              color: AppColors.raised2,
                              border: Border.all(
                                color: AppColors.borderControl,
                              ),
                            ),
                            child: Text(
                              level,
                              style: const TextStyle(
                                fontWeight: AppFontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          if (streak > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                borderRadius: Radii.pillAll,
                                color: AppColors.caution.withValues(alpha: 0.12),
                                border: Border.all(
                                  color: AppColors.caution.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(LucideIcons.flame, color: AppColors.caution, size: 15),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$streak-day streak — keep it up!',
                                    style: const TextStyle(fontWeight: AppFontWeight.w600, color: AppColors.caution),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      AppButton.primary(
                        expand: true,
                        label: 'Practice',
                        icon: LucideIcons.mic,
                        onPressed: () => context.go(AppRoutes.topics),
                      ),
                      const SizedBox(height: 24),
                      if (allSessions.isNotEmpty) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _MiniStatCard(
                                icon: LucideIcons.barChart2,
                                value: '${allSessions.length}',
                                label: 'Sessions',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MiniStatCard(
                                icon: LucideIcons.trophy,
                                value:
                                    '${allSessions.map((s) => s.result.overallScore).reduce((a, b) => a > b ? a : b)}',
                                label: 'Best',
                                color: AppColors.scoreColor(
                                  allSessions.map((s) => s.result.overallScore).reduce((a, b) => a > b ? a : b),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MiniStatCard(
                                icon: LucideIcons.trendingUp,
                                value:
                                    '${allSessions.map((s) => s.result.overallScore).reduce((a, b) => a + b) ~/ allSessions.length}',
                                label: 'Avg',
                                color: AppColors.scoreColor(
                                  allSessions.map((s) => s.result.overallScore).reduce((a, b) => a + b) ~/
                                      allSessions.length,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Progress',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        SurfaceCard(
                          padding: const EdgeInsets.all(16),
                          child: ProgressLineChart(sessions: allSessions),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Recent Sessions',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (allSessions.length > 3)
                              TextButton(
                                onPressed: () => context.go(AppRoutes.history),
                                child: const Text(
                                  'See all',
                                  style: TextStyle(color: AppColors.ink),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...recent.map(
                          (s) => SessionTile(
                            record: s,
                            onTap: () =>
                                context.push(AppRoutes.results, extra: s),
                          ),
                        ),
                      ] else
                        _EmptyState(
                          onStart: () => context.go(AppRoutes.topics),
                        ),
                      const SizedBox(height: 24),
                      const AppAdBannerWidget(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _MiniStatCard({
    required this.icon,
    required this.value,
    required this.label,
    this.color = AppColors.ink,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        borderRadius: Radii.mdAll,
        color: AppColors.raised,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontWeight: AppFontWeight.w800, color: color),
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

class _EmptyState extends StatelessWidget {
  final VoidCallback onStart;
  const _EmptyState({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.raised2,
              border: Border.all(color: AppColors.borderControl),
            ),
            child: const Icon(LucideIcons.mic, size: 30, color: AppColors.ink),
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
          Pressable(
            onTap: onStart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(color: AppColors.action),
              child: const Text(
                'Pick Your First Topic',
                style: TextStyle(
                  color: AppColors.onAction,
                  fontWeight: AppFontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
