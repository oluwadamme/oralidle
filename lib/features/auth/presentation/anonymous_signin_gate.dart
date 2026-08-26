import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/services/captcha/hcaptcha_service.dart';
import '../providers/auth_provider.dart';

/// Creates the anonymous account on the first save, once there is something to
/// sync.
///
/// The project enforces CAPTCHA on every auth endpoint, so the account cannot
/// be created silently at launch — the challenge needs a [BuildContext].
/// Deferring it to here means a first-time visitor records and sees their
/// result before anything is asked of them, and dismissing the challenge simply
/// leaves the session on the device.
///
/// Renders nothing. Mount it on a screen the user reaches after finishing a
/// session.
class AnonymousSignInGate extends ConsumerStatefulWidget {
  const AnonymousSignInGate({super.key});

  /// Asked at most once per app run. A user who dismisses the challenge is not
  /// nagged for the rest of the session; the next launch tries again, and the
  /// outbox holds their work in the meantime.
  static bool _askedThisRun = false;

  @visibleForTesting
  static void resetForTest() => _askedThisRun = false;

  @override
  ConsumerState<AnonymousSignInGate> createState() =>
      _AnonymousSignInGateState();
}

class _AnonymousSignInGateState extends ConsumerState<AnonymousSignInGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrompt());
  }

  Future<void> _maybePrompt() async {
    if (!mounted || AnonymousSignInGate._askedThisRun) return;

    final auth = ref.read(authProvider.notifier);
    if (!auth.needsAnonymousSignIn) return;

    // Nothing waiting to go up means nothing to ask about yet.
    if (ref.read(syncOutboxProvider).isEmpty) return;

    AnonymousSignInGate._askedThisRun = true;

    final token = await HCaptchaService.verify(context);
    if (token == null || !mounted) return;

    await auth.signInAnonymously(captchaToken: token);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
