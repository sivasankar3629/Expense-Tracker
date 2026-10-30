import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'sms_parser.dart';

/// Where SMS come from: the phone's inbox on Android, a fake in tests.
abstract interface class SmsSource {
  Future<bool> hasPermission();

  /// Shows Android's permission prompt; true if granted.
  Future<bool> requestPermission();

  /// Makes sure new SMS can be caught as they arrive. Android grants this
  /// without asking once reading SMS is allowed.
  Future<void> ensureLivePermission();

  /// Inbox messages received after [since], newest first.
  Future<List<SmsMessage>> inbox({required DateTime since});

  /// SMS arriving while the app is running.
  Stream<SmsMessage> get arrivals;

  /// For when the permission was refused for good and must be turned on there.
  Future<void> openAppSettings();
}

/// Reads the inbox and hears new SMS through MainActivity.kt; SmsReceiver.kt
/// handles those that arrive while the app isn't running.
class AndroidSmsSource implements SmsSource {
  AndroidSmsSource() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'received') {
        _arrivals.add(smsFromMap(call.arguments as Map<Object?, Object?>));
      }
    });
  }

  static const _channel = MethodChannel('kipto/sms');
  final _arrivals = StreamController<SmsMessage>.broadcast();

  /// Only Android lets apps read SMS.
  static bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// An SMS as the Android side sends it: sender, body and time.
  static SmsMessage smsFromMap(Map<Object?, Object?> map) => SmsMessage(
        sender: map['address'] as String,
        body: map['body'] as String,
        date: DateTime.fromMillisecondsSinceEpoch((map['date'] as num).toInt()),
      );

  @override
  Future<bool> hasPermission() async => await _channel.invokeMethod<bool>('hasPermission') ?? false;

  @override
  Future<bool> requestPermission() async =>
      await _channel.invokeMethod<bool>('requestPermission') ?? false;

  @override
  Future<void> ensureLivePermission() => _channel.invokeMethod<void>('ensureLivePermission');

  @override
  Future<List<SmsMessage>> inbox({required DateTime since}) async {
    final rows = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'inbox',
      {'since': since.millisecondsSinceEpoch},
    );
    return [for (final row in rows ?? const <Map<Object?, Object?>>[]) smsFromMap(row)];
  }

  @override
  Stream<SmsMessage> get arrivals => _arrivals.stream;

  @override
  Future<void> openAppSettings() => _channel.invokeMethod<void>('openAppSettings');
}

/// For the background, where SMS arrive one at a time and nothing is read
/// from the inbox or asked for.
class NoSmsSource implements SmsSource {
  const NoSmsSource();

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> ensureLivePermission() async {}

  @override
  Future<List<SmsMessage>> inbox({required DateTime since}) async => const [];

  @override
  Stream<SmsMessage> get arrivals => const Stream.empty();

  @override
  Future<void> openAppSettings() async {}
}
