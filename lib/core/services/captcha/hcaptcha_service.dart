import 'package:flutter/widgets.dart';

import '../../config/hcaptcha_config.dart';
import 'hcaptcha_modal.dart';

/// Top-level service for triggering hCaptcha verification.
abstract final class HCaptchaService {
  /// Presents the hCaptcha challenge modal to the user and awaits the verified
  /// token. Returns `null` if the user closes or dismisses the challenge.
  static Future<String?> verify(
    BuildContext context, {
    String? siteKey,
  }) async {
    final activeKey = (siteKey != null && siteKey.isNotEmpty)
        ? siteKey
        : HCaptchaConfig.siteKey;

    if (activeKey.isEmpty) return null;

    return HCaptchaModal.show(context, siteKey: activeKey);
  }
}
