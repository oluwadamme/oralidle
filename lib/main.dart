import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'core/config/url_strategy.dart';
import 'core/constants/app_constants.dart';
import 'core/services/ad_service.dart';
import 'core/services/speech/gemma_speech_service.dart';
import 'core/theme/app_theme.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureUrlStrategy();
  // Optional: web builds ship an empty .env because the API key lives on the
  // server behind api/gemini.js, and CI has no secrets to write into it.
  await dotenv.load(isOptional: kReleaseMode);
  await Hive.initFlutter();
  await Hive.openBox<String>(AppConstants.hiveSessionsBox);
  await Hive.openBox<String>(AppConstants.hiveInterviewsBox);

  await GemmaSpeechService.initializeRuntime();
  await AdService.initialize();

  runApp(const ProviderScope(child: SpeechCoachApp()));
}

class SpeechCoachApp extends StatelessWidget {
  const SpeechCoachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Oralidle',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
