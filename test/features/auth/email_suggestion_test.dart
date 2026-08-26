import 'package:flutter_test/flutter_test.dart';
import 'package:widget_overlay_outside/features/auth/data/email_suggestion.dart';

void main() {
  String? suggest(String email) => EmailSuggestion.forAddress(email);

  group('catches a mistyped domain', () {
    test('a dropped character', () {
      expect(suggest('me@gmai.com'), 'me@gmail.com');
      expect(suggest('me@outlok.com'), 'me@outlook.com');
    });

    test('a transposed pair', () {
      expect(suggest('me@gmial.com'), 'me@gmail.com');
      expect(suggest('me@hotmial.com'), 'me@hotmail.com');
    });

    test('a doubled character', () {
      expect(suggest('me@gmaill.com'), 'me@gmail.com');
    });

    test('a wrong character', () {
      expect(suggest('me@gmail.con'), 'me@gmail.com');
      expect(suggest('me@yahoo.con'), 'me@yahoo.com');
    });

    test('the local part is preserved exactly', () {
      expect(
        suggest('first.last+tag@gmial.com'),
        'first.last+tag@gmail.com',
      );
    });
  });

  group('stays quiet', () {
    test('when the domain is already right', () {
      for (final ok in [
        'me@gmail.com',
        'me@icloud.com',
        'me@proton.me',
        'me@outlook.com',
      ]) {
        expect(suggest(ok), isNull, reason: ok);
      }
    });

    test('for a legitimate company domain', () {
      // The real risk of a suggestion list: "correcting" an address that was
      // never wrong. Nothing here is one edit from a consumer domain.
      for (final ok in [
        'ayodeji@nomba.com',
        'someone@vercel.com',
        'dev@supabase.io',
        'me@a-very-unusual-domain.co',
      ]) {
        expect(suggest(ok), isNull, reason: ok);
      }
    });

    test('when the domain is too far off to guess', () {
      expect(suggest('me@completelydifferent.com'), isNull);
    });

    test('for input that is not an address yet', () {
      expect(suggest(''), isNull);
      expect(suggest('me'), isNull);
      expect(suggest('me@'), isNull);
      expect(suggest('@gmail.com'), isNull);
    });
  });
}
