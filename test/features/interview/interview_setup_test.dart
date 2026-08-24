import 'package:flutter_test/flutter_test.dart';
import 'package:widget_overlay_outside/features/interview/data/models/interview_models.dart';

void main() {
  group('InterviewSetup with Custom Document Context', () {
    test('initializes with default null custom document fields', () {
      const setup = InterviewSetup(
        mode: InterviewMode.technical,
        questionCount: 5,
      );

      expect(setup.mode, equals(InterviewMode.technical));
      expect(setup.questionCount, equals(5));
      expect(setup.customCvContent, isNull);
      expect(setup.customCvFileName, isNull);
    });

    test('initializes with custom project README context', () {
      const customContent =
          '# My E-Commerce Microservice\n\n## Tech Stack\nNode.js, Redis, PostgreSQL';
      const fileName = 'README.md';

      const setup = InterviewSetup(
        mode: InterviewMode.mixed,
        questionCount: 7,
        customCvContent: customContent,
        customCvFileName: fileName,
      );

      expect(setup.mode, equals(InterviewMode.mixed));
      expect(setup.questionCount, equals(7));
      expect(setup.customCvContent, equals(customContent));
      expect(setup.customCvFileName, equals(fileName));
    });
  });
}
