import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:widget_overlay_outside/core/constants/app_constants.dart';
import 'package:widget_overlay_outside/core/providers/core_providers.dart';
import 'package:widget_overlay_outside/features/auth/presentation/link_account_sheet.dart';

import '../../core/services/sync/fake_remote_store.dart';

/// The reported bug: tapping Send code left the button permanently disabled
/// after a cancelled or failed captcha, recoverable only by hot reload.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('link_sheet');
    Hive.init(dir.path);
    for (final box in [
      AppConstants.hiveSessionsBox,
      AppConstants.hiveInterviewsBox,
      AppConstants.hiveOutboxBox,
      AppConstants.hivePendingAudioBox,
      AppConstants.hivePrefsBox,
    ]) {
      await Hive.openBox<String>(box);
    }
    dotenv.testLoad(fileInput: '');
  });

  Future<void> pumpSheet(
    WidgetTester tester,
    Future<String?> Function(BuildContext) captcha,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [remoteStoreProvider.overrideWithValue(FakeRemoteStore())],
        child: MaterialApp(
          home: Scaffold(body: LinkAccountSheet(requestCaptcha: captcha)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fillDetails(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField).at(0), 'Damilola');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'me@example.com',
    );
    await tester.pumpAndSettle();
  }

  bool sendEnabled(WidgetTester tester) {
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Send code'),
    );
    return button.onPressed != null;
  }

  testWidgets('the button comes back after a cancelled captcha', (
    tester,
  ) async {
    var attempts = 0;
    await pumpSheet(tester, (_) async {
      attempts++;
      return null; // dismissed
    });
    await fillDetails(tester);

    expect(sendEnabled(tester), isTrue);

    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    expect(attempts, 1);
    expect(
      sendEnabled(tester),
      isTrue,
      reason: 'a dismissed captcha must not strand the button',
    );

    // And it can be tapped again — the part that needed a hot reload before.
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(sendEnabled(tester), isTrue);
  });

  testWidgets('the button comes back after the captcha throws', (
    tester,
  ) async {
    await pumpSheet(tester, (_) async => throw Exception('challenge-error'));
    await fillDetails(tester);

    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    expect(sendEnabled(tester), isTrue);
    expect(find.textContaining('challenge-error'), findsOneWidget);
  });

  testWidgets('the button comes back when sending the code fails', (
    tester,
  ) async {
    // A captcha token arrives, then the auth call fails — Supabase is
    // unconfigured here, so sendLinkCode throws.
    await pumpSheet(tester, (_) async => 'a-token');
    await fillDetails(tester);

    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    expect(sendEnabled(tester), isTrue);
    expect(find.byType(LinkAccountSheet), findsOneWidget);
  });

  testWidgets('an invalid form never reaches the captcha', (tester) async {
    var attempts = 0;
    await pumpSheet(tester, (_) async {
      attempts++;
      return null;
    });

    // Nothing filled in.
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    expect(attempts, 0);
    expect(find.text('Enter your name'), findsOneWidget);
    expect(sendEnabled(tester), isTrue);
  });

  testWidgets('the typo guard offers a correction', (tester) async {
    await pumpSheet(tester, (_) async => null);
    await tester.enterText(find.byType(TextFormField).at(1), 'me@gmial.com');
    await tester.pumpAndSettle();

    expect(find.text('Did you mean me@gmail.com?'), findsOneWidget);

    await tester.tap(find.text('Did you mean me@gmail.com?'));
    await tester.pumpAndSettle();

    expect(find.text('Did you mean me@gmail.com?'), findsNothing);
  });
}
