import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/services/captcha/hcaptcha_service.dart';
import '../providers/auth_provider.dart';

/// Creates the anonymous account on the first save, once there is something to
/// sync.
class AnonymousSignInGate extends ConsumerStatefulWidget {
  const AnonymousSignInGate({super.key});

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
