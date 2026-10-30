/// One SMS as read from the phone's inbox.
class SmsMessage {
  const SmsMessage({required this.id, required this.sender, required this.body, required this.date});

  final String id;

  /// e.g. "VM-HDFCBK", or a phone number for personal messages.
  final String sender;
  final String body;
  final DateTime date;
}

/// Money that left an account or card, as told by a bank's SMS.
class DetectedTransaction {
  const DetectedTransaction({
    required this.smsId,
    required this.amount,
    required this.date,
    required this.sender,
    required this.body,
    this.merchant,
    this.accountHint,
    this.isCard = false,
    this.reference,
  });

  final String smsId;
  final double amount;
  final DateTime date;
  final String sender;
  final String body;

  /// Who was paid, e.g. "Swiggy"; null when the SMS doesn't say clearly.
  final String? merchant;

  /// The account or card's last digits, e.g. "5678".
  final String? accountHint;
  final bool isCard;

  /// UPI or card reference number, to spot the same payment told twice.
  final String? reference;

  /// The sender without its routing prefix: "VM-HDFCBK-S" → "HDFCBK".
  String get senderName {
    final parts = sender.split('-');
    if (parts.length >= 2 && parts[0].length == 2) {
      return parts[1];
    }
    return sender;
  }
}

final _otp = RegExp(r'\botp\b|one[ -]time password|verification code|\bcvv\b', caseSensitive: false);

/// Not money that has left: future debits, requests, failures, refunds and bills.
final _notASpend = RegExp(
  r'will be (?:debited|charged)|to be debited|is due|due (?:date|on|by)|payment due|min(?:imum)?\.? (?:amt|amount) due'
  r'|total (?:amt|amount) due|\brequest(?:ed)?\b|\bfailed\b|\bdeclined\b|\breversed\b|\brefund|\bsuccessfully reversed'
  r'|\bmandate\b|\bscheduled\b|\breminder\b',
  caseSensitive: false,
);

final _debitVerb = RegExp(
  r'\b(?:debited|spent|sent|paid|withdrawn|withdrawal|purchase[ds]?|charged|txn of|transaction of|used for|debit of)\b',
  caseSensitive: false,
);

final _currencyAmount = RegExp(r'(?:rs\.?|inr|₹)\s*([\d,]*\d(?:\.\d{1,2})?)', caseSensitive: false);

/// SBI and some others give the amount without a currency: "debited by 250.0".
final _bareAmount = RegExp(
  r'\b(?:debited|spent|sent|paid|withdrawn)\s+(?:by|for|of|with)\s+([\d,]*\d(?:\.\d{1,2})?)\b',
  caseSensitive: false,
);

final _balanceContext = RegExp(r'(?:bal|balance|limit|avl|available|due)[^\d]{0,12}$', caseSensitive: false);

final _cardMask = RegExp(
  r'\bcard\b[^\d\n]{0,25}?(?:[xX*.]+\s*)?(\d{3,6})\b',
  caseSensitive: false,
);
final _accountMask = RegExp(
  r'\b(?:a/c|a/c\.|acct|account|ac)\b[^\d\n]{0,20}?(?:[xX*.]+\s*)?(\d{3,6})\b',
  caseSensitive: false,
);
final _looseMask = RegExp(r'[xX*]{2,}(\d{3,6})\b');

final _reference = RegExp(
  r'(?:ref(?:erence)?(?:\s*(?:no|number))?|\brrn|\butr|upi(?:\s*ref)?|txn\s*id)[\s.:#-]*(\d{6,})',
  caseSensitive: false,
);

final _vpa = RegExp(r'\b([\w.\-]{2,})@([a-zA-Z]{2,})\b');
final _upiPath = RegExp(r'UPI[/-](?:[A-Z0-9]+[/-])?\d{6,}[/-]([A-Za-z][\w .&' "'" r'-]{1,40})', caseSensitive: false);

/// Text after these words, up to a delimiter, is usually the payee.
final _payeeWord = RegExp(r'(?:\bat|\btrf to|\btowards|\bto|\binfo:?)\s+', caseSensitive: false);
final _payeeText = RegExp(r'^[A-Za-z][\w .&' "'" r'*/-]{1,45}');

/// ICICI style: "…; SWIGGY credited."
final _creditedPayee = RegExp(r';\s*([A-Za-z][\w .&' "'" r'-]{1,40}?)\s+credited', caseSensitive: false);

/// Some cards: "…spent … on BOOKMYSHOW."
final _onPayee = RegExp(r'\bon\s+([A-Z][A-Z0-9 &.' "'" r'*-]{2,40})', caseSensitive: true);

final _payeeEnd = RegExp(
  r'\s+(?:on|via|ref\w*|upi|avl|avbl|txn|using|for|not|if|from|by|is|has|with|bal|and|info|call|sms|rrn|utr)\b|[.,;:()\n]|\s+-|\s{2,}|\s+\d',
  caseSensitive: false,
);

