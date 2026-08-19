import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/models/interview_models.dart';
import '../data/repositories/interview_repository.dart';
import '../data/repositories/interview_repository_impl.dart';

// ── Repository ─────────────────────────────────────────────────────────────

final interviewRepositoryProvider = Provider<InterviewRepository>(
  (_) => InterviewRepositoryImpl(),
);

// ── Interview history ───────────────────────────────────────────────────────

class InterviewHistoryNotifier
    extends StateNotifier<List<CompletedInterview>> {
  InterviewHistoryNotifier(this._repository) : super([]) {
    _load();
  }

  final InterviewRepository _repository;

  void _load() => state = _repository.getAll();

  void refresh() => state = _repository.getAll();

  Future<void> delete(String id) async {
    await _repository.delete(id);
    state = _repository.getAll();
  }
}

final interviewHistoryProvider = StateNotifierProvider<
    InterviewHistoryNotifier, List<CompletedInterview>>(
  (ref) => InterviewHistoryNotifier(ref.watch(interviewRepositoryProvider)),
);

// ── Microphone permission ───────────────────────────────────────────────────
//
// autoDispose so that re-entering the interview tab after granting permission
// causes the provider to re-evaluate rather than serving a stale cached value.

final micPermissionProvider = FutureProvider.autoDispose<PermissionStatus>(
  (_) => Permission.microphone.status,
);
