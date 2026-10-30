import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:expense_tracker/data/sqlite_storage.dart';
import 'package:expense_tracker/main.dart';
import 'package:expense_tracker/models/account.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/sms/detection_storage.dart';
import 'package:expense_tracker/sms/sms_detection.dart';
import 'package:expense_tracker/sms/sms_parser.dart';
import 'package:expense_tracker/sms/sms_source.dart';
import 'package:expense_tracker/state/expense_store.dart';

class FakeSmsSource implements SmsSource {
  FakeSmsSource({this.granted = true, this.grantOnRequest = true});

  bool granted;
  bool grantOnRequest;
  final List<SmsMessage> messages = [];
  DateTime? lastSince;

  @override
  Future<bool> hasPermission() async => granted;

  @override
  Future<bool> requestPermission() async => granted = grantOnRequest;

  @override
  Future<List<SmsMessage>> inbox({required DateTime since}) async {
    lastSince = since;
    return [for (final m in messages) if (m.date.isAfter(since)) m]..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<void> openAppSettings() async {}
}

final now = DateTime(2026, 10, 29, 12);

SmsMessage sms(String id, String body, {Duration ago = const Duration(hours: 1), String sender = 'VM-HDFCBK'}) =>
    SmsMessage(id: id, sender: sender, body: body, date: now.subtract(ago));

SmsDetection detectionFor(ExpenseStore store, FakeSmsSource source,
        {DetectionStorage? storage, DetectionData data = const DetectionData()}) =>
    SmsDetection(
      store: store,
      source: source,
      storage: storage ?? InMemoryDetectionStorage(),
      data: data,
      clock: () => now,
    );

void main() {
  group('Scanning', () {
    test('does nothing until turned on, and stays off without permission', () async {
      final source = FakeSmsSource(granted: false, grantOnRequest: false)
        ..messages.add(sms('1', 'Sent Rs.250 from A/C *1234 to swiggy@icici. Ref 430212345678'));
      final detection = detectionFor(ExpenseStore(), source);

      expect(await detection.scan(), 0);
      expect(await detection.enable(), SmsAccess.denied);
      expect(detection.enabled, isFalse);
      expect(detection.pending, isEmpty);
    });

    test('first looks back 30 days, keeps spends only, and drops the same payment told twice', () async {
      final source = FakeSmsSource()
        ..messages.addAll([
          sms('1', 'Sent Rs.250.00 from HDFC Bank A/C *1234 to swiggy@icici. UPI Ref 430212345678'),
          // The same payment, from the UPI app's bank too.
          sms('2', 'Rs 250 debited from A/c XX1234 to VPA swiggy@icici. UPI Ref No 430212345678',
              ago: const Duration(minutes: 59), sender: 'AX-HDFCBK'),
          sms('3', '123456 is your OTP for txn of Rs.650 at BOOKMYSHOW on card 5678.'),
          sms('4', 'Spent Rs.650 On HDFC Bank Card 5678 At BOOKMYSHOW On 2026-10-26', ago: const Duration(days: 3)),
          sms('5', 'Spent Rs.999 On HDFC Bank Card 5678 At OLDSHOP', ago: const Duration(days: 40)),
        ]);
      final detection = detectionFor(ExpenseStore(), source);

      expect(await detection.enable(), SmsAccess.granted);
      expect(source.lastSince, now.subtract(const Duration(days: 30)));
      expect(detection.pending.map((t) => t.merchant), ['Swiggy', 'Bookmyshow']);
    });

    test('later scans only read what arrived since', () async {
      final source = FakeSmsSource()..messages.add(sms('1', 'Sent Rs.250 from A/C *1234 to swiggy@icici'));
      final detection = detectionFor(ExpenseStore(), source);
      await detection.enable();
      detection.ignore(detection.pending.single);

      source.messages.add(sms('2', 'Sent Rs.120 from A/C *1234 to zomato@icici', ago: const Duration(minutes: 5)));
      expect(await detection.scan(), 1);
      expect(source.lastSince, now.subtract(const Duration(hours: 1)));
      expect(detection.pending.single.merchant, 'Zomato');
    });

    test('turns itself off if the permission is taken back', () async {
      final source = FakeSmsSource()..messages.add(sms('1', 'Sent Rs.250 from A/C *1234 to swiggy@icici'));
      final detection = detectionFor(ExpenseStore(), source);
      await detection.enable();

      source.granted = false;
      await detection.scan();
      expect(detection.enabled, isFalse);
      expect(detection.pending, isEmpty);
    });
  });

  group('Adding', () {
    test('fills in the form, remembering the category and the card for next time', () async {
      final store = ExpenseStore();
      final food = store.addCategory(name: 'Food', iconKey: 'food', colorValue: 0xFFE53935);
      final card = store.addAccount('HDFC Millennia', AccountType.creditCard);
      store.addExpense(Expense(
        title: 'Swiggy', amount: 300, dateTime: now.subtract(const Duration(days: 5)),
        accountId: 'cash', categoryId: food.id,
      ));
      final source = FakeSmsSource()
        ..messages.addAll([
          sms('1', 'Spent Rs.250 On HDFC Bank Card 5678 At SWIGGY', ago: const Duration(hours: 2)),
          sms('2', 'Spent Rs.400 On HDFC Bank Card 5678 At ZEPTO', ago: const Duration(hours: 1)),
        ]);
      final detection = detectionFor(store, source);
      await detection.enable();

      final swiggy = detection.pending.firstWhere((t) => t.merchant == 'Swiggy');
      final draft = detection.draftFor(swiggy);
      expect(draft.title, 'Swiggy');
      expect(draft.amount, 250);
      expect(draft.dateTime, swiggy.date);
      expect(draft.categoryId, food.id);

      // The user picks the card for it…
      final saved = draft.copyWith(accountId: card.id);
      store.addExpense(saved);
      detection.added(swiggy, saved);
      expect(detection.pending.map((t) => t.merchant), ['Zepto']);

      // …so the next SMS about card 5678 starts on that card.
      expect(detection.draftFor(detection.pending.single).accountId, card.id);
      expect(detection.accountFor(detection.pending.single)?.nickname, 'HDFC Millennia');
    });

    test('points out an expense that looks already added', () async {
      final store = ExpenseStore()
        ..addExpense(Expense(title: 'Lunch', amount: 250, dateTime: now.subtract(const Duration(hours: 3)), accountId: 'cash'));
      final source = FakeSmsSource()..messages.add(sms('1', 'Sent Rs.250 from A/C *1234 to swiggy@icici'));
      final detection = detectionFor(store, source);
      await detection.enable();
      expect(detection.possibleDuplicate(detection.pending.single)?.title, 'Lunch');
    });
  });

  test('survives a relaunch: the list, the learned cards and where scanning got to', () async {
    sqfliteFfiInit();
    final dir = Directory.systemTemp.createTempSync('kipto_sms');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/test.db';
    final source = FakeSmsSource()
      ..messages.addAll([
        sms('1', 'Spent Rs.250 On HDFC Bank Card 5678 At SWIGGY', ago: const Duration(hours: 2)),
        sms('2', 'Spent Rs.400 On HDFC Bank Card 5678 At ZEPTO', ago: const Duration(hours: 1)),
      ]);

    var storage = await SqliteStorage.open(factory: databaseFactoryFfi, path: path);
    var store = await ExpenseStore.open(storage);
    final card = store.addAccount('HDFC Millennia', AccountType.creditCard);
    var detection = detectionFor(store, source, storage: storage);
    await detection.enable();
    final swiggy = detection.pending.last;
    final saved = detection.draftFor(swiggy).copyWith(accountId: card.id);
    store.addExpense(saved);
    detection.added(swiggy, saved);
    await store.saved;
    await detection.saved;
    await storage.close();

    storage = await SqliteStorage.open(factory: databaseFactoryFfi, path: path);
    store = await ExpenseStore.open(storage);
    detection = detectionFor(store, source, storage: storage, data: await storage.loadDetection());
    expect(detection.enabled, isTrue);
    expect(detection.pending.map((t) => (t.merchant, t.amount, t.accountHint, t.isCard)), [('Zepto', 400.0, '5678', true)]);
    expect(detection.draftFor(detection.pending.single).accountId, card.id);
    // Nothing new since, so nothing reappears.
    expect(await detection.scan(), 0);
    expect(source.lastSince, now.subtract(const Duration(hours: 1)));
    await storage.close();
  });

  group('Screens', () {
    testWidgets('Home shows what to review; Add opens the form filled in', (tester) async {
      final store = ExpenseStore();
      final source = FakeSmsSource()
        ..messages.addAll([
          sms('1', 'Sent Rs.250.00 from HDFC Bank A/C *1234 to swiggy@icici', ago: const Duration(hours: 2)),
          sms('2', 'Spent Rs.650 On HDFC Bank Card 5678 At BOOKMYSHOW', ago: const Duration(hours: 1)),
        ]);
      final detection = detectionFor(store, source);
      await detection.enable();
      await tester.pumpWidget(ExpenseTrackerApp(store: store, detection: detection));

      await tester.tap(find.text('2 spends to review'));
      await tester.pumpAndSettle();
      expect(find.text('To review'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Ignore').first);
      await tester.pumpAndSettle();
      expect(find.text('Bookmyshow'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Add expense'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '250'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Swiggy'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      expect(store.expenses.single.title, 'Swiggy');
      expect(detection.pending, isEmpty);
      expect(find.text('All caught up'), findsOneWidget);
    });

    testWidgets('Settings explains when SMS access is refused', (tester) async {
      final store = ExpenseStore();
      final detection = detectionFor(store, FakeSmsSource(granted: false, grantOnRequest: false));
      await tester.pumpWidget(ExpenseTrackerApp(store: store, detection: detection));
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(detection.enabled, isFalse);
      expect(find.textContaining('needs SMS access'), findsOneWidget);
    });
  });
}
