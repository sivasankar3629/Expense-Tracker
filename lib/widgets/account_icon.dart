import 'package:flutter/material.dart';

import '../models/account.dart';

/// A rounded, colour-coded tile so cash, banks and cards are told apart at a glance.
class AccountIcon extends StatelessWidget {
  const AccountIcon(this.type, {super.key, this.size = 40});

  final AccountType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (type) {
      AccountType.cash => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      AccountType.bank => (scheme.primaryContainer, scheme.onPrimaryContainer),
      AccountType.creditCard => (scheme.secondaryContainer, scheme.onSecondaryContainer),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(type.icon, color: foreground, size: size * 0.5),
    );
  }
}
