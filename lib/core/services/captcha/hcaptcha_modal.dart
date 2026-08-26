import 'dart:developer' show log;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../constants/app_constants.dart';
import '../../theme/app_spacing.dart';
import '../../theme/text_styles.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_button.dart';
import '../../widgets/waveform_loader.dart';
import 'hcaptcha_view.dart';

/// Modal dialog or bottom sheet for solving an hCaptcha challenge.
class HCaptchaModal extends StatefulWidget {
  const HCaptchaModal({super.key, required this.siteKey});

  final String siteKey;

  static Future<String?> show(BuildContext context, {required String siteKey}) {
    final isWide = MediaQuery.of(context).size.width >= Breakpoints.twoColumn;
    if (isWide) {
      return showDialog<String>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => Dialog(
          backgroundColor: AppColors.raised,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.lg),
            side: const BorderSide(color: AppColors.line),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: HCaptchaModal(siteKey: siteKey),
          ),
        ),
      );
    }

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.raised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
      ),
      builder: (ctx) => HCaptchaModal(siteKey: siteKey),
    );
  }

  @override
  State<HCaptchaModal> createState() => _HCaptchaModalState();
}

class _HCaptchaModalState extends State<HCaptchaModal> {
  bool _hasError = false;
  String? _errorCode;
  int _reloadKey = 0;

  void _onSuccess(String token) {
    if (!mounted) return;
    Navigator.of(context).pop(token);
  }

  void _onError(String? code) {
    if (!mounted) return;
    // Surfaced rather than swallowed: 'invalid-data' or a hostname complaint
    // means the sitekey does not list this domain, which is indistinguishable
    // from a network problem without the code.
    log('hCaptcha failed: ${code ?? "unknown"} (sitekey ${widget.siteKey})');
    setState(() {
      _hasError = true;
      _errorCode = code;
    });
  }

  void _onExpired() {
    if (!mounted) return;
    setState(() {
      _hasError = false;
      _reloadKey++;
    });
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _reloadKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.shieldCheck,
                size: IconSize.md,
                color: AppColors.accent,
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text('Verification', style: context.title),
              ),
              IconButton(
                icon: const Icon(LucideIcons.x, color: AppColors.inkMuted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(
            'Please complete the verification below to continue.',
            style: context.body.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: Space.lg),
          Container(
            height: 340,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.raised2,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: AppColors.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: _hasError
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(Space.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.circleAlert,
                            size: IconSize.lg,
                            color: AppColors.critical,
                          ),
                          const SizedBox(height: Space.sm),
                          Text(
                            'Failed to load verification.',
                            style: context.body.copyWith(
                              color: AppColors.critical,
                            ),
                          ),
                          if (_errorCode != null) ...[
                            const SizedBox(height: Space.xs),
                            Text(
                              _errorCode!,
                              textAlign: TextAlign.center,
                              style: context.caption.copyWith(
                                color: AppColors.inkFaint,
                              ),
                            ),
                          ],
                          const SizedBox(height: Space.md),
                          AppButton.secondary(
                            label: 'Retry',
                            icon: LucideIcons.refreshCw,
                            onPressed: _retry,
                          ),
                        ],
                      ),
                    ),
                  )
                : Stack(
                    children: [
                      const Center(
                        child: WaveformLoader.compact(
                          height: 20,
                          barCount: 4,
                          barWidth: 3,
                          barSpacing: 2,
                          color: AppColors.inkMuted,
                        ),
                      ),
                      KeyedSubtree(
                        key: ValueKey(_reloadKey),
                        child: buildHCaptchaPlatformView(
                          siteKey: widget.siteKey,
                          onToken: _onSuccess,
                          onError: _onError,
                          onExpired: _onExpired,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
