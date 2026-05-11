import 'package:go_router/go_router.dart';
import 'core/constants/app_constants.dart';
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

final appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    GoRoute(
      path: AppRoutes.home,
      builder: (_, __) => const HomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.topics,
      builder: (_, __) => const TopicSelectionScreen(),
    ),
    GoRoute(
      path: AppRoutes.prepare,
      builder: (context, state) =>
          PreparationScreen(topic: state.extra as Topic),
    ),
    GoRoute(
      path: AppRoutes.record,
      builder: (context, state) =>
          RecordingScreen(topic: state.extra as Topic),
    ),
    GoRoute(
      path: AppRoutes.processing,
      builder: (context, state) =>
          ProcessingScreen(session: state.extra as RecordingSession),
    ),
    GoRoute(
      path: AppRoutes.results,
      builder: (context, state) =>
          ResultsScreen(record: state.extra as SessionRecord),
    ),
    GoRoute(
      path: AppRoutes.history,
      builder: (_, __) => const HistoryScreen(),
    ),
  ],
);
