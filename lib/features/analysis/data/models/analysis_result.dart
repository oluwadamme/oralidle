class AnalysisResult {
  final SpeechScores scores;
  final int overallScore;
  final Map<String, int> fillerWords;
  final int wpm;
  final List<String> strengths;
  final List<ImprovementTip> improvements;
  final String summary;

  const AnalysisResult({
    required this.scores,
    required this.overallScore,
    required this.fillerWords,
    required this.wpm,
    required this.strengths,
    required this.improvements,
    required this.summary,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      scores: SpeechScores.fromJson(json['scores'] as Map<String, dynamic>),
      overallScore: (json['overall_score'] as num).toInt(),
      fillerWords: (json['filler_words'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as num).toInt()),
      ),
      wpm: (json['wpm'] as num).toInt(),
      strengths: List<String>.from(json['strengths'] as List),
      improvements: (json['improvements'] as List)
          .map((e) => ImprovementTip.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: json['summary'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'scores': scores.toJson(),
    'overall_score': overallScore,
    'filler_words': fillerWords,
    'wpm': wpm,
    'strengths': strengths,
    'improvements': improvements.map((e) => e.toJson()).toList(),
    'summary': summary,
  };
}

class SpeechScores {
  final int fluency;
  final int vocabulary;
  final int grammar;
  final int coherence;
  final int topicRelevance;
  final int confidence;

  const SpeechScores({
    required this.fluency,
    required this.vocabulary,
    required this.grammar,
    required this.coherence,
    required this.topicRelevance,
    required this.confidence,
  });

  factory SpeechScores.fromJson(Map<String, dynamic> json) => SpeechScores(
    fluency: (json['fluency'] as num).toInt(),
    vocabulary: (json['vocabulary'] as num).toInt(),
    grammar: (json['grammar'] as num).toInt(),
    coherence: (json['coherence'] as num).toInt(),
    topicRelevance: (json['topic_relevance'] as num).toInt(),
    confidence: (json['confidence'] as num).toInt(),
  );

  Map<String, dynamic> toJson() => {
    'fluency': fluency,
    'vocabulary': vocabulary,
    'grammar': grammar,
    'coherence': coherence,
    'topic_relevance': topicRelevance,
    'confidence': confidence,
  };

  List<double> get asList => [
    fluency.toDouble(),
    vocabulary.toDouble(),
    grammar.toDouble(),
    coherence.toDouble(),
    topicRelevance.toDouble(),
    confidence.toDouble(),
  ];
}

class ImprovementTip {
  final String area;
  final String tip;

  const ImprovementTip({required this.area, required this.tip});

  factory ImprovementTip.fromJson(Map<String, dynamic> json) => ImprovementTip(
    area: json['area'] as String,
    tip: json['tip'] as String,
  );

  Map<String, dynamic> toJson() => {'area': area, 'tip': tip};
}
