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

/// Which verification a pending code belongs to. The two flows use different
/// OTP types, and picking the wrong one fails verification.
enum LinkFlow {
  /// The address is being attached to the anonymous user already signed in, so
  /// the uid is preserved and nothing needs migrating. Verified with
  /// [OtpType.emailChange].
  emailChange,

  /// A direct email sign-in: either this device had no session at all, or the
  /// address already belongs to an account. Verified with [OtpType.email].
  /// Whatever sits in the anonymous namespace is claimed by the account
  /// afterwards — see `SyncService._claimAnonymousData`.
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
  ///
  /// Reads the server's own `is_anonymous` rather than inferring from the email
  /// field, which is only populated after confirmation and so can disagree with
  /// itself mid-flow.
  bool get isLinked => isSignedIn && !isAnonymous;

  /// Which local namespace this account's rows belong to.
  String get storageScope => isLinked ? (userId ?? '') : StorageScope.anonymous;

  /// What the home screen greets you as.
  ///
  /// First name only: a full one runs past the headline on a narrow screen, and
  /// this is a friendly greeting rather than an address label. Falls back to
  /// 'Speaker' for anyone who has not linked an email.
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
  /// Creating the anonymous user is deliberately *not* done here. The project
  /// enforces CAPTCHA on every gotrue endpoint — signup included — so a silent
  /// `signInAnonymously()` at launch is rejected outright with `captcha_failed`,
  /// and the failure is invisible: no uid, nothing syncs, the outbox just grows.
  /// The account is created on the first save instead, where there is a
  /// [BuildContext] to present the challenge from. See [signInAnonymously].
  void restoreSession() => _apply(_client?.auth.currentUser);

  /// True when there is data worth syncing but no account to hang it on.
  bool get needsAnonymousSignIn =>
      _client != null && _client.auth.currentUser == null;

  /// Creates the anonymous account, with a token from the CAPTCHA challenge.
  /// Returns false if the request was rejected, so the caller can leave the
  /// session local and try again later.
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

  /// Emails a 6-digit code. Tries to attach the address to the current
  /// anonymous user first; if it already belongs to an account, falls back to
  /// signing into that one.
  ///
  /// `shouldCreateUser: false` on the fallback matters — without it a transient
  /// failure on the first call would silently create a *second* account and
  /// orphan everything recorded so far.
  Future<LinkFlow> sendLinkCode({
    required String name,
    required String email,
    String? captchaToken,
  }) async {
    final client = _requireClient();
    _pendingName = name.trim();

    // No session to upgrade. Happens to anyone who taps Sign in before
    // finishing a session — including every existing user on the launch after
    // this ships, whose cached history predates any account. `updateUser`
    // throws AuthSessionMissingException here, so go straight to OTP: one call
    // creates a new account or signs an existing one in, and spends the single
    // captcha token exactly once.
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
      // Only fall through when the address genuinely belongs to someone. A
      // network blip used to land here too, and the user — who typed a brand
      // new address — got told "signups not allowed for otp".
      if (!_isEmailAlreadyRegistered(e)) rethrow;
      log('Auth: that address already has an account; signing into it');
      // updateUser does not consume a captcha token, so the one the sheet
      // handed us is still good for this call.
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
    // Older gotrue responses carry no code; 422 is what the API returns when
    // the address is taken, and anything 5xx or connection-level is not.
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
    // Pulls this account's history down and, on a device that recorded before
    // linking, pushes those rows up under the account's uid.
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
