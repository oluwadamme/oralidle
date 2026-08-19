import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../data/models/interview_models.dart';

/// UI-layer colour mapping for question types.
/// Kept here (not in models) so model layer stays free of Flutter dependencies.
extension QuestionTypeUI on QuestionType {
  Color get color {
    switch (this) {
      case QuestionType.cvBased:
        return AppColors.good;
      case QuestionType.technical:
        return AppColors.primary;
      case QuestionType.behavioral:
        return AppColors.amber;
      case QuestionType.leetcode:
        return AppColors.poor;
    }
  }
}
