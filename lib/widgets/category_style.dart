import 'package:flutter/material.dart';

/// Presentation colors only. Stored category colors and user choices stay intact.
Color categoryAccent(Color color) => switch (color.toARGB32()) {
      0xFFE53935 => const Color(0xFFEA7565), // coral
      0xFFD81B60 => const Color(0xFFDA6D99),
      0xFF8E24AA => const Color(0xFF9B75CD), // grape
      0xFF3949AB => const Color(0xFF7787D1),
      0xFF1E88E5 => const Color(0xFF55A8D9), // sky
      0xFF00897B => const Color(0xFF4CA99B),
      0xFF43A047 => const Color(0xFF7BA95E), // leaf
      0xFFF9A825 => const Color(0xFFE7B642), // sunny amber
      0xFFEF6C00 => const Color(0xFFE99851),
      _ => color,
    };

Color categorySurface(BuildContext context, Color color) {
  final theme = Theme.of(context);
  return Color.lerp(
    theme.colorScheme.surfaceContainerLow,
    categoryAccent(color),
    theme.brightness == Brightness.dark ? 0.23 : 0.22,
  )!;
}

/// A darker/lighter ink than the decorative accent, for small labels and icons.
Color categoryInk(BuildContext context, Color color) {
  final hsl = HSLColor.fromColor(categoryAccent(color));
  return hsl.withLightness(Theme.of(context).brightness == Brightness.dark ? 0.82 : 0.28).toColor();
}
