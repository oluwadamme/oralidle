import 'dart:developer' show log;
import 'package:uuid/uuid.dart';

enum QuestionType { cvBased, technical, behavioral, leetcode }

enum InterviewMode { technical, behavioral, mixed }

extension QuestionTypeExt on QuestionType {
  String get label {
    switch (this) {
      case QuestionType.cvBased:
        return 'CV-Based';
      case QuestionType.technical:
        return 'Technical';
      case QuestionType.behavioral:
        return 'Behavioral';
      case QuestionType.leetcode:
        return 'DSA';
    }
  }
}

extension InterviewModeExt on InterviewMode {
  String get label {
    switch (this) {
      case InterviewMode.technical:
        return 'Technical';
      case InterviewMode.behavioral:
        return 'Behavioral';
      case InterviewMode.mixed:
        return 'Full Interview';
    }
  }

  String get description {
    switch (this) {
      case InterviewMode.technical:
        return 'Coding, system design & CV deep-dive';
      case InterviewMode.behavioral:
        return 'STAR-method & leadership scenarios';
      case InterviewMode.mixed:
        return 'Realistic mix of all question types';
    }
  }
}

class InterviewQuestion {
  final String text;
  final QuestionType type;

  const InterviewQuestion({required this.text, required this.type});

  factory InterviewQuestion.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['question_type'] as String?) ?? 'technical';
    final type = QuestionType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () {
        log('InterviewQuestion: unrecognized question_type "$typeStr", defaulting to technical');
        return QuestionType.technical;
      },
    );
    return InterviewQuestion(text: json['question'] as String, type: type);
  }

  Map<String, dynamic> toJson() => {
        'question': text,
        'question_type': type.name,
      };
}

class TurnEvaluation {
  final int contentScore;
  final String feedback;
  // Present only when contentScore < 80 — provided by the AI to show the
  // candidate what an excellent answer looks like.
  final String? modelAnswer;

  const TurnEvaluation({
    required this.contentScore,
    required this.feedback,
    this.modelAnswer,
  });

  factory TurnEvaluation.fromJson(Map<String, dynamic> json) => TurnEvaluation(
        contentScore: (json['content_score'] as num).toInt(),
        feedback: json['feedback'] as String,
        modelAnswer: json['model_answer'] as String?,
      );

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'content_score': contentScore,
      'feedback': feedback,
    };
    if (modelAnswer != null) m['model_answer'] = modelAnswer;
    return m;
  }
}

class InterviewTurn {
  final InterviewQuestion question;
  final String transcript;
  final TurnEvaluation evaluation;

  const InterviewTurn({
    required this.question,
    required this.transcript,
    required this.evaluation,
  });

  factory InterviewTurn.fromJson(Map<String, dynamic> json) => InterviewTurn(
        question: InterviewQuestion.fromJson(
            json['question'] as Map<String, dynamic>),
        transcript: json['transcript'] as String,
        evaluation: TurnEvaluation.fromJson(
            json['evaluation'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'question': question.toJson(),
        'transcript': transcript,
        'evaluation': evaluation.toJson(),
      };
}

class InterviewEvaluation {
  final int overallScore;
  final String summary;
  final List<String> strengths;
  final List<String> improvements;

  const InterviewEvaluation({
    required this.overallScore,
    required this.summary,
    required this.strengths,
    required this.improvements,
  });

  factory InterviewEvaluation.fromJson(Map<String, dynamic> json) =>
      InterviewEvaluation(
        overallScore: (json['overall_score'] as num).toInt(),
        summary: json['summary'] as String,
        strengths: (json['strengths'] as List<dynamic>)
            .map((e) => e as String)
            .toList(),
        improvements: (json['improvements'] as List<dynamic>)
            .map((e) => e as String)
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'overall_score': overallScore,
        'summary': summary,
        'strengths': strengths,
        'improvements': improvements,
      };
}

class CompletedInterview {
  final String id;
  final InterviewMode mode;
  final int targetQuestions;
  final List<InterviewTurn> turns;
  final InterviewEvaluation evaluation;
  final DateTime timestamp;

  CompletedInterview({
    String? id,
    required this.mode,
    required this.targetQuestions,
    required this.turns,
    required this.evaluation,
    DateTime? timestamp,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  factory CompletedInterview.fromJson(Map<String, dynamic> json) =>
      CompletedInterview(
        id: json['id'] as String,
        mode: InterviewMode.values.firstWhere(
          (m) => m.name == json['mode'] as String,
          orElse: () {
            log('CompletedInterview: unrecognized mode "${json['mode']}", defaulting to mixed');
            return InterviewMode.mixed;
          },
        ),
        targetQuestions: (json['target_questions'] as num).toInt(),
        turns: (json['turns'] as List<dynamic>)
            .map((e) => InterviewTurn.fromJson(e as Map<String, dynamic>))
            .toList(),
        evaluation: InterviewEvaluation.fromJson(
            json['evaluation'] as Map<String, dynamic>),
        timestamp: DateTime.parse(json['timestamp'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'mode': mode.name,
        'target_questions': targetQuestions,
        'turns': turns.map((t) => t.toJson()).toList(),
        'evaluation': evaluation.toJson(),
        'timestamp': timestamp.toIso8601String(),
      };

  int get averageContentScore {
    if (turns.isEmpty) return 0;
    return turns
            .map((t) => t.evaluation.contentScore)
            .reduce((a, b) => a + b) ~/
        turns.length;
  }
}

class InterviewSetup {
  final InterviewMode mode;
  final int questionCount;
  final String? customCvContent;
  final String? customCvFileName;

  const InterviewSetup({
    required this.mode,
    required this.questionCount,
    this.customCvContent,
    this.customCvFileName,
  });
}