final _notAPayee = RegExp(
  r'^(?:your|you|a/c|ac|acct|account|bank|card|the|a|an|upi|vpa|imps|neft|rtgs|mobile|date|beneficiary|block|dispute|report)\b'
  r'|^(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\b|^\d|bank\b',
  caseSensitive: false,
);

/// Reads a bank or card SMS. Returns null unless it clearly tells of money
/// spent: an amount, a debit word, and an account, card or UPI reference.
/// Works on wording shared by Indian banks rather than any one bank's format.
DetectedTransaction? parseBankSms(SmsMessage sms) {
  // Personal messages come from phone numbers; banks use letter codes.
  if (!RegExp(r'[A-Za-z]').hasMatch(sms.sender)) return null;
  final body = sms.body.trim();
  if (body.isEmpty || _otp.hasMatch(body) || _notASpend.hasMatch(body)) return null;
  if (!_debitVerb.hasMatch(body)) return null;

  final amount = _amountOf(body);
  if (amount == null || amount <= 0) return null;

  final card = _cardMask.firstMatch(body);
  final account = _accountMask.firstMatch(body) ?? _looseMask.firstMatch(body);
  final hintDigits = (card ?? account)?.group(1);
  final reference = _reference.firstMatch(body)?.group(1);
  final vpa = _vpa.firstMatch(body);
  // Promotions mention amounts and "paid" too, but never your account.
  if (hintDigits == null && reference == null && vpa == null) return null;

  return DetectedTransaction(
    smsId: sms.id,
    amount: amount,
    date: sms.date,
    sender: sms.sender,
    body: body,
    merchant: _payeeOf(body),
    accountHint: hintDigits?.substring(hintDigits.length > 4 ? hintDigits.length - 4 : 0),
    isCard: card != null,
    reference: reference,
  );
}

double? _amountOf(String body) {
  for (final match in _currencyAmount.allMatches(body)) {
    // Skip "Avl Bal Rs.12,345" and "Limit: INR …" ahead of the spend itself.
    final before = body.substring(match.start > 20 ? match.start - 20 : 0, match.start);
    if (_balanceContext.hasMatch(before)) continue;
    return double.tryParse(match.group(1)!.replaceAll(',', ''));
  }
  final bare = _bareAmount.firstMatch(body);
  return bare == null ? null : double.tryParse(bare.group(1)!.replaceAll(',', ''));
}

String? _payeeOf(String body) {
  if (RegExp(r'\batm\b', caseSensitive: false).hasMatch(body) &&
      RegExp(r'withdraw', caseSensitive: false).hasMatch(body)) {
    return 'ATM withdrawal';
  }
  final vpa = _vpa.firstMatch(body);
  if (vpa != null) {
    final name = _nameFromVpa(vpa.group(1)!);
    if (name != null) return name;
  }
  for (final pattern in [_upiPath, _creditedPayee]) {
    for (final match in pattern.allMatches(body)) {
      final name = _cleanPayee(match.group(1)!);
      if (name != null) return name;
    }
  }
  // Each "at"/"to"/"towards" gets its own look, so an unhelpful
  // "to your account" doesn't hide a later "towards RAHUL SHARMA".
  for (final word in _payeeWord.allMatches(body)) {
    final text = _payeeText.firstMatch(body.substring(word.end));
    final name = text == null ? null : _cleanPayee(text.group(0)!);
    if (name != null) return name;
  }
  for (final match in _onPayee.allMatches(body)) {
    final name = _cleanPayee(match.group(1)!);
    if (name != null) return name;
  }
  return null;
}

/// "swiggy@icici" → "Swiggy"; phone-number and QR-code handles say nothing.
String? _nameFromVpa(String handle) {
  if (RegExp(r'\d{5,}').hasMatch(handle)) return null;
  final words = handle.split(RegExp(r'[._-]+')).where((w) => w.isNotEmpty && !RegExp(r'^\d+$').hasMatch(w));
  if (words.isEmpty) return null;
  return _titleCase(words.join(' '));
}

String? _cleanPayee(String raw) {
  var name = raw;
  final end = _payeeEnd.firstMatch(name);
  if (end != null) name = name.substring(0, end.start);
  name = name.replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'^[*/\s-]+|[*/\s.-]+$'), '').trim();
  if (name.length < 2 || _notAPayee.hasMatch(name) || name.contains('@')) return null;
  if (name.length > 32) name = name.substring(0, 32).trim();
  return name == name.toUpperCase() || name == name.toLowerCase() ? _titleCase(name) : name;
}

String _titleCase(String text) => text
    .toLowerCase()
    .split(' ')
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
    .join(' ');
