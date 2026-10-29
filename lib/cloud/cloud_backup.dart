import '../data/expense_storage.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/expense.dart';

/// A signed-in user's copy of the data in the cloud.
abstract interface class CloudBackup {
  /// Everything currently in the cloud for this user.
  ///
  /// With [fromServer], fails when offline instead of answering from a local
  /// cache that may be empty, which would look like "nothing in the cloud".
  Future<StoredData> fetch({bool fromServer = false});

  Future<void> saveExpense(Expense expense);
  Future<void> deleteExpense(String id);
  Future<void> saveAccount(Account account);
  Future<void> deleteAccount(String id);
  Future<void> saveCategory(ExpenseCategory category);
  Future<void> deleteCategory(String id);
  Future<void> saveLastUsedAccountId(String id);

  /// Makes the cloud match [data] exactly, writing only what differs.
  Future<void> replaceAll(StoredData data);
}

/// Combines this phone's data with the cloud's when signing in, so nothing is
/// lost on either side.
///
/// - Records are matched by id; where both sides have one, the phone's wins.
/// - A cloud account or category with the same name as one on the phone (say
///   "SBI Savings" or "Food" made separately on two phones) is folded into the
///   phone's, and its expenses follow it.
StoredData mergeForSignIn({required StoredData phone, required StoredData cloud}) {
  final accountRemap = <String, String>{};
  final accounts = _mergeById(
    phone: phone.accounts,
    cloud: cloud.accounts,
    id: (a) => a.id,
    sameThing: (a) => '${a.type.name}:${a.nickname.trim().toLowerCase()}',
    remap: accountRemap,
  );
  final categoryRemap = <String, String>{};
  final categories = _mergeById(
    phone: phone.categories,
    cloud: cloud.categories,
    id: (c) => c.id,
    sameThing: (c) => c.name.trim().toLowerCase(),
    remap: categoryRemap,
  );

  final expenses = {
    for (final e in cloud.expenses)
      e.id: e.copyWith(
        accountId: accountRemap[e.accountId],
        categoryId: categoryRemap[e.categoryId],
      ),
  };
  for (final e in phone.expenses) {
    expenses[e.id] = e;
  }

  // A phone with no expenses yet (e.g. a new one) has no real preference.
  final lastUsed = phone.expenses.isEmpty
      ? cloud.lastUsedAccountId ?? phone.lastUsedAccountId
      : phone.lastUsedAccountId ?? cloud.lastUsedAccountId;
  return StoredData(
    accounts: accounts,
    categories: categories,
    expenses: expenses.values.toList(),
    lastUsedAccountId: lastUsed == null ? null : accountRemap[lastUsed] ?? lastUsed,
  );
}

/// The phone's items, then cloud-only ones. Cloud items that are the same
/// thing as a phone item (per [sameThing]) are dropped and recorded in [remap]
/// as cloud id → phone id.
List<T> _mergeById<T>({
  required List<T> phone,
  required List<T> cloud,
  required String Function(T) id,
  required String Function(T) sameThing,
  required Map<String, String> remap,
}) {
  final phoneIds = {for (final item in phone) id(item)};
  final byKey = {for (final item in phone) sameThing(item): item};
  final merged = [...phone];
  for (final item in cloud) {
    if (phoneIds.contains(id(item))) continue;
    final twin = byKey[sameThing(item)];
    if (twin != null) {
      remap[id(item)] = id(twin);
    } else {
      merged.add(item);
      byKey[sameThing(item)] = item;
    }
  }
  return merged;
}
