import 'package:flutter/material.dart';

/// A user-made group for expenses, like "Food" or "Rent". Optional on an
/// expense, and none exist until the user creates them.
class ExpenseCategory {
  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.colorValue,
    this.monthlyBudget,
  });

  final String id;
  final String name;

  /// A key into [categoryIcons]; the key is saved rather than the icon so
  /// saved data doesn't depend on icon font internals.
  final String iconKey;

  /// ARGB colour, one of [categoryColors].
  final int colorValue;

  /// Spending limit per calendar month, or null for none. Resets each month.
  final double? monthlyBudget;

  IconData get icon => categoryIcons[iconKey] ?? Icons.label_outline;

  Color get color => Color(colorValue);

  /// Pass [clearBudget] to remove the budget, since a null [monthlyBudget]
  /// here means "keep it".
  ExpenseCategory copyWith({
    String? name,
    String? iconKey,
    int? colorValue,
    double? monthlyBudget,
    bool clearBudget = false,
  }) =>
      ExpenseCategory(
        id: id,
        name: name ?? this.name,
        iconKey: iconKey ?? this.iconKey,
        colorValue: colorValue ?? this.colorValue,
        monthlyBudget: clearBudget ? null : monthlyBudget ?? this.monthlyBudget,
      );
}

/// Icons a category can use. Keys are stored, so never rename or remove one.
const categoryIcons = <String, IconData>{
  'tag': Icons.label_outline,
  'food': Icons.restaurant,
  'coffee': Icons.local_cafe_outlined,
  'groceries': Icons.shopping_cart_outlined,
  'shopping': Icons.shopping_bag_outlined,
  'clothes': Icons.checkroom,
  'transport': Icons.directions_bus_outlined,
  'car': Icons.directions_car_outlined,
  'fuel': Icons.local_gas_station_outlined,
  'travel': Icons.flight_outlined,
  'home': Icons.home_outlined,
  'bills': Icons.receipt_long_outlined,
  'power': Icons.bolt_outlined,
  'phone': Icons.smartphone,
  'internet': Icons.wifi,
  'health': Icons.medical_services_outlined,
  'fitness': Icons.fitness_center,
  'beauty': Icons.spa_outlined,
  'education': Icons.school_outlined,
  'entertainment': Icons.movie_outlined,
  'games': Icons.sports_esports_outlined,
  'gifts': Icons.card_giftcard,
  'kids': Icons.child_care,
  'pets': Icons.pets,
  'work': Icons.work_outline,
  'savings': Icons.savings_outlined,
  'charity': Icons.volunteer_activism_outlined,
  'other': Icons.more_horiz,
};

/// Mid-tone colours that stay readable on both light and dark backgrounds.
const categoryColors = <int>[
  0xFFE53935, // red
  0xFFD81B60, // pink
  0xFF8E24AA, // purple
  0xFF3949AB, // indigo
  0xFF1E88E5, // blue
  0xFF00897B, // teal
  0xFF43A047, // green
  0xFFF9A825, // amber
  0xFFEF6C00, // orange
  0xFF6D4C41, // brown
  0xFF546E7A, // blue grey
];
