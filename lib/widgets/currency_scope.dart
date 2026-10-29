import 'package:flutter/widgets.dart';

import '../models/currency.dart';

/// Makes the chosen currency available below it; everything showing an
/// amount rebuilds when it changes.
class CurrencyScope extends InheritedWidget {
  const CurrencyScope({super.key, required this.currency, required super.child});

  final Currency currency;

  /// Rupees when there's no scope, e.g. a widget tested on its own.
  static Currency of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CurrencyScope>()?.currency ?? Currency.inr;

  @override
  bool updateShouldNotify(CurrencyScope oldWidget) => currency != oldWidget.currency;
}

extension FormatAmount on BuildContext {
  /// e.g. "₹1,240" in the chosen currency.
  String formatAmount(double amount) => CurrencyScope.of(this).format(amount);

  /// Goes before amount fields, e.g. "₹ ".
  String get currencyPrefix => '${CurrencyScope.of(this).symbol} ';
}
