import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'core/constants/app_constants.dart';
import 'core/services/speech/gemma_speech_service.dart';
import 'core/theme/app_theme.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await Hive.initFlutter();
  await Hive.openBox<String>(AppConstants.hiveSessionsBox);
  await Hive.openBox<String>(AppConstants.hiveInterviewsBox);

  // Registers the on-device speech backend. Offline and cheap — it wires up
  // the runtime without touching model files, which are fetched lazily the
  // first time a recording screen is opened. No-op on web.
  await GemmaSpeechService.initializeRuntime();

  runApp(const ProviderScope(child: SpeechCoachApp()));
}

class SpeechCoachApp extends StatelessWidget {
  const SpeechCoachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Speech Coach',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
