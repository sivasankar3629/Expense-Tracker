import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:expense_tracker/data/sqlite_storage.dart';
import 'package:expense_tracker/main.dart';
import 'package:expense_tracker/models/currency.dart';
import 'package:expense_tracker/sms/detection_storage.dart';
import 'package:expense_tracker/sms/sms_detection.dart';
import 'package:expense_tracker/sms/sms_parser.dart';
import 'package:expense_tracker/sms/sms_source.dart';
import 'package:expense_tracker/sms/spend_notifications.dart';
import 'package:expense_tracker/state/expense_store.dart';

import 'sms_detection_test.dart' show FakeSmsSource;

class FakeNotifier implements SpendNotifier {
  final shown = <String, ({String title, String body})>{};
  final cancelled = <String>[];
  bool permissionAsked = false;

  @override
  Future<bool> requestPermission() async => permissionAsked = true;

  @override
  Future<void> show(String smsId, {required String title, required String body}) async =>
      shown[smsId] = (title: title, body: body);

  @override
  Future<void> cancel(String smsId) async => cancelled.add(smsId);
}

final now = DateTime(2026, 10, 30, 12);
const swiggyBody = 'Spent Rs.649 On HDFC Bank Card 5678 At SWIGGY On 2026-10-30:12:10:01';

SmsMessage arrived(String body, {String sender = 'VM-HDFCBK', Duration ago = Duration.zero}) =>
    SmsMessage(sender: sender, body: body, date: now.subtract(ago));

Future<SmsDetection> enabledDetection({
  ExpenseStore? store,
  FakeSmsSource? source,
  FakeNotifier? notifier,
  DetectionStorage? storage,
}) async {
  final detection = SmsDetection(
    store: store ?? ExpenseStore(),
    source: source ?? FakeSmsSource(),
    storage: storage ?? InMemoryDetectionStorage(),
    notifier: notifier,
    clock: () => now,
  );
  await detection.enable();
  return detection;
}

