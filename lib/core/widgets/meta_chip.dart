import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color textColor;
  final double iconSize;
  final double fontSize;

  const MetaChip({
    super.key,
    required this.icon,
    required this.label,
    this.iconColor = AppColors.borderControl,
    this.textColor = AppColors.inkMuted,
    this.iconSize = 13,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: iconColor),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: fontSize, color: textColor),
        ),
      ],
    );
  }
}
