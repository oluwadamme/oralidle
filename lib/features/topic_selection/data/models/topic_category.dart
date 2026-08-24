import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum TopicCategory {
  technology('Technology', LucideIcons.cpu),
  society('Society', LucideIcons.users),
  personalGrowth('Personal Growth', LucideIcons.sprout),
  hypotheticals('Hypotheticals', LucideIcons.helpCircle),
  currentEvents('Current Events', LucideIcons.newspaper),
  funCreative('Fun & Creative', LucideIcons.sparkles),
  business('Business', LucideIcons.briefcase),
  environment('Environment', LucideIcons.leaf),
  philosophy('Philosophy', LucideIcons.scale),
  health('Health', LucideIcons.heartPulse),
  other('Other', LucideIcons.tag);

  const TopicCategory(this.label, this.icon);

  final String label;
  final IconData icon;

  static TopicCategory fromLabel(String value) => values.firstWhere(
    (c) => c.label.toLowerCase() == value.toLowerCase(),
    orElse: () => other,
  );
}
