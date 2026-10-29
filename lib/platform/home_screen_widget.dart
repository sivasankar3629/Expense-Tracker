import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../state/expense_store.dart';

/// What the home-screen widget shows: "Spent in October" and "₹21,502".
({String label, String total}) homeWidgetTexts(ExpenseStore store, DateTime now) => (
      label: 'Spent ${store.budgetMonthLabel(now)}',
      total: store.currency.format(totalOf(store.expensesInBudgetMonth(now))),
    );

/// Keeps the Android home-screen widget showing this month's spending, and
/// turns taps on its + button (or the "Add expense" app shortcut) into
/// [addRequests].
class HomeScreenWidget {
  HomeScreenWidget(this.store);

  final ExpenseStore store;

  /// Opens the add-expense form. Single-subscription, so a request made while
  /// the app is still starting waits until the app is ready for it.
  Stream<void> get addRequests => _addRequests.stream;
  final _addRequests = StreamController<void>();

  static const _provider = 'com.kipto.app.QuickAddWidget';
  static const _addUri = 'kipto://add';

  ({String label, String total})? _shown;

  /// Android only; elsewhere there's no widget to talk to.
  static bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> start() async {
    store.addListener(_refresh);
    unawaited(_refresh());
    try {
      _handle(await HomeWidget.initiallyLaunchedFromHomeWidget());
      HomeWidget.widgetClicked.listen(_handle);
    } catch (e, stack) {
      debugPrint('Home-screen widget unavailable: $e\n$stack');
    }
  }

  void _handle(Uri? uri) {
    if (uri?.toString() == _addUri) _addRequests.add(null);
  }

  Future<void> _refresh() async {
    final texts = homeWidgetTexts(store, DateTime.now());
    if (texts == _shown) return;
    _shown = texts;
    try {
      await HomeWidget.saveWidgetData<String>('label', texts.label);
      await HomeWidget.saveWidgetData<String>('total', texts.total);
      await HomeWidget.updateWidget(qualifiedAndroidName: _provider);
    } catch (e, stack) {
      _shown = null;
      debugPrint('Could not update the home-screen widget: $e\n$stack');
    }
  }
}
