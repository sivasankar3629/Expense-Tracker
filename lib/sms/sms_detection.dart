import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/account.dart';
import '../models/expense.dart';
import '../state/expense_store.dart';
import 'detection_storage.dart';
import 'sms_parser.dart';
import 'sms_source.dart';

/// How turning detection on went.
enum SmsAccess { granted, denied }

/// Finds spends in bank SMS and keeps them for review, so adding one is a
/// tap and a check rather than typing it out. Nothing is added without the
/// user saying so.
class SmsDetection extends ChangeNotifier {
  SmsDetection({
    required this.store,
    required this.source,
    required this.storage,
    DetectionData data = const DetectionData(),
    DateTime Function()? clock,
  })  : _enabled = data.enabled,
        _scannedUntil = data.scannedUntil,
        _pending = [...data.pending]..sort(_newestFirst),
        _accountHints = {...data.accountHints},
        _clock = clock ?? DateTime.now;

  final ExpenseStore store;
  final SmsSource source;
  final DetectionStorage storage;
  final DateTime Function() _clock;

  bool _enabled;
  DateTime? _scannedUntil;
  final List<DetectedTransaction> _pending;
  final Map<String, String> _accountHints;
  Future<void> _pendingWrites = Future.value();
  Future<int>? _scanning;
  AppLifecycleListener? _lifecycle;

  /// How far back the first scan looks.
  static const firstScanDays = 30;

  static int _newestFirst(DetectedTransaction a, DetectedTransaction b) => b.date.compareTo(a.date);

  bool get enabled => _enabled;

  /// Newest first.
  List<DetectedTransaction> get pending => List.unmodifiable(_pending);

  /// Completes once every change made so far has been saved.
  Future<void> get saved => _pendingWrites;

  void _save(Future<void> Function() write) {
    _pendingWrites = _pendingWrites.then((_) => write()).catchError(
      (Object error, StackTrace stack) => debugPrint('Failed to save detection: $error\n$stack'),
    );
  }

  /// Scans whenever the app comes back to the foreground, as well as now.
  void startAutoScan() {
    _lifecycle ??= AppLifecycleListener(onResume: () => unawaited(scan()));
    unawaited(scan());
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  /// Asks for SMS access and, if given, scans the last [firstScanDays] days.
  Future<SmsAccess> enable() async {
    if (!await source.hasPermission() && !await source.requestPermission()) {
      return SmsAccess.denied;
    }
    _enabled = true;
    notifyListeners();
    _save(() => storage.saveDetectionEnabled(true));
    await scan();
    return SmsAccess.granted;
  }

  /// Stops scanning and drops what's waiting; what was already added stays.
  void disable() {
    _enabled = false;
    final ids = [for (final t in _pending) t.smsId];
    _pending.clear();
    notifyListeners();
    _save(() => storage.saveDetectionEnabled(false));
    _save(() => storage.removeDetected(ids));
  }

  /// Looks at SMS received since the last scan. Returns how many new spends
  /// were found. Calls made while a scan is running share it.
  Future<int> scan() => _scanning ??= _scan().whenComplete(() => _scanning = null);

  Future<int> _scan() async {
    if (!_enabled) return 0;
    if (!await source.hasPermission()) {
      // Taken back in Android's settings: stop until turned on again.
      disable();
      return 0;
    }
    final now = _clock();
    final since = _scannedUntil ?? now.subtract(const Duration(days: firstScanDays));
    final List<SmsMessage> messages;
    try {
      messages = await source.inbox(since: since);
    } catch (e, stack) {
      debugPrint('Could not read SMS: $e\n$stack');
      return 0;
    }

    final found = <DetectedTransaction>[];
    for (final sms in messages) {
      final t = parseBankSms(sms);
      if (t == null || _pending.any((p) => p.smsId == t.smsId)) continue;
      if ([..._pending, ...found].any((p) => _sameSpend(p, t))) continue;
      found.add(t);
    }
    final newest = messages.fold<DateTime>(since, (latest, m) => m.date.isAfter(latest) ? m.date : latest);
    _scannedUntil = newest;
    _save(() => storage.saveScannedUntil(newest));
    if (found.isEmpty || !_enabled) return 0;
    _pending
      ..addAll(found)
      ..sort(_newestFirst);
    notifyListeners();
    _save(() => storage.addDetected(found));
    return found.length;
  }

  /// The same payment told twice, e.g. by the bank and by the card.
  static bool _sameSpend(DetectedTransaction a, DetectedTransaction b) {
    if (a.reference != null && a.reference == b.reference) return true;
    return a.amount == b.amount && a.date.difference(b.date).inMinutes.abs() <= 3;
  }

  /// Fills in the add form: the amount, date and payee from the SMS, the
  /// account from its card or account ending, and the category (and, if
  /// the ending is new, the account) last used for the same payee.
  Expense draftFor(DetectedTransaction t) {
    final title = t.merchant ?? (t.isCard ? 'Card payment' : 'Payment');
    final previous = _lastExpenseTitled(title);
    final hinted = t.accountHint == null ? null : store.accountById(_accountHints[t.accountHint] ?? '');
    final account = hinted ??
        (previous == null ? null : store.accountById(previous.accountId)) ??
        store.lastUsedAccount;
    return Expense(
      title: title,
      amount: t.amount,
      dateTime: t.date,
      accountId: account.id,
      categoryId: store.categoryById(previous?.categoryId)?.id,
    );
  }

  Expense? _lastExpenseTitled(String title) {
    final wanted = title.toLowerCase();
    for (final e in store.expenses) {
      if (e.title.toLowerCase() == wanted) return e;
    }
    return null;
  }

  /// An expense already in the app that looks like this one, e.g. added by
  /// hand before the SMS was seen.
  Expense? possibleDuplicate(DetectedTransaction t) {
    for (final e in store.expenses) {
      if (e.amount == t.amount && e.dateTime.difference(t.date).inHours.abs() < 24) return e;
    }
    return null;
  }

  /// Account named for a detected transaction, if its ending is known.
  Account? accountFor(DetectedTransaction t) =>
      t.accountHint == null ? null : store.accountById(_accountHints[t.accountHint] ?? '');

  /// Called once the user has saved [expense] from [t]: it leaves the review
  /// list, and its account ending now points at the account they chose.
  void added(DetectedTransaction t, Expense expense) {
    _pending.removeWhere((p) => p.smsId == t.smsId);
    final hint = t.accountHint;
    if (hint != null && expense.accountId != Account.cash.id) {
      _accountHints[hint] = expense.accountId;
      _save(() => storage.saveAccountHint(hint, expense.accountId));
    }
    notifyListeners();
    _save(() => storage.removeDetected([t.smsId]));
  }

  void ignore(DetectedTransaction t) {
    _pending.removeWhere((p) => p.smsId == t.smsId);
    notifyListeners();
    _save(() => storage.removeDetected([t.smsId]));
  }

  void ignoreAll() {
    final ids = [for (final t in _pending) t.smsId];
    _pending.clear();
    notifyListeners();
    _save(() => storage.removeDetected(ids));
  }
}
