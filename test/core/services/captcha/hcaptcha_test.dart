import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widget_overlay_outside/core/config/hcaptcha_config.dart';
import 'package:widget_overlay_outside/core/services/captcha/hcaptcha_modal.dart';

void main() {
  group('HCaptchaConfig', () {
    test('resolves default test sitekey when unconfigured', () {
      expect(HCaptchaConfig.siteKey, isNotEmpty);
      expect(HCaptchaConfig.isConfigured, isTrue);
    });

    test('default test sitekey matches standard hCaptcha test key', () {
      expect(
        HCaptchaConfig.testSiteKey,
        '10000000-ffff-ffff-ffff-000000000001',
      );
    });
  });

  group('HCaptchaModal', () {
    testWidgets('renders title and close button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HCaptchaModal(siteKey: HCaptchaConfig.testSiteKey),
          ),
        ),
      );

      expect(find.text('Verification'), findsOneWidget);
      expect(
        find.text('Please complete the verification below to continue.'),
        findsOneWidget,
      );
    });
  });
}
