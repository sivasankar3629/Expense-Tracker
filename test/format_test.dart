import 'package:flutter_test/flutter_test.dart';

import 'package:expense_tracker/models/currency.dart';
import 'package:expense_tracker/utils/format.dart';

void main() {
  test('rupees use Indian digit grouping', () {
    const inr = Currency.inr;
    expect(inr.format(12), '₹12');
    expect(inr.format(180.5), '₹180.50');
    expect(inr.format(1240), '₹1,240');
    expect(inr.format(15000), '₹15,000');
    expect(inr.format(100000.5), '₹1,00,000.50');
    expect(inr.format(12345678), '₹1,23,45,678');
  });

  test('other currencies group in thousands, with a space after letter symbols', () {
    expect(Currency.byCode('USD').format(12), r'$12');
    expect(Currency.byCode('USD').format(1234567.5), r'$1,234,567.50');
    expect(Currency.byCode('EUR').format(100000), '€100,000');
    expect(Currency.byCode('AED').format(1240), 'AED 1,240');
    expect(Currency.byCode('PKR').format(100000), 'Rs 1,00,000');
  });

  test('an unknown currency code falls back to rupees', () {
    expect(Currency.byCode('XYZ'), Currency.inr);
    expect(Currency.byCode(null), Currency.inr);
  });

  test('ordinals', () {
    expect([1, 2, 3, 4, 11, 12, 13, 21, 22, 23, 25, 28].map(formatOrdinal), [
      '1st', '2nd', '3rd', '4th', '11th', '12th', '13th', '21st', '22nd', '23rd', '25th', '28th',
    ]);
  });

  test('day labels stay short', () {
    final now = DateTime(2026, 10, 29, 9, 30);
    expect(formatDayLabel(DateTime(2026, 10, 29, 23, 59), now: now), 'Today');
    expect(formatDayLabel(DateTime(2026, 10, 28, 8), now: now), 'Yesterday');
    expect(formatDayLabel(DateTime(2026, 10, 2), now: now), '2 Oct');
    expect(formatDayLabel(DateTime(2025, 12, 31), now: now), '31 Dec 2025');
    // Yesterday across a month and a year boundary.
    expect(formatDayLabel(DateTime(2026, 12, 31), now: DateTime(2027, 1, 1)), 'Yesterday');
  });
}
