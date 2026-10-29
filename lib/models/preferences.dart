import 'currency.dart';

/// Light or dark look; kept per phone rather than in backups.
enum ThemeChoice { system, light, dark }

/// Choices that change how the data reads, so they travel with backups.
class Preferences {
  const Preferences({this.currencyCode = 'INR', this.monthStartDay = 1});

  final String currencyCode;

  /// The day budgets and "this month" start over, e.g. 25 for payday.
  /// Up to 28, so every month has it.
  final int monthStartDay;

  static const maxMonthStartDay = 28;

  Currency get currency => Currency.byCode(currencyCode);

  Preferences copyWith({String? currencyCode, int? monthStartDay}) => Preferences(
        currencyCode: currencyCode ?? this.currencyCode,
        monthStartDay: monthStartDay ?? this.monthStartDay,
      );

  Map<String, Object?> toJson() => {
        'currency': currencyCode,
        'monthStartDay': monthStartDay,
      };

  /// Tolerates missing or odd values, falling back to the defaults.
  factory Preferences.fromJson(Map<Object?, Object?> json) => Preferences(
        currencyCode: Currency.byCode(json['currency'] as String?).code,
        monthStartDay: switch (json['monthStartDay']) {
          final num day when day >= 1 && day <= maxMonthStartDay => day.toInt(),
          _ => 1,
        },
      );

  @override
  bool operator ==(Object other) =>
      other is Preferences &&
      other.currencyCode == currencyCode &&
      other.monthStartDay == monthStartDay;

  @override
  int get hashCode => Object.hash(currencyCode, monthStartDay);
}
