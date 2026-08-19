import 'dart:developer' show log;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart' as ph;

/// Microphone permission, in the terms this app actually branches on.
enum MicPermission {
  granted,
  denied,

  /// Denied in a way only the OS settings app can undo. Mobile only.
  permanentlyDenied,
}

/// Platform-appropriate microphone permission handling.
///
/// `permission_handler` has no web implementation, so calling it in a browser
/// throws `MissingPluginException`. Everything here funnels through one place
/// so that web takes the browser's own model instead: the prompt appears
/// inline on the first `getUserMedia` call, which must follow a user gesture.
abstract final class MicPermissions {
  /// Current status, without prompting.
  ///
  /// Reports [granted] on web — a pre-emptive banner there would be both
  /// unanswerable (no gesture yet) and misleading, since the browser asks at
  /// the moment recording starts. Denial surfaces from
  /// `AudioCaptureService.start` instead.
  static Future<MicPermission> status() async {
    if (kIsWeb) return MicPermission.granted;
    try {
      return _map(await ph.Permission.microphone.status);
    } catch (e) {
      // Desktop platforms without a permission_handler implementation: assume
      // granted and let the actual capture attempt be the source of truth.
      log('MicPermissions: status unavailable, assuming granted: $e');
      return MicPermission.granted;
    }
  }

  /// Prompts for access. On web the browser prompts when capture starts, so
  /// this is a no-op that reports [granted].
  static Future<MicPermission> request() async {
    if (kIsWeb) return MicPermission.granted;
    try {
      return _map(await ph.Permission.microphone.request());
    } catch (e) {
      log('MicPermissions: request unavailable, assuming granted: $e');
      return MicPermission.granted;
    }
  }

  /// Only mobile has an app-settings page worth offering.
  static bool get canOpenSettings => !kIsWeb;

  static Future<void> openSettings() async {
    if (kIsWeb) return;
    try {
      await ph.openAppSettings();
    } catch (e) {
      log('MicPermissions: could not open settings: $e');
    }
  }

  static MicPermission _map(ph.PermissionStatus status) {
    if (status.isGranted || status.isLimited) return MicPermission.granted;
    if (status.isPermanentlyDenied) return MicPermission.permanentlyDenied;
    return MicPermission.denied;
  }
}
