import '../constants/app_constants.dart';

class PreComputedMetrics {
  final int wordCount;
  final int wpm;
  final Map<String, int> fillerWords;
  final double uniqueWordRatio;

  const PreComputedMetrics({
    required this.wordCount,
    required this.wpm,
    required this.fillerWords,
    required this.uniqueWordRatio,
  });
}

class SpeechAnalyser {
  static PreComputedMetrics analyse(String transcript, int durationSeconds) {
    final words = _words(transcript);
    final wordCount = words.length;
    final wpm = durationSeconds > 0 ? (wordCount / (durationSeconds / 60)).round() : 0;
    final fillerWords = _detectFillerWords(transcript.toLowerCase());
    final unique = words.map((w) => w.toLowerCase()).toSet();
    final uniqueRatio = wordCount > 0 ? unique.length / wordCount : 0.0;

    return PreComputedMetrics(
      wordCount: wordCount,
      wpm: wpm,
      fillerWords: fillerWords,
      uniqueWordRatio: uniqueRatio,
    );
  }

  static List<String> _words(String text) =>
      text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  static Map<String, int> _detectFillerWords(String text) {
    final counts = <String, int>{};
    for (final filler in AppConstants.fillerWords) {
      final pattern = RegExp(r'\b' + RegExp.escape(filler) + r'\b');
      final matches = pattern.allMatches(text).length;
      if (matches > 0) counts[filler] = matches;
    }
    return counts;
  }
}
