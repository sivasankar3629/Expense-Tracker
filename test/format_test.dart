import 'package:flutter_test/flutter_test.dart';

import 'package:expense_tracker/utils/format.dart';

void main() {
  test('amounts use Indian digit grouping', () {
    expect(formatAmount(12), '₹12');
    expect(formatAmount(180.5), '₹180.50');
    expect(formatAmount(1240), '₹1,240');
    expect(formatAmount(15000), '₹15,000');
    expect(formatAmount(100000.5), '₹1,00,000.50');
    expect(formatAmount(12345678), '₹1,23,45,678');
  });
}
