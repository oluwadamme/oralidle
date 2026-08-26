import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

import '../constants/app_constants.dart';

/// Small device-local key/value scratch space.
///
/// Everything here is a UI or sync bookkeeping detail that belongs to *this
/// install* and must never sync: how many times the "sync across devices"
/// banner has been shown, and which users have already been backfilled.
class AppPrefs {
  Box<String> get _box => Hive.box<String>(AppConstants.hivePrefsBox);

  static const _syncPromptShownCount = 'sync_prompt_shown_count';
  static const _syncPromptDismissed = 'sync_prompt_dismissed';
  static const _backfilledUsers = 'backfilled_users';
  static const _lastSyncedUserId = 'last_synced_user_id';

  int get syncPromptShownCount =>
      int.tryParse(_box.get(_syncPromptShownCount) ?? '') ?? 0;

  Future<void> recordSyncPromptShown() =>
      _box.put(_syncPromptShownCount, '${syncPromptShownCount + 1}');

  /// Set when the user closes the banner. They can still link from the
  /// permanent home-screen row at any time.
  bool get syncPromptDismissed => _box.get(_syncPromptDismissed) == 'true';

  Future<void> dismissSyncPrompt() => _box.put(_syncPromptDismissed, 'true');

  
  String? lastSyncedUserIdFor(String scope) => _userIdsByScope()[scope];

  Future<void> setLastSyncedUserIdFor(String scope, String userId) async {
    final map = _userIdsByScope()..[scope] = userId;
    await _box.put(_lastSyncedUserId, jsonEncode(map));
  }

  Map<String, String> _userIdsByScope() {
    final raw = _box.get(_lastSyncedUserId);
    if (raw == null || raw.isEmpty) return {};
    try {
      return (jsonDecode(raw) as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value as String),
      );
    } catch (_) {
      return {};
    }
  }

  /// Whether every pre-existing local row has already been pushed for this
  /// user. Runs once per uid: on the first launch after this feature ships,
  /// and again if the user later links into a different account.
  bool hasBackfilled(String userId) =>
      (_box.get(_backfilledUsers) ?? '').split(',').contains(userId);

  Future<void> markBackfilled(String userId) async {
    final existing = (_box.get(_backfilledUsers) ?? '')
        .split(',')
        .where((s) => s.isNotEmpty)
        .toSet()
      ..add(userId);
    await _box.put(_backfilledUsers, existing.join(','));
  }
}
