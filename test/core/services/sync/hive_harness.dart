import 'dart:io';

import 'package:hive_ce/hive.dart';
import 'package:widget_overlay_outside/core/constants/app_constants.dart';

/// Opens the app's boxes against a throwaway directory.
///
/// `Hive.initFlutter()` needs path_provider, which is unavailable under
/// `flutter test`, so tests drive `Hive.init` directly.
class HiveHarness {
  late Directory _dir;

  static const _boxes = [
    AppConstants.hiveSessionsBox,
    AppConstants.hiveInterviewsBox,
    AppConstants.hiveOutboxBox,
    AppConstants.hivePendingAudioBox,
    AppConstants.hivePrefsBox,
    AppConstants.hiveEventsBox,
  ];

  Future<void> setUp() async {
    _dir = await Directory.systemTemp.createTemp('oradile_hive_test');
    Hive.init(_dir.path);
    for (final name in _boxes) {
      await Hive.openBox<String>(name);
    }
  }

  Future<void> tearDown() async {
    await Hive.close();
    if (await _dir.exists()) await _dir.delete(recursive: true);
  }
}
