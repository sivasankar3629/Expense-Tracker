const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// ₹12 for whole amounts, ₹12.50 otherwise.
String formatAmount(double amount) {
  final isWhole = amount == amount.roundToDouble();
  return '₹${amount.toStringAsFixed(isWhole ? 0 : 2)}';
}

/// e.g. "October 2026"
String formatMonth(DateTime date) => '${_months[date.month - 1]} ${date.year}';

/// e.g. "27 Oct 2026"
String formatDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1].substring(0, 3)} ${date.year}';
