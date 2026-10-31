import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:expense_tracker/data/sqlite_storage.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/sms/sms_parser.dart';
import 'package:expense_tracker/state/expense_store.dart';

void main() {
  test('a phone can go back to 1.0 and forward again without losing anything', () async {
    sqfliteFfiInit();
    final dir = Directory.systemTemp.createTempSync('kipto_versions');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/test.db';

    // This version: an expense, and a spend waiting for review.
    var storage = await SqliteStorage.open(factory: databaseFactoryFfi, path: path);
    final store = await ExpenseStore.open(storage)
      ..addExpense(Expense(title: 'Tea', amount: 12, dateTime: DateTime(2026, 10, 29), accountId: 'cash'));
    final sms = SmsMessage(sender: 'VM-HDFCBK', body: 'Spent Rs.649 On HDFC Bank Card 5678 At SWIGGY', date: DateTime(2026, 10, 30));
    await storage.addDetected([parseBankSms(sms)!]);
    await store.saved;
    await storage.close();

    // 1.0 opens it: it knows only version 3 and has no downgrade step, so
    // the version drops to 3 and the newer tables are left as they are.
    final old = await databaseFactoryFfi.openDatabase(path, options: OpenDatabaseOptions(version: 3));
    expect(await old.getVersion(), 3);
    await old.close();

    // Back on this version: the upgrade from 3 meets tables that are already there.
    storage = await SqliteStorage.open(factory: databaseFactoryFfi, path: path);
    expect((await ExpenseStore.open(storage)).expenses.single.title, 'Tea');
    expect((await storage.loadDetection()).pending.single.merchant, 'Swiggy');
    await storage.close();
  });
}