void main() {
  test('the same SMS read from the inbox, caught as it arrived and seen in its notification is one SMS', () {
    final live = arrived(swiggyBody);
    final fromInbox = SmsMessage(sender: 'VM-HDFCBK', body: swiggyBody, date: now.add(const Duration(seconds: 3)));
    expect(live.id, fromInbox.id);
    // A notification names the bank, and may lay the text out a little differently.
    expect(arrived(' ${swiggyBody.replaceFirst(' ', '\n')} ', sender: 'HDFC Bank').id, live.id);
    expect(arrived('$swiggyBody.').id, isNot(live.id));
  });

  group('An RCS message, read from its notification', () {
    const flipkart = 'Rs.3,265.00 spent on your SBI Credit Card ending 4913 at FLIPKARTINTERNETPVTLTD on 31/10/26. '
        'Trxn. not done by you? Report at https://sbicard.com/Dispute';

    test('is a spend like any SMS, named after the sender the notification shows', () async {
      final notifier = FakeNotifier();
      final detection = await enabledDetection(notifier: notifier);
      final t = (await detection.receive(arrived(flipkart, sender: 'SBI Card')))!;
      expect((t.amount, t.accountHint, t.isCard), (3265.0, '4913', true));
      expect(notifier.shown[t.smsId]?.body, 'SBI Card card ••4913 · Add it to Kipto?');
    });

    test('once added, doesn’t come back when the same message is in the SMS inbox', () async {
      final source = FakeSmsSource();
      final store = ExpenseStore();
      final detection = await enabledDetection(store: store, source: source);
      final t = (await detection.receive(arrived(flipkart, sender: 'SBI Card', ago: const Duration(minutes: 5))))!;
      detection.added(t, detection.draftFor(t));

      source.messages.add(SmsMessage(sender: 'JD-SBICRD-S', body: flipkart, date: now.subtract(const Duration(minutes: 4))));
      expect(await detection.scan(), 0);
      expect(detection.pending, isEmpty);
    });
  });

  test('notification access is checked on start and noticed when it changes', () async {
    final source = FakeSmsSource();
    final detection = await enabledDetection(source: source);
    var changes = 0;
    detection.addListener(() => changes++);

    detection.startAutoScan();
    await pumpEventQueue();
    expect(detection.notificationAccess, isFalse);

    source.notificationAccess = true;
    await detection.refreshNotificationAccess();
    expect(detection.notificationAccess, isTrue);
    final afterChange = changes;
    await detection.refreshNotificationAccess();
    expect(changes, afterChange, reason: 'nothing changed, so nothing to redraw');
  });

  test('notification text: amount and payee, then where it was paid from', () {
    final t = parseBankSms(arrived(swiggyBody))!;
    expect(spendNotificationText(t, currency: Currency.inr),
        (title: '₹649 at Swiggy', body: 'HDFCBK card ••5678 · Add it to Kipto?'));
    expect(spendNotificationText(t, currency: Currency.inr, account: 'HDFC Millennia').body,
        'HDFC Millennia · Add it to Kipto?');
    final noPayee = parseBankSms(arrived('Rs 99 sent from A/c XX1234 to 9876543210@ybl'))!;
    expect(spendNotificationText(noPayee, currency: Currency.byCode('USD')).title, r'$99 spent');
  });

  group('A new SMS', () {
    test('that is a spend joins the list and pops up a notification', () async {
      final notifier = FakeNotifier();
      final detection = await enabledDetection(notifier: notifier);
      expect(notifier.permissionAsked, isTrue);

      final t = await detection.receive(arrived(swiggyBody));
      expect(t!.merchant, 'Swiggy');
      expect(detection.pending.single.smsId, t.smsId);
      expect(notifier.shown[t.smsId]?.title, '₹649 at Swiggy');
    });

    test('is left alone when it isn’t a spend, detection is off, or it’s already known', () async {
      final notifier = FakeNotifier();
      final off = SmsDetection(
        store: ExpenseStore(), source: FakeSmsSource(), storage: InMemoryDetectionStorage(), notifier: notifier,
      );
      expect(await off.receive(arrived(swiggyBody)), isNull);

      final detection = await enabledDetection(notifier: notifier);
      expect(await detection.receive(arrived('123456 is your OTP for txn of Rs.649 at SWIGGY')), isNull);
      await detection.receive(arrived(swiggyBody));
      // Again, and the same payment as told by the bank account.
      expect(await detection.receive(arrived(swiggyBody)), isNull);
      expect(await detection.receive(arrived('Rs 649 debited from A/c XX1234 at SWIGGY', sender: 'AD-HDFCBK')), isNull);
      expect(detection.pending, hasLength(1));
      expect(notifier.shown, hasLength(1));
    });

    test('arriving while the app is open is caught too', () async {
      final source = FakeSmsSource();
      final detection = await enabledDetection(source: source);
      detection.startAutoScan();
      expect(source.livePermissionAsked, isTrue);

      source.arrivalsController.add(arrived(swiggyBody));
      await pumpEventQueue();
      expect(detection.pending.single.merchant, 'Swiggy');
    });
  });

  test('once added or ignored, it doesn’t come back from the inbox, and its notification goes', () async {
    final source = FakeSmsSource();
    final notifier = FakeNotifier();
    final detection = await enabledDetection(source: source, notifier: notifier);
    final t = (await detection.receive(arrived(swiggyBody, ago: const Duration(minutes: 5))))!;
    detection.ignore(t);
    expect(notifier.cancelled, [t.smsId]);

    // The default SMS app files it in the inbox, after the last scan.
    source.messages.add(SmsMessage(sender: 'VM-HDFCBK', body: swiggyBody, date: now.subtract(const Duration(minutes: 5))));
    expect(await detection.scan(), 0);
    expect(detection.pending, isEmpty);
  });

  test('what the background did is picked up when the app comes back', () async {
    sqfliteFfiInit();
    final dir = Directory.systemTemp.createTempSync('kipto_live');
    addTearDown(() => dir.deleteSync(recursive: true));
    final storage = await SqliteStorage.open(factory: databaseFactoryFfi, path: '${dir.path}/test.db');
    addTearDown(storage.close);
    final store = await ExpenseStore.open(storage);
    final app = await enabledDetection(store: store, storage: storage);
    await app.saved;

    // An SMS while the app is closed: handled by a second instance, as the
    // background engine does.
    final background = SmsDetection(
      store: store, source: const NoSmsSource(), storage: storage, data: await storage.loadDetection(),
    );
    final t = (await background.receive(arrived(swiggyBody)))!;
    await background.saved;
    expect(app.pending, isEmpty);
    await app.reload();
    expect(app.pending.single.smsId, t.smsId);

    // Ignore tapped on its notification, also in the background.
    await storage.removeDetected([t.smsId]);
    await storage.markHandled([t.smsId]);
    await app.reload();
    expect(app.pending, isEmpty);
    expect(await app.receive(arrived(swiggyBody)), isNull);
  });

  group('Tapping the notification', () {
    testWidgets('opens that spend’s form, filled in', (tester) async {
      final store = ExpenseStore();
      final detection = await enabledDetection(store: store);
      final t = (await detection.receive(arrived(swiggyBody)))!;
      final taps = StreamController<String>();
      await tester.pumpWidget(ExpenseTrackerApp(store: store, detection: detection, openSpendRequests: taps.stream));
      await tester.pumpAndSettle();

      taps.add(t.smsId);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Add expense'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '649'), findsOneWidget);
      // Everything but the title: that field waits, empty, keyboard up.
      final title = find.descendant(of: find.widgetWithText(TextFormField, 'Title'), matching: find.byType(EditableText));
      expect(tester.widget<EditableText>(title).focusNode.hasFocus, isTrue);
      expect(tester.widget<EditableText>(title).controller.text, isEmpty);

      await tester.enterText(title, 'Biryani');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      expect(store.expenses.single.title, 'Biryani');
      expect(detection.pending, isEmpty);
      await taps.close();
    });

    testWidgets('for a spend already dealt with shows the review list', (tester) async {
      final store = ExpenseStore();
      final detection = await enabledDetection(store: store);
      final taps = StreamController<String>();
      await tester.pumpWidget(ExpenseTrackerApp(store: store, detection: detection, openSpendRequests: taps.stream));
      await tester.pumpAndSettle();

      taps.add('gone');
      await tester.pumpAndSettle();
      expect(find.text('To review'), findsOneWidget);
      await taps.close();
    });
  });
}
