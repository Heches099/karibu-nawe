import 'package:flutter/material.dart';
import '../../core/utils/format.dart';

/// Styled money text with color semantics.
class MoneyText extends StatelessWidget {
  final num value;
  final bool showSign;
  final bool compact;
  final TextStyle? style;
  final Color? positiveColor;
  final Color? negativeColor;
  final Color? zeroColor;
  final bool bold;

  const MoneyText(
    this.value, {
    super.key,
    this.showSign = false,
    this.compact = false,
    this.style,
    this.positiveColor,
    this.negativeColor,
    this.zeroColor,
    this.bold = true,
  });

  Color _color() {
    if (value > 0) return positiveColor ?? const Color(0xFF2E7D32);
    if (value < 0) return negativeColor ?? const Color(0xFFC62828);
    return zeroColor ?? const Color(0xFF616161);
  }

  @override
  Widget build(BuildContext context) {
    final base = style ??
        (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    final plain = fmtMoneyPlain(value.round());
    final String display;
    if (showSign) {
      display = '${value >= 0 ? '+' : ''}${fmtMoneyPlain(value.round())}';
    } else {
      display = plain;
    }
    return Text(
      display,
      style: base.copyWith(color: _color()),
    );
  }
}

/// Row of "Label: Value" used in detail screens.
class MoneyRow extends StatelessWidget {
  final String label;
  final num value;
  final bool bold;
  final TextStyle? labelStyle;

  const MoneyRow({super.key, required this.label, required this.value, this.bold = true, this.labelStyle});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: labelStyle)),
        MoneyText(value, bold: bold),
      ],
    );
  }
}