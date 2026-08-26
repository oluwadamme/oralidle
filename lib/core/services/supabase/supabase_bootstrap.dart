import 'dart:developer' show log;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_config.dart';

abstract final class SupabaseBootstrap {
  static bool _ready = false;

  static bool get isReady => _ready;

  static SupabaseClient? get client =>
      _ready ? Supabase.instance.client : null;

  static Future<void> initialize() async {
    if (!SupabaseConfig.isConfigured) {
      log('Supabase: not configured — running local-only.');
      return;
    }
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
      _ready = true;
    } catch (e) {
      log('Supabase: initialization failed, running local-only: $e');
    }
  }
}
