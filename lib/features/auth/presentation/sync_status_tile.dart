import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/services/sync/sync_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../history/providers/history_provider.dart';
import '../providers/auth_provider.dart';
import 'link_account_sheet.dart';

/// The account control, top-right of the home screen.
///
class SyncStatusTile extends ConsumerWidget {
  const SyncStatusTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(syncAvailableProvider)) return const SizedBox.shrink();

    ref.watch(historyProvider);
    ref.watch(localDataVersionProvider);

    final status = ref.watch(syncStatusProvider).value ?? SyncStatus.idle;
    final linked = ref.watch(authProvider).isLinked;
    final pending = !ref.watch(syncOutboxProvider).isEmpty;
    final failed = status == SyncStatus.failed;

    if (linked && !pending && !failed) return const SizedBox.shrink();

    final syncing = status == SyncStatus.syncing;

    return AppButton.secondary(
      label: !linked
          ? 'Sign in'
          : failed
          ? 'Retry sync'
          : 'Sync session',
      icon: linked ? LucideIcons.refreshCw : LucideIcons.logIn,
      size: AppButtonSize.small,
      busy: syncing,
      semanticHint: linked
          ? "Sends this device's sessions to your account"
          : 'Adds an email so your history opens on any device',
      onPressed: syncing ? null : () => _act(context, ref, linked: linked),
    );
  }

  void _act(BuildContext context, WidgetRef ref, {required bool linked}) {
    if (linked) {
      ref.read(syncServiceProvider)?.syncNow();
    } else {
      LinkAccountSheet.show(context);
    }
  }
}
