import 'dart:convert';
import 'dart:developer' show log;
import 'package:hive_ce_flutter/hive_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/scoped_keys.dart';
import '../../../../core/services/storage_scope.dart';
import '../../../../core/services/sync/sync_outbox.dart';
import '../models/interview_models.dart';
import 'interview_repository.dart';

class InterviewRepositoryImpl implements InterviewRepository {
  InterviewRepositoryImpl(this._scope, [this._outbox]);

  final StorageScope _scope;
  final SyncOutbox? _outbox;

  Box<String> get _box => Hive.box<String>(AppConstants.hiveInterviewsBox);

  String get _currentScope => _scope.value;

  @override
  Future<void> save(CompletedInterview interview) async {
    await _put(_currentScope, interview);
    await _outbox?.enqueue(SyncEntity.interview, interview.id, _currentScope);
  }

  @override
  Future<void> cacheFromRemote(CompletedInterview interview) =>
      _put(_currentScope, interview);

  Future<void> _put(String scope, CompletedInterview interview) => _box.put(
    ScopedKeys.of(scope, interview.id),
    jsonEncode(interview.toJson()),
  );

  @override
  List<CompletedInterview> getAll({String? scope}) {
    final target = scope ?? _currentScope;
    final interviews = <CompletedInterview>[];
    for (final key in _box.keys) {
      if (!ScopedKeys.matches(key, target)) continue;
      final raw = _box.get(key);
      if (raw == null) continue;
      try {
        interviews.add(
          CompletedInterview.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        );
      } catch (e) {
        log('InterviewRepository: unreadable interview $key: $e');
      }
    }
    return interviews..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  @override
  Future<void> rekey(
    String oldId,
    CompletedInterview updated, {
    String? scope,
  }) async {
    final target = scope ?? _currentScope;
    await _box.delete(ScopedKeys.of(target, oldId));
    await _outbox?.resolve(SyncEntity.interview, oldId, target);
    await _put(target, updated);
    await _outbox?.enqueue(SyncEntity.interview, updated.id, target);
  }

  @override
  Future<void> claimFromAnonymous(
    String anonymousId,
    CompletedInterview updated,
    String toScope,
  ) async {
    await _box.delete(ScopedKeys.of(StorageScope.anonymous, anonymousId));
    await _outbox?.resolve(
      SyncEntity.interview,
      anonymousId,
      StorageScope.anonymous,
    );
    await _put(toScope, updated);
    await _outbox?.enqueue(SyncEntity.interview, updated.id, toScope);
  }

  @override
  Future<void> forget(String id) async {
    await _box.delete(ScopedKeys.of(_currentScope, id));
    await _outbox?.resolve(SyncEntity.interview, id, _currentScope);
  }

  @override
  Future<void> delete(String id) async {
    await _box.delete(ScopedKeys.of(_currentScope, id));
    await _outbox?.enqueue(SyncEntity.interview, id, _currentScope);
  }
}
