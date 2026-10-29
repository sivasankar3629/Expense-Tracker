const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const _weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

/// e.g. "WED"
String formatWeekday(DateTime date) => _weekdays[date.weekday - 1];

/// e.g. "October"
String formatMonthName(DateTime date) => _months[date.month - 1];

/// e.g. "October 2026"
String formatMonth(DateTime date) => '${_months[date.month - 1]} ${date.year}';

/// e.g. "27 Oct 2026"
String formatDate(DateTime date) => '${formatShortDate(date)} ${date.year}';

/// e.g. "27 Oct"
String formatShortDate(DateTime date) => '${date.day} ${_months[date.month - 1].substring(0, 3)}';

/// As short as stays clear: "Today", "Yesterday", "27 Oct" this year,
/// otherwise "27 Oct 2025".
String formatDayLabel(DateTime date, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(date.year, date.month, date.day);
  if (day == today) return 'Today';
  if (day == DateTime(today.year, today.month, today.day - 1)) return 'Yesterday';
  return day.year == today.year ? formatShortDate(day) : formatDate(day);
}

/// e.g. "1st", "22nd", "25th"
String formatOrdinal(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  return '$n${switch (n % 10) { 1 => 'st', 2 => 'nd', 3 => 'rd', _ => 'th' }}';
}
