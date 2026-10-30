import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'sms_parser.dart';

/// Where SMS come from: the phone's inbox on Android, a fake in tests.
abstract interface class SmsSource {
  Future<bool> hasPermission();

  /// Shows Android's permission prompt; true if granted.
  Future<bool> requestPermission();

  /// Inbox messages received after [since], newest first.
  Future<List<SmsMessage>> inbox({required DateTime since});

  /// For when the permission was refused for good and must be turned on there.
  Future<void> openAppSettings();
}

/// Reads the inbox through MainActivity.kt.
class AndroidSmsSource implements SmsSource {
  static const _channel = MethodChannel('kipto/sms');

  /// Only Android lets apps read SMS.
  static bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> hasPermission() async => await _channel.invokeMethod<bool>('hasPermission') ?? false;

  @override
  Future<bool> requestPermission() async =>
      await _channel.invokeMethod<bool>('requestPermission') ?? false;

  @override
  Future<List<SmsMessage>> inbox({required DateTime since}) async {
    final rows = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'inbox',
      {'since': since.millisecondsSinceEpoch},
    );
    return [
      for (final row in rows ?? const <Map<Object?, Object?>>[])
        SmsMessage(
          id: row['id'] as String,
          sender: row['address'] as String,
          body: row['body'] as String,
          date: DateTime.fromMillisecondsSinceEpoch((row['date'] as num).toInt()),
        ),
    ];
  }

  @override
  Future<void> openAppSettings() => _channel.invokeMethod<void>('openAppSettings');
}
