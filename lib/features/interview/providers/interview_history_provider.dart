import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/speech/mic_permission.dart';
import '../data/models/interview_models.dart';
import '../data/repositories/interview_repository.dart';

export '../../../core/providers/core_providers.dart'
    show interviewRepositoryProvider;

// ── Interview history ───────────────────────────────────────────────────────

class InterviewHistoryNotifier extends StateNotifier<List<CompletedInterview>> {
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

final interviewHistoryProvider =
    StateNotifierProvider<InterviewHistoryNotifier, List<CompletedInterview>>((
      ref,
    ) {
      ref.watch(localDataVersionProvider);
      return InterviewHistoryNotifier(ref.watch(interviewRepositoryProvider));
    });

// ── Microphone permission ───────────────────────────────────────────────────
//
// autoDispose so that re-entering the interview tab after granting permission
// causes the provider to re-evaluate rather than serving a stale cached value.

final micPermissionProvider = FutureProvider.autoDispose<MicPermission>(
  (_) => MicPermissions.status(),
);
