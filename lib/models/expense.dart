class Expense {
  Expense({
    String? id,
    required this.title,
    required this.amount,
    required this.dateTime,
    required this.accountId,
    this.categoryId,
    this.notes = '',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  final String id;
  final String title;
  final double amount;
  final DateTime dateTime;
  final String accountId;

  /// Null when the expense has no category.
  final String? categoryId;
  final String notes;

  /// Pass [clearCategory] to remove the category, since a null [categoryId]
  /// here means "keep it".
  Expense copyWith({
    String? title,
    double? amount,
    DateTime? dateTime,
    String? accountId,
    String? categoryId,
    bool clearCategory = false,
    String? notes,
  }) =>
      Expense(
        id: id,
        title: title ?? this.title,
        amount: amount ?? this.amount,
        dateTime: dateTime ?? this.dateTime,
        accountId: accountId ?? this.accountId,
        categoryId: clearCategory ? null : categoryId ?? this.categoryId,
        notes: notes ?? this.notes,
      );
}
