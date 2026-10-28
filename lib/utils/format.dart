const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// Indian digit grouping: ₹12, ₹1,240, ₹1,00,000.50. Decimals only when needed.
String formatAmount(double amount) {
  final isWhole = amount == amount.roundToDouble();
  final parts = amount.toStringAsFixed(isWhole ? 0 : 2).split('.');
  final decimals = parts.length > 1 ? '.${parts[1]}' : '';
  return '₹${_groupIndian(parts[0])}$decimals';
}

/// Last three digits form one group, then groups of two: 12,34,567.
String _groupIndian(String digits) {
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

const _weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

/// e.g. "WED"
String formatWeekday(DateTime date) => _weekdays[date.weekday - 1];

/// e.g. "October"
String formatMonthName(DateTime date) => _months[date.month - 1];

/// e.g. "October 2026"
String formatMonth(DateTime date) => '${_months[date.month - 1]} ${date.year}';

/// e.g. "27 Oct 2026"
String formatDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1].substring(0, 3)} ${date.year}';
