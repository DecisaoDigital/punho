import 'package:flutter/material.dart';

abstract final class PunhoTheme {
  static const navy = Color(0xFF10283A);
  static const navyDeep = Color(0xFF0A1C2A);
  static const orange = Color(0xFFF2A23A);
  static const softBackground = Color(0xFFF5F7FA);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: orange,
      brightness: Brightness.light,
      surface: softBackground,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: softBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      // TabBar herda a cor do AppBar (navy escuro). Sem estes overrides o M3
      // caia para labels em onSurfaceVariant (cinza), ilegivel em navy.
      tabBarTheme: TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.70),
        indicatorColor: orange,
        overlayColor: WidgetStatePropertyAll(
          Colors.white.withValues(alpha: 0.08),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFE5EAF0)),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: orange,
          foregroundColor: navyDeep,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
