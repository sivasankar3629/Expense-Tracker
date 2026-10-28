import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_tracker/data/backup.dart';
import 'package:expense_tracker/data/backup_files.dart';
import 'package:expense_tracker/data/expense_storage.dart';
import 'package:expense_tracker/models/account.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/screens/backup_screen.dart';
import 'package:expense_tracker/state/expense_store.dart';
import 'package:expense_tracker/theme.dart';

/// Stands in for the system file picker.
class FakeBackupFiles implements BackupFiles {
  FakeBackupFiles({this.toOpen});

  Uint8List? toOpen;
  String? savedName;
  Uint8List? savedBytes;

  @override
  Future<bool> save(String fileName, Uint8List bytes) async {
    savedName = fileName;
    savedBytes = bytes;
    return true;
  }

  @override
  Future<Uint8List?> open() async => toOpen;
}

const _card = Account(id: 'card-1', nickname: 'HDFC Millennia', type: AccountType.creditCard);

StoredData _sampleData() => StoredData(
      accounts: const [_card],
      expenses: [
        Expense(
          id: 'e1',
          title: 'Lunch',
          amount: 180.5,
          dateTime: DateTime(2026, 10, 27, 13, 5),
          accountId: _card.id,
          notes: 'With team',
        ),
        Expense(
          id: 'e2',
          title: 'Tea',
          amount: 12,
          dateTime: DateTime(2026, 10, 28, 9, 30),
          accountId: Account.cash.id,
        ),
      ],
      lastUsedAccountId: _card.id,
    );

Map<String, Object?> _json(Backup backup) =>
    jsonDecode(backup.encode()) as Map<String, Object?>;

void main() {
  group('Backup file format', () {
    test('round-trips everything exactly', () {
      final original = Backup(data: _sampleData(), exportedAt: DateTime(2026, 10, 28, 10, 32));
      final restored = Backup.decode(original.encode());

      expect(restored.exportedAt, original.exportedAt);
      expect(restored.data.lastUsedAccountId, _card.id);
      expect(restored.data.accounts.single.nickname, 'HDFC Millennia');
      expect(restored.data.accounts.single.type, AccountType.creditCard);

      final lunch = restored.data.expenses.first;
      expect(lunch.id, 'e1');
      expect(lunch.amount, 180.5);
      expect(lunch.dateTime, DateTime(2026, 10, 27, 13, 5));
      expect(lunch.accountId, _card.id);
      expect(lunch.notes, 'With team');
    });

    test('names the file after the backup date', () {
      final backup = Backup(data: const StoredData(), exportedAt: DateTime(2026, 3, 7));
      expect(backup.fileName, 'kipto-backup-2026-03-07.json');
    });

    test('rejects files that are not backups', () {
      expect(() => Backup.decode('not json'), throwsA(isA<BackupFormatException>()));
      expect(() => Backup.decode('{"app": "other"}'), throwsA(isA<BackupFormatException>()));
      expect(() => Backup.decode('[1, 2]'), throwsA(isA<BackupFormatException>()));
    });

    test('rejects backups from a newer app version', () {
      final json = _json(Backup(data: const StoredData(), exportedAt: DateTime(2026)))
        ..['version'] = Backup.currentVersion + 1;
      expect(
        () => Backup.decode(jsonEncode(json)),
        throwsA(isA<BackupFormatException>().having((e) => e.message, 'message', contains('newer'))),
      );
    });

    test('rejects damaged backups instead of half-restoring them', () {
      final json = _json(Backup(data: _sampleData(), exportedAt: DateTime(2026)));
      (json['expenses'] as List).add({'id': 'bad', 'title': 'Broken', 'amountPaise': 'lots'});
      expect(
        () => Backup.decode(jsonEncode(json)),
        throwsA(isA<BackupFormatException>().having((e) => e.message, 'message', contains('damaged'))),
      );
    });

    test('moves expenses of a missing account to Cash', () {
      final json = _json(Backup(data: _sampleData(), exportedAt: DateTime(2026)))
        ..['accounts'] = <Object?>[];
      final restored = Backup.decode(jsonEncode(json));
      expect(restored.data.expenses.map((e) => e.accountId), everyElement(Account.cash.id));
      expect(restored.data.lastUsedAccountId, isNull);
    });
  });

  group('Backup screen', () {
    Future<void> pumpScreen(WidgetTester tester, ExpenseStore store, BackupFiles files) {
      return tester.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.light),
        home: BackupScreen(store: store, files: files),
      ));
    }

    testWidgets('backing up saves a restorable file and records the time', (tester) async {
      final store = ExpenseStore(data: _sampleData());
      final files = FakeBackupFiles();
      await pumpScreen(tester, store, files);
      expect(find.text('Never backed up'), findsOneWidget);

      await tester.tap(find.text('Back up now'));
      await tester.pumpAndSettle();

      expect(files.savedName, startsWith('kipto-backup-'));
      final saved = Backup.decode(utf8.decode(files.savedBytes!));
      expect(saved.data.expenses.map((e) => e.id), ['e2', 'e1']);
      expect(saved.data.accounts.single.id, _card.id);
      expect(store.lastBackupAt, isNotNull);
      expect(find.textContaining('Last backup:'), findsOneWidget);
      expect(find.text('Backup saved'), findsOneWidget);
    });

    testWidgets('restoring asks first, then replaces everything', (tester) async {
      final store = ExpenseStore()
        ..addExpense(Expense(
          title: 'Old',
          amount: 1,
          dateTime: DateTime(2026),
          accountId: Account.cash.id,
        ));
      final backup = Backup(data: _sampleData(), exportedAt: DateTime(2026, 10, 28, 10, 32));
      final files = FakeBackupFiles(toOpen: utf8.encode(backup.encode()));
      await pumpScreen(tester, store, files);

      await tester.tap(find.text('Choose backup file'));
      await tester.pumpAndSettle();

      expect(find.text('Restore this backup?'), findsOneWidget);
      expect(find.text('2 expenses · 1 account'), findsOneWidget);
      expect(find.textContaining('replaces the 1 expense and 0 accounts'), findsOneWidget);

      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();

      expect(store.expenses.map((e) => e.title), ['Tea', 'Lunch']);
      expect(store.accountById(_card.id)?.nickname, 'HDFC Millennia');
      expect(store.lastUsedAccount.id, _card.id);
      expect(find.text('Restored 2 expenses'), findsOneWidget);
    });

    testWidgets('cancelling a restore changes nothing', (tester) async {
      final store = ExpenseStore();
      final backup = Backup(data: _sampleData(), exportedAt: DateTime(2026));
      await pumpScreen(tester, store, FakeBackupFiles(toOpen: utf8.encode(backup.encode())));

      await tester.tap(find.text('Choose backup file'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(store.expenses, isEmpty);
    });

    testWidgets('a wrong file shows an error and changes nothing', (tester) async {
      final store = ExpenseStore(data: _sampleData());
      await pumpScreen(tester, store, FakeBackupFiles(toOpen: utf8.encode('hello')));

      await tester.tap(find.text('Choose backup file'));
      await tester.pumpAndSettle();

      expect(find.text('Can’t restore'), findsOneWidget);
      expect(find.text('This file isn’t a backup from this app.'), findsOneWidget);
      expect(store.expenses, hasLength(2));
    });
  });
}
