import 'package:flutter/material.dart';

enum AccountType {
  cash('Cash', 'Cash', Icons.payments_outlined),
  bank('Bank account', 'Bank', Icons.account_balance_outlined),
  creditCard('Credit card', 'Credit card', Icons.credit_card_outlined);

  const AccountType(this.label, this.shortLabel, this.icon);

  final String label;

  /// Fits in tight spots such as the type toggle.
  final String shortLabel;
  final IconData icon;
}

class Account {
  const Account({required this.id, required this.nickname, required this.type});

  /// Built in and always available, so an expense never lacks a source.
  static const cash = Account(id: 'cash', nickname: 'Cash', type: AccountType.cash);

  final String id;
  final String nickname;
  final AccountType type;

  Account copyWith({String? nickname, AccountType? type}) => Account(
        id: id,
        nickname: nickname ?? this.nickname,
        type: type ?? this.type,
      );
}
