import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'core/constants/app_constants.dart';
import 'features/shell/lumina_shell.dart';
import 'features/home/presentation/screens/home_screen.dart';
import 'features/topic_selection/presentation/screens/topic_selection_screen.dart';
import 'features/topic_selection/data/models/topic.dart';
import 'features/recording/presentation/screens/preparation_screen.dart';
import 'features/recording/presentation/screens/recording_screen.dart';
import 'features/recording/data/models/recording_session.dart';
import 'features/analysis/presentation/screens/processing_screen.dart';
import 'features/analysis/presentation/screens/results_screen.dart';
import 'features/analysis/data/models/session_record.dart';
import 'features/history/presentation/screens/history_screen.dart';
import 'features/interview/presentation/screens/interview_home_screen.dart';
import 'features/interview/presentation/screens/interview_session_screen.dart';
import 'features/interview/presentation/screens/interview_results_screen.dart';
import 'features/interview/data/models/interview_models.dart';
import 'core/theme/text_styles.dart';

GoRouterRedirect _requireExtra<T>(String fallback) {
  return (context, state) => state.extra is T ? null : fallback;
}

GoRouter createAppRouter() => GoRouter(
  initialLocation: AppRoutes.home,
  errorBuilder: (context, state) => _RouteNotFound(uri: state.uri),
  routes: [
    // ── Tabbed shell (Home / Practice / Insights) ────────────────────────────
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => LuminaShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.topics,
              builder: (context, state) => const TopicSelectionScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.history,
              builder: (context, state) => const HistoryScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.interview,
              builder: (context, state) => const InterviewHomeScreen(),
            ),
          ],
        ),
      ],
    ),

    // ── Full-screen recording flow (no bottom nav) ────────────────────────────
    GoRoute(
      path: AppRoutes.prepare,
      redirect: _requireExtra<Topic>(AppRoutes.topics),
      builder: (context, state) =>
          PreparationScreen(topic: state.extra as Topic),
    ),
    GoRoute(
      path: AppRoutes.record,
      redirect: _requireExtra<Topic>(AppRoutes.topics),
      builder: (context, state) => RecordingScreen(topic: state.extra as Topic),
    ),
    GoRoute(
      path: AppRoutes.processing,
      redirect: _requireExtra<RecordingSession>(AppRoutes.topics),
      builder: (context, state) =>
          ProcessingScreen(session: state.extra as RecordingSession),
    ),
    GoRoute(
      path: AppRoutes.results,
      redirect: _requireExtra<SessionRecord>(AppRoutes.history),
      builder: (context, state) =>
          ResultsScreen(record: state.extra as SessionRecord),
    ),
    GoRoute(
      path: AppRoutes.interviewSession,
      redirect: _requireExtra<InterviewSetup>(AppRoutes.interview),
      builder: (context, state) =>
          InterviewSessionScreen(setup: state.extra as InterviewSetup),
    ),
    GoRoute(
      path: AppRoutes.interviewResults,
      redirect: _requireExtra<CompletedInterview>(AppRoutes.interview),
      builder: (context, state) =>
          InterviewResultsScreen(interview: state.extra as CompletedInterview),
    ),
  ],
);

final appRouter = createAppRouter();

class _RouteNotFound extends StatelessWidget {
  final Uri uri;

  const _RouteNotFound({required this.uri});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.compass,
                size: 40,
                color: AppColors.inkMuted,
              ),
              const SizedBox(height: 16),
              Text(
                'Page not found',
                style: context.title.copyWith(
                  color: AppColors.ink,
                  fontWeight: AppFontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                uri.path,
                textAlign: TextAlign.center,
                style: context.caption.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go(AppRoutes.home),
                child: const Text('Go home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
