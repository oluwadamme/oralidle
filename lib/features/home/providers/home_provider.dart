import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../analysis/data/models/session_record.dart';
import '../../history/providers/history_provider.dart';
import '../../analysis/providers/analysis_provider.dart' show storageServiceProvider;

final streakProvider = Provider<int>((ref) {
  ref.watch(historyProvider);
  return ref.read(storageServiceProvider).calculateStreak();
});

final recentSessionsProvider = Provider<List<SessionRecord>>((ref) {
  final all = ref.watch(historyProvider);
  return all.take(3).toList();
});
