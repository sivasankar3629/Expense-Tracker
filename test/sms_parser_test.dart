import 'package:flutter_test/flutter_test.dart';

import 'package:expense_tracker/sms/sms_parser.dart';

DetectedTransaction? parse(String body, {String sender = 'VM-BANKIN-S'}) =>
    parseBankSms(SmsMessage(id: '1', sender: sender, body: body, date: DateTime(2026, 10, 29, 10, 42)));

void main() {
  group('Spends are read from the usual wordings', () {
    // (description, SMS, amount, merchant, last digits, card?)
    final cases = <(String, String, double, String?, String?, bool)>[
      (
        'UPI, multi-line, "Sent … To"',
        'Sent Rs.250.00\nFrom HDFC Bank A/C *1234\nTo SWIGGY\nOn 29/10/26\nRef 430212345678\n'
            'Not You?\nCall 18002586161/SMS BLOCK UPI to 7308080808',
        250, 'Swiggy', '1234', false,
      ),
      (
        'credit card, "Spent … On … Card … At"',
        'Spent Rs.650 On HDFC Bank Card 5678 At BOOKMYSHOW On 2026-10-26:20:15:10.Not You? '
            'To Block+Reissue Call 18002323232/SMS BLOCK CC 5678 to 7308080808',
        650, 'Bookmyshow', '5678', true,
      ),
      (
        'amount without currency, "trf to"',
        'Dear UPI user A/C X1234 debited by 250.0 on date 29Oct26 trf to SWIGGY Refno 430212345678. '
            'If not u? call 1800111109. -SBI',
        250, 'Swiggy', '1234', false,
      ),
      (
        'payee before "credited"',
        'ICICI Bank Acct XX234 debited for Rs 250.00 on 29-Oct-26; SWIGGY credited. UPI:430212345678. '
            'Call 18002662 for dispute. SMS BLOCK 234 to 9215676766.',
        250, 'Swiggy', '234', false,
      ),
      (
        'card, payee after the date, limit afterwards',
        'INR 650.00 spent using ICICI Bank Card XX5678 on 26-Oct-26 on BOOKMYSHOW. Avl Limit: INR 1,23,456.00. '
            'If not you, call 1800 2662/SMS BLOCK 5678 to 9215676766',
        650, 'Bookmyshow', '5678', true,
      ),
      (
        'UPI path "UPI/P2M/ref/NAME"',
        'INR 250.00 debited\nA/c no. XX1234\n29-10-26, 10:42:11\nUPI/P2M/430212345678/SWIGGY\n'
            'Not you? SMS BLOCKUPI Cust ID to 919951860002\nAxis Bank',
        250, 'Swiggy', '1234', false,
      ),
      (
        'UPI handle as the payee',
        'Sent Rs.250.00 from Kotak Bank AC X1234 to swiggy@icici on 29-10-26.UPI Ref 430212345678. '
            'Not you, https://kotak.com/KBANKT/Fraud',
        250, 'Swiggy', '1234', false,
      ),
      (
        'card, "ending … at"',
        'Rs.650.00 spent on your SBI Credit Card ending 5678 at BOOKMYSHOW on 26/10/26. '
            'Trxn. not done by you? Report at https://sbicard.com/Dispute',
        650, 'Bookmyshow', '5678', true,
      ),
      (
        '"towards UPI/ref/NAME", balance afterwards',
        'Your A/C XXXXXX1234 has been debited with INR 250.00 on 29/10/2026 10:42 towards UPI/430212345678/SWIGGY. '
            'Avl bal INR 12,345.67',
        250, 'Swiggy', '1234', false,
      ),
      (
        'card with mixed-case merchant',
        "You've spent INR 1,299.00 on your OneCard credit card ending 5678 at Amazon Pay India on 29 Oct.",
        1299, 'Amazon Pay India', '5678', true,
      ),
      (
        'capital DEBITED, "towards" a person',
        'An amount of INR 2,000.00 has been DEBITED to your account XXX1234 on 29/10/2026 towards RAHUL SHARMA. '
            'Total Avail.Bal INR 8,000.00. - Canara Bank',
        2000, 'Rahul Sharma', '1234', false,
      ),
      (
        'ATM withdrawal',
        'Rs.2000.00 withdrawn from A/c XX1234 on 29-10-26 at ATM HDFC0001234. Avl Bal Rs 6,000.00',
        2000, 'ATM withdrawal', '1234', false,
      ),
      (
        'personal UPI handle',
        'Rs 120.00 debited from A/c **1234 on 29-10-26 to VPA rahul.sharma@okaxis (UPI Ref No 430212345678).',
        120, 'Rahul Sharma', '1234', false,
      ),
      (
        'phone-number UPI handle has no payee name',
        'Rs 99 sent from A/c XX1234 to 9876543210@ybl on 29-10-26. UPI Ref 430212345678',
        99, null, '1234', false,
      ),
      (
        '₹ sign and "paid"',
        '₹349 paid to Zomato from your account ending 1234. UPI Ref: 430212345678',
        349, 'Zomato', '1234', false,
      ),
    ];

    for (final (description, body, amount, merchant, hint, isCard) in cases) {
      test(description, () {
        final t = parse(body);
        expect(t, isNotNull, reason: body);
        expect(t!.amount, amount);
        expect(t.merchant, merchant);
        expect(t.accountHint, hint);
        expect(t.isCard, isCard);
      });
    }
  });

  group('Not spends', () {
    final notSpends = <(String, String)>[
      ('OTP', '123456 is your OTP for txn of Rs.650 at BOOKMYSHOW on HDFC Bank card 5678. Valid for 5 mins.'),
      ('money in', 'Rs.5000.00 credited to A/c XX1234 on 29-10-26 by NEFT from ACME CORP. Avl Bal Rs 15,000'),
      ('refund', 'Refund of Rs 250 for SWIGGY has been credited to your A/c XX1234 on 29-10-26.'),
      ('promotion', 'Get Rs.500 cashback when you pay Rs.2000 or more with your HDFC Bank Card. T&C apply.'),
      ('bill', 'HDFC Bank Credit Card XX5678 statement: Total due Rs.12,345, Min due Rs.620, due by 05-11-26.'),
      ('future debit', 'Rs 499 will be debited from your A/c XX1234 on 01-11-26 towards NETFLIX.'),
      ('declined', 'Your txn of Rs 250 at SWIGGY using card XX5678 has been declined due to insufficient funds.'),
      ('collect request', 'You have received a collect request of Rs.250 from swiggy@icici. Pay only if you know them.'),
      ('balance', 'Avl bal in A/c XX1234 is Rs 12,345.67 as on 29-10-26.'),
      ('reversal', 'Rs 250 debited from A/c XX1234 on 29-10-26 has been reversed.'),
    ];
    for (final (description, body) in notSpends) {
      test(description, () => expect(parse(body), isNull, reason: body));
    }

    test('personal messages from phone numbers', () {
      expect(parse('Sent Rs 500 to your A/c XX1234 for dinner', sender: '+919876543210'), isNull);
    });
  });

  test('keeps the UPI reference and a readable sender', () {
    final t = parse('Sent Rs.250.00 from Kotak Bank AC X1234 to swiggy@icici. UPI Ref 430212345678',
        sender: 'JD-KOTAKB-S')!;
    expect(t.reference, '430212345678');
    expect(t.senderName, 'KOTAKB');
  });

  test('long account numbers are cut to their last four digits', () {
    expect(parse('Rs 100 debited from A/c XXXXXX987654 to swiggy@icici')!.accountHint, '7654');
  });
}
