import 'package:flutter/material.dart';

import '../models/category.dart';
import 'category_style.dart';

/// A category's icon on a soft tint of its colour.
class CategoryIcon extends StatelessWidget {
  const CategoryIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
  });

  CategoryIcon.of(ExpenseCategory category, {Key? key, double size = 40})
      : this(key: key, icon: category.icon, color: category.color, size: size);

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: categoryAccent(color).withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: categoryInk(context, color), size: size * 0.55),
    );
  }
}
