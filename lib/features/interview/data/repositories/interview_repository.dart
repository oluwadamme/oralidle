import '../models/interview_models.dart';

/// Boundary between the provider/notifier layer and persistence.
///
/// Rows are partitioned by `StorageScope`; every method works in the current
/// scope unless one is named explicitly.
abstract interface class InterviewRepository {
  Future<void> save(CompletedInterview interview);
  List<CompletedInterview> getAll({String? scope});
  Future<void> delete(String id);

  /// Drops a row the server says was deleted elsewhere, without queueing a
  /// second tombstone for a deletion this device did not make.
  Future<void> forget(String id);

  /// Writes a row pulled from the server. Unlike [save] it does not enqueue for
  /// sync, which would push straight back what was just pulled.
  Future<void> cacheFromRemote(CompletedInterview interview);

  /// Replaces a row's id in place, leaving no tombstone: the row under the old
  /// id belongs to a server account this device can no longer write to.
  Future<void> rekey(String oldId, CompletedInterview updated, {String? scope});

  /// Moves a row out of the anonymous namespace into [toScope]. A move rather
  /// than a copy — anything left behind would be claimed by the next person to
  /// link an account on this device.
  Future<void> claimFromAnonymous(
    String anonymousId,
    CompletedInterview updated,
    String toScope,
  );
}
