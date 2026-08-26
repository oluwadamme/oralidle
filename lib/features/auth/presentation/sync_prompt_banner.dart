import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/surface_card.dart';
import '../providers/auth_provider.dart';
import 'link_account_sheet.dart';


class SyncPromptBanner extends ConsumerStatefulWidget {
  const SyncPromptBanner({super.key, required this.sessionCount});

  final int sessionCount;

  @override
  ConsumerState<SyncPromptBanner> createState() => _SyncPromptBannerState();
}

class _SyncPromptBannerState extends ConsumerState<SyncPromptBanner> {
  bool _closed = false;
  bool _counted = false;

  @override
  Widget build(BuildContext context) {
    final shouldOffer = ref.watch(shouldOfferSyncProvider(widget.sessionCount));
    if (_closed || !shouldOffer) return const SizedBox.shrink();

    if (!_counted) {
      _counted = true;
      // After this frame, so the write never happens mid-build.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await ref.read(appPrefsProvider).recordSyncPromptShown();
        if (!mounted) return;
        // Invalidates the cached gate so a second results screen this session
        // does not show the banner again and spend the other offer.
        ref.read(syncPromptVersionProvider.notifier).state++;
      });
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: SurfaceCard(
        level: SurfaceLevel.two,
        borderColor: AppColors.accent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  LucideIcons.refreshCw,
                  size: IconSize.md,
                  color: AppColors.accent,
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    'Keep your progress on any device',
                    style: context.cardTitle,
                  ),
                ),
                Pressable(
                  onTap: _dismiss,
                  semanticLabel: 'Dismiss',
                  minSize: TouchTarget.min,
                  child: const Icon(
                    LucideIcons.x,
                    size: IconSize.sm,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            Text(
              'Add your email and this history opens on your phone or another '
              'browser. No password needed.',
              style: context.caption.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: Space.md),
            AppButton.secondary(
              label: 'Add email',
              icon: LucideIcons.mail,
              onPressed: () => LinkAccountSheet.show(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _dismiss() async {
    setState(() => _closed = true);
    await ref.read(appPrefsProvider).dismissSyncPrompt();
    if (!mounted) return;
    ref.read(syncPromptVersionProvider.notifier).state++;
  }
}
