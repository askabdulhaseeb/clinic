import 'package:flutter/material.dart';

import '../utils/money.dart';

/// Right-aligned rupee amount with tabular figures so columns line up.
class MoneyText extends StatelessWidget {
  const MoneyText(this.amount, {super.key, this.style, this.symbol = true});

  final int amount;
  final TextStyle? style;
  final bool symbol;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    return Text(
      Money.format(amount, symbol: symbol),
      textAlign: TextAlign.right,
      style: base.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
    );
  }
}
