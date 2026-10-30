import 'package:flutter/foundation.dart';

import '../data/sqlite_storage.dart';
import '../state/expense_store.dart';
import 'sms_detection.dart';
import 'sms_parser.dart';
import 'sms_source.dart';
import 'spend_notifications.dart';

/// An SMS that arrived while the app wasn't running (see SmsReceiver.kt):
/// if it's a spend, it joins the review list and the user is notified.
Future<void> handleSmsInBackground(SmsMessage sms) async {
  // Cheap checks first: most SMS aren't spends.
  if (parseBankSms(sms) == null) return;
  // Not closed afterwards: the app may share the same connection.
  final storage = await SqliteStorage.open();
  final data = await storage.loadDetection();
  if (!data.enabled) return;
  await LocalSpendNotifier.initialize();
  final detection = SmsDetection(
    store: await ExpenseStore.open(storage),
    source: const NoSmsSource(),
    storage: storage,
    notifier: LocalSpendNotifier(),
    data: data,
  );
  final found = await detection.receive(sms);
  await detection.saved;
  debugPrint(found == null ? 'Background SMS: not a new spend' : 'Background SMS: ${found.amount}');
}
