import 'package:flutter/material.dart';

class Topic {
  final String id;
  final String title;
  final String category;
  final String hint;

  const Topic({
    required this.id,
    required this.title,
    required this.category,
    required this.hint,
  });
}

extension TopicCategoryColor on String {
  Color get categoryColor {
    switch (this) {
      case 'Technology':
        return const Color(0xFF2196F3);
      case 'Society':
        return const Color(0xFF9C27B0);
      case 'Personal Growth':
        return const Color(0xFF4CAF50);
      case 'Hypotheticals':
        return const Color(0xFFFF9800);
      case 'Current Events':
        return const Color(0xFFF44336);
      case 'Fun & Creative':
        return const Color(0xFFE91E63);
      case 'Business':
        return const Color(0xFF009688);
      case 'Environment':
        return const Color(0xFF8BC34A);
      case 'Philosophy':
        return const Color(0xFF3F51B5);
      case 'Health':
        return const Color(0xFF00BCD4);
      default:
        return const Color(0xFF607D8B);
    }
  }
}
