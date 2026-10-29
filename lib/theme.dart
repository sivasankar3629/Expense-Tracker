import 'package:flutter/material.dart';

const _seed = Color(0xFF285C46);

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: brightness,
  ).copyWith(
    primary: dark ? const Color(0xFFB4D9B8) : const Color(0xFF285C46),
    onPrimary: dark ? const Color(0xFF123526) : Colors.white,
    surface: dark ? const Color(0xFF121B17) : const Color(0xFFF7F6F0),
    surfaceContainerLow: dark ? const Color(0xFF1B2720) : const Color(0xFFFFFEFA),
    onSurface: dark ? const Color(0xFFE9EEE5) : const Color(0xFF202E27),
    onSurfaceVariant: dark ? const Color(0xFFB2C0B5) : const Color(0xFF626F64),
    outlineVariant: dark ? const Color(0xFF35463A) : const Color(0xFFE1E5DA),
  );
  final radius = BorderRadius.circular(16);
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    fontFamily: 'PlusJakartaSans',
  );

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: base.textTheme.copyWith(
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(letterSpacing: -0.2),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.4),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      centerTitle: false,
      scrolledUnderElevation: 0,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: scheme.onSurface,
      ),
    ),
    // Warm filled fields with a quiet outline and a clear focus state.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.focused)
            ? Color.lerp(scheme.surfaceContainerLow, scheme.primary, 0.06)!
            : scheme.surfaceContainerLow,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: 'PlusJakartaSans', fontSize: 16, fontWeight: FontWeight.w700,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 3,
      highlightElevation: 4,
      extendedTextStyle: const TextStyle(
        fontFamily: 'PlusJakartaSans', fontSize: 14, fontWeight: FontWeight.w800,
      ),
      shape: const StadiumBorder(),
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      shadowColor: const Color(0x14285C46),
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: dark ? const Color(0xFF354D3C) : const Color(0xFFE1ECD9),
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 12,
        fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
        color: states.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
      )),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: scheme.surfaceContainerLow,
      selectedColor: dark ? const Color(0xFF354D3C) : const Color(0xFFDDEBD4),
      side: BorderSide(color: scheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      labelStyle: TextStyle(
        fontFamily: 'PlusJakartaSans', fontSize: 13,
        fontWeight: FontWeight.w700, color: scheme.onSurface,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dividerTheme: DividerThemeData(
      space: 1,
      thickness: 1,
      color: scheme.outlineVariant.withValues(alpha: 0.5),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}
