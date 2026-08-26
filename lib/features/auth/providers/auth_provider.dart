import 'dart:async';
import 'dart:developer' show log;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/app_prefs.dart';
import '../../../core/services/storage_scope.dart';
import '../../../core/services/supabase/remote_store.dart';
import '../../../core/services/supabase/supabase_bootstrap.dart';
import '../../../core/services/sync/sync_service.dart';


enum LinkFlow {

  emailChange,

  emailOtp,
}

class AccountState {
  const AccountState({
    this.userId,
    this.email,
    this.displayName,
    this.isAnonymous = true,
  });

  final String? userId;
  final String? email;
  final String? displayName;
  final bool isAnonymous;

  bool get isSignedIn => userId != null;

  /// True once an email has been verified — the point at which history becomes
  /// reachable from another device.

  bool get isLinked => isSignedIn && !isAnonymous;

  /// Which local namespace this account's rows belong to.
  String get storageScope => isLinked ? (userId ?? '') : StorageScope.anonymous;

  /// What the home screen greets you as.
  ///

  String get greetingName {
    final trimmed = displayName?.trim() ?? '';
    if (trimmed.isEmpty) return 'Speaker';
    return trimmed.split(RegExp(r'\s+')).first;
  }
}

class AuthNotifier extends StateNotifier<AccountState> {
  AuthNotifier(
    this._client,
    this._remote,
    this._sync,
    this._scope,
    this._onScopeChanged,
  ) : super(const AccountState()) {
    _bootstrap();
  }

  final SupabaseClient? _client;
  final RemoteStore? _remote;
  final SyncService? _sync;
  final StorageScope _scope;
  final void Function() _onScopeChanged;

  StreamSubscription<AuthState>? _authSub;
  String? _pendingName;

  Future<void> _bootstrap() async {
    final client = _client;
    if (client == null) return;

    _authSub = client.auth.onAuthStateChange.listen(
      (event) => _apply(event.session?.user),
    );

    restoreSession();
    unawaited(_sync?.syncNow());
  }

  /// Adopts a session already persisted on this device. Never creates one.
  ///
  void restoreSession() => _apply(_client?.auth.currentUser);

  /// True when there is data worth syncing but no account to hang it on.
  bool get needsAnonymousSignIn =>
      _client != null && _client.auth.currentUser == null;


  Future<bool> signInAnonymously({required String captchaToken}) async {
    final client = _client;
    if (client == null) return false;
    if (client.auth.currentUser != null) return true;
    try {
      final response = await client.auth.signInAnonymously(
        captchaToken: captchaToken,
      );
      _apply(response.user);
      await _sync?.syncNow();
      return true;
    } catch (e) {
      log('Auth: anonymous sign-in failed: $e');
      return false;
    }
  }

  void _apply(User? user) {
    if (!mounted) return;
    final next = user == null
        ? const AccountState()
        : AccountState(
            userId: user.id,
            email: user.email,
            displayName: user.userMetadata?['display_name'] as String?,
            isAnonymous: user.isAnonymous,
          );

    // Repoint local storage before the state lands, so anything that rebuilds
    // off the new account reads from the right namespace.
    final scopeChanged = _scope.value != next.storageScope;
    _scope.value = next.storageScope;
    state = next;
    if (scopeChanged) _onScopeChanged();
  }


  Future<LinkFlow> sendLinkCode({
    required String name,
    required String email,
    String? captchaToken,
  }) async {
    final client = _requireClient();
    _pendingName = name.trim();

    if (client.auth.currentUser == null) {
      await client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
        captchaToken: captchaToken,
        data: {'display_name': _pendingName},
      );
      return LinkFlow.emailOtp;
    }

    try {
      await client.auth.updateUser(
        UserAttributes(email: email, data: {'display_name': _pendingName}),
      );
      return LinkFlow.emailChange;
    } on AuthException catch (e) {

      if (!_isEmailAlreadyRegistered(e)) rethrow;
      log('Auth: that address already has an account; signing into it');

      await client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
        captchaToken: captchaToken,
      );
      return LinkFlow.emailOtp;
    }
  }

  static bool _isEmailAlreadyRegistered(AuthException e) {
    const codes = {'email_exists', 'user_already_exists'};
    if (e.code != null) return codes.contains(e.code);
    return e.statusCode == '422';
  }

  Future<void> verifyLinkCode({
    required String email,
    required String token,
    required LinkFlow flow,
  }) async {
    final client = _requireClient();
    await client.auth.verifyOTP(
      email: email,
      token: token.trim(),
      type: flow == LinkFlow.emailChange
          ? OtpType.emailChange
          : OtpType.email,
    );

    final user = client.auth.currentUser;
    _apply(user);
    if (user == null) return;

    final name = _pendingName;
    if (name != null && name.isNotEmpty) {
      await _remote?.upsertProfile(userId: user.id, displayName: name);
    }
    await _sync?.syncNow();
  }

  Future<void> signOut() async {
    await _client?.auth.signOut();
    _pendingName = null;
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw StateError('Sync is unavailable: Supabase is not configured.');
    }
    return client;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AccountState>(
  (ref) => AuthNotifier(
    SupabaseBootstrap.client,
    ref.watch(remoteStoreProvider),
    ref.watch(syncServiceProvider),
    ref.watch(storageScopeProvider),
    () => ref.read(localDataVersionProvider.notifier).state++,
  ),
);

/// Whether the "sync across devices" affordances should appear at all.
final syncAvailableProvider = Provider<bool>(
  (ref) => ref.watch(remoteStoreProvider) != null,
);

final syncPromptVersionProvider = StateProvider<int>((_) => 0);

/// Shown at most twice, and never before the user has finished a couple of
/// sessions — see [AppPrefs].
final shouldOfferSyncProvider = Provider.family<bool, int>((ref, sessionCount) {
  if (!ref.watch(syncAvailableProvider)) return false;
  if (ref.watch(authProvider).isLinked) return false;

  ref.watch(syncPromptVersionProvider);

  final prefs = ref.watch(appPrefsProvider);
  if (prefs.syncPromptDismissed && prefs.syncPromptShownCount > 1) return false;

  final shown = prefs.syncPromptShownCount;
  if (shown >= AppConstants.syncPromptAtSessionCounts.length) return false;
  return sessionCount >= AppConstants.syncPromptAtSessionCounts[shown];
});
