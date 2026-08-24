import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:widget_overlay_outside/core/constants/app_constants.dart';
import 'package:widget_overlay_outside/core/theme/app_spacing.dart';
import 'package:widget_overlay_outside/core/theme/app_theme.dart';
import 'package:widget_overlay_outside/core/widgets/app_button.dart';
import 'package:widget_overlay_outside/core/widgets/category_badge.dart';
import 'package:widget_overlay_outside/core/widgets/pressable.dart';
import 'package:widget_overlay_outside/core/widgets/score_meter.dart';
import 'package:widget_overlay_outside/core/widgets/surface_card.dart';
import 'package:widget_overlay_outside/core/widgets/tabular_text.dart';

Widget _host(Widget child, {bool reduceMotion = false, double textScale = 1}) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: MediaQuery(
      data: MediaQueryData(
        disableAnimations: reduceMotion,
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('Pressable', () {
    testWidgets('reaches the 48dp minimum without inflating its child', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          Pressable(onTap: () {}, child: const SizedBox(width: 12, height: 12)),
        ),
      );

      final target = tester.getSize(find.byType(Pressable));
      expect(target.width, greaterThanOrEqualTo(TouchTarget.min));
      expect(target.height, greaterThanOrEqualTo(TouchTarget.min));

      // The visual child keeps its own size; only the ink area grew.
      expect(tester.getSize(find.byType(SizedBox).first).height, 12);
    });

    testWidgets('announces itself as a button and reports disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const Pressable(onTap: null, child: Text('Go'))),
      );

      final node = tester.getSemantics(find.byType(Pressable).first);
      expect(node.flagsCollection.isButton, isTrue);
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
        reason: 'a disabled control must not offer a tap action',
      );
    });

    testWidgets('fires onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(Pressable(onTap: () => taps++, child: const Text('Go'))),
      );
      await tester.tap(find.byType(Pressable));
      expect(taps, 1);
    });
  });

  group('AppButton', () {
    testWidgets('busy blocks taps and keeps its width', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(AppButton.primary(label: 'Analyse', onPressed: () => taps++)),
      );
      final idleWidth = tester.getSize(find.byType(AppButton)).width;

      await tester.pumpWidget(
        _host(
          AppButton.primary(
            label: 'Analyse',
            onPressed: () => taps++,
            busy: true,
          ),
        ),
      );
      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(taps, 0, reason: 'a busy button must not re-fire');
      expect(
        tester.getSize(find.byType(AppButton)).width,
        idleWidth,
        reason: 'the spinner must not collapse the button',
      );
    });

    testWidgets('destructive is an outline, not a filled block', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(AppButton.destructive(label: 'Delete', onPressed: () {})),
      );
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('AppIconButton exposes its tooltip as the accessible name', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          AppIconButton(
            icon: LucideIcons.trash2,
            onPressed: () {},
            tooltip: 'Delete session',
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(AppIconButton)).label,
        'Delete session',
      );
    });
  });

  group('ScoreMeter', () {
    // Bands were an explicit product decision: the breakdown has to be
    // scannable. What must not come back is the voice ramp, which encodes
    // amplitude and would make a high score read as "too loud".
    testWidgets('fills with its score band, never the voice ramp', (
      tester,
    ) async {
      for (final (score, band) in [
        (20, AppColors.scoreLow),
        (50, AppColors.scoreFair),
        (70, AppColors.scoreGood),
        (90, AppColors.scoreHigh),
      ]) {
        await tester.pumpWidget(_host(ScoreMeter(score: score)));
        await tester.pumpAndSettle();

        final fills = tester
            .widgetList<DecoratedBox>(find.byType(DecoratedBox))
            .map((d) => (d.decoration as BoxDecoration).color)
            .whereType<Color>()
            .toSet();

        expect(
          fills.contains(band),
          isTrue,
          reason: 'score $score should fill with its band',
        );
        for (final banned in [
          AppColors.voiceLow,
          AppColors.voiceMid,
          AppColors.voicePeak,
        ]) {
          expect(
            fills.contains(banned),
            isFalse,
            reason: 'score $score must not borrow the voice ramp',
          );
        }
      }
    });

    testWidgets('announces the trajectory when an average is given', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ScoreMeter(score: 72, label: 'Fluency', previousAverage: 68),
        ),
      );
      final node = tester.getSemantics(find.byType(ScoreMeter));
      expect(node.label, 'Fluency');
      expect(node.value, contains('72 out of 100'));
      expect(node.value, contains('up 4'));
    });

    // The first version of this shipped a fill at zero height: the widget was
    // in the tree, so a presence check passed while every bar rendered empty.
    testWidgets('the fill has real size, proportional to the score', (
      tester,
    ) async {
      for (final (score, expected) in [(0, 0.0), (50, 100.0), (100, 200.0)]) {
        await tester.pumpWidget(
          _host(SizedBox(width: 200, child: ScoreMeter(score: score))),
        );
        await tester.pumpAndSettle();

        final fill = tester
            .renderObjectList<RenderBox>(find.byType(DecoratedBox))
            .firstWhere(
              (b) =>
                  ((b.parent as dynamic) != null) &&
                  b.size.height > 0 &&
                  b.size.width == expected,
              orElse: () => throw TestFailure(
                'score $score: no fill of width $expected found',
              ),
            );
        expect(
          fill.size.height,
          greaterThan(0),
          reason: 'a zero-height fill is invisible',
        );
      }
    });

    testWidgets('settles immediately under reduced motion', (tester) async {
      await tester.pumpWidget(
        _host(const ScoreMeter(score: 80), reduceMotion: true),
      );
      await tester.pump();

      final fill = tester
          .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .first;
      expect(fill.widthFactor, closeTo(0.8, 0.001));
    });
  });

  group('SurfaceCard', () {
    testWidgets('an interactive card is identified by borderControl', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(SurfaceCard(onTap: () {}, child: const Text('Session'))),
      );

      final border =
          tester
                  .widgetList<Container>(find.byType(Container))
                  .map((c) => c.decoration)
                  .whereType<BoxDecoration>()
                  .firstWhere((d) => d.border != null)
                  .border!
              as Border;

      expect(border.top.color, AppColors.borderControl);
    });

    testWidgets('a static card uses the decorative line', (tester) async {
      await tester.pumpWidget(_host(const SurfaceCard(child: Text('Summary'))));

      final border =
          tester
                  .widgetList<Container>(find.byType(Container))
                  .map((c) => c.decoration)
                  .whereType<BoxDecoration>()
                  .firstWhere((d) => d.border != null)
                  .border!
              as Border;

      expect(border.top.color, AppColors.line);
    });
  });

  group('TabularText', () {
    testWidgets('gives every digit an identical slot', (tester) async {
      await tester.pumpWidget(_host(const TabularText('111')));
      final narrow = tester.getSize(find.byType(TabularText)).width;

      await tester.pumpWidget(_host(const TabularText('000')));
      final wide = tester.getSize(find.byType(TabularText)).width;

      expect(
        narrow,
        wide,
        reason: 'a timer must not change width as digits change',
      );
    });

    testWidgets('reads as one value rather than per-glyph', (tester) async {
      await tester.pumpWidget(_host(const TabularText('1:47')));
      expect(tester.getSemantics(find.byType(TabularText)).label, '1:47');
    });
  });

  group('CategoryBadge', () {
    testWidgets('the icon carries the accent, the label stays muted', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const CategoryBadge(label: 'Technology', icon: LucideIcons.cpu)),
      );

      expect(find.byIcon(LucideIcons.cpu), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byType(Icon)).color,
        AppColors.accent,
        reason: 'the icon is the card\'s spark of colour',
      );
      expect(
        tester.widget<Text>(find.text('Technology')).style?.color,
        AppColors.inkMuted,
        reason: 'an unselected label must not compete with the icon',
      );
    });

    testWidgets('holds its layout at 1.5x text scale', (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 160,
            child: CategoryBadge(
              label: 'Personal Growth',
              icon: LucideIcons.sprout,
            ),
          ),
          textScale: 1.5,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
