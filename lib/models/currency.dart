/// How amounts are shown. Only the symbol and digit grouping change;
/// amounts are never converted.
class Currency {
  const Currency(this.code, this.symbol, this.name, {this.lakhGrouping = false});

  final String code;
  final String symbol;
  final String name;

  /// Groups as 1,00,000 (lakh and crore) instead of 100,000.
  final bool lakhGrouping;

  static const inr = Currency('INR', '₹', 'Indian rupee', lakhGrouping: true);

  static const all = [
    inr,
    Currency('USD', r'$', 'US dollar'),
    Currency('EUR', '€', 'Euro'),
    Currency('GBP', '£', 'British pound'),
    Currency('AED', 'AED', 'UAE dirham'),
    Currency('SAR', 'SAR', 'Saudi riyal'),
    Currency('QAR', 'QAR', 'Qatari riyal'),
    Currency('SGD', r'S$', 'Singapore dollar'),
    Currency('MYR', 'RM', 'Malaysian ringgit'),
    Currency('AUD', r'A$', 'Australian dollar'),
    Currency('CAD', r'C$', 'Canadian dollar'),
    Currency('NZD', r'NZ$', 'New Zealand dollar'),
    Currency('JPY', '¥', 'Japanese yen'),
    Currency('CHF', 'CHF', 'Swiss franc'),
    Currency('LKR', 'Rs', 'Sri Lankan rupee'),
    Currency('NPR', 'Rs', 'Nepalese rupee', lakhGrouping: true),
    Currency('PKR', 'Rs', 'Pakistani rupee', lakhGrouping: true),
    Currency('BDT', '৳', 'Bangladeshi taka', lakhGrouping: true),
  ];

  /// Rupees for an unknown code, e.g. from a newer app version's backup.
  static Currency byCode(String? code) =>
      all.firstWhere((c) => c.code == code, orElse: () => inr);

  /// Letter symbols get a space: "₹1,240" but "AED 1,240".
  String get prefix => RegExp(r'[A-Za-z]$').hasMatch(symbol) ? '$symbol ' : symbol;

  /// e.g. ₹12, ₹1,240, ₹1,00,000.50, $100,000.50. Decimals only when needed.
  String format(double amount) {
    final isWhole = amount == amount.roundToDouble();
    final parts = amount.abs().toStringAsFixed(isWhole ? 0 : 2).split('.');
    final decimals = parts.length > 1 ? '.${parts[1]}' : '';
    final digits = lakhGrouping ? _groupLakh(parts[0]) : _groupThousands(parts[0]);
    return '${amount < 0 ? '-' : ''}$prefix$digits$decimals';
  }

  /// Last three digits form one group, then groups of two: 12,34,567.
  static String _groupLakh(String digits) {
    if (digits.length <= 3) return digits;
    final lastThree = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final groups = <String>[];
    while (rest.length > 2) {
      groups.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    groups.insert(0, rest);
    return '${groups.join(',')},$lastThree';
  }

  /// Groups of three: 1,234,567.
  static String _groupThousands(String digits) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}
