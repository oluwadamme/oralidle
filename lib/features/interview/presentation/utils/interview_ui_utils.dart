import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/interview_models.dart';

/// Question types carry a glyph, not a hue. See DESIGN.md §6.
///
/// The previous mapping painted `leetcode` in the danger colour, so a coding
/// question rendered as an error state.
extension QuestionTypeUI on QuestionType {
  IconData get icon {
    switch (this) {
      case QuestionType.cvBased:
        return LucideIcons.fileText;
      case QuestionType.technical:
        return LucideIcons.cpu;
      case QuestionType.behavioral:
        return LucideIcons.messagesSquare;
      case QuestionType.leetcode:
        return LucideIcons.code;
    }
  }
}
