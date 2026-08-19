import '../models/interview_models.dart';

/// Boundary between the provider/notifier layer and persistence.
/// Swap the implementation (e.g. remote API, SQLite) without touching business logic.
abstract interface class InterviewRepository {
  Future<void> save(CompletedInterview interview);
  List<CompletedInterview> getAll();
  Future<void> delete(String id);
}
