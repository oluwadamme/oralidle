import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../providers/home_provider.dart';
import '../../../history/presentation/widgets/session_tile.dart';
import '../../../history/presentation/widgets/progress_line_chart.dart';
import '../../../history/providers/history_provider.dart';
import '../../../analysis/data/models/session_record.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/utils/responsive.dart';

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

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= Breakpoints.twoColumn) {
            return _WebHome(
              availableWidth: constraints.maxWidth,
              greeting: greeting,
              level: level,
              streak: streak,
              allSessions: allSessions,
              recent: recent,
            );
          }
          return _MobileHome(
            greeting: greeting,
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
  final String level;
  final int streak;
  final List<SessionRecord> allSessions;
  final List<SessionRecord> recent;

  const _WebHome({
    required this.availableWidth,
    required this.greeting,
    required this.level,
    required this.streak,
    required this.allSessions,
    required this.recent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        const Positioned(
          top: -60,
          right: -40,
          child: AmbientOrb(color: AppColors.primary, size: 260),
        ),
        const Positioned(
          bottom: 60,
          left: -60,
          child: AmbientOrb(color: AppColors.amber, size: 180),
        ),
        SafeArea(
          child: SingleChildScrollView(
            // Side margins grow on wide windows so the content stops
            // widening, while the ambient-orb backdrop stays full-bleed.
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
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                            ),
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
                        const SizedBox(height: 6),
                        Text(
                          '$greeting,',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: AppColors.textMedium),
                        ),
                        Text(
                          'Speaker!',
                          style: Theme.of(
                            context,
                          ).textTheme.headlineLarge?.copyWith(height: 1.1),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (streak > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.amber.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              LucideIcons.flame,
                              color: AppColors.amber,
                              size: 15,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '$streak-day streak',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.amber,
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
                            GlassCard(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Your Stats',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(color: AppColors.textMedium),
                                  ),
                                  const SizedBox(height: 16),
                                  _StatRow(
                                    icon: LucideIcons.barChart2,
                                    label: 'Sessions',
                                    value: '${allSessions.length}',
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(height: 12),
                                  _StatRow(
                                    icon: LucideIcons.trophy,
                                    label: 'Best Score',
                                    value:
                                        '${allSessions.map((s) => s.result.overallScore).reduce((a, b) => a > b ? a : b)}',
                                    color: AppColors.good,
                                  ),
                                  const SizedBox(height: 12),
                                  _StatRow(
                                    icon: LucideIcons.trendingUp,
                                    label: 'Avg Score',
                                    value:
                                        '${allSessions.map((s) => s.result.overallScore).reduce((a, b) => a + b) ~/ allSessions.length}',
                                    color: AppColors.fair,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            GlassCard(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Progress',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(color: AppColors.textMedium),
                                  ),
                                  const SizedBox(height: 12),
                                  ProgressLineChart(sessions: allSessions),
                                ],
                              ),
                            ),
                          ] else
                            GlassCard(
                              padding: const EdgeInsets.all(20),
                              bgColor: AppColors.primary.withValues(
                                alpha: 0.05,
                              ),
                              borderColor: AppColors.primary.withValues(
                                alpha: 0.2,
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.primary.withValues(
                                        alpha: 0.12,
                                      ),
                                    ),
                                    child: const Icon(
                                      LucideIcons.mic,
                                      size: 24,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No sessions yet',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Complete your first session to see stats here.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textMedium,
                                    ),
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
                          GlassCard(
                            padding: const EdgeInsets.all(24),
                            bgColor: AppColors.primary.withValues(alpha: 0.05),
                            borderColor: AppColors.primary.withValues(
                              alpha: 0.15,
                            ),
                            child: Row(
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
                                      const Text(
                                        'AI analysis will coach your fluency, pace, and filler word frequency in real-time.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textMedium,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 24),
                                PrimaryGradientButton(
                                  label: 'Practice',
                                  icon: LucideIcons.mic,
                                  height: 48,
                                  onTap: () => context.go(AppRoutes.topics),
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
                                    style: TextStyle(color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            GlassCard(
                              padding: EdgeInsets.zero,
                              child: _SessionsTable(sessions: recent, ref: ref),
                            ),
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
            border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
          ),
          child: const Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  'SESSION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.outline,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'DATE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.outline,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'DURATION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.outline,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'SCORE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.outline,
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
            hoverColor: AppColors.primary.withValues(alpha: 0.04),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : const Border(
                        bottom: BorderSide(color: AppColors.cardBorder),
                      ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      s.topicTitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      DateFormat('MMM d, y').format(s.timestamp),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      s.formattedDuration,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMedium,
                      ),
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
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: color.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            '$score',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
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
  final String value;
  final Color color;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.12),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textMedium),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ── Mobile layout ─────────────────────────────────────────────────────────────

class _MobileHome extends ConsumerWidget {
  final String greeting;
  final String level;
  final int streak;
  final List<SessionRecord> allSessions;
  final List<SessionRecord> recent;

  const _MobileHome({
    required this.greeting,
    required this.level,
    required this.streak,
    required this.allSessions,
    required this.recent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
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
                                      ?.copyWith(color: AppColors.textMedium),
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary.withValues(alpha: 0.25),
                                  AppColors.primaryLight.withValues(
                                    alpha: 0.15,
                                  ),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.4),
                              ),
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
                      if (streak > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.amber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.amber.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                LucideIcons.flame,
                                color: AppColors.amber,
                                size: 15,
                              ),
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
                      PrimaryGradientButton(
                        label: 'Practice',
                        icon: LucideIcons.mic,
                        height: 60,
                        fontSize: 17,
                        onTap: () => context.go(AppRoutes.topics),
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
                                color: AppColors.good,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MiniStatCard(
                                icon: LucideIcons.trendingUp,
                                value:
                                    '${allSessions.map((s) => s.result.overallScore).reduce((a, b) => a + b) ~/ allSessions.length}',
                                label: 'Avg',
                                color: AppColors.fair,
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
                        GlassCard(
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
                                  style: TextStyle(color: AppColors.primary),
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
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
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
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(
              LucideIcons.mic,
              size: 30,
              color: AppColors.primary,
            ),
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
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
