import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/sqlite_storage.dart';
import '../models/currency.dart';
import 'sms_parser.dart';

/// Tells the user about a spend as its SMS arrives.
abstract interface class SpendNotifier {
  /// Android 13+ asks before an app may notify; true if allowed.
  Future<bool> requestPermission();
  Future<void> show(String smsId, {required String title, required String body});
  Future<void> cancel(String smsId);
}

/// "₹649 at Swiggy" / "HDFC Millennia · Add it to Kipto?"
({String title, String body}) spendNotificationText(
  DetectedTransaction t, {
  required Currency currency,
  String? account,
}) {
  final amount = currency.format(t.amount);
  final from = account ??
      [t.senderName, if (t.accountHint case final hint?) '${t.isCard ? 'card' : 'a/c'} ••$hint'].join(' ');
  return (
    title: t.merchant == null ? '$amount spent' : '$amount at ${t.merchant}',
    body: '$from · Add it to Kipto?',
  );
}

/// Notification buttons.
const addAction = 'add';
const ignoreAction = 'ignore';

/// A notification id for an SMS: the same in every isolate and on every run.
int notificationIdFor(String smsId) {
  var hash = 0x811c9dc5;
  for (final unit in smsId.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

/// Android notifications through flutter_local_notifications.
class LocalSpendNotifier implements SpendNotifier {
  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Call once in each isolate that shows notifications. [onResponse] hears
  /// taps on a notification or its Add button while the app is running;
  /// Ignore is handled by [onSpendNotificationActionInBackground].
  static Future<void> initialize({DidReceiveNotificationResponseCallback? onResponse}) async {
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('ic_notification')),
      onDidReceiveNotificationResponse: onResponse,
      onDidReceiveBackgroundNotificationResponse: onSpendNotificationActionInBackground,
    );
  }

  /// The SMS whose notification opened the app, if one did (and not via Ignore).
  static Future<String?> launchedFor() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    final response = details?.notificationResponse;
    if (details?.didNotificationLaunchApp != true || response?.actionId == ignoreAction) return null;
    return response?.payload;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'spends',
      'Spends from SMS',
      channelDescription: 'A spend found in a bank SMS, to add or ignore',
      // High, so it pops up over whatever is on screen.
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.recommendation,
      actions: [
        AndroidNotificationAction(addAction, 'Add', showsUserInterface: true),
        AndroidNotificationAction(ignoreAction, 'Ignore'),
      ],
    ),
  );

  @override
  Future<bool> requestPermission() async =>
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission() ??
      false;

  @override
  Future<void> show(String smsId, {required String title, required String body}) => _plugin.show(
        id: notificationIdFor(smsId),
        title: title,
        body: body,
        notificationDetails: _details,
        payload: smsId,
      );

  @override
  Future<void> cancel(String smsId) => _plugin.cancel(id: notificationIdFor(smsId));
}

/// Ignore, tapped without opening the app: runs in a background isolate, so
/// it records the choice straight in the database. The app picks it up when
/// it next comes to the foreground.
@pragma('vm:entry-point')
Future<void> onSpendNotificationActionInBackground(NotificationResponse response) async {
  final smsId = response.payload;
  if (response.actionId != ignoreAction || smsId == null) return;
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  // Not closed afterwards: the app may share the same connection.
  final storage = await SqliteStorage.open();
  await storage.removeDetected([smsId]);
  await storage.markHandled([smsId]);
}
