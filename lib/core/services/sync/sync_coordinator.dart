import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../providers/core_providers.dart';

/// Decides when a sync runs: at startup, when connectivity returns, and when
/// the app comes back to the foreground.
///
/// Also the thing that brings [authProvider] to life, which is what triggers
/// the silent anonymous sign-in on first launch.
class SyncCoordinator extends ConsumerStatefulWidget {
  const SyncCoordinator({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SyncCoordinator> createState() => _SyncCoordinatorState();
}

class _SyncCoordinatorState extends ConsumerState<SyncCoordinator>
    with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Reading it is what constructs AuthNotifier, which signs in anonymously
    // and kicks off the first sync.
    ref.read(authProvider);

    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) _sync();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sync();
  }

  void _sync() => unawaited(_syncNow());

  Future<void> _syncNow() async {
    // Only adopts a session that already exists. Creating the anonymous account
    // needs a CAPTCHA token and so belongs to AnonymousSignInGate, which has a
    // BuildContext to present the challenge from.
    ref.read(authProvider.notifier).restoreSession();
    await ref.read(syncServiceProvider)?.syncNow();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
