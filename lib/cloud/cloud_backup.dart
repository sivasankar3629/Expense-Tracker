import '../data/expense_storage.dart';
import '../models/account.dart';
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
  Future<void> saveLastUsedAccountId(String id);

  /// Makes the cloud match [data] exactly, writing only what differs.
  Future<void> replaceAll(StoredData data);
}

/// Combines this phone's data with the cloud's when signing in, so nothing is
/// lost on either side.
///
/// - Records are matched by id; where both sides have one, the phone's wins.
/// - A cloud account with the same type and nickname as a phone account (say
///   "SBI Savings" added separately on two phones) is folded into the phone's,
///   and its expenses follow it.
StoredData mergeForSignIn({required StoredData phone, required StoredData cloud}) {
  String key(Account a) => '${a.type.name}:${a.nickname.trim().toLowerCase()}';

  final phoneIds = {for (final a in phone.accounts) a.id};
  final phoneByKey = {for (final a in phone.accounts) key(a): a};
  final remap = <String, String>{};
  final accounts = [...phone.accounts];
  for (final account in cloud.accounts) {
    if (phoneIds.contains(account.id)) continue;
    final twin = phoneByKey[key(account)];
    if (twin != null) {
      remap[account.id] = twin.id;
    } else {
      accounts.add(account);
      phoneByKey[key(account)] = account;
    }
  }

  final expenses = {for (final e in cloud.expenses) e.id: e};
  for (final e in expenses.values.toList()) {
    final target = remap[e.accountId];
    if (target != null) {
      expenses[e.id] = Expense(
        id: e.id,
        title: e.title,
        amount: e.amount,
        dateTime: e.dateTime,
        accountId: target,
        notes: e.notes,
      );
    }
  }
  for (final e in phone.expenses) {
    expenses[e.id] = e;
  }

  // A phone with no expenses yet (e.g. a new one) has no real preference.
  final lastUsed = phone.expenses.isEmpty
      ? cloud.lastUsedAccountId ?? phone.lastUsedAccountId
      : phone.lastUsedAccountId ?? cloud.lastUsedAccountId;
  return StoredData(
    accounts: accounts,
    expenses: expenses.values.toList(),
    lastUsedAccountId: lastUsed == null ? null : remap[lastUsed] ?? lastUsed,
  );
}
