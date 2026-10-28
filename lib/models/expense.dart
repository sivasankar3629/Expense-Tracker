class Expense {
  Expense({
    required this.title,
    required this.amount,
    required this.dateTime,
    this.notes = '',
  }) : id = DateTime.now().microsecondsSinceEpoch.toString();

  final String id;
  final String title;
  final double amount;
  final DateTime dateTime;
  final String notes;
}
