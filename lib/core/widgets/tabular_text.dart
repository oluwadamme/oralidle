import 'package:flutter/material.dart';

class TabularText extends StatelessWidget {
  const TabularText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.center,
    this.semanticsLabel,
  });

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final String? semanticsLabel;

  static bool _isDigit(String c) {
    final code = c.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }

  double _digitWidth(TextStyle? effective, TextScaler scaler) {
    var widest = 0.0;
    for (var d = 0; d <= 9; d++) {
      final painter = TextPainter(
        text: TextSpan(text: '$d', style: effective),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      if (painter.width > widest) widest = painter.width;
    }
    return widest;
  }

  @override
  Widget build(BuildContext context) {
    final effective = style ?? DefaultTextStyle.of(context).style;
    final scaler = MediaQuery.textScalerOf(context);
    final slot = _digitWidth(effective, scaler);

    return Semantics(
      label: semanticsLabel ?? text,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          for (final char in text.split(''))
            if (_isDigit(char))
              SizedBox(
                width: slot,
                child: Text(char, style: effective, textAlign: textAlign),
              )
            else
              Text(char, style: effective),
        ],
      ),
    );
  }
}
